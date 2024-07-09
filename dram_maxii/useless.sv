module useless
  (
   input 	clk,
   output [7:0] ram_addr,
   inout [3:0] 	ram_dq,
   output 	ram_we_,
   output 	ram_oe_,
   output 	ram_ras_,
   output 	ram_cas_
   );

   reg 		     write = 0, ena = 0;
   reg [3:0] 	     wr_data = 0;
   reg [3:0] 	     rd_data = 0;
   reg 		     busy;
   reg [7:0] 	     addr = 0;
	     
   tms4464 ram(clk, addr, rd_data, busy, write, ena,
     ram_addr, ram_dq, ram_we_, ram_oe_, ram_ras_, ram_cas_);
   assign ram_dq = (!ram_we_ ? wr_data : 4'hz);

   reg [2:0] 	     state = 0;
   reg [22:0] 	     count = 0;

   always @(posedge clk) begin
      // states 0-2 write a linked list to the first 256 bytes of the
      // memory: a[0] = 1, a[1] = 2, ..., a[255] = 0
      case (state)
	0: begin
	   // wr_data <= 8'b10101010;
	   // wr_data <= 8'b00101011;
	   wr_data <= addr[3:0] + 4'd1;
	   write <= 1;
	   ena <= 1;
	   if (busy) state <= 1;
	end
	1: begin
	   ena <= 0;
	   if (!busy) state <= 2;
	end
	2: begin
	   if (addr == 8'd255) begin
	      addr <= 0;
	      state <= 3;
	   end else begin
	      addr <= addr + 8'd1;
	      state <= 0;
	   end
	end
	// states 3+ perform pointer chasing. set addr to the byte at addr.
	3: begin
	   write <= 0;
	   ena <= 1;
	   if (busy) state <= 4;
	end
	4: begin
	   ena <= 0;
	   if (!busy) state <= 5;
	end
	5: begin
	   addr <= rd_data;
	   count <= 1;
	   state <= 6;
	end
	6: begin
	   count <= count + 23'd1;
	   if (count == 23'd0) state <= 3;
	end
	   
      endcase // case (state)
   end
      
endmodule // useless

module tms4464
  (
   input 	    clk,
   input [15:0]     addr,
   output [3:0]     rd_data,
   output 	    busy,
   input 	    write,
   input 	    ena,
   output reg [7:0] ram_addr,
   input [3:0] 	    ram_dq,
   output reg 	    ram_we_,
   output reg 	    ram_oe_,
   output reg 	    ram_ras_,
   output reg 	    ram_cas_
   );

   typedef enum      { INIT, IDLE, U0, U1, U2, U3 } state_t;
   reg [4:0] 	     state = INIT;
   reg [3:0] 	     twait = 0;
   reg [3:0] 	     data_latch = 0;
   reg [13:0] 	     cyc = 0;
   parameter refresh_cycles = 781;
   reg 		      init = 1;

   typedef enum       { NOP, LATCH_DATA, COLA, ROWA } op_t;
   typedef struct packed {
      bit 	  we_;
      bit 	  oe_;
      bit 	  cas_;
      bit 	  ras_;
      bit [2:0]   op;
      bit [3:0]   cycles;
      bit 	  h;
   } u_control;
   
   reg [4:0] 	      upc;
   u_control  	      uinst;
   
   assign busy = (state != IDLE) || init;
   assign rd_data = data_latch;

   always @(*) begin
     case (upc)
       //
       // CBR refresh.
       // 0. ras high, cas low, others don't care. wait 90 ns
       // 1. ras low. wait 100ns
       //
       0: uinst <= '{oe_:1, we_:1, ras_:1, cas_:0, op:NOP, cycles:5, h:0};
       1: uinst <= '{oe_:1, we_:1, ras_:0, cas_:0, op:NOP, cycles:5, h:1};
       //
       // Read cycle.
       // 2. present row addr, ras low, we high. wait tRLCL=[25,50]ns=2c
       // 3. present col addr, cas low, oe low, wait tw(CL)=50ns=3c
       //       tw(RL)=100ns is satisfied
       // 4. latch data, cas high, oe high. wait tRHrd=10ns=1c
       // 5. ras high. wait tw(RH)=90ns=5c (precharge)
       //
       2: uinst <= '{oe_:1, we_:1, ras_:0, cas_:1, op:ROWA, cycles:2, h:0};
       3: uinst <= '{oe_:0, we_:1, ras_:0, cas_:0, op:COLA, cycles:3, h:0};
       4: uinst <= '{oe_:1, we_:1, ras_:0, cas_:1, op:LATCH_DATA, cycles:1, h:0};
       5: uinst <= '{oe_:1, we_:1, ras_:1, cas_:1, op:NOP, cycles:5, h:1};
       //
       // Write cycle (early).
       // 6. present row addr, ras low, we low. wait tRLCL=[25,50]ns=2c
       // 7. present col addr, cas low, present data (tri-state assign), 
       //      wait max(th(CLW), th(CLD)) = max(30,30) = 2c
       //      but also meet tRLCH and tw(RL) = 100ns, so 3c to make 5c total
       // 8. cas high, ras high, we high. wait tw(RH) = 90ns = 5c
       //
       6: uinst <= '{oe_:1, we_:0, ras_:0, cas_:1, op:ROWA, cycles:2, h:0};
       7: uinst <= '{oe_:1, we_:0, ras_:0, cas_:0, op:COLA, cycles:3, h:0};
       8: uinst <= '{oe_:1, we_:1, ras_:1, cas_:1, op:NOP, cycles:5, h:1};
       
       default:
	 uinst <= '{oe_:1, we_:1, ras_:1, cas_:1, op:NOP, cycles:0, h:1};
     endcase // case (upc)
   end // always @ (*)
   
   always @(posedge clk) begin
      cyc <= cyc + 14'd1;
      
      case (state)
	INIT: begin
	   // Pause 200us = 10000 cycles
	   // if (cyc == 10000) begin
	   if (cyc == 10) begin
	      cyc <= 0;
	      state <= IDLE;
	   end
	end
	IDLE: begin
	   // Command = output disable
	   ram_oe_ <= 1;
	   ram_we_ <= 1;
	   ram_ras_ <= 1;
	   ram_cas_ <= 1;
	   if (init) begin
	      // CBR takes 10 cycles. Do at least 8 of them.
	      if (cyc < 100) begin
		 upc <= 0;
		 state <= U0;
	      end
	      else init <= 0;
	   end else if (cyc >= refresh_cycles) begin
	      cyc <= 0;  // cyc - refresh_cycles;
	      upc <= 0;
	      state <= U0;
	   end else if (ena) begin
	      if (write) begin
		 upc <= 6;
		 state <= U0;
	      end else begin
		 upc <= 2;
		 state <= U0;
	      end
	   end
	end
	U0: begin  // state: 2
	   ram_oe_ = uinst.oe_;
	   ram_we_ = uinst.we_;
	   ram_ras_ = uinst.ras_;
	   ram_cas_ = uinst.cas_;
	   if (uinst.op == LATCH_DATA) data_latch <= ram_dq;
	   if (uinst.op == ROWA) ram_addr <= addr[15:8];
	   if (uinst.op == COLA) ram_addr <= addr[7:0];
	   twait <= 2;
	   state <= U1;
	end
	U1: begin  // state: 3
	   twait <= twait + 4'd1;
	   if (twait >= uinst.cycles) begin
	      if (uinst.h) begin
		 state <= IDLE;
	      end else begin
		 upc <= upc + 5'd1;
		 state <= U0;
	      end
	   end
	end
      endcase
   end
   
endmodule
