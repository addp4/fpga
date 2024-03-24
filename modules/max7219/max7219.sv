module spi #(parameter CLK_DIV = 1000000)(
                                    input        clk,
                                    input        rst,
                                    input        miso,
                                    output       mosi,
                                    output       sck,
                                    input        start,
                                    input [7:0]  data_in,
                                    output [7:0] data_out,
                                    output       busy,
                                    output       new_data
  );
   
   localparam STATE_SIZE = 2;
   localparam IDLE = 2'd0,
     SCK_LO = 2'd1,
     SCK_HI = 2'd2;
   
   reg [STATE_SIZE-1:0]                          state_d, state_q;
   
   reg [7:0]                                     data_d, data_q;
   reg [31:0]                                    sck_d, sck_q;
   reg                                           spiclk;
   reg                                           mosi_d, mosi_q;
   reg [2:0]                                     ctr_d, ctr_q;  // bit counter, 0-7
   reg                                           new_data_d, new_data_q;
   reg [7:0]                                     data_out_d, data_out_q;
   
   assign mosi = mosi_q;
   // sck is set for "sample rising edge"
   assign sck = spiclk;
   assign busy = state_d != IDLE;
   assign data_out = data_out_q;
   assign new_data = new_data_q;
   
   always @(*) begin
      sck_d = sck_q;
      data_d = data_q;
      mosi_d = mosi_q;
      ctr_d = ctr_q;
      new_data_d = 1'b0;
      data_out_d = data_out_q;
      state_d = state_q;
      spiclk = 0;
      
      case (state_q)
        IDLE: begin
           sck_d = 0;                 // reset clock counter
           ctr_d = 3'b0;              // reset bit counter
           if (start == 1'b1) begin   // if start command
              data_d = data_in;       // latch data to send
              state_d = SCK_LO;       // change state
           end
           spiclk = 0;
        end
        SCK_LO: begin
           sck_d = sck_q + 1'b1;         // increment clock counter
           mosi_d = data_q[7];           // output the MSB of data
           spiclk = 0;
           if (sck_q >= (CLK_DIV/2)) begin // if clock is half full (about to rise)
              state_d = SCK_HI;          // change state
           end
        end
        SCK_HI: begin
           sck_d = sck_q + 1'b1;                           // increment clock counter
           spiclk = 1;
           if (sck_q >= CLK_DIV) begin                   
              data_d = {data_q[6:0], miso};                 // read in data (shift in)
              ctr_d = ctr_q + 1'b1;                         // increment bit counter
              if (ctr_q == 3'b111) begin                    // if we are on the last bit
                 state_d = IDLE;                             // change state
                 data_out_d = data_q;                        // output data
                 new_data_d = 1'b1;                          // signal data is valid
              end
              else begin
                 sck_d = 0;
                 state_d = SCK_LO;
              end
           end
        end
      endcase
   end
   
   always @(posedge clk) begin
      if (rst) begin
         ctr_q <= 3'b0;
         data_q <= 8'b0;
         sck_q <= 0;
         mosi_q <= 1'b0;
         state_q <= IDLE;
         data_out_q <= 8'b0;
         new_data_q <= 1'b0;
      end else begin
         ctr_q <= ctr_d;
         data_q <= data_d;
         sck_q <= sck_d;
         mosi_q <= mosi_d;
         state_q <= state_d;
         data_out_q <= data_out_d;
         new_data_q <= new_data_d;
      end
   end
   
endmodule


/*
 module max7219(input clk, input rst, input miso, output mosi, output sck, output load, input [7:0]addr, input [7:0]data, input start, output busy);
 
 wire new_data;
 reg [7:0] data_in;
 wire [7:0] data_out;
 
 endmodule // max7219
 */


module max7219(input CLOCK_50, input rst_n, output max_din, output max_load, output max_clk);

   wire [7:0] data_out;
   reg [7:0]  data;
   wire       busy;
   wire       miso_ignored, new_data_ignored;
   reg        spi_start;
   wire       rst;
   enum { INIT, INIT1, INIT1_WAIT, INIT2, INIT2_WAIT, INIT_HOLD, INIT_DONE, DISP1, DISP2 } state_t;
   reg [3:0]    state;
   reg [4:0]    addr;
   reg [31:0]   disp_dig;
   reg [7:0]    LED_out;
   
   localparam DECODEMODE_ADDR = 9;
   localparam BRIGHTNESS_ADDR = 10;
   localparam SCANLIMIT_ADDR = 11;
   localparam SHUTDOWN_ADDR = 12;
   localparam DISPLAYTEST_ADDR = 13;
   
   localparam INITBYTES = 14;
   reg [7:0]  maxinit[0:INITBYTES-1] = 
                '{0, 0,         // nop; this may help recover a random state
                  DISPLAYTEST_ADDR, 0,
                  SCANLIMIT_ADDR, 7,
                  DECODEMODE_ADDR, 0,
                  SHUTDOWN_ADDR, 1,
                  BRIGHTNESS_ADDR, 12,
                  1, 8'h0      // byte 12-13
                  };
   reg [4:0]    pinit;

   spi #(10) max7219(.clk(CLOCK_50),
                    .rst(rst),
                    .miso(miso_ignored),
                    .mosi(max_din),
                    .sck(max_clk),
                    .new_data(new_data_ignored),
                    .start(spi_start),
                    .data_in(data),
                    .data_out(data_out),
                    .busy(busy)
                    );
   reg [31:0]   cycles;
   
   assign rst = ~rst_n;

   always @(posedge CLOCK_50) begin
      cycles <= cycles + 1;
      
      case (state)
        INIT: begin
           pinit <= 0;
           state <= INIT1;
           max_load <= 0;
           addr <= 1;           // for displaying digits (optional)
           disp_dig <= 0;
        end
        INIT1: begin
           max_load <= 0;
           data <= maxinit[pinit];
           pinit <= pinit + 4'b1;
           spi_start <= 1;
           state <= INIT1_WAIT;
        end
        INIT1_WAIT: begin     // 1
          spi_start <= 0;
          if (busy == 0) state <= INIT2;
        end
        INIT2: begin
           data <= maxinit[pinit];
           pinit <= pinit + 4'b1;
           spi_start <= 1;
           state <= INIT2_WAIT;
        end
        INIT2_WAIT: begin     // 1
           spi_start <= 0;
           if (busy == 0) state <= INIT_HOLD;
        end
        INIT_HOLD: begin
           max_load <= 1;
           state <= (pinit < 12) ? INIT1 : INIT_DONE;
        end
        // Formally, we're done with init here. But use the loop to
        // iterate through numbers as well. We'll update only one
        // digit per cycle. The digit is selected by addr, where 1 is
        // the rightmost digit on the display, hence the low 4 bits of
        // disp_num. After doing all the digits, we increment
        // disp_num.
        INIT_DONE: begin
           pinit <= 12;
           maxinit[12] <= addr;
           maxinit[13] <= LED_out;

           if (addr < 8) begin
              addr <= addr + 4'b1;
              disp_dig <= disp_dig >> 4;
           end else begin
              addr <= 1;
              disp_dig <= cycles;
           end
           state <= rst ? INIT : INIT1;
        end // case: INIT_DONE
        
      endcase // case (state)
   end // always @ (posedge CLOCK_50)

   always @(*) begin
           case(disp_dig & 4'hf)
             4'b0000: LED_out = 7'b1111110; // "0"     
             4'b0001: LED_out = 7'b0110000; // "1" 
             4'b0010: LED_out = 7'b1101101; // "2" 
             4'b0011: LED_out = 7'b1111001; // "3" 
             4'b0100: LED_out = 7'b0110011; // "4" 
             4'b0101: LED_out = 7'b1011011; // "5" 
             4'b0110: LED_out = 7'b1011111; // "6" 
             4'b0111: LED_out = 7'b1110000; // "7" 
             4'b1000: LED_out = 7'b1111111; // "8"     
             4'b1001: LED_out = 7'b1111011; // "9" 
             4'b1010: LED_out = 7'b1110111; // "A" 
             4'b1011: LED_out = 7'b0011111; // "b" 
             4'b1100: LED_out = 7'b1001110; // "C" 
             4'b1101: LED_out = 7'b0111101; // "d" 
             4'b1110: LED_out = 7'b1001111; // "E" 
             4'b1111: LED_out = 7'b1000111; // "F"
             default: LED_out = 7'b0000000; // can't happen
           endcase // case (disp_dig & 8'hf)
   end
endmodule // max7219



module main(input CLOCK_50, input [1:0]KEY, output [33:0]GPIO_1);

   max7219 disp(CLOCK_50, KEY[0], GPIO_1[0], GPIO_1[1], GPIO_1[3]);
   
endmodule // main

