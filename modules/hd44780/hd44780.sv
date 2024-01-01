`timescale 1ns / 1ps
// https://en.wikipedia.org/wiki/Hitachi_HD44780_LCD_controller 

`define DELAY_THEN(next) \
   begin \
      if (!i2c_busy) delay <= delay - 1; \
      if (signed'(delay) < 0) state <= next; \
   end

module hd44780 #(parameter SIM=0) (
     input  clk,
     input  sda_in,
     input  scl_in,
     output sda_out,
     output scl_out,
     output busy
                                  );
   localparam us = 100;
   reg [31:0]         delay;
   wire               i2c_busy, error;
   reg                rst_n = 1, we = 0;
   reg [4:0]          dindex;
   reg [7:0]          data8;
   reg [7:0]          vchr;
   reg [3:0]          init_data[14] = {4'b0011, // magic crap, first set to 8 bits by sending
                                       4'b0011, // ... 0011 three times. this is supposed to
                                       4'b0011, // ... work in any mode
                                       4'b0010, // now set to 4-bit mode
                                       4'b0010, 4'b1000, // set N=1 and F=0, 53us
                                       4'b0000, 4'b1000, // display control (d=0, c=0, b=0), 53us
                                       4'b0000, 4'b0001, // clear display, 3000us
                                       4'b0000, 4'b0110, // entry mode (id=1), 53us
                                       4'b0000, 4'b1111  // display control (d=1, c=1, b=1), 53us
                                       };
   reg [13:0]         init_delay[14] = {4100, 100, 100, 100, 0, 53, 0, 53, 0, 3000, 0, 53, 0, 53};
   enum      logic[4:0] {
                         IDLE, INIT, INIT_1, INIT_2, INIT_3, INIT_4, INIT_5, INIT_6, INIT_7,
                         WRITE_1, WRITE_2, WRITE_3, WRITE_4,
                         WRITE_5, WRITE_6, WRITE_7, WRITE_8
                       } state = IDLE;
   enum      logic[1:0] {
                       CMD_IDLE,
                       CMD_INIT,
                       CMD_WRITE
                       } cmd;
   
   simple_i2c #SIM i2c(.clk(clk), .rst_n(rst_n), .write_ena(we),
                       .sda_in(sda_in), .scl_in(scl_in), .sda_out(sda_out), .scl_out(scl_out),
                       .busy(i2c_busy), .error(error));

   assign busy = (state != IDLE);
   
   always_ff @(posedge clk) begin
      case (state)
        IDLE: begin
           case (cmd)
             CMD_INIT: state <= INIT;
             CMD_WRITE: state <= WRITE_1;
             default: state <= IDLE;
           endcase // case (cmd)
        end
        INIT: begin
           i2c.address <= 8'h27;
           rst_n <= 0;          // reset i2c
           we <= 0;
           dindex <= 0;
           if (i2c_busy) state <= INIT_1;
        end
        INIT_1: begin
           rst_n <= 1;
           if (!i2c_busy) state <= INIT_2; // wait for i2c init done
        end
        INIT_2: begin
           data8 <= 8'(init_data[dindex]);
           state <= INIT_3;
        end
        INIT_3: begin
           i2c.data <= (data8 << 4) | 4'b1100;  // 8'b00111100;
           we <= 1;
           delay <= SIM ? 0 : 100 * us;
           if (i2c_busy) state <= INIT_4;
        end
        INIT_4: begin
           we <= 0;
           `DELAY_THEN(INIT_5)
        end
        INIT_5: begin
           i2c.data <= (data8 << 4) | 4'b1000;
           we <= 1;
           delay <= SIM ? 0 : init_delay[dindex] * us;
           if (i2c_busy) state <= INIT_6;
        end
        INIT_6: begin
           we <= 0;
           `DELAY_THEN(INIT_7)
        end
        INIT_7: begin
           dindex <= dindex + 1;
           if (dindex + 1 < 14) state <= INIT_2;
           else state <= IDLE;
        end

        WRITE_1: begin
           i2c.data <= (vchr & 8'hf0) | 4'b1101;
           we <= 1;
           delay <= SIM ? 0 : 100 * us;
           if (i2c_busy) state <= WRITE_2;
        end
        WRITE_2: begin
           we <= 0;
           `DELAY_THEN(WRITE_3)
        end
        WRITE_3: begin
           i2c.data <= (vchr & 8'hf0) | 4'b1001;
           we <= 1;
           delay <= SIM ? 0 : 100 * us;
           if (i2c_busy) state <= WRITE_4;
        end
        WRITE_4: begin
           we <= 0;
           `DELAY_THEN(WRITE_5)
        end
        WRITE_5: begin
           i2c.data <= (vchr << 4) | 4'b1101;
           we <= 1;
           delay <= SIM ? 0 : 100 * us;
           if (i2c_busy) state <= WRITE_6;
        end
        WRITE_6: begin
           we <= 0;
           `DELAY_THEN(WRITE_7)
        end
        WRITE_7: begin
           i2c.data <= (vchr << 4) | 4'b1001;
           we <= 1;
           delay <= SIM ? 0 : 10000 * us;
           if (i2c_busy) state <= WRITE_8;
        end
        WRITE_8: begin
           we <= 0;
           `DELAY_THEN(IDLE)
        end
      endcase // case (state)
   end
   
   
endmodule
