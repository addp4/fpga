module useless
  #(parameter ABITS = 8)
  (
   input 	      clk,
   output [ABITS-1:0] ram_addr,
   inout [7:0] 	      ram_io,
   output 	      ram_we_,
   output 	      ram_oe_
   );

   reg 		     write = 0, ena = 0;
   reg [7:0] 	     wr_data = 0;
   reg [7:0] 	     rd_data = 0;
   reg 		     busy;
   reg [ABITS-1:0]   addr = 0;
	     
   hm628128 ram(clk, addr, rd_data, busy, write, ena,
     ram_addr, ram_io, ram_we_, ram_oe_);
   assign ram_io = (!ram_we_ ? wr_data : 8'hz);

   reg [2:0] 	     state = 0;
   reg [22:0] 	     count = 0;

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
	   count <= count + 23'd1;
	   if (count == 23'd0) state <= 3;
	end
	   
      endcase // case (state)
   end
      
endmodule // useless

module hm628128
  (
   input 	     clk,
   input [16:0]      addr,
   output [7:0]      rd_data,
   output 	     busy,
   input 	     write,
   input 	     ena,
   output reg [16:0] ram_addr,
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
   
endmodule
