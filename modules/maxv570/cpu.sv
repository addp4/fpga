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
   

module register_file(input clk,
                     input [2:0]   waddr,
                     input [15:0]  wdata,
                     input [2:0]   raddr1,
                     output [15:0] rdata1,
                     input [2:0]   raddr2,
                     output [15:0] rdata2,
                     input         we);
   
   reg [7:0]                      regs[6];
   assign rdata1 = regs[raddr1];
   assign rdata2 = regs[raddr2];
   always @(posedge clk) begin
      if (we) regs[waddr] = wdata;
   end
endmodule // register_file


module max2(CLK_n, MEM_ADDR, MEM_DATA, MEM_OE, MEM_WE);
   input CLK_n       /* synthesis chip_pin = "64" */;
   output [11:0] MEM_ADDR /* synthesis chip_pin = "1,2,3,4,5,6,7,8,15,16,17,18" */;
   inout [15:0]  MEM_DATA /* synthesis chip_pin = "29,30,33,34,35,36,37,38,39,40,41,42,47,48,49,50" */;
   output        MEM_OE /* synthesis chip_pin = "51" */;
   output        MEM_WE;
   
   // PC
   wire         pc_in_sel_incr;
   reg [11:0]   pc, sp;
   reg [15:0]   inst;

   // RAM
   wire         ifetch;
   wire [15:0]       data_bus, addr_bus;
   assign MEM_ADDR = (state == FETCH) ? pc : reg_outa;
   // assign MEM_ADDR = pc;
   assign MEM_DATA = MEM_WE ? reg_outb : 15'bz;

   // REGS
   wire [2:0]   reg_inaddr, reg_outa_addr, reg_outb_addr;
   wire [15:0]  reg_in, reg_outa, reg_outb;
   wire         reg_we;
   register_file regs(.clk(CLK_n),
                      .waddr(reg_inaddr),
                      .raddr1(reg_outa_addr),
                      .raddr2(reg_outb_addr),
                      .wdata(reg_in),
                      .rdata1(reg_outa),
                      .rdata2(reg_outb),
                      .we(reg_we));
   assign reg_inaddr = inst[2:0];
   assign reg_in = data_bus;
   assign reg_outa_addr = inst[5:3];
   assign reg_outb_addr = inst[8:6];
   
   // ALU
   reg [4:0]    flags;
   wire [15:0]  alu_out;
   wire [3:0]   alu_op;
   ALU alu(.op(alu_op),
           .a(reg_outa),
           .b(reg_outb),
           .c(alu_out),
           .flags(flags));
   assign alu_op = inst[15:12];
   assign data_bus = MEM_OE ? MEM_DATA : alu_out;

   
   reg [22:0]   memclk;
   always @(posedge CLK_n) memclk <= memclk + 1;

   reg [3:0]    state, next;
   enum         { FETCH, DECODE, EXECUTE } state_t;
      
   always @(posedge memclk[18]) begin
      state <= next;
      pc <= pc_in_sel_incr ? pc + 1 : reg_outa;
      if (next == FETCH)
        inst <= MEM_DATA;
   end

   always @(*) begin
      pc_in_sel_incr = 1;
      MEM_OE = 0;
      MEM_WE = 0;
      case (state)
        FETCH: begin
           MEM_OE = 1;
           next <= DECODE;
        end

        DECODE: begin
           next <= EXECUTE;
           
        end

        EXECUTE: begin
           MEM_WE = 1;
           next <= FETCH;
        end
      endcase // case (state)
   end // always @ (*)
   
   
   
endmodule // max2

  
