// A0  A1  A2  A3  A4  B0  B1  B2  B3  B4    s(M)            σ(M)
// 1RB 4LA 1LA 1RH 2RB 2LB 3LA 1LB 2RA 0RB   7,021,292,621   37
// >>> hex(7021292621) = '0x1a2806c4d'

module busy(input CLK_66MHZ,
            input        SW_USER_1,
            input        SW_USER_2,
            output [7:0] LB_IO9,
            output [7:0] LB_COMM,
            output       LED_1_BLUE,
            output       LED_1_GREEN,
            output       LED_1_RED, 
            output       LED_2_BLUE,
            output       LED_2_GREEN,
            output       LED_2_RED, 
            output       LED_3_BLUE,
            output       LED_3_GREEN,
            output       LED_3_RED, 
            output       LED_4_BLUE,
            output       LED_4_GREEN,
            output       LED_4_RED,
            output       TR_OE_1, TR_OE_2, TR_OE_3, TR_OE_4, TR_OE_5,
            output       TR_DIR_1, TR_DIR_2, TR_DIR_3, TR_DIR_4, TR_DIR_5
            );

   enum                  bit [1:0] { A, B, C, H } state_t;
   reg [1:0]             state = C, next = C;
   enum                  bit { L, R } dir_t;
   reg                   dir;
   wire                  halt;
   wire                  reset = !SW_USER_1 || !SW_USER_2;
   
   // Single-ported RAM
   reg [2:0]     tape[64];
   wire [2:0]    sym;
   reg [2:0]     newsym;
   reg [6:0]     pos = 0;       // see check for -1 in state C
   assign sym = tape[pos];
   always @(posedge CLK_66MHZ) begin
      tape[pos] = newsym;
   end

   // LED
   assign LED_1_GREEN = halt;      // led 1 = green if not halted, red if halted
   assign LED_1_RED = !halt;
   assign LED_1_BLUE = 1;
   assign LED_2_GREEN = 1;
   assign LED_2_RED = 1;     // led 2 = unused
   assign LED_2_BLUE = 1;
   assign LED_3_GREEN = 1;
   assign LED_3_RED = 1;
   assign LED_3_BLUE = !reset;       // led 3 = blue for reset
   assign LED_4_GREEN = 1;      // led 4 = red if state C
   assign LED_4_RED = !(state == C);
   assign LED_4_BLUE = 1;
   
   assign halt = state == H;
   assign LB_COMM[0] = halt;
   assign LB_IO9[0] = halt;
   assign LB_IO9[7:1] = pos;

   // this board sucks ass. have to set level shifter OE and DIR or NO OUTPUTEE
   // set DIR to 0 for cpld output (B->A), to 1 for cpld input (A->B)
   // set OE in negative logic
   assign TR_OE_1 = 0;
   assign TR_OE_2 = 0;
   assign TR_OE_3 = 0;
   assign TR_OE_4 = 0;
   assign TR_OE_5 = 0;
   assign TR_DIR_1 = 0;
   assign TR_DIR_2 = 0;
   assign TR_DIR_3 = 0;
   assign TR_DIR_4 = 0;
   assign TR_DIR_5 = 0;

   always @(posedge CLK_66MHZ) begin
      state <= reset ? C : next;
      pos <= (reset || state == H) ? 0 :
             (dir == L) ? pos - 1'b1 : pos + 1'b1;
   end

   // A0  A1  A2  A3  A4  B0  B1  B2  B3  B4    s(M)            σ(M)
   // 1RB 4LA 1LA 1RH 2RB 2LB 3LA 1LB 2RA 0RB   7,021,292,621   37
   // >>> hex(7021292621) = '0x1a2806c4d'
   always @(*) begin
      newsym <= 0;
      dir <= R;
      next <= A;
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
                next <= H;
             end
             4: begin
                newsym <= 2;
                dir <= R;
                next <= B;
             end
             default: begin  // halt on error
                next <= H;
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
             default: begin  // halt on error
                next <= H;
             end
           endcase // case (sym)
        end // case: B
        C: begin  // clear tape, then state A
           newsym <= 3'h0;
           dir <= R;
           next <= (pos == 7'b1111111) ? A : C;
        end
        H: begin  // halt
           next <= reset ? C : H;
        end
      endcase // case (state)
   end // always @ (*)
   
endmodule // busy  
