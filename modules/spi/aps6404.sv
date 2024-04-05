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

module aps6406a(input sysclk, input rst_n, output spiclk, output mosi, input miso, output ce_q_,
               output [7:0]led_q, output[63:0] ramstatus);
//output mosiq[3:0], input misoq[3:0], output we);

   wire [7:0]              recv_byte;
   reg [7:0]               send_byte;
   reg [3:0]               readid_rdcount;
   wire                    busy;
   wire                    new_data;
   reg                     spi_start;
   reg                     ce_;
   wire                    rst;
   enum                    { POR, RESET, RESET_0, RESET_1, RESET_2, RESET_2A, RESET_3,
                             RESETA_BACKPORCH, RESETB_BACKPORCH,
                             READID, READID_0, READID_1, READID_A1, READID_A1BUSY, READID_A2,
                             READID_ID_INTER, READID_A2BUSY,
                             READID_A3, READID_A3BUSY, READID_ID, READID_ID_RD, READID_END,
                             SPI_DELAY, SPI_DELAY2,
                             MEMTEST, MT0, MT1, MTA1, MTA1_W, MTA2, MTA2_W, MTA3, MTA3_W,
                             MTD1, MTD1_W, MTD2,
                             INIT
                             } state_t;
   reg [5:0]               state = POR, post_delay_state;
   reg [23:0]              addr = 0;
   reg [7:0]               led;
   reg [15:0]              delay_cnt; // count to POWERON_CYCLES
   reg [31:0]              ramstatus_d;
   reg [7:0]               eid[8];

   assign led_q = led;
   assign ce_q_ = ce_;
   assign ramstatus = {eid[0], eid[1], eid[2], eid[3], eid[4], eid[5], eid[6], eid[7]};

   localparam POWERON_CYCLES = 50 * 150; // 50MHz clk cycles for 150 microseconds delay
   localparam                        // device commands
     CMD_WRITE = 8'h2,
     CMD_READ = 8'h3,
     CMD_RSTEN = 8'h66,
     CMD_RST = 8'h99,
     CMD_READID = 8'h9f;

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
           if (delay_cnt == POWERON_CYCLES)
             state = RESET;
        end
        RESET: begin
           led <= 8'h00;
           if (!rst) begin
              ce_ <= 0;
              delay_cnt <= 50;
              post_delay_state <= RESET_0;
              state <= SPI_DELAY2;
           end
        end
        RESET_0: begin
           send_byte <= CMD_RSTEN;
           spi_start <= 1;
           state <= RESET_1;
        end
        RESET_1: begin
           spi_start <= 0;
           if (busy == 0) begin
              post_delay_state <= RESETA_BACKPORCH;
              delay_cnt <= 50;
              state <= SPI_DELAY2;
           end
        end
        RESETA_BACKPORCH: begin
           ce_ <= 1;
           post_delay_state <= RESET_2;
           state <= SPI_DELAY;
        end
        RESET_2: begin
           ce_ <= 0;
           delay_cnt <= 50;
           post_delay_state <= RESET_2A;
           state <= SPI_DELAY2;
        end
        RESET_2A: begin
           send_byte <= CMD_RST;
           spi_start <= 1;
           state <= RESET_3;
        end
        RESET_3: begin
           spi_start <= 0;
           if (busy == 0) begin
              post_delay_state <= RESETB_BACKPORCH;
              delay_cnt <= 50;
              state <= SPI_DELAY2;
           end
        end
        RESETB_BACKPORCH: begin
           ce_ <= 1;
           post_delay_state <= READID;
           state <= SPI_DELAY;
        end

        READID: begin
           ce_ <= 0;            // start command
           delay_cnt <= 50;
           post_delay_state <= READID_0;
           state <= SPI_DELAY2;
        end
        READID_0: begin
           send_byte <= CMD_READID;
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
           state <= READID_ID_RD;
        end
        READID_ID_RD: begin
           spi_start <= 0;
           // if (new_data == 1) begin
           if (busy == 0) begin
              eid[readid_rdcount] = recv_byte;
              state <= READID_ID_INTER;
              readid_rdcount <= readid_rdcount + 1;
           end
        end // case: READID_ID_RD
        READID_ID_INTER: begin
           delay_cnt <= 30;
           post_delay_state <= readid_rdcount < 8 ? READID_ID : READID_END;
           state <= SPI_DELAY2;
        end
        READID_END: begin
           ce_ <= 1;
           // post_delay_state = MEMTEST;
           post_delay_state = READID;
           // post_delay_state = RESET;
           state <= SPI_DELAY;
        end
        SPI_DELAY: begin
           delay_cnt <= 100;
           state <= SPI_DELAY2;
        end
        SPI_DELAY2: begin
           delay_cnt <= delay_cnt - 1;
           if (delay_cnt == 0)
             state <= post_delay_state;
        end
        MEMTEST: begin
           state <= MT0;
        end
        MT0: begin
           send_byte <= CMD_WRITE;
           ce_ = 0;             // start command
           spi_start <= 1;
           state <= MT1;
        end
        MT1: begin
           spi_start <= 0;
           if (busy == 0) state <= MTA1;
        end
        MTA1: begin  // send address
           send_byte <= addr[23:16];
           spi_start <= 1;
           state <= MTA1_W;
        end
        MTA1_W: begin
           spi_start <= 0;
           if (busy == 0) state <= MTA2;
        end
        MTA2: begin  // send address
           send_byte <= addr[15:8];
           spi_start <= 1;
           state <= MTA2_W;
        end
        MTA2_W: begin
           spi_start <= 0;
           if (busy == 0) state <= MTA3;
        end
        MTA3: begin  // send address
           send_byte <= addr[7:0];
           spi_start <= 1;
           state <= MTA3_W;
        end
        MTA3_W: begin
           spi_start <= 0;
           if (busy == 0) state <= MTD1;
        end
        MTD1: begin  // send data
           send_byte <= 0;
           spi_start <= 1;
           state <= MTD1_W;
        end
        MTD1_W: begin
           spi_start <= 0;
           if (busy == 0) state <= MTD2;
        end
        MTD2: begin
           ce_ = 1;  // end command
           addr <= addr + 1;
           post_delay_state <= (addr & 16'hffff) == 0 ? READID : MEMTEST;
           // post_delay_state <= MEMTEST;
           state <= SPI_DELAY;
        end

        INIT: begin
           ce_ <= 1;
           if (rst) state <= RESET;
           // state <= rst ? RESET : READID;
        end // case: INIT_DONE

      endcase // case (state)
   end // always @ (posedge clk)

endmodule // aps6406


module aps6406(input sysclk, input rst_n, output spiclk, output mosi, input miso, output ce_q_,
                output [7:0] led_q, output[63:0] ramstatus);
//output mosiq[3:0], input misoq[3:0], output we);

   wire [7:0]              recv_byte;
   reg [7:0]               send_byte;
   wire                    busy;
   wire                    new_data;
   reg                     spi_start;
   reg                     ce_, set_chip_select, clear_chip_select;
   enum                    { INIT,
                             RDID,
                             RDID_FPORCH,
                             RDID_CMD,
                             RDID_CMD_WAIT,
                             RDID_ADDR,
                             RDID_ADDR_WAIT,
                             RDID_ADDR_LOOP,
                             RDID_LOAD,
                             RDID_LOAD_WAIT,
                             RDID_LOAD_LOOP,
                             RDID_DONE,
                             RDID_BPORCH
                             } state_t;
   reg [5:0]               state = INIT, next = INIT;
   reg [7:0]               downcnt, loadcnt;
   reg                     reset_downcnt, reset_loadcnt, decr_downcnt, decr_loadcnt, data_rdy;
   reg [7:0]               delay_cnt, init_delay;
   reg [7:0]               eid[8];

   assign ce_q_ = ce_;
   assign ramstatus = {eid[7], eid[6], eid[5], eid[4], eid[3], eid[2], eid[1], eid[0]};

   localparam                        // device commands
     CMD_WRITE = 8'h2,
     CMD_READ = 8'h3,
     CMD_RSTEN = 8'h66,
     CMD_RST = 8'h99,
     CMD_READID = 8'h9f;

   spi #(4) psram(.clk(sysclk),
                   .rst(~rst_n),
                   .miso(miso),
                   .mosi(mosi),
                   .sck(spiclk),
                   .new_data(new_data),
                   .start(spi_start),
                   .data_in(send_byte),
                   .data_out(recv_byte),
                   .busy(busy)
                   );

   assign led_q = state;

   always @(posedge sysclk or negedge rst_n) begin
      if (!rst_n) state <= INIT;
      else state <= next;
   end

   always @(posedge sysclk) begin
      if (init_delay != 0) delay_cnt <= init_delay; else delay_cnt <= delay_cnt - 1;
      if (reset_downcnt) downcnt <= 2;
      if (decr_downcnt) downcnt <= downcnt - 1;
      if (reset_loadcnt) loadcnt <= 7;
      if (decr_loadcnt) loadcnt <= loadcnt - 1;
      if (set_chip_select) ce_ <= 0;
      if (clear_chip_select) ce_ <= 1;
      if (data_rdy) eid[loadcnt] <= recv_byte;
   end

   always @(*) begin
      set_chip_select <= 0;
      clear_chip_select <= 0;
      send_byte <= 0;
      spi_start <= 0;
      init_delay <= 0;
      reset_downcnt <= 0;
      reset_loadcnt <= 0;
      decr_downcnt <= 0;
      decr_loadcnt <= 0;
      data_rdy <= 0;
      next <= state;

      case (state)
        INIT: begin
           clear_chip_select <= 1;
           spi_start <= 0;
           if (rst_n) next <= RDID;
        end
        RDID: begin
           set_chip_select <= 1;
           init_delay <= 5;
           next <= RDID_FPORCH;
        end
        RDID_FPORCH: begin
           if (delay_cnt == 0) next <= RDID_CMD;
        end
        RDID_CMD: begin
           send_byte <= CMD_READID;
           spi_start <= 1;
           if (busy) next <= RDID_CMD_WAIT;
        end
        RDID_CMD_WAIT: begin
           spi_start <= 0;
           reset_downcnt <= 1;
           if (!busy) next <= RDID_ADDR;
        end
        // Send 3 bytes of don't care address.
        RDID_ADDR: begin
           send_byte <= 8'h35;   // silence the MOSI line
           spi_start <= 1;
           if (busy) next <= RDID_ADDR_WAIT;
        end
        RDID_ADDR_WAIT: begin
           spi_start <= 0;
           init_delay <= 10;
           if (!busy) next <= RDID_ADDR_LOOP;
        end
        RDID_ADDR_LOOP: begin
           reset_loadcnt <= 1;
           decr_downcnt <= 1;

           if (downcnt != 0) next <= RDID_ADDR;
           else next <= RDID_LOAD;
        end
        // Load 8 bytes of EID.
        RDID_LOAD: begin
           send_byte <= 8'h71;   // silence the MOSI line
           spi_start <= 1;
           next <= RDID_LOAD_WAIT;
        end
        RDID_LOAD_WAIT: begin
           spi_start <= 0;
           if (!busy) next <= RDID_LOAD_LOOP;
        end
        RDID_LOAD_LOOP: begin
           data_rdy <= 1;
           decr_loadcnt <= 1;
           if (loadcnt != 0) next <= RDID_LOAD;
           else next <= RDID_DONE;
        end
        RDID_DONE: begin
           clear_chip_select <= 1;
           init_delay <= 10;
           next <= RDID_BPORCH;
        end
        RDID_BPORCH: begin
           if (delay_cnt == 0) next <= INIT; // start over
        end

      endcase // case (state)
   end // always @ (posedge clk)

endmodule // aps6406
