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
                 // data_out_d = data_q;                    // output data
                 data_out_d = {data_q[6:0], miso};          // output data
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


module aps6406(input sysclk, input rst_n, output spiclk, output mosi, input miso, output ce_q_,
               output [7:0]led_q);
//output mosiq[3:0], input misoq[3:0], output we);
   
   wire [7:0]              recv_byte;
   reg [7:0]               send_byte;
   reg [7:0]               eid, kgd, mfid;
   reg [3:0]               readid_rdcount;
   wire                    busy;
   wire                    new_data;
   reg                     spi_start;
   reg                     ce_;
   wire                    rst;
   enum                    { POR, RESET, RESET_0, RESET_1, RESET_2, RESET_3, RESET_4,
                             READID, READID_1, READID_A1, READID_A1BUSY, READID_A2, READID_A2BUSY,
                             READID_A3, READID_A3BUSY, READID_ID, READID_ID_RD, READID_END,
                             INIT
                             } state_t;
   reg [5:0]               state = POR;
   reg [4:0]               addr;
   reg [7:0]               led;
   reg [15:0]              delay_cnt; // count to POR_CYCLES
 
   assign led_q = led;
   assign ce_q_ = ce_;
   
   localparam POR_CYCLES = 50 * 150; // 50MHz clk cycles for 150 microseconds delay
   localparam                        // device commands
     CMD_RSTEN = 8'h66,
     CMD_RST = 8'h99,
     CMD_READID = 8'h9f
                      ;
 
   spi #(10) psram(.clk(sysclk),
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
   
   assign rst = ~rst_n;

   always @(posedge sysclk) begin
      case (state)
        // "From the beginning of power ramp to the end of the 150us period, CLK
        // should remain low, CE# should remain high, and SI/SO/SIO[3:0] should
        // remain low." POR state will show device busy (which is good)
        POR: begin
           led <= 8'hff;
           ce_ <= 1;
           delay_cnt <= delay_cnt + 1'b1;
           // if (delay_cnt == POR_CYCLES)
             state = RESET;
        end
        RESET: begin
           led <= 8'h00;
           if (!rst) state <= RESET_0;
        end
        RESET_0: begin
           send_byte <= CMD_RSTEN;
           ce_ <= 0;
           spi_start <= 1;
           state <= RESET_1;
        end
        RESET_1: begin
           spi_start <= 0;
           if (busy == 0) begin
              ce_ <= 1;
              state <= RESET_2;
           end
        end
        RESET_2: begin
           send_byte <= CMD_RST;
           ce_ <= 0;
           spi_start <= 1;
           state <= RESET_3;
        end
        RESET_3: begin
           spi_start <= 0;
           if (busy == 0) begin
              ce_ <= 1;
              delay_cnt <= 5;
              state <= RESET_4;
           end
        end
        RESET_4: begin
           delay_cnt <= delay_cnt - 1;
           if (delay_cnt == 0) state <= READID;
        end
        
        READID: begin
           send_byte <= CMD_READID;
           ce_ <= 0;
           spi_start <= 1;
           state <= READID_1;
        end
        READID_1: begin
           send_byte <= 0;
           spi_start <= 0;
           if (busy == 0)
             state <= READID_A1;
        end
        // Send 24 bits (3 bytes) of don't care address.
        READID_A1: begin
           spi_start <= 1;
           state <= READID_A1BUSY;
        end
        READID_A1BUSY: begin
           spi_start <= 0;
           if (busy == 0) state <= READID_A2;
        end
        READID_A2: begin
           spi_start <= 1;
           state <= READID_A2BUSY;
        end
        READID_A2BUSY: begin
           spi_start <= 0;
           if (busy == 0) state <= READID_A3;
        end
        READID_A3: begin
           spi_start <= 1;
           state <= READID_A3BUSY;
        end
        READID_A3BUSY: begin
           spi_start <= 0;
           readid_rdcount <= 0;
           if (busy == 0) state <= READID_ID;
        end
        READID_ID: begin
           spi_start <= 1;
           readid_rdcount <= readid_rdcount + 1;
           state <= READID_ID_RD;
        end
        READID_ID_RD: begin
           spi_start <= 0;
           if (new_data == 1) begin
              case (readid_rdcount)
                1: mfid <= recv_byte;
                2: kgd <= recv_byte;
                3: eid <= recv_byte;
              endcase
              state <= readid_rdcount < 8 ? READID_ID : READID_END;
           end
        end
        READID_END: begin
           ce_ <= 1;
           state <= INIT;
        end
          
        INIT: begin
           led <= kgd;
           ce_ <= 1;
           if (rst) state <= RESET;
           // state <= rst ? RESET : READID;
        end // case: INIT_DONE
        
      endcase // case (state)
   end // always @ (posedge clk)

endmodule // aps6406



module aps_tb() ;

   reg sysclk=0;
   reg rst_n=0, spiclk, mosi, miso, busy, ce_;
   reg [7:0] send_byte, recv_byte, x, led;

   aps6406 psram(.sysclk(sysclk), .rst_n(rst_n), .spiclk(spiclk),
                 .mosi(mosi), .miso(miso), .ce_q_(ce_), .led_q(led));
   
   // Run the clock
   always #1 sysclk++;

   initial begin

      #1 rst_n = 0;
      #1 rst_n = 1;

      $display("send reset command");
      for (int i=0; i<16; i=i+1) begin
         @(posedge spiclk) ;
      end

      $display("send read id command and 3 bytes of address");
      for (int i=0; i<24; i=i+1) begin
         @(posedge spiclk) ;
      end
      
      @(negedge spiclk) ;
      $display("inject byte 1");
      x = 8'h0d;
      for (int i=0; i<8; i=i+1) begin
         miso = x[7];
         @(negedge spiclk) ;
         x = x << 1;
      end
      
      $display("inject byte 2");
      x = 8'h5d;
      for (int i=0; i<8; i=i+1) begin
         miso = x[7];
         @(negedge spiclk) ;
         x = x << 1;
      end
      
      $display("inject byte 3");
      x = 8'h60;
      for (int i=0; i<8; i=i+1) begin
         miso = x[7];
         @(negedge spiclk) ;
         x = x << 1;
      end
      
   end
   
endmodule // aps_tb


