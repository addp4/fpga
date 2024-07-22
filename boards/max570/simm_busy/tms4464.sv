module tms4464
  (
   input 	    clk,
   input [23:0]     addr,
   output [7:0]     rd_data,
   output 	    busy,
   output 	    ack,
   input 	    write,
   input 	    ena,
   output reg [11:0] ram_addr,
   input [7:0] 	    ram_dq,
   output reg 	    ram_we_,
   output reg 	    ram_ras_,
   output reg 	    ram_cas_
   );

   typedef enum      { INIT, IDLE, U0, U1 } state_t;
   reg [4:0] 	     state = INIT;
   reg [3:0] 	     twait = 0;
   reg [7:0] 	     dlatch = 0;
   reg [13:0] 	     cyc = 0;
   parameter refresh_cycles = 781;
   // parameter refresh_cycles = 40;
   reg 		     init = 1;

   typedef enum       { NOP, DLATCH, COLA, ROWA } op_t;
   typedef struct {
      bit 	  we_;
      bit 	  cas_;
      bit 	  ras_;
      bit [2:0]   op;
      bit [3:0]   stall;
      bit 	  h;
   } u_control;
   reg [4:0] 	  upc = 0;
   u_control  	  uinst;

   assign busy = (state != IDLE);
   assign rd_data = dlatch;

   always @(*) begin
      case (upc)
	//
	// CBR refresh.
	// 0. cas low, others don't care. wait 90 ns
	// 1. ras low. wait 100ns
	//
	0: uinst <= '{we_:1, ras_:1, cas_:0, op:NOP, stall:4, h:0};
	1: uinst <= '{we_:1, ras_:0, cas_:0, op:NOP, stall:4, h:0};
	2: uinst <= '{we_:1, ras_:1, cas_:1, op:NOP, stall:4, h:1};
	//
	// 8-bit Read cycle.
	// present row addr, wait tRLCL=[25,50]ns=2c
	// ras low
	// present col addr
	// cas low, oe low, wait tw(CL)=50ns=3c (tw(RL)=100ns is satisfied)
	// latch data, cas high, oe high. wait tRHrd=10ns=1c
	// ras high. wait tw(RH)=90ns=5c (precharge)
	//
	3: uinst <= '{we_:1, ras_:1, cas_:1, op:ROWA, stall:2, h:0};
	4: uinst <= '{we_:1, ras_:0, cas_:1, op:NOP, stall:1, h:0};
	5: uinst <= '{we_:1, ras_:0, cas_:1, op:COLA, stall:0, h:0};
	6: uinst <= '{we_:1, ras_:0, cas_:0, op:NOP, stall:2, h:0};
	7: uinst <= '{we_:1, ras_:0, cas_:0, op:DLATCH, stall:0, h:0};
	8: uinst <= '{we_:1, ras_:1, cas_:1, op:NOP, stall:0, h:1};
	//
	// 8-bit Write cycle (early).
	// we_ is either don't-care or low.
	// present row addr, ras low, we low. wait tRLCL=[25,50]ns=2c
	// present col addr, cas low, present data (tri-state assign),
	//      wait max(th(CLW), th(CLD)) = max(30,30) = 2c
	//      but also meet tRLCH and tw(RL) = 100ns, so 3c to make 5c total
	// cas high, ras high, we high. wait tw(RH) = 90ns = 5c
	//
	11: uinst <= '{we_:0, ras_:1, cas_:1, op:ROWA, stall:2, h:0};
	12: uinst <= '{we_:0, ras_:0, cas_:1, op:NOP, stall:2, h:0};
	13: uinst <= '{we_:0, ras_:0, cas_:1, op:COLA, stall:2, h:0};
	14: uinst <= '{we_:0, ras_:0, cas_:0, op:NOP, stall:3, h:0};
	15: uinst <= '{we_:1, ras_:1, cas_:1, op:NOP, stall:4, h:1};

	default:
	  uinst <= '{we_:1, ras_:1, cas_:1, op:NOP, stall:0, h:1};
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
	      cyc <= cyc - 14'(refresh_cycles);
	      upc <= 0;
	      state <= U0;
	   end else if (ena) begin
	      ack <= 1;
	      if (write) begin
		 upc <= 11;
		 state <= U0;
	      end else begin
		 upc <= 3;
		 state <= U0;
	      end
	   end
	end
	U0: begin  // state: 2
	   ram_we_ <= uinst.we_;
	   ram_ras_ <= uinst.ras_;
	   ram_cas_ <= uinst.cas_;
	   case (uinst.op)
	     DLATCH: dlatch <= ram_dq;
	     // ROWA: ram_addr <= addr[11:0];  // not swapped
	     // COLA: ram_addr <= addr[23:12];
	     ROWA: ram_addr <= addr[23:12];  // swap
	     COLA: ram_addr <= addr[11:0];
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
