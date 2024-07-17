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
   reg [7:0] 	rd_data = 0;
   reg 		busy;
   reg 		ack = 0;
   reg 		error = 0;
   reg [15:0] 	addr = 0;
   tms4464 ram(.clk(clk), .addr(addr), .rd_data(rd_data),
	       .busy(busy), .ack(ack), .write(write), .ena(ena),
	       .ram_addr(ram_addr), .ram_dq(ram_dq),
	       .ram_we_(ram_we_), .ram_oe_(ram_oe_),
	       .ram_ras_(ram_ras_), .ram_cas_(ram_cas_)
	       );
   assign ram_dq = (!ram_we_ ? wr_data : 4'hz);
   assign dir = !ram_we_;

   // Indicator (glowing)
   glow_led glo(.clk(clk), .led(led_glow));

   // 8-digit SPI display
   reg [31:0] 	max_display;
   max7219 max(.clk(clk), .rst_n(rst_n), .max_din(max_din), .ce_(max_ce_),
	       .max_clk(max_clk), .display_value(max_display[31:0]));

   reg [2:0] 	state = 0;
   reg [24:0] 	count = 0;
   // assign led[3:0] = rd_data;
   assign max_display[31:28] = error ? 4'hf : 4'h0;
   assign max_display[27:24] = (busy & !ena) ? 4'd8 : 4'd1;
   assign max_display[23:16] = rd_data;
   assign max_display[15:0] = addr[15:0];
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
	   if (addr[3:0] + OFF != rd_data[3:0]) error <= 1;
	   if (addr[3:0] + OFF + 4'd1 != rd_data[7:4]) error <= 1;
	   // addr <= addr + 16'd1;
	   // state <= 4;
	   count <= 1;
	   state <= 7;
	end
	7: begin
	   count <= count + 24'd1;
	   if (count[20:0] == 21'd0) begin
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

