/*
 inst format: 5/opcode, 3/a, 3/b, 3/c
 */

module ALU(input [3:0] op, input [15:0] a, input [15:0] b, output [15:0] c,
           output [5:0] flags);
   always @(*) begin
      case (op)
        0: c = 0;
        1: c = a;
        2: c = ~a;
        3: c = a + b;
        4: c = a - b;
        5: c = a & b;
        6: c = a | b;
        7: c = a ^ b;
        8: c = {1'b0, a[7:1]};  // logical shift right
        9: c = {a[6:0], 1'b0};  // logical shift left
        10: c = {a[6:0], a[7]}; // rotate left
        11: c = {a[7], a[7:1]}; // arithmetic shift right
        default: c = 0;
      endcase // case (op)
      flags = {1'b1, c == 0, c[15], ~c[15], c[14]};
   end
endmodule // ALU
   

/*
 Test just the ALU incrementing a single register each cycle.
 Connect the ALU output to "memory" so it doesn't get eliminated.
 */

module max2(CLK_n, MEM_ADDR, MEM_DATA, MEM_OE, MEM_WE);
   input CLK_n       /* synthesis chip_pin = "64" */;
   output [11:0] MEM_ADDR /* synthesis chip_pin = "1,2,3,4,5,6,7,8,15,16,17,18" */;
   inout [15:0]  MEM_DATA /* synthesis chip_pin = "29,30,33,34,35,36,37,38,39,40,41,42,47,48,49,50" */;
   output        MEM_OE /* synthesis chip_pin = "51" */;
   output        MEM_WE;

   reg [15:0]    data1, data2;
   
   // ALU
   reg [4:0]    flags;
   wire [15:0]  alu_a, alu_b, alu_out;
   reg [3:0]   alu_op;
   ALU alu(.op(alu_op),
           .a(alu_a),
           .b(alu_b),
           .c(alu_out),
           .flags(flags));
   assign alu_a = data1;
   assign alu_b = data2;
   assign MEM_DATA = alu_out;
   
   reg [22:0]   memclk;
   always @(posedge CLK_n) memclk <= memclk + 1;

   reg [3:0]    state, next;
   enum         { FETCH, DECODE, EXECUTE } state_t;
      
   always @(posedge memclk[18]) begin
      if (alu_op & 1) data1 <= alu_out;
      else data2 <= alu_out;
      alu_op <= alu_op + 1;
   end
   
endmodule // max2

  
