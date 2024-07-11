module useless
  (
   input 	clk,
   output [7:0] ram_addr,
   inout [7:0] 	ram_io,
   output 	ram_we_,
   output 	ram_oe_
   );

   reg 		     write = 0, ena = 0;
   reg [7:0] 	     wr_data = 0;
   reg [7:0] 	     rd_data = 0;
   reg 		     busy;
   reg [7:0] 	     addr = 0;
	     
   hm628128 ram(clk, addr, rd_data, busy, write, ena,
     ram_addr, ram_io, ram_we_, ram_oe_);
   assign ram_io = (!ram_we_ ? wr_data : 8'hz);

   reg [2:0] 	     state = 0;
   reg [21:0] 	     count = 0;

   always @(posedge clk) begin
      // states 0-2 write a linked list to the first 256 bytes of the
      // memory: a[0] = 1, a[1] = 2, ..., a[255] = 0
      case (state)
	0: begin
	   // wr_data <= 8'b10101010;
	   // wr_data <= 8'b00101011;
	   wr_data <= addr + 8'd1;
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
	   count <= count + 22'd1;
	   if (count == 22'd0) state <= 3;
	end
	   
      endcase // case (state)
   end
      
endmodule // useless

module hm628128_old
  (
   input 	     clk,
   input [7:0]      addr,
   output [7:0]      rd_data,
   output 	     busy,
   input 	     write,
   input 	     ena,
   output reg [7:0] ram_addr,
   input [7:0] 	     ram_io,
   output reg 	     ram_we_,
   output reg 	     ram_oe_
   );

   typedef enum { IDLE, R0, R1, W0, W1 } state_t;
   reg [4:0]  	      state = IDLE;
   reg [7:0] 	      t_ns = 0;  // max 255
   reg [7:0] 	      data_latch = 8'hff;

   assign busy = state != IDLE;
   assign ram_addr = addr;
   assign rd_data = data_latch;
   
   always @(posedge clk) begin
      case (state)
	IDLE: begin
	   // Command = output disable
	   ram_oe_ <= 1;
	   ram_we_ <= 1;
	   if (ena && !write) state <= R0;
	   if (ena && write) state <= W0;
	end
	R0: begin
	   ram_oe_ <= 0;
	   ram_we_ <= 1;
	   t_ns <= 0;
	   state <= R1;
	end
	R1: begin
	   t_ns <= t_ns + 8'd20;
	   if (t_ns >= 8'd70) begin
	      data_latch <= ram_io;
	      // Pre-disable RAM output so if the next op is
	      // write, t(OHZ) will already be met.
	      ram_oe_ <= 1;
	      state <= IDLE;
	   end
	end
	W0: begin
	   ram_oe_ <= 1;
	   ram_we_ <= 0;  // Drives ram_io.
	   t_ns <= 0;
	   state <= W1;
	end
	W1: begin
	   t_ns <= t_ns + 8'd20;
	   if (t_ns >= 8'd70) begin
	      ram_we_ <= 1;
	      state <= IDLE;
	   end
	end
      endcase
   end
endmodule // hm628128_old

module hm628128
  (
   input 	    clk,
   input [7:0] 	    addr,
   output [7:0]     rd_data,
   output 	    busy,
   input 	    write,
   input 	    ena,
   output reg [7:0] ram_addr,
   input [7:0] 	    ram_dq,
   output reg 	    ram_we_,
   output reg 	    ram_oe_
   );

   typedef enum     { IDLE, U0, U1 } state_t;
   reg [2:0] 	    state = IDLE;
   reg [2:0] 	    twait = 0;
   reg [7:0] 	    data_latch = 0;

   typedef enum       { NOP, LATCH_DATA } op_t;
   typedef struct packed {
      bit 	  we_;
      bit 	  oe_;
      bit 	  op;
      bit [2:0]   cycles;
      bit 	  h;
   } u_control;
   
   reg [1:0] 	      upc;
   u_control  	      uinst;
   
   assign ram_addr = addr;
   assign busy = (state != IDLE);
   assign rd_data = data_latch;

   always @(*) begin
     case (upc)
       //
       // Read cycle.
       // 0. present addr, oe low, wait tw(CL)=70ns=4c
       // 1. latch data, oe high, wait t(OHZ)=25ns=1c
       //
       0: uinst <= '{oe_:0, we_:1, op:NOP, cycles:4, h:0};
       1: uinst <= '{oe_:1, we_:1, op:LATCH_DATA, cycles:1, h:1};
       //
       // Write cycle.
       // 2. present addr, we_ low, wait tw(CL)=70ns=4c
       // 3. we_ high
       //
       2: uinst <= '{oe_:1, we_:0, op:NOP, cycles:4, h:0};
       3: uinst <= '{oe_:1, we_:1, op:NOP, cycles:0, h:1};
       
       default:
	 uinst <= '{oe_:1, we_:1, op:NOP, cycles:0, h:1};
     endcase // case (upc)
   end // always @ (*)
   
   always @(posedge clk) begin
      case (state)
	IDLE: begin  // state:0
	   // output disable
	   ram_oe_ <= 1;
	   ram_we_ <= 1;
	   if (ena && !write) begin
	      upc <= 0;		// read
	      state <= U0;
	   end else if (ena && write) begin
	      upc <= 2;		// write
	      state <= U0;
	   end
	end
	U0: begin  // state: 1
	   ram_oe_ = uinst.oe_;
	   ram_we_ = uinst.we_;
	   if (uinst.op == LATCH_DATA) data_latch <= ram_dq;
	   twait <= 2;
	   state <= U1;
	end
	U1: begin  // state: 2
	   twait <= twait + 3'd1;
	   if (twait >= uinst.cycles) begin
	      if (uinst.h) begin
		 state <= IDLE;
	      end else begin
		 upc <= upc + 2'd1;
		 state <= U0;
	      end
	   end
	end
      endcase
   end
   
endmodule

