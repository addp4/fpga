parameter ALEN = 16;

module useless
  (
   input 		 clk,
   output reg [ALEN-1:0] ram_addr,
   inout [7:0] 		 ram_dq,
   output reg 		 ram_we_,
   output reg 		 ram_oe_
   );

   reg 		     write = 0, ena = 0;
   reg [7:0] 	     wr_data = 0;
   reg [7:0] 	     rd_data = 0;
   reg 		     busy;
   reg [ALEN-1:0]    addr = 0;
   reg [ALEN-1:0]    ptr = 2;
   reg [3:0] 	     state = 13;
   reg [23:0] 	     count = 0;
	     
   hm628128 ram(.clk(clk), .addr(addr), .rd_data(rd_data),
		.busy(busy), .write(write), .ena(ena),
		.ram_addr(ram_addr), .ram_dq(ram_dq),
		.ram_we_(ram_we_), .ram_oe_(ram_oe_));
   assign ram_dq = (!ram_we_ ? wr_data : 8'hz);

   always @(posedge clk) begin
      // states 0-4 write a circular linked list to bytes [0..65535] where
      // each pointer is two bytes little endian. memory contents:
      //   addr value
      //   0     2
      //   1     0
      //   2     4
      //   3     0
      //   ...
      //   65534 0
      //   65535 0
      case (state)
 	0: begin		// write low byte of ptr at even addr
	   wr_data <= ptr[7:0];
	   write <= 1;
	   ena <= 1;
	   if (busy) state <= 1;
	end
	1: begin
	   ena <= 0;
	   if (!busy) begin
	      addr <= addr + 16'd1;
	      state <= 2;
	   end
	end
	2: begin		// write high byte of pointer at odd addr
	   wr_data <= ptr[15:8];
	   write <= 1;
	   ena <= 1;
	   if (busy) state <= 3;
	end
	3: begin
	   ena <= 0;
	   if (!busy) state <= 4;
	end
	4: begin
	   if (addr != 16'hffff) begin
	      ptr <= ptr + 16'd2;
	      addr <= addr + 16'd1;
	      state <= 0;
	   end else begin
	      addr <= 0;
	      ptr <= 0;
	      state <= 5;
	   end
	end
	// states 5+ perform pointer chasing. set addr to the byte at addr.
	5: begin		// read low byte
	   write <= 0;
	   ena <= 1;
	   if (busy) state <= 6;
	end
	6: begin
	   ena <= 0;
	   if (!busy) state <= 7;
	end
	7: begin
	   ptr <= { 8'd0, rd_data };
	   addr <= addr + 16'd1;
	   state <= 8;
	end
	8: begin		// read high byte
	   write <= 0;
	   ena <= 1;
	   if (busy) state <= 9;
	end
	9: begin
	   ena <= 0;
	   if (!busy) state <= 10;
	end
	10: begin
	   addr <= { 8'd0, rd_data };
	   // ptr[15:8] <= rd_data;
	   ptr[15:8] <= 0;
	   count <= 1;
	   state <= 11;
	end
	11: begin
	   count <= count + 24'd1;
	   if (count == 24'd0) state <= 12;
	end
	12: begin
	   addr <= ptr;
	   state <= 5;
	end
	13: begin
	   count <= 1;
	   state <= 14;
	end
	14: begin
	   count <= count + 24'd1;
	   if (count == 24'd0) state <= 0;
	end
	   
      endcase // case (state)
   end
      
endmodule // useless


module hm628128
  (
   input 	     clk,
   input [ALEN-1:0]  addr,
   output reg [7:0]  rd_data,
   output 	     busy,
   input 	     write,
   input 	     ena,
   output [ALEN-1:0] ram_addr,
   input [7:0] 	     ram_dq,
   output 	     ram_we_,
   output 	     ram_oe_
   );

   typedef enum     { IDLE, U0, U1 } state_t;
   reg [2:0] 	    state = IDLE;
   reg [2:0] 	    twait = 0;

   typedef enum       { NOP, LATCH_DATA } op_t;
   typedef struct packed {
      bit 	  we_;
      bit 	  oe_;
      bit 	  op;
      bit [2:0]   cycles;
      bit 	  h;
   } u_control;
   
   reg [2:0] 	      upc;
   u_control  	      uinst;
   
   assign ram_addr = addr;
   assign busy = (state != IDLE);
   // assign rd_data = data_latch;

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
       // 2. present addr and data, we_ low, wait tw(CL)=70ns=4c
       // 3. we_ high
       //
       2: uinst <= '{oe_:1, we_:0, op:NOP, cycles:4, h:0};
       3: uinst <= '{oe_:1, we_:1, op:NOP, cycles:1, h:1};
       
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
	   if (uinst.op == LATCH_DATA) rd_data <= ram_dq;
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
