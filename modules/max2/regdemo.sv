module register_file(input clk,
                     input [2:0]   waddr,
                     input [15:0]  wdata,
                     input [2:0]   raddr1,
                     output [15:0] rdata1,
                     input [2:0]   raddr2,
                     output [15:0] rdata2,
                     input         we);
   
   reg [7:0]                      regs[5];
   assign rdata1 = regs[raddr1];
   assign rdata2 = regs[raddr2];
   always @(posedge clk) begin
      if (we) regs[waddr] = wdata;
   end
endmodule // register_file


/*
 Test the register file. Each cycle a different reg is written to "memory".
 */

module max2(CLK_n, MEM_ADDR, MEM_DATA, MEM_OE, MEM_WE);
   input CLK_n       /* synthesis chip_pin = "64" */;
   output [11:0] MEM_ADDR /* synthesis chip_pin = "1,2,3,4,5,6,7,8,15,16,17,18" */;
   inout [15:0]  MEM_DATA /* synthesis chip_pin = "29,30,33,34,35,36,37,38,39,40,41,42,47,48,49,50" */;
   output        MEM_OE /* synthesis chip_pin = "51" */;
   output        MEM_WE;

   reg [2:0]    regaddr;
   
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
   assign reg_we = 1;
   assign reg_outa_addr = regaddr;
   assign reg_outb_addr = regaddr + 1;
   assign reg_inaddr = regaddr;
   assign reg_in = reg_outa + 1;
   
   reg [22:0]   memclk;
   always @(posedge CLK_n) memclk <= memclk + 1;

   always @(posedge memclk[18]) begin
      regaddr <= regaddr + 1;
      MEM_DATA[7:0] <= reg_outa;
      MEM_DATA[15:8] <= reg_outb;
   end
   
endmodule // max2

  
