module busybeaver_37space(input clk,
                          input         rst_n,
                          output [63:0] count,
                          output        halt);

   localparam
     A = 0,
     B = 1,
     L = 0,
     R = 1;
   reg                          dir;
   reg [63:0]                   count_d;
   reg                          state = A, next;
   reg                          halt_d = 0, halt_q = 0;

   // Single-ported RAM
   reg [2:0]                    tape[128];  // size is power of 2 so pos can wrap
   wire [2:0]                   sym;
   reg [2:0]                    newsym;
   reg [6:0]                    pos = 0;
   assign sym = tape[pos];
   always @(posedge clk) begin
      tape[pos] = newsym;
   end
   
   assign halt = halt_q;
   assign count = count_d;
   
   always @(posedge clk) begin
      halt_q <= halt_q | halt_d;
      if (!rst_n) state <= A;
      else state <= next;
      pos <= (dir == L) ? pos - 1 : pos + 1;
      if (!halt_q) count_d <= count_d + 1;
   end

   // A0  A1  A2  A3  A4  B0  B1  B2  B3  B4    s(M)            σ(M)
   // 1RB 4LA 1LA 1RH 2RB 2LB 3LA 1LB 2RA 0RB   7,021,292,621   37
   // >>> hex(7021292621) = '0x1a2806c4d'
   always @(*) begin
      halt_d = 0;
      newsym <= 0;
      next <= A;
      dir <= R;
      case (state)
        A: begin      // 1RB 4LA 1LA 1RH 2RB
           case (sym)
             0: begin
                newsym <= 1;
                dir <= R;
                next <= B;
             end
             1: begin
                newsym <= 4;
                dir <= L;
                next <= A;
             end
             2: begin
                newsym <= 1;
                dir <= L;
                next <= A;
             end
             3: begin           // halt
                halt_d <= 1;
             end
             4: begin
                newsym <= 2;
                dir <= R;
                next <= B;
             end
             default: begin  // Used to clear the tape on reset
                newsym <= 0;
                dir <= R;
                next <= A;
             end
           endcase // case (sym)
        end // case: A
        B: begin     // 2LB 3LA 1LB 2RA 0RB
           case (sym)
             0: begin
                newsym <= 2;
                dir <= L;
                next <= B;
             end
             1: begin
                newsym <= 3;
                dir <= L;
                next <= A;
             end
             2: begin
                newsym <= 1;
                dir <= L;
                next <= B;
             end
             3: begin
                newsym <= 2;
                dir <= R;
                next <= A;
             end
             4: begin
                newsym <= 0;
                dir <= R;
                next <= B;
             end
             default: begin  // Clear the tape on reset
                newsym <= 0;
                dir <= R;
                next <= A;
             end
           endcase // case (sym)
        end
      endcase // case (state)
   end // always @ (*)
   
endmodule // busybeaver_37space


