`timescale 1ns / 1ps

module i2c_tb();

   reg clk=0, busy=0, sda_in, scl_in, rst_n=1, re, we;
   wire sda_out, scl_out, error;
   
   simple_i2c i2c(.clk(clk), .rst_n(rst_n), .read_ena(re), .write_ena(we),
                  .sda_in(sda_in), .scl_in(scl_in),
                  .sda_out(sda_out), .scl_out(scl_out), .busy(busy), .error(error));

   // Run the clock
   always #1 clk++;
   
   initial begin
      logic d0, d1;
      time  t0, t1, t2;
      int  data, want;
      localparam address = 8'h27;
     
      $monitor("time=%0d rst_n=%0d re=%0d we=%0d busy=%d state=%s cmd=%s clk=%d delay=%d shift_count=%d", 
               $time, i2c.rst_n, i2c.read_ena, i2c.write_ena, busy, i2c.state.name(), i2c.cmd.name(), clk, i2c.delay, i2c.shift_count);

      rst_n = 1;
      re = 0;
      we = 0;
      
      // Send start sequence and target address on the bus.
      #8 i2c.address = address;
      #2 rst_n = 0;
      #2 rst_n = 1;
      
      // Receive start sequence
      // The start condition is indicated by a high-to-low transition of SDA with SCL high
      @(posedge scl_out);
      d0 = sda_out;
      t0 = $time;
      fork
         begin
            @scl_out;
            t2 = $time;
         end
         begin
            @sda_out;
            t1 = $time;
            d1 = sda_out;
         end
      join
      $display("start sequence t0=%0d(d=%d) t1=%0d(d=%d) t2=%0d", t0, d0, t1, d1, t2);
      assert(t0 < t1 && t1 < t2 && d0 === 'z && d1 == 0) $display("start sequence OK");
      else $error("start sequence failed");
      
      // Receive address byte shifted left 1, MSB first
      data = 0;
      for (int i = 7; i >= 0; i--) begin
         @(posedge scl_out);
         d0 = (sda_out === 'z ? 1 : 0);
         $display("scl i=%0d sda=%d", i, sda_out);
         data = (data << 1) | d0;
         @(negedge scl_out);
         d1 = (sda_out === 'z ? 1 : 0);
         assert(d0 == d1) else $error("data changed during clock");
      end
      assert((data >> 1) == address) $display("addr is good (%0x)", data >> 1);
        else $error("address: wanted %x got %x", address, data >> 1);
      assert((data & 1) == 0) $display("write mode is good (%0d)", data & 1);
        else $error("write mode: wanted 0 got %d", data & 1);

      // Send ack to DUT
      sda_in = 0;               // ack=0, nack=1
      @scl_out;
      d0 = (sda_out === 'z ? 1 : 0);
      assert(d0) $display("master is waiting for ack, ack sent");
      @scl_out;
      sda_in = 'z;
      $display("ack ack");

      while (busy == 1) #1 ;
      
      // Send byte
      want = 8'b10101010;
      i2c.data = want;
      #2 we = 1;
      #2 we = 0;
      while (busy == 0) #1 ;
      
      // Receive byte
      data = 0;
      for (int i = 7; i >= 0; i--) begin
         @(posedge scl_out);
         d0 = (sda_out === 'z ? 1 : 0);
         $display("scl i=%0d sda=%d", i, sda_out);
         data = (data << 1) | d0;
         @(negedge scl_out);
         d1 = (sda_out === 'z ? 1 : 0);
         assert(d0 == d1) else $error("data changed during clock");
      end
      assert(data == want) $display("wrote expected value %0x", want);
        else $error("write: wanted %0x got %0x", want, data);
      
      // Send ack to DUT
      @(posedge scl_out);
      d0 = (sda_out === 'z ? 1 : 0);
      scl_in = 1;
      assert(d0) $display("master is waiting for ack, ack sent");
      @(negedge scl_out);
      $display("ack ack");
      scl_in = 'z;

   end
 
   
endmodule // test_i2c

   
