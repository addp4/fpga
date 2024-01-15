`timescale 1ns / 1ns
module ALU(input clk, 
	   input [3:0] 	    opcode, 
	   input [7:0] 	    a, 
	   input [7:0] 	    b, 
	   output reg [7:0] out, 
	   output reg [3:0] flags);
   typedef enum 	    { HALT, ADD, SUB, CMP } instopcode;
   always @(posedge clk) begin
      case (opcode)
	ADD: out <= a + b;
	SUB: out <= a - b;
	CMP: begin
	   out <= 0;
	   flags[1:0] <= { a < b, a == b };
	end
	default: out <= 0;
      endcase // case (opcode)
      flags[2] <= 0;		// TODO: carry
      flags[3] <= 0;		// TODO: overflow
   end
endmodule // ALU

   
/* How do we integrate the ALU into the state machine and bus usage of
 a microprocessor?
 
 8-bit regs, 8 regs, 16-bit instructions, 8-bit PC (256 x 16 bits = 4K bit ROM)
 ALU:    4/opcode, 4/src1, 4/src2, 4/dst
 branch: 4/opcode, 4/condition, 8/newpc
 mem:    4/opcode, 4/unused, 4/src, 4/dst
 */

module CPU(input clk, output [7:0]led);
   reg [7:0] regs[7:0]={0,0,0,0,0,0,0,0}, in1, in2;	
   reg [15:0] mem[255:0], inst;
   reg [7:0]  pc = 0, next_pc;
   reg [3:0]  alu_op;
   reg 	      wb = 0;
   reg [2:0] dst_reg;
   typedef enum       { Z=1, N=2, C=4, V=8 } flagval;
   typedef enum       { HALT, ADD, SUB, CMP, ADC, LOAD, STORE, x7,
			x8, x9, x10, x11, x12, x13, x14, B } instopcode;
   typedef enum       { BR, EQ, NE, GT, GE, LT, LE, OV } brcond;
   enum bit[2:0] { FETCH, DECODE, EXECUTE, EX2, HALTED } state = FETCH;

   // Declare buses from register file to alu, alu to register file
   wire [7:0] alu_reg;
   wire [3:0] alu_flags;
   ALU alu(.clk(clk), .opcode(alu_op), .a(in1), .b(in2), .out(alu_reg),
	   .flags(alu_flags));

   initial begin
      $readmemh("C:/Users/yumgr/git/fpga/modules/alu1/rom.txt", mem);
   end
   assign led = pc;

   always @(posedge clk) begin
      case (state)
	FETCH: begin
	   inst <= mem[pc];
	   state <= DECODE;
	   next_pc <= pc + 1;
	end
	DECODE: begin
	   dst_reg <= inst[11:8];
	   case (inst[15:12])
	     ADD, SUB, CMP: begin
		alu_op <= inst[15:12];
		in1 <= regs[inst[7:4]];
		in2 <= regs[inst[3:0]];
		wb <= (inst[11:8] != 0);
	     end
	     ADC: begin
		alu_op <= ADD;
		in1 <= regs[inst[7:4]];
		in2 <= inst[3:0];
		wb <= (inst[11:8] != 0);
	     end
	     B: begin
		case (inst[11:8])
		  EQ: if (alu_flags & Z) next_pc <= inst[7:0];
		  NE: if (alu_flags & Z) next_pc <= inst[7:0];
		  GT: if ((alu_flags & (N|Z)) == 0) next_pc <= inst[7:0];
		  GE: if ((alu_flags & N) == 0) next_pc <= inst[7:0];
		  LT: if ((alu_flags & N) != 0) next_pc <= inst[7:0];
		  LE: if ((alu_flags & (N|Z)) != 0) next_pc <= inst[7:0];
		  OV: if ((alu_flags & V) != 0) next_pc <= inst[7:0];
		  default: next_pc <= inst[7:0];
		endcase // case (inst[11:8])
		wb <= 0;
	     end
	   endcase // case (inst[15:12])
	   state <= EXECUTE;
	end
	EXECUTE: begin
	   state <= EX2;
	end
	EX2: begin
	   if (wb) regs[dst_reg] <= alu_reg;
	   wb <= 0;
	   pc <= next_pc;
	   state <= inst[15:12] == HALT ? HALTED : FETCH;
	end
	HALTED: state <= HALTED;
   endcase
   end
   
   
endmodule // CPU

