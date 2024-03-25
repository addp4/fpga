`timescale 1ns / 100ps

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
     SCK_HI = 2'd2,
     DATA_INTR = 2'd3;
   
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
           sck_d = 1;                 // reset clock counter
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
                 state_d = DATA_INTR;                       // change state
                 data_out_d = data_q;                        // output data
              end
              else begin
                 sck_d = 1;
                 state_d = SCK_LO;
              end
           end
        end // case: SCK_HI
        DATA_INTR: begin
           new_data_d = 1'b1;                          // signal data is valid
           state_d = IDLE;
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


module spi_tb() ;

   reg sysclk=0;
   reg rst=0, spiclk, mosi, miso, new_data, spi_start, busy;
   reg [7:0] send_byte, recv_byte, x;
   
   spi #(4) psram(.clk(sysclk),
                  .rst(rst),
                  .miso(miso),
                  .mosi(mosi),
                  .sck(spiclk),
                  .new_data(new_data),
                  .start(spi_start),
                  .data_in(send_byte),
                  .data_out(recv_byte),
                  .busy(busy)
                  );
   
   // Run the clock
   always #1 sysclk++;

   initial begin
      $display("test someoutoput");

      #1 rst = 1;
      #1 rst = 0;
      
      #2 send_byte = 8'h55;
      #1 spi_start = 1;

      x = ~8'h55;
      @(posedge spiclk) begin
         miso = x & 1;
         x = x >> 1;
      end
      @(posedge spiclk) begin
         miso = x & 1;
         x = x >> 1;
      end
      @(posedge spiclk) begin
         miso = x & 1;
         x = x >> 1;
      end
      @(posedge spiclk) begin
         miso = x & 1;
         x = x >> 1;
      end
      @(posedge spiclk) begin
         miso = x & 1;
         x = x >> 1;
      end
      @(posedge spiclk) begin
         miso = x & 1;
         x = x >> 1;
      end
      @(posedge spiclk) begin
         miso = x & 1;
         x = x >> 1;
      end
      @(posedge spiclk) begin
         miso = x & 1;
         x = x >> 1;
      end
      
   end
   
endmodule // spi_tb

