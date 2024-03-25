/* APS6404 psram memory

 In QPI mode all 4 mosi/miso pins are a bidirectional bus while in SPI mode the
 si and so pins are dedicated in and out. This is annoying given we might
 switch from SPI to QPI dynamically. For QPI it makes sense to have two
 parameters connected to the same pins along with a write-enable to switch
 between tristate and output, but for SPI the mosi pin is always output and the
 miso pin is always input.
 
 Of course we have to start with the SPI case since that's how the device comes up
 and is the simplest to debug.
 
*/

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
           if (delay_cnt == POR_CYCLES)
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
           send_byte <= 0;      // avoid twiddling the MOSI line during this long operation. should we tristate it?
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
           led <= eid;
           ce_ <= 1;
           if (rst) state <= RESET;
           // state <= rst ? RESET : READID;
        end // case: INIT_DONE
        
      endcase // case (state)
   end // always @ (posedge clk)

endmodule // aps6406


