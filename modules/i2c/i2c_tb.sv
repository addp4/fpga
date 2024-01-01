`timescale 1ns / 1ps
`define SDA (sda === 'z ? 1 : 0)
`define SCL (scl === 'z ? 1 : 0)

module i2c_tb();

   reg clk=0, busy=0, rst_n=1, we, sda_in, scl_in;
   wire sda, scl, error;
   
   simple_i2c #1 i2c(.clk(clk), .rst_n(rst_n), .write_ena(we), .busy(busy), .error(error),
                     .sda_in(sda_in), .scl_in(scl_in), .sda_out(sda), .scl_out(scl));
   pullup(scl);
   pullup(sda);
   // Run the clock
   always #1 clk++;
   
   initial begin
      logic d0, d1;
      time  t0, t1, t2;
      int  data, want;
      localparam address = 8'h27;
     
      $monitor("time=%0d rst_n=%0d we=%0d busy=%d i2c_state=%s cmd=%s clk=%d i2c_delay=%0d shift_count=%d shift_data=%0x scl_in=%0d scl_out=%0d sda_in=%0d sda_out=%0d", 
               $time, i2c.rst_n, i2c.write_ena, busy, i2c.state.name(), i2c.cmd.name(), clk, i2c.delay, i2c.shift_count, i2c.shift_data, i2c.scl_in, i2c.scl_out, i2c.sda_in, i2c.sda_out);

      i2c.delay_shift = 0;
      rst_n = 1;
      we = 0;
      
      // Send start sequence and target address on the bus.
      #8 i2c.address = address;
      #2 rst_n = 0;
      #2 rst_n = 1;
      
      // Receive start sequence
      // The start condition is indicated by a high-to-low transition of SDA with SCL high
      @(posedge scl);
      d0 = sda;
      t0 = $time;
      fork
         begin
            @scl;
            t2 = $time;
         end
         begin
            @sda;
            t1 = $time;
            d1 = sda;
         end
      join
      $display("start sequence t0=%0d(d=%d) t1=%0d(d=%d) t2=%0d", t0, d0, t1, d1, t2);
      assert(t0 < t1 && t1 < t2 && d0 == 1 && d1 == 0) $display("start sequence OK");
      else $error("start sequence failed");
      
      // Receive address byte shifted left 1, MSB first
      data = 0;
      for (int i = 7; i >= 0; i--) begin
         @scl;
         d0 = sda;
         $display("scl i=%0d sda=%d", i, d0);
         data = (data << 1) | d0;
         scl_in = 1;
         #8 scl_in = 'z;
         @scl;
      end
      assert((data >> 1) == address) $display("addr is good (%0x)", data >> 1);
        else $error("address: wanted %x got %x", address, data >> 1);
      assert((data & 1) == 0) $display("write mode is good (%0d)", data & 1);
        else $error("write mode: wanted 0 got %d", data & 1);

      // Send ack to DUT
      sda_in = 0;               // ack=0, nack=1
      @scl;
      scl_in = 1;
      #10 scl_in = 'z;
      $display("ack ack");

      while (busy) #1 ;
      
      // Send byte
      want = 8'b10101010;
      i2c.data = want;
      we = 1;
      while (busy == 0) #1 ;
      we = 0;
      
      // Receive byte
      data = 0;
      for (int i = 7; i >= 0; i--) begin
         @scl;
         d0 = sda;
         $display("scl i=%0d sda=%d", i, sda);
         data = (data << 1) | d0;
         scl_in = 1;
         #8 scl_in = 'z;
         @scl;
      end
      assert(data == want) $display("wrote expected value %0x", want);
        else $error("write: wanted %0x got %0x", want, data);
      
      // Send ack to DUT
      sda_in = 0;               // ack=0, nack=1
      @scl;
      scl_in = 1;
      #10 scl_in = 'z;
      $display("ack ack");
   end
endmodule // test_i2c

   
