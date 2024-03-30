// A0  A1  A2  A3  A4  B0  B1  B2  B3  B4    s(M)            σ(M)
// 1RB 4LA 1LA 1RH 2RB 2LB 3LA 1LB 2RA 0RB   7,021,292,621   37
// >>> hex(7021292621) = '0x1a2806c4d'

module max2(CLK_n, MEM_ADDR, MEM_DATA, halt);
   input CLK_n       /* synthesis chip_pin = "64" */;
   output [11:0] MEM_ADDR /* synthesis chip_pin = "1,2,3,4,5,6,7,8,15,16,17,18" */;
   inout [15:0]  MEM_DATA /* synthesis chip_pin = "29,30,33,34,35,36,37,38,39,40,41,42,47,48,49,50" */;
   output        halt /* synthesis chip_pin = "51" */;
   
   localparam
     A = 1'b0,
     B = 1'b1,
     L = 1'b0,
     R = 1'b1;
   reg           dir;
   reg           state = A, next;
   reg           halt_d = 0, halt_q = 0;
   
   // Single-ported RAM
   reg [2:0]     tape[64];
   wire [2:0]    sym;
   reg [2:0]     newsym;
   reg [6:0]     pos = 0;
   assign sym = tape[pos];
   always @(posedge CLK_n) begin
      tape[pos] = newsym;
   end
   
   assign halt = halt_q;
   assign MEM_ADDR[6:0] = pos;

   always @(posedge CLK_n) begin
      halt_q <= halt_q | halt_d;
      state <= next;
      pos <= (dir == L) ? pos - 1'b1 : pos + 1'b1;
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
                newsym <= 3'h2;
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
   
endmodule // max2

  
