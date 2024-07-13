parameter OFF = 4'd2;

module useless
  (
   input 	clk,
   input 	rst_n,
   output [7:0] ram_addr,
   inout [3:0] 	ram_dq,
   output 	ram_we_,
   output 	ram_oe_,
   output 	ram_ras_,
   output 	ram_cas_,
   output 	dir,
   output 	max_clk,
   output 	max_din,
   output 	max_ce_,
   output 	led_glow,
   output 	led_error
   );

   // DRAM device
   reg 		write = 0, ena = 0;
   reg [3:0] 	wr_data = 0;
   reg [3:0] 	rd_data = 0;
   reg 		busy;
   reg 		ack = 0;
   reg 		error = 0;
   reg [15:0] 	addr = 0;
   tms4464 ram(.clk(clk), .addr(addr), .rd_data(rd_data),
	       .busy(busy), .ack(ack), .write(write), .ena(ena),
	       .ram_addr(ram_addr), .ram_dq(ram_dq),
	       .ram_we_(ram_we_), .ram_oe_(ram_oe_),
	       .ram_ras_(ram_ras_), .ram_cas_(ram_cas_));
   assign ram_dq = (!ram_we_ ? wr_data : 4'hz);
   assign dir = !ram_we_;

   // Indicator (glowing)
   glow_led glo(.clk(clk), .led(led_glow));

   // 8-digit SPI display
   reg [31:0] 	max_display = 32'hdeadbeef;
   max7219 max(.clk(clk), .rst_n(rst_n), .max_din(max_din), .ce_(max_ce_),
	       .max_clk(max_clk), .display_value(max_display[31:0]));

   reg [2:0] 	state = 0;
   reg [24:0] 	count = 0;
   // assign led[3:0] = rd_data;
   assign max_display[7:4] = addr[7:4];
   assign max_display[3:0] = rd_data;
   assign led_error = error;

   always @(posedge clk) begin
      // states 0-2 write a linked list to the first 256 bytes of the
      // memory: a[0] = 1, a[1] = 2, ..., a[255] = 0
      case (state)
	0: if (!busy) state <= 1;
	1: begin
	   // wr_data <= 4'b1100;
	   // wr_data <= 8'b00101011;
	   wr_data <= addr[3:0] + OFF;
	   write <= 1;
	   ena <= 1;
	   if (ack) state <= 2;
	end
	2: begin
	   ena <= 0;
	   if (!busy) state <= 3;
	end
	3: begin
	   // if (addr != 16'hffff) begin
	   if (addr != 16'hffff) begin
	      addr <= addr + 16'd1;
	      state <= 1;
	   end else begin
	      addr <= 0;
	      state <= 4;
	   end
	end
	// states 4+ read all of memory and check each nybble equals the
	// nybble plus 1, as initialized.
	4: begin
	   write <= 0;
	   ena <= 1;
	   if (ack) state <= 5;
	end
	5: begin
	   ena <= 0;
	   if (!busy) state <= 6;
	end
	6: begin
	   if (addr[3:0] != 4'(rd_data-OFF)) error <= 1;
	   count <= 1;
	   addr <= addr + 16'd1;
	   state <= 4;
	end
	7: begin
	   count <= count + 24'd1;
	   if (count[3:0] == 20'd0) begin
	      addr <= addr + 16'd1;
	      state <= 4;
	   end
	end
      endcase // case (state)
   end
endmodule // useless


module glow_led (input clk, output led);
   reg [31:0] count;
   reg [3:0]  duty;
   reg [3:0]  inc = 1;

   assign led = (count[3:0] < duty) ? '1 : '0;
   always @(posedge clk) count <= count + '1;

   // update duty cycle every 1/32 second
   always @(posedge count[20]) begin
      duty <= duty + inc;
      if (duty == 8) inc <= 15;  // -1
      if (duty == 1) inc <= 1;
   end
endmodule // glow_led


module tms4464
  (
   input 	    clk,
   input [15:0]     addr,
   output [3:0]     rd_data,
   output 	    busy,
   output 	    ack,
   input 	    write,
   input 	    ena,
   output reg [7:0] ram_addr,
   input [3:0] 	    ram_dq,
   output reg 	    ram_we_,
   output reg 	    ram_oe_,
   output reg 	    ram_ras_,
   output reg 	    ram_cas_
   );

   typedef enum      { INIT, IDLE, U0, U1 } state_t;
   reg [4:0] 	     state = INIT;
   reg [3:0] 	     twait = 0;
   reg [3:0] 	     data_latch = 0;
   reg [13:0] 	     cyc = 0;
   parameter refresh_cycles = 781;
   // parameter refresh_cycles = 40;
   reg 		     init = 1;

   typedef enum       { NOP, LATCH_DATA, COLA, ROWA } op_t;
   typedef struct {
      bit 	  we_;
      bit 	  oe_;
      bit 	  cas_;
      bit 	  ras_;
      bit [2:0]   op;
      bit [3:0]   stall;
      bit 	  h;
   } u_control;
   reg [4:0] 	  upc = 0;
   u_control  	  uinst;

   assign busy = (state != IDLE);
   assign rd_data = data_latch;

   always @(*) begin
      case (upc)
	//
	// CBR refresh.
	// 0. cas low, others don't care. wait 90 ns
	// 1. ras low. wait 100ns
	//
	0: uinst <= '{oe_:1, we_:1, ras_:1, cas_:0, op:NOP, stall:5, h:0};
	1: uinst <= '{oe_:1, we_:1, ras_:0, cas_:0, op:NOP, stall:5, h:1};
	//
	// Read cycle.
	// 2. present row addr, ras low, we high. wait tRLCL=[25,50]ns=2c
	// 3. present col addr, cas low, oe low, wait tw(CL)=50ns=3c
	//       tw(RL)=100ns is satisfied
	// 4. latch data, cas high, oe high. wait tRHrd=10ns=1c
	// 5. ras high. wait tw(RH)=90ns=5c (precharge)
	//
	2: uinst <= '{oe_:1, we_:1, ras_:1, cas_:1, op:ROWA, stall:2, h:0};
	3: uinst <= '{oe_:1, we_:1, ras_:0, cas_:1, op:NOP, stall:1, h:0};
	4: uinst <= '{oe_:0, we_:1, ras_:0, cas_:1, op:COLA, stall:1, h:0};
	5: uinst <= '{oe_:0, we_:1, ras_:0, cas_:0, op:NOP, stall:2, h:0};
	6: uinst <= '{oe_:1, we_:1, ras_:0, cas_:1, op:LATCH_DATA, stall:1, h:0};
	7: uinst <= '{oe_:1, we_:1, ras_:1, cas_:1, op:NOP, stall:4, h:1};
	//
	// Write cycle (early).
	// 6. present row addr, ras low, we low. wait tRLCL=[25,50]ns=2c
	// 7. present col addr, cas low, present data (tri-state assign),
	//      wait max(th(CLW), th(CLD)) = max(30,30) = 2c
	//      but also meet tRLCH and tw(RL) = 100ns, so 3c to make 5c total
	// 8. cas high, ras high, we high. wait tw(RH) = 90ns = 5c
	//
	8: uinst <= '{oe_:1, we_:0, ras_:1, cas_:1, op:ROWA, stall:2, h:0};
	9: uinst <= '{oe_:1, we_:0, ras_:0, cas_:1, op:NOP, stall:2, h:0};
	10: uinst <= '{oe_:1, we_:0, ras_:0, cas_:1, op:COLA, stall:2, h:0};
	11: uinst <= '{oe_:1, we_:0, ras_:0, cas_:0, op:NOP, stall:3, h:0};
	12: uinst <= '{oe_:1, we_:1, ras_:1, cas_:1, op:NOP, stall:5, h:1};

	default:
	  uinst <= '{oe_:1, we_:1, ras_:1, cas_:1, op:NOP, stall:0, h:1};
      endcase // case (upc)
   end // always @ (*)

   always @(posedge clk) begin
      cyc <= cyc + 14'd1;

      case (state)
	INIT: begin
	   // Pause 200us = 10000 cycles
	   if (cyc == 10000) begin
	   // if (cyc == 10) begin for simulation
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
	   ack <= 0;
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
	      ack <= 1;
	      if (write) begin
		 upc <= 8;
		 state <= U0;
	      end else begin
		 upc <= 2;
		 state <= U0;
	      end
	   end
	end
	U0: begin  // state: 2
	   ram_oe_ <= uinst.oe_;
	   ram_we_ <= uinst.we_;
	   ram_ras_ <= uinst.ras_;
	   ram_cas_ <= uinst.cas_;
	   case (uinst.op)
	     LATCH_DATA: data_latch <= ram_dq;
	     ROWA: ram_addr <= addr[15:8];
	     // ROWA: ram_addr <= 1;
	     COLA: ram_addr <= addr[7:0];
	     default: ;
	   endcase // case (uinst.op)

	   if (uinst.stall < 2) begin
	      if (uinst.h) state <= IDLE;
	      else upc <= upc + 5'd1;
	   end else begin
	      twait <= 1;
	      state <= U1;
	   end
	end
	U1: begin  // state: 3
	   twait <= twait + 4'd1;
	   if (twait >= uinst.stall) begin
	      if (uinst.h) begin
		 state <= IDLE;
	      end else begin
		 upc <= upc + 5'd1;
		 state <= U0;
	      end
	   end
	end // case: U1
      endcase
   end

endmodule