// A0  A1  A2  A3  A4  B0  B1  B2  B3  B4  s(M)               σ(M)
// 1RB 3LA 1LA 4LA 1RA 2LB 2RA 1RH 0RA 0RB 26,375,397,569,930 143
module busybeaver_143space(input clk,
                           input         rst_n,
                           output [63:0] count,
                           output        halt);

   localparam
     A = 0,
     B = 1,
     L = 0,
     R = 1;
   reg                          dir;
   reg [63:0]                   count_d = 0;
   reg [15:0]                   smallcnt = 0;
   reg                          state = A, next;
   reg                          halt_d = 0, halt_q = 0;

   // Single-ported RAM
   localparam MEMBITS = 8;
   reg [2:0]                    tape[1 << MEMBITS];  // size is power of 2 so pos can wrap
   wire [2:0]                   sym;
   reg [2:0]                    newsym;
   reg [MEMBITS-1:0]                    pos = 0;
   assign sym = tape[pos];
   always @(posedge clk) begin
      tape[pos] = newsym;
   end
   
   assign halt = halt_q;
   assign count = count_d;
   
   always @(posedge clk) begin
      halt_q <= halt_q | halt_d;
      if (!rst_n) state <= A;
      else state <= next;
      pos <= (dir == L) ? pos - 1 : pos + 1;
      if (!halt_q) count_d <= count_d + 1;
   end
  
   always @(*) begin
      halt_d = 0;
      newsym <= 0;
      next <= A;
      dir <= R;
      case (state)
        A: begin   // 1RB 3LA 1LA 4LA 1RA
           case (sym)
             0: begin
                newsym <= 1;
                dir <= R;
                next <= B;
             end
             1: begin
                newsym <= 3;
                dir <= L;
                next <= A;
             end
             2: begin
                newsym <= 1;
                dir <= L;
                next <= A;
             end
             3: begin
                newsym <= 4;
                dir <= L;
                next <= A;
             end
             4: begin
                newsym <= 1;
                dir <= R;
                next <= A;
             end
             default: begin  // Used to clear the tape on reset
                newsym <= 0;
                dir <= R;
                next <= A;
             end
           endcase // case (sym)
        end // case: A
        B: begin  // 2LB 2RA 1RH 0RA 0RB
           case (sym)
             0: begin
                newsym <= 2;
                dir <= L;
                next <= B;
             end
             1: begin
                newsym <= 2;
                dir <= R;
                next <= A;
             end
             2: begin
                halt_d <= 1;
             end
             3: begin
                newsym <= 0;
                dir <= R;
                next <= A;
             end
             4: begin
                newsym <= 0;
                dir <= R;
                next <= B;
             end
             default: begin  // Clear the tape on reset
                newsym <= 0;
                dir <= R;
                next <= A;
             end
           endcase // case (sym)
        end
      endcase // case (state)
   end // always @ (*)
   
endmodule // busybeaver_143space


module main(input clk,  // 50 MHz system clock
            input rst_n,
            output led,
            output din0,
            output ce_0,
            output clk0,
            output din1,
            output ce_1,
            output clk1);

   // ALTPLL for bb
   wire       CLOCK_150, CLOCK_250, CLOCK_300;
   clk_wiz_0 bbclk(.clk_in1(clk), .clk_out1(CLOCK_300), .clk_out2(CLOCK_250),
                   .clk_out3(CLOCK_150));

   // Busybeaver module
   wire [63:0] bb_count[4];
   reg [63:0]  display_value;
   wire        bb_halt0, bb_halt1, bb_halt2, bb_halt3;
   reg [31:0]  cnt;
   
   busybeaver_143space bb0(.clk(clk), .rst_n(rst_n), .count(bb_count[0]), .halt(bb_halt0));
   busybeaver_143space bb1(.clk(CLOCK_150), .rst_n(rst_n), .count(bb_count[1]), .halt(bb_halt1));
   busybeaver_143space bb2(.clk(CLOCK_250), .rst_n(rst_n), .count(bb_count[2]), .halt(bb_halt2));
   busybeaver_143space bb3(.clk(CLOCK_300), .rst_n(rst_n), .count(bb_count[3]), .halt(bb_halt3));
   
   max7219 max0(.clk(clk), .rst_n(rst_n), .max_din(din0), .ce_(ce_0), .max_clk(clk0),
               .display_value(display_value[31:0]));

   max7219 max1(.clk(clk), .rst_n(rst_n), .max_din(din1), .ce_(ce_1), .max_clk(clk1),
               .display_value(display_value[63:32]));

   wire        [1:0]index;

   assign led = cnt[24];
   assign index = cnt[27:26];
   // assign display_value[59:0] = { bb_count[index][59:16], 16'h0};
   // assign display_value[63:60] = { 2'b0, index };
   
   always @(posedge clk) begin
      cnt <= cnt + 1;
      if (cnt[15:0] == 0) display_value <= { 2'b0, index, bb_count[index][59:0] };
   end
endmodule // main
