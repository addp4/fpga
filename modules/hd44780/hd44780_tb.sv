`timescale 1ns / 1ps

module hd44780_tb();

   reg clk=0, busy=0, ena=0, sda_in, scl_in;
   wire sda_out, scl_out, error;
   
   hd44780 #1 lcd(.clk(clk), .sda_in(sda_in), .scl_in(scl_in),
                  .sda_out(sda_out), .scl_out(scl_out), .busy(busy));
   
   always #1 clk++;
   
   initial begin
      $monitor("time=%0d i2c_busy=%d i2c_data=%x lcd.state=%s i2c.cmd=%s i2c.state=%s clk=%d delay=%0d dindex=%d", 
               $time, lcd.i2c_busy, lcd.i2c.data, lcd.state.name(), lcd.i2c.cmd.name(), lcd.i2c.state.name(), clk, lcd.i2c.delay, lcd.dindex);

      lcd.i2c.delay_shift = 0;
      scl_in = 1;               // fake the handshake for clock
      sda_in = 0;               // fake the handshake for ack
      
      lcd.cmd <= lcd.CMD_IDLE;
      #2 lcd.cmd = lcd.CMD_INIT;
      while (!busy) #1;
      lcd.cmd = lcd.CMD_IDLE;
      while (busy) #1;
      #100 lcd.cmd = lcd.CMD_WRITE;
      
   end
     
endmodule; // hd44780_tb
