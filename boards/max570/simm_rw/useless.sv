/*
 Update a 32-bit integer in memory and verify against a register.
 */
parameter OFF = 4'd1;

module useless
  (
   input 	clk,
   input 	rst_n,
   output [11:0] ram_addr,
   inout [7:0] 	ram_dq,
   output 	ram_we_,
   output 	ram_ras_,
   output 	ram_cas_,
   output 	dq_dir,
   output 	max_clk,
   output 	max_din,
   output 	max_ce_
   );

   // DRAM device
   reg 		write = 0, ena = 0;
   reg [7:0] 	wr_data = 0;
   reg [7:0] 	rd_data = 0;
   reg 		busy;
   reg 		ack = 0;
   reg [23:0] 	addr = 0;
   reg [23:0] 	base_addr = 0;
   tms4464 ram(.clk(clk), .addr(addr), .rd_data(rd_data),
	       .busy(busy), .ack(ack), .write(write), .ena(ena),
	       .ram_addr(ram_addr), .ram_dq(ram_dq),
	       .ram_we_(ram_we_), .ram_ras_(ram_ras_), .ram_cas_(ram_cas_)
	       );
   assign ram_dq = (!ram_we_ ? wr_data : 4'hz);
   assign dq_dir = !ram_we_;

   // 8-digit SPI display
   reg [31:0] 	max_display;
   max7219 max(.clk(clk), .rst_n(rst_n), .max_din(max_din), .ce_(max_ce_),
	       .max_clk(max_clk), .display_value(max_display[31:0]));

   reg [4:0] 	state = 0;
   reg [15:0] 	expected = 0;
   reg [15:0] 	mem_val = 0;
   assign max_display[23:0] = base_addr;

   always @(posedge clk) begin
      case (state)
	0: if (!busy) state <= 1; // ram init
	1: begin
	   addr <= base_addr;
	   write <= 0;
	   ena <= 1;
	   if (ack) state <= 2;
	end
	2: begin
	   ena <= 0;
	   mem_val[7:0] = rd_data;
	   if (!busy) state <= 3;
	end
	3: begin
	   addr <= base_addr + 24'd1;
	   write <= 0;
	   ena <= 1;
	   if (ack) state <= 4;
	end	   
	4: begin
	   ena <= 0;
	   mem_val[15:8] = rd_data;
	   if (!busy) state <= 5;
	end
	5: begin
	   if (mem_val == expected) begin
	      mem_val <= mem_val + 16'd1;
	      expected <= expected + 16'd1;
	      base_addr <= base_addr + 24'd1;
	      state <= 6;
	   end
	end
	6: begin
	   addr <= base_addr;
	   wr_data <= mem_val[7:0];
	   write <= 1;
	   ena <= 1;
	   if (ack) state <= 7;
	end
	7: begin
	   ena <= 0;
	   if (!busy) state <= 8;
	end
	8: begin
	   addr <= base_addr + 24'd1;
	   wr_data <= mem_val[15:8];
	   write <= 1;
	   ena <= 1;
	   if (ack) state <= 9;
	end
	9: begin
	   ena <= 0;
	   if (!busy) state <= 1;
	end
      endcase // case (state)
   end
endmodule // useless

