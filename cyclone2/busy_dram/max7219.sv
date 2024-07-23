/* SPI interface (no quad support)

 Write to device: (1) set send_byte (2) set start=1 (3) poll busy
 starting in next sysclk cycle until busy == 0. Consider if setup time
 for device is met between (1) and (2), including that at least 1
 sysclk elapses from setting mosi to raising spiclk.

 Read from device: if new_data == 1 then data is in recv_byte. this is
 signaled every 8 spiclk, data is constantly being shifted in every
 clock. whether the data is valid depends on the higher level
 protocol, i.e. a read command is in progress.

 Timing is driven by the 50MHz system clock (sysclk). To run SPI faster
 than 1/2 of sysclk requires a local clock.

 TODO: fix reset so it always works
*/

module spi #(parameter CLK_DIV = 10000)(
        input 	     clk,
	input 	     rst,
	input 	     miso,
	output 	     mosi,
	output 	     sck,
	input 	     start,
	input [7:0]  data_in,
	output [7:0] data_out,
	output 	     busy,
	output 	     new_data
  );

   localparam STATE_SIZE = 2;
   localparam IDLE = 2'd0,
     SCK_LO = 2'd1,
     SCK_HI = 2'd2,
     DATA_INTR = 2'd3;

   reg [STATE_SIZE-1:0] state_d, state_q;

   reg [7:0] 		data_d, data_q;
   reg [31:0] 		sck_d, sck_q;
   reg 			spiclk;
   reg 			mosi_d, mosi_q;
   reg [2:0] 		ctr_d, ctr_q;  // bit counter, 0-7
   reg 			new_data_d, new_data_q;
   reg [7:0] 		data_out_d, data_out_q;

   assign mosi = mosi_q;
   // sck is set for "sample rising edge"
   assign sck = spiclk;
   assign busy = state_d != IDLE;
   assign data_out = data_out_q;
   assign new_data = new_data_q;

   always @(*) begin
      sck_d = sck_q;
      data_d = data_q;
      mosi_d = mosi_q;
      ctr_d = ctr_q;
      new_data_d = 1'b0;
      data_out_d = data_out_q;
      state_d = state_q;
      spiclk = 0;

      case (state_q)
        IDLE: begin
           sck_d = 1;                 // reset clock counter
           ctr_d = 3'b0;              // reset bit counter
           if (start == 1'b1) begin   // if start command
              data_d = data_in;       // latch data to send
              state_d = SCK_LO;       // change state
           end
           spiclk = 0;
        end
        SCK_LO: begin
           sck_d = sck_q + 1'b1;         // increment clock counter
           mosi_d = data_q[7];           // output the MSB of data
           spiclk = 0;
           if (sck_q >= (CLK_DIV/2)) begin // if clock is half full (about to rise)
              state_d = SCK_HI;          // change state
           end
        end
        SCK_HI: begin
           sck_d = sck_q + 1'b1;                           // increment clock counter
           spiclk = 1;
           if (sck_q >= CLK_DIV) begin
              data_d = {data_q[6:0], miso};                 // read in data (shift in)
              ctr_d = ctr_q + 1'b1;                         // increment bit counter
              sck_d = 1;
              if (ctr_q == 3'b111) begin                    // if we are on the last bit
                 state_d = DATA_INTR;                       // change state
                 // data_out_d = data_q;                    // output data
                 data_out_d = {data_q[6:0], miso};          // output data
              end
              else begin
                 // sck_d = 1;
                 state_d = SCK_LO;
              end
           end
        end // case: SCK_HI
        DATA_INTR: begin
           new_data_d = 1'b1;                          // signal data is valid
           // pause a bit between bytes
           sck_d = sck_q + 1'b1;                           // increment clock counter
           if (sck_q >= (CLK_DIV/2)) state_d = IDLE;
        end
      endcase
   end

   always @(posedge clk) begin
      if (rst) begin
         ctr_q <= 3'b0;
         data_q <= 8'b0;
         sck_q <= 0;
         mosi_q <= 1'b0;
         state_q <= IDLE;
         data_out_q <= 8'b0;
         new_data_q <= 1'b0;
      end else begin
         ctr_q <= ctr_d;
         data_q <= data_d;
         sck_q <= sck_d;
         mosi_q <= mosi_d;
         state_q <= state_d;
         data_out_q <= data_out_d;
         new_data_q <= new_data_d;
      end
   end

endmodule


/* Continuously display a 32-bit value on 8-digit LED module with max7219+SPI interface

 TODO: fix reset so it works for any messed up state SPI is in
*/

module max7219(input clk, input rst_n, output max_din, output ce_,
	       output max_clk, input [31:0]display_value);

   wire [7:0] data_out;
   reg [7:0]  data;
   wire       busy;
   wire       miso_ignored, new_data_ignored;
   reg        spi_start;
   wire       rst;
   enum       { POR, INIT, INIT1, INIT1_WAIT, INIT2, INIT2_WAIT, INIT_HOLD, INIT_HOLD2, INIT_DONE } state_t;
   reg [3:0]    state = POR;
   reg [4:0]    addr;
   reg [31:0]   disp_dig = 0;
   reg [24:0] 	rst_cnt = 1;
   reg [7:0]    LED_out;
   reg          max_load;
   assign ce_ = max_load;

   localparam NOP_ADDR = 0;
   localparam DECODEMODE_ADDR = 9;
   localparam BRIGHTNESS_ADDR = 10; // 0xa
   localparam SCANLIMIT_ADDR = 11; // 0xb
   localparam SHUTDOWN_ADDR = 12; // 0xc
   localparam DISPLAYTEST_ADDR = 13; // 0xd
   localparam INITBYTES = 5'd16;
   reg [4:0] 	pinit = 0;
   reg [7:0] 	maxinit[0:INITBYTES-1] =
                '{SHUTDOWN_ADDR, 0, // display off
                  DISPLAYTEST_ADDR, 0, // display test off
                  SCANLIMIT_ADDR, 7,  // display 8 digits
                  DECODEMODE_ADDR, 0, // no decode (hex digits are manual)
                  BRIGHTNESS_ADDR, 1,  // intensity low
                  SHUTDOWN_ADDR, 1, // display on
                  SHUTDOWN_ADDR, 1, // display on
                  1, 8'h0      // byte 14-15
                  };
   reg [7:0] 	hold_cnt;

   spi #(1024) max7219(.clk(clk),
                    .rst(rst),
                    .miso(miso_ignored),
                    .mosi(max_din),
                    .sck(max_clk),
                    .new_data(new_data_ignored),
                    .start(spi_start),
                    .data_in(data),
                    .data_out(data_out),
                    .busy(busy)
                    );

   assign rst = ~rst_n;

   always @(posedge clk) begin
      rst_cnt <= rst_cnt + 25'd1;
      case (state)
	POR: begin
	   disp_dig <= disp_dig + 32'd1;
	   if (disp_dig[20]) state <= INIT;
	end
        INIT: begin
           max_load <= 0;
           addr <= 1;           // for displaying digits (optional)
           disp_dig <= 0;
           state <= INIT1;
        end
        INIT1: begin
           max_load <= 0;
           data <= maxinit[pinit];
           pinit <= pinit + 4'b1;
           spi_start <= 1;
           state <= INIT1_WAIT;
        end
        INIT1_WAIT: begin     // 1
          spi_start <= 0;
          if (busy == 0) state <= INIT2;
        end
        INIT2: begin
           data <= maxinit[pinit];
           pinit <= pinit + 4'b1;
           spi_start <= 1;
           state <= INIT2_WAIT;
        end
        INIT2_WAIT: begin     // 1
           spi_start <= 0;
           if (busy == 0) state <= INIT_HOLD;
        end
        INIT_HOLD: begin
           max_load <= 1;
	   hold_cnt <= 1;
	   state <= (pinit < INITBYTES-5'd2) ? INIT1 : INIT_HOLD2;
	end
        INIT_HOLD2: begin
	   hold_cnt <= hold_cnt + 8'd1;
	   if (hold_cnt == 0) state <= INIT_DONE;
	end
        // Use the init loop with indices 12 and 13 to drive the 8 hex
        // digits. The low 4 bits of disp_num are mapped to a segment
        // code. addr counts the digits from 1 to 8 and disp_num is
        // shifted right 4 per digit. When addr reaches 8 a new
        // display value is latched and addr resets to 1.
        INIT_DONE: begin
           pinit <= INITBYTES-5'd2;
           maxinit[INITBYTES-5'd2] <= addr;
           maxinit[INITBYTES-5'd1] <= LED_out;

           state <= INIT1;
           if (addr < 8) begin
              addr <= addr + 4'b1;
              disp_dig <= disp_dig >> 4;
           end else begin
              addr <= 1;
              disp_dig <= display_value;
	      if (rst_cnt == 0) begin
		 pinit <= 2;  // skip shutdown
		 state <= INIT;
	      end
           end
        end // case: INIT_DONE

      endcase // case (state)
   end // always @ (posedge clk)

   always @(*) begin
           case(disp_dig & 4'hf)
             4'b0000: LED_out = 7'b1111110; // "0"
             4'b0001: LED_out = 7'b0110000; // "1"
             4'b0010: LED_out = 7'b1101101; // "2"
             4'b0011: LED_out = 7'b1111001; // "3"
             4'b0100: LED_out = 7'b0110011; // "4"
             4'b0101: LED_out = 7'b1011011; // "5"
             4'b0110: LED_out = 7'b1011111; // "6"
             4'b0111: LED_out = 7'b1110000; // "7"
             4'b1000: LED_out = 7'b1111111; // "8"
             4'b1001: LED_out = 7'b1111011; // "9"
             4'b1010: LED_out = 7'b1110111; // "A"
             4'b1011: LED_out = 7'b0011111; // "b"
             4'b1100: LED_out = 7'b1001110; // "C"
             4'b1101: LED_out = 7'b0111101; // "d"
             4'b1110: LED_out = 7'b1001111; // "E"
             4'b1111: LED_out = 7'b1000111; // "F"
             default: LED_out = 7'b0000000; // can't happen
           endcase // case (disp_dig & 8'hf)
   end
endmodule // max7219
