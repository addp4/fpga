`timescale 1ns / 1ns

module tb_simm();

   reg clk=0;
   reg [23:0] addr;
   reg write=0, ena=0;
   reg dtack;
   reg ram_we_, ram_ras_, ram_cas_;
   reg [11:0] ram_addr;
   reg [7:0]  rd_data;
   reg [7:0] wr_data;
   wire [7:0]  ram_dq;
   wire sda, scl, error;

   simm_16mb ram(.clk(clk),
		 .addr(addr),
		 .rd_data(rd_data),
		 .dtack(dtack),
		 .write(write),
		 .ena(ena),
		 .ram_addr(ram_addr),
		 .ram_dq(ram_dq),
		 .ram_we_(ram_we_),
		 .ram_ras_(ram_ras_),
		 .ram_cas_(ram_cas_)
		 );

   // Run the clock
   always #1 clk++;
   int 	      t0, t_ras, t_cas, t_ras2, ras_to_cas;
   assign ram_dq = !ram_we_ ? wr_data : 8'hz;

   initial begin
      // Read at address 100
      addr <= 100;
      write <= 0;
      wr_data <= 1;
      ena <= 1;
      t0 <= $time;
      @(posedge dtack);

      ena <= 0;
      #2 ena <= 1;
      write <= 1;
      wr_data <= 2;
      @(posedge dtack);


      if ($time-t0 != 2) $error("expected 2 got", $time-t0);
      @(negedge ram_ras_);
      t_ras = $time;
      @(negedge ram_cas_);
      t_cas = $time;
      @(posedge ram_ras_);
      t_ras2 = $time;
      ras_to_cas = t_cas - t_ras;
      if (ras_to_cas < 3 || ras_to_cas > 5)
	$error("expected ras_to_cas in [25,50] got", ras_to_cas);
      if (t_ras2 - t_ras < 10)
	$error("expected ras_low to ras_high >= tw(RL) got", t_ras2 - t_ras);
      @(negedge dtack);
      if ($time-t_ras < 20) $error("expected cycle time at least 20 got", $time-t_ras);
      if ($time-t_ras > 23) $error("read cycle time excessive, got", $time-t_ras);

   end

endmodule // tms4464_tb
