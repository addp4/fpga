`ifdef x
`timescale 1ns / 1ns

module useless_tb();

   reg clk=0, write=0, ena=0;
   wire busy;
   reg ram_we_, ram_oe_, ram_ras_, ram_cas_;
   reg [16:0] addr;  // 128K
   reg [7:0] ram_addr;
   reg [7:0]  data_in;
   wire [7:0]  data_out;
   wire [3:0]  ram_dq;
   wire sda, scl, error;
   
   useless ram(.clk(clk), 
	       .addr(addr),
	       .data_in(data_in),
	       .data_out(data_out),
	       .busy(busy),
	       .write(write),
	       .ena(ena),
	       .ram_addr(ram_addr),
	       .ram_dq(ram_dq),
	       .ram_we_(ram_we_),
	       .ram_oe_(ram_oe_),
	       .ram_ras_(ram_ras_),
	       .ram_cas_(ram_cas_)
	       );
   
   // Run the clock
   always #1 clk++;
   reg [31:0] t;
   int 	      t0;
   always @(posedge clk) t <= t + 20;

   initial begin
      #3;
      ena <= 1;
      if (busy) $error("expected !busy got 1");
      addr <= 100;
      write <= 0;
      t0 <= $time;
      @(posedge busy);
      if ($time-t0 != 2) $error("expected 2 got", $time-t0);
      ena <= 0;
      @(posedge busy);
      if ($time-t0 < 7) $error("expected at least 7 got", $time-t0);
      if ($time-t0 > 8) $error("expected lt 8 got", $time-t0);
      
   end
  
endmodule  // useless_tb
`endif
