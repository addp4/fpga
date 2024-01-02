module lcdtest(input clk, input [4:0]sw, input btnC, inout [1:0]JC,
               output [15:0] led, [0:6]seg, [3:0]an );
   wire lcd_busy, scl, sda, rst_n;
   localparam us = 100;
   localparam ms = us * 1000;

   assign scl = JC[0];
   assign sda = JC[1];
   assign rst_n = btnC;

   hd44780 lcd(.clk(clk), .scl_in(scl), .sda_in(sda),
               .scl_out(scl), .sda_out(sda), .busy(lcd_busy));
   Seven_segment_LED_Display_Controller sevenseg(.clock_100Mhz(clk), .reset(rst_n),
                                                 .Anode_Activate(an), .LED_out(seg),
                                                 .displayed_number({lcd.i2c.shift_count[3:0],
                                                                    lcd.i2c.state[3:0],
                                                                    lcd.i2c.data}));
   assign lcd.i2c.delay_shift = sw;

   enum      bit[2:0] { RESET, RESET_1, INIT, INIT_1, WRITE, W1, W2, W3 } state = RESET;
   reg [31:0] delay;
   reg [7:0]  chr = 8'h20;
   reg [5:0]  col = 19;         // count down
   reg [1:0]  row = 0;          // 0..3
   assign led[0] = lcd.i2c.ack;
   assign led[1] = lcd.i2c.error;
   assign led[4:2] = state;
   assign led[9:5] = lcd.state;
   assign led[11:10] = lcd.cmd;
   assign led[12] = lcd.rst_n;
   assign led[14:13] = JC;
   assign led[15] = lcd_busy;

   always_ff @(posedge clk) begin
      case (state)
        RESET: begin
           lcd.cmd <= lcd.CMD_IDLE;
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
           lcd.cmd <= lcd.CMD_IDLE;
           if (!lcd_busy) state <= WRITE; // if init done
        end

        WRITE: begin
           if (signed'(col) < 0) begin
              col <= 19;
              row <= row + 1;
              case (row)        // DDRAM addr for start of row
                0: lcd.vchr <= 9'b1_1000_0000;
                1: lcd.vchr <= 9'b1_1100_0000;
                2: lcd.vchr <= 9'b1_1001_0100;
                3: lcd.vchr <= 9'b1_1101_0100;
              endcase
           end
           else begin
              col <= col - 1;
              lcd.vchr <= 9'(chr);
              if (chr == 8'h7f) chr <= 8'h20;
              else chr <= chr + 1;
           end // else: !if(signed'(col) < 0)
           state <= W1;
        end
        W1: begin
           lcd.cmd <= lcd.CMD_WRITE;
           if (lcd_busy) state <= W2; // if write started
        end
        W2: if (!lcd_busy) state <= WRITE; // write forever
      endcase // case (state)
   end

endmodule  // lcdtest
