`define TOP_DELAY_THEN(next) \
   begin \
      if (!lcd_busy) delay <= delay - 1; \
      if ($signed(delay) < 0) state <= next; \
   end

module lcdtest(input clk, inout [1:0]JC,
               output [15:0] led, [6:0]seg, [3:0]an );
   wire lcd_busy, scl, sda;
   localparam us = 100;
   localparam ms = us * 1000;

   assign scl = JC[0];
   assign sda = JC[1];
   
   hd44780 lcd(.clk(clk), .scl_in(scl), .sda_in(sda), 
               .scl_out(scl), .sda_out(sda), .busy(lcd_busy));
   
   enum      bit[2:0] { RESET, RESET_1, INIT, INIT_1, WRITE, WRITE_1 } state = RESET;
   reg [31:0] delay;
   assign led[2:0] = state;
   assign led[11] = lcd.we;
   assign led[12] = lcd.rst_n;
   assign led[14:13] = JC;
   assign led[15] = lcd_busy;

   always_ff @(posedge clk) begin
      case (state)
        RESET: begin
           delay <= 100 * ms;
           state <= RESET_1;
        end
        RESET_1: `TOP_DELAY_THEN(INIT)
        INIT: begin
           lcd.cmd <= lcd.CMD_INIT;
           if (lcd_busy) state <= INIT_1; // if init started
        end
        INIT_1: if (!lcd_busy) state <= WRITE; // if init done
        WRITE: begin
           lcd.cmd <= lcd.CMD_WRITE;
           if (lcd_busy) state <= WRITE_1; // if write started
        end
        WRITE_1: if (!lcd_busy) state <= WRITE; // write forever
      endcase // case (state)
   end
   
endmodule; // lcdtest
