`timescale 1ns / 1ns

// Driver for the Futaba 16-SD-13GINK 16-digit 5x7 VFD (built-in driver IC), 3-wire serial.
//
// Shows value[47:0] as an unsigned decimal number, right-justified, leading zeros blank.
// Commas every 3 digits when the whole string fits in 16 positions (a comma takes a full
// character cell on a 5x7 tube), i.e. for values < 10^12; larger values show plain digits.
//
// Bus (datasheet): CS active low frames a transfer; bits shift in on the rising edge of CP,
// LSB first; CP idles high.  CP max 0.5 MHz.  Every update re-sends the full init (the
// datasheet recommends periodic re-init to recover from noise), then the digits, then E8.
module vfd_16sd13gink #(
    parameter integer CLK_HZ      = 50_000_000,
    parameter integer SCLK_HZ     = 10_000,      // CP rate; datasheet max 500_000
    parameter integer COMMAS      = 1,           // 0 = never use commas
    parameter [7:0]   DIM         = 8'h70,       // brightness 0..255 (240+ = max)
    // Idle clocks between updates.  Time between samples of `value` = HOLD_CYCLES + 50 + 472*HALF
    // (from a cycle-level model of this FSM).  If `value` is a free-running counter, make that
    // total coprime with 10 (odd, not a multiple of 5), or the bottom decimal digits will look
    // frozen or will only toggle between a few values.  The default gives an odd total.
    parameter integer HOLD_CYCLES = 12_501
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [63:0] value,        // only [47:0] is displayed
    output reg         vfd_clk,      // CP
    output reg         vfd_cs,       // CS, active low
    output reg         vfd_sdi       // DA
);
    initial begin vfd_clk = 1'b1; vfd_cs = 1'b1; vfd_sdi = 1'b0; end   // idle levels from time 0

    localparam integer HALF = ((CLK_HZ / (2 * SCLK_HZ)) < 1) ? 1 : (CLK_HZ / (2 * SCLK_HZ));
    localparam integer POR_CYCLES = CLK_HZ / 100;   // 10 ms after reset (datasheet: >= 2 ms)
    localparam [3:0]   GAP_TICKS  = 4'd4;           // idle half-periods between bytes/frames
    localparam [31:0]  POR_LAST   = POR_CYCLES - 1;
    localparam [31:0]  HOLD_LAST  = HOLD_CYCLES - 1;
    localparam [31:0]  HALF_LAST  = HALF - 1;
    localparam [3:0]   GAP_LAST   = GAP_TICKS - 4'd1;

    localparam [3:0] S_POR = 0, S_CONV_INIT = 1, S_CONV = 2, S_FMT = 3, S_CS_ASSERT = 4,
                     S_CS_SETUP = 5, S_BIT_LOW = 6, S_BIT_HIGH = 7, S_BYTE_GAP = 8,
                     S_CS_HIGH = 9, S_FRAME_GAP = 10, S_HOLD = 11;

    reg [3:0]   st   = S_POR;
    reg [47:0]  bin  = 48'd0;
    reg [59:0]  bcd  = 60'd0;        // 15 BCD digits, bcd[3:0] = least significant
    reg [5:0]   cnt  = 6'd0;
    reg [127:0] line = {16{8'h20}};  // line[127:120] = leftmost character
    reg [4:0]   bi   = 5'd0;         // byte index 0..21 (see byte_at)
    reg [2:0]   bitn = 3'd0;
    reg [7:0]   sh   = 8'd0;
    reg [3:0]   gap  = 4'd0;
    reg [31:0]  hold = 32'd0;

    // Half-period tick: every SPI state change happens on a tick.  The prescaler restarts at the
    // start of each update (S_FMT) so the update period is exactly HOLD_CYCLES + a fixed amount,
    // not rounded up to a whole tick (which made the period a multiple of HALF and froze the
    // low decimal digits of a free-running counter).
    reg [31:0] pre = 32'd0;
    wire tick = (pre == HALF_LAST);
    always @(posedge clk) pre <= (tick || st == S_FMT) ? 32'd0 : pre + 32'd1;

    // scratch for double-dabble and formatting (blocking, fully combinational use)
    integer i, n;
    reg [59:0]  t;
    reg [127:0] tmp;
    reg         use_commas;

    // Byte stream per update (22 bytes, 4 CS frames):
    //   frame A: E0 0F        16 digits           (bytes 0-1)
    //   frame B: E4 DIM       dimming             (bytes 2-3)
    //   frame C: 20 c0..c15   DCRAM write at addr 0, 16 chars, auto-increment (bytes 4-20)
    //   frame D: E8           display normal      (byte 21)
    function [7:0] byte_at(input [4:0] idx);
        reg [4:0] kk;
        begin
            case (idx)
                5'd0:  byte_at = 8'hE0;
                5'd1:  byte_at = 8'h0F;
                5'd2:  byte_at = 8'hE4;
                5'd3:  byte_at = DIM;
                5'd4:  byte_at = 8'h20;
                5'd21: byte_at = 8'hE8;
                default: begin
                    kk = idx - 5'd5;                  // character position 0..15 (0 = leftmost)
                    byte_at = line[{~kk[3:0], 3'b000} +: 8];   // 15-k == ~k for 4 bits: no subtract
                end
            endcase
        end
    endfunction

    function frame_end(input [4:0] idx);
        frame_end = (idx == 5'd1) || (idx == 5'd3) || (idx == 5'd20) || (idx == 5'd21);
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            st <= S_POR; hold <= 32'd0;
            vfd_clk <= 1'b1; vfd_cs <= 1'b1; vfd_sdi <= 1'b0;
        end else begin
            case (st)
                S_POR: begin
                    hold <= hold + 32'd1;
                    if (hold == POR_LAST) st <= S_CONV_INIT;
                end

                // ---- binary -> BCD, 48 clocks (double dabble: no divider needed) ----
                S_CONV_INIT: begin
                    bin <= value[47:0]; bcd <= 60'd0; cnt <= 6'd0; st <= S_CONV;
                end
                S_CONV: begin
                    t = bcd;
                    for (i = 0; i < 15; i = i + 1)
                        if (t[4*i +: 4] >= 4'd5) t[4*i +: 4] = t[4*i +: 4] + 4'd3;
                    bcd <= {t[58:0], bin[47]};
                    bin <= {bin[46:0], 1'b0};
                    cnt <= cnt + 6'd1;
                    if (cnt == 6'd47) st <= S_FMT;
                end

                // ---- format: right-justify, blank leading zeros, optional commas ----
                S_FMT: begin
                    n = 1;                                   // number of significant digits
                    for (i = 0; i < 15; i = i + 1)
                        if (bcd[4*i +: 4] != 4'd0) n = i + 1;
                    use_commas = (COMMAS != 0) && (n <= 12); // n digits + (n-1)/3 commas <= 16
                    tmp = {16{8'h20}};
                    for (i = 14; i >= 0; i = i - 1) begin    // most significant digit first
                        if (i < n) begin
                            tmp = {tmp[119:0], 8'h30 + {4'h0, bcd[4*i +: 4]}};
                            if (use_commas && (i % 3 == 0) && (i > 0))
                                tmp = {tmp[119:0], 8'h2C};   // ','
                        end
                    end
                    line <= tmp;
                    bi <= 5'd0;
                    st <= S_CS_ASSERT;
                end

                // ---- serial engine: one state change per half-period tick ----
                S_CS_ASSERT: if (tick) begin
                    vfd_cs <= 1'b0; gap <= 4'd0; st <= S_CS_SETUP;
                end
                S_CS_SETUP: if (tick) begin
                    if (gap == 4'd1) begin
                        sh <= byte_at(bi); bitn <= 3'd0; st <= S_BIT_LOW;
                    end else gap <= gap + 4'd1;
                end
                S_BIT_LOW: if (tick) begin       // CP falls, data changes (settles a half-period)
                    vfd_clk <= 1'b0; vfd_sdi <= sh[0]; st <= S_BIT_HIGH;
                end
                S_BIT_HIGH: if (tick) begin      // CP rises: the device samples DA
                    vfd_clk <= 1'b1; sh <= {1'b0, sh[7:1]};
                    if (bitn == 3'd7) begin gap <= 4'd0; st <= S_BYTE_GAP; end
                    else begin bitn <= bitn + 3'd1; st <= S_BIT_LOW; end
                end
                S_BYTE_GAP: if (tick) begin
                    if (gap == GAP_LAST) begin
                        if (frame_end(bi)) st <= S_CS_HIGH;
                        else begin
                            bi <= bi + 5'd1; sh <= byte_at(bi + 5'd1); bitn <= 3'd0; st <= S_BIT_LOW;
                        end
                    end else gap <= gap + 4'd1;
                end
                S_CS_HIGH: if (tick) begin
                    vfd_cs <= 1'b1; gap <= 4'd0; st <= S_FRAME_GAP;
                end
                S_FRAME_GAP: if (tick) begin
                    if (gap == GAP_LAST) begin
                        if (bi == 5'd21) begin st <= S_HOLD; hold <= 32'd0; end
                        else begin bi <= bi + 5'd1; st <= S_CS_ASSERT; end
                    end else gap <= gap + 4'd1;
                end

                S_HOLD: begin
                    hold <= hold + 32'd1;
                    if (hold == HOLD_LAST) st <= S_CONV_INIT;
                end
                default: st <= S_POR;
            endcase
        end
    end
endmodule
