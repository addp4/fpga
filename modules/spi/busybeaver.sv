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

   // |state A----------| |state B----------|   time            space 
   // 1RB 4LA 1LA 1RH 2RB 2LB 3LA 1LB 2RA 0RB   7,021,292,621   37
   // >>> hex(7021292621) = '0x1a2806c4d'
   always @(*) begin
      halt_d = 0;
      newsym <= 0;
      next <= A;
      dir <= R;
      case (state)
        A: begin 
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
        // -----state A------- -----state B-------
        // 1RB 4LA 1LA 1RH 2RB 2LB 3LA 1LB 2RA 0RB 7,021,292,621 37
        B: begin
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
   reg [63:0]                   count_d;
   reg                          state = A, next;
   reg                          halt_d = 0, halt_q = 0;

   // Single-ported RAM
   reg [2:0]                    tape[512];  // size is power of 2 so pos can wrap
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

   // 1RB 3LA 1LA 4LA 1RA
   always @(*) begin
      halt_d = 0;
      newsym <= 0;
      next <= A;
      dir <= R;
      case (state)
        A: begin 
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
        //  2LB 2RA 1RH 0RA 0RB
        B: begin
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


