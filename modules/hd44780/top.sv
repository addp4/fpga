module lcdtest(input clk, inout [1:0]JC,
               output [15:0] led, [0:6]seg, [3:0]an );
   wire lcd_busy, scl, sda;
   reg [15:0] segment_value;
   localparam us = 100;
   localparam ms = us * 1000;

   assign scl = JC[0];
   assign sda = JC[1];
   
   hd44780 lcd(.clk(clk), .scl_in(scl), .sda_in(sda), 
               .scl_out(scl), .sda_out(sda), .busy(lcd_busy));
   Seven_segment_LED_Display_Controller(.clock_100Mhz(clk), .reset(rst_n), 
                                        .Anode_Activate(an), .LED_out(seg),
                                        .displayed_number({lcd.i2c.shift_data, lcd.i2c.data}));
   
   enum      bit[2:0] { RESET, RESET_1, INIT, INIT_1, WRITE, WRITE_1 } state = RESET;
   reg [31:0] delay;
   assign led[2:0] = state;
   assign led[7:3] = lcd.state;
   assign led[9:8] = lcd.cmd;
   assign led[11] = lcd.we;
   assign led[12] = lcd.rst_n;
   assign led[14:13] = JC;
   assign led[15] = lcd_busy;

   always_ff @(posedge clk) begin
      case (state)
        RESET: begin
           delay <= 1000 * ms;
           state <= RESET_1;
        end
        RESET_1: begin
           delay <= delay - 1;
           if (signed'(delay) < 0) state <= INIT;
        end
        INIT: begin
           lcd.cmd <= lcd.CMD_INIT;
           if (lcd_busy) state <= INIT_1; // if init started
        end
        INIT_1: begin
           if (!lcd_busy) state <= WRITE; // if init done
        end
        WRITE: begin
           lcd.cmd <= lcd.CMD_WRITE;
           if (lcd_busy) state <= WRITE_1; // if write started
        end
        WRITE_1: if (!lcd_busy) state <= WRITE; // write forever
      endcase // case (state)
   end
   
endmodule  // lcdtest
