module top(input clk,
	   input  rst_n,
	   output vfd_sdi,
	   output vfd_cs,
	   output vfd_clk,
	   output led_blink,
	   output done);
   reg [31:0] cnt;
   always @(posedge clk) cnt <= cnt + 1;
   assign led_blink = cnt[23];    // free-running divider
   reg [63:0] display_value;

   /*
   max7219 display(.clk(clk),
			.rst_n(rst_n),
			.max_din(spi_din),
			.ce_(spi_ce_),
			.max_clk(spi_clk),
			.display_value(display_value)
                    );
   */

   // Inside your top module (add outputs vfd_clk, vfd_cs, vfd_sdi to its port list):
   vfd_16sd13gink #(
		    .CLK_HZ(50_000_000),
		    .SCLK_HZ(10_000),        // datasheet max 500_000
		    .COMMAS(1)
		    ) u_vfd (
			     .clk    (clk),
			     .rst_n  (rst_n),
			     .value  (display_value),   // any 64-bit value; bits [47:0] are shown
			     .vfd_clk(vfd_clk),
			     .vfd_cs (vfd_cs),
			     .vfd_sdi(vfd_sdi)
			     );

   // Busybeaver module
   wire [63:0] bb_count;
   wire	       bb_halt;

   busybeaver_143space bb0(.clk(clk), .rst_n(rst_n), .count(bb_count), .halt(bb_halt));

   always @(posedge clk) begin
      display_value <= bb_count;
   end

endmodule
