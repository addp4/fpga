/*
 This module owns psram memory and the dequeue end of the fifo.
 This is a proof of concept that is totally bare bones.

 Writes with BSTRB != 4'b1111, i.e. unaligned transfers, are done
 1 byte at a time.
 */

`timescale 1 ns / 1 ps

`include "/home/nomura/git/fpga/modules/woof_simple_spi/simple_spi.sv"

typedef struct packed {
   logic       write_enable;
   logic [3:0] wstrb;
   logic [31:0] data;
   logic [23:0] address;
} transaction_t;
localparam integer TXN_WIDTH = $bits(transaction_t);

typedef struct packed {
   logic [7:0] cmd;
   logic [23:0] address;
   logic [31:0] data;
} spi64_t;

localparam integer CMD_WRITE = 'h2;
localparam integer CMD_READ = 'h3;
localparam integer CMD_FASTREAD = 'hb;
localparam integer CMD_WRSR = 'h1;


module psram_fifo
  (
   input wire         clock,
   input wire         reset_n,
   output wire [31:0] data_o,
   output wire        data_valid_o,
   output wire        fifo_rd_en_o,
   input              transaction_t fifo_rd_data,
   input wire         fifo_rd_empty,
   input wire         spi_csn_i,
   output wire        spi_csn_o,
   output wire        spi_csn_t,
   input wire         spi_sck_i,
   output wire        spi_sck_o,
   output wire        spi_sck_t,
   input wire         spi_mosi_i,
   output wire        spi_mosi_o,
   output wire        spi_mosi_t,
   input wire         spi_miso_i,
   output wire        spi_miso_o,
   output wire        spi_miso_t
   );

   reg                data_valid = 0;
   reg [7:0]          fifo_delay;
   reg                rd_en;
   assign fifo_rd_en_o = rd_en;
   assign data_valid_o = data_valid;

   //
   // ============ SPI ===============
   //
   reg             spi_csn = 1;
   wire            rd_en_i;
   reg             wr_en_i;
   reg [7:0]       wr_data_i;
   wire [7:0]      rd_data_o;
   wire            busy_o;

   simple_spi spi
     (
      .clock(clock),
      .rst_n(reset_n),
      .spi_csn(spi_csn),
      .rd_en_i(rd_en_i),
      .wr_en_i(wr_en_i),
      .wr_data_i(wr_data_i),
      .rd_data_o(rd_data_o),
      .busy_o(busy_o),
      .spi_csn_i(spi_csn_i),
      .spi_csn_o(spi_csn_o),
      .spi_csn_t(spi_csn_t),
      .spi_sck_i(spi_sck_i),
      .spi_sck_o(spi_sck_o),
      .spi_sck_t(spi_sck_t),
      .spi_mosi_i(spi_mosi_i),
      .spi_mosi_o(spi_mosi_o),
      .spi_mosi_t(spi_mosi_t),
      .spi_miso_i(spi_miso_i),
      .spi_miso_o(spi_miso_o),
      .spi_miso_t(spi_miso_t)
      );

   reg [3:0]       bytes_sent;
   reg [4:0]       state = 10;

   wire mem_wren; assign mem_wren = !fifo_rd_empty && fifo_rd_data.write_enable;
   wire mem_rden; assign mem_rden = !fifo_rd_empty && !fifo_rd_data.write_enable;
   spi64_t spi_out;
   reg [31:0] spi_in;
   assign data_o = spi_in;

   reg        add_dummy_byte_after_addr;
   reg [1:0]  n;
   reg [31:0] lane_data;
   reg [19:0] cntr = 0;

   always @(posedge clock)
     begin
        case (state)
          0:                    // accept new requests
            begin
               data_valid <= 0;
               add_dummy_byte_after_addr = 0;
               rd_en <= 0;      // end pop fifo (if set)
               spi_out.data <= fifo_rd_data.data;
               spi_out.address <= {fifo_rd_data.address[23:2], 2'b0};

               if (mem_rden && !busy_o)
                 begin
                    spi_out.cmd <= CMD_FASTREAD;
                    add_dummy_byte_after_addr = 1;
                    bytes_sent <= 0;
                    spi_csn <= 0; // CSn low
                    state <= 1;
                 end
               if (mem_wren && !busy_o)
                 begin
                    spi_out.cmd <= CMD_WRITE;
                    bytes_sent <= 0;
                    spi_csn <= 0; // CSn low
                    state <= fifo_rd_data.wstrb == 4'b1111 ? 1 : 5;
                    // state <= 5; // FIXME for testing we use the slow path
                 end
            end

          1:                   // read, always 4 bytes
            begin
               wr_data_i <= spi_out[63:56] ;
               wr_en_i <= 1;  // start spi
               if (busy_o) state <= 2;
            end
          2:
            begin
               wr_en_i <= 0;  // end start spi
               if (!busy_o)
                 begin
                    spi_out <= {spi_out[55:0], spi_out[63:56]};
                    spi_in <= {spi_in[23:0], rd_data_o};
                    bytes_sent <= bytes_sent + 1;
                    if (bytes_sent == 3 && add_dummy_byte_after_addr)
                      begin
                         spi_out <= spi_out; // dummy byte: avoid shift
                         state <= 1;
                      end
                    else if (bytes_sent < 7 && !add_dummy_byte_after_addr)
                      begin
                         state <= 1;
                      end
                    else if (bytes_sent < 8 && add_dummy_byte_after_addr)
                      begin
                         state <= 1;
                      end
                    else
                      begin
                         state <= 3;
                      end
                 end
            end
          3:
            begin
               data_valid <= 1; // ok to read 32-bit data output
               spi_csn <= 1; // CSn high
               rd_en <= 1;   // pop fifo. add a cycle delay for fifo to respond.
               state <= 4; // idle state
            end
          4:
            begin
               rd_en <= 0;
               state <= 0;
            end

          /* The excruciating unaligned case. Write bytes one at a
           time for each bit set in WSTRB. From 1 to 3 bytes are
           possible.  The data has gaps where wstrb has gaps, e.g. if
           wstrb = 4'b1010 and the data is 32'h11xx22xx then the data
           written is 16'h1122.

           Each byte is a 40 bit transaction: 8/command, 24/address,
           8/data, instead of 64 bits. We prepare the 40 bits in the
           initial state and then send and rotate 5 times. spi_out is
           rebuilt each time since addr and data need customization.

           */

          5:                    // loop header, for n=0..3
            begin
               n <= 0;
               lane_data <= fifo_rd_data.data;
               state <= 6;
            end
          6:                   // write byte lane i
            begin
               bytes_sent <= 0;
               if (!fifo_rd_data.wstrb[n])
                 state <= 9;
               else
                 begin
                    spi_csn <= 0; // CSn low
                    spi_out.cmd <= CMD_WRITE;
                    spi_out.address <= {fifo_rd_data.address[23:2], n};
                    spi_out.data[31:24] <= lane_data[7:0];
                    state <= 7;
                 end
            end // case: 5
          7:
            begin
               wr_data_i <= spi_out[63:56] ;
               wr_en_i <= 1;  // start spi
               if (busy_o) state <= 8;
            end
          8:
            begin
               wr_en_i <= 0;  // end start spi
               if (!busy_o)
                 begin
                    spi_out <= {spi_out[55:0], spi_out[63:56]};
                    spi_in <= {spi_in[23:0], rd_data_o};
                    bytes_sent <= bytes_sent + 1;
                    if (bytes_sent < 4)
                      begin
                         state <= 7;
                      end
                    else
                      begin
                         spi_csn <= 1; // CSn high
                         state <= 9;
                      end
                 end
            end // case: 8
          9:    // loop latch
            begin
               lane_data <= {8'b0, lane_data[31:8]}; // right shift out data
               n <= n + 1;
               state <= (n == 3) ? 3 : 6;
            end

          // power on initialization for microchip 23aa04m

          10:
            begin
               spi_csn <= 1;
               cntr <= cntr + 1;
               // if (cntr > 10) // for simulation
               if (cntr > 100 * 144) // 100us = 144MHz * 100
                 state <= 11;
            end
          11:
            begin
               spi_csn <= 0;    // start command
               wr_data_i <= CMD_WRSR; // first byte
               wr_en_i <= 1;  // start spi
               if (busy_o) state <= 12;
            end
          12:
            begin
               wr_en_i <= 0;  // end start spi
               if (!busy_o)   // first byte finish
                 state <= 13;
            end
          13:
            begin
               wr_data_i <= 8'h40; // second byte
               wr_en_i <= 1;  // start spi
               if (busy_o) state <= 14;
            end
          14:
            begin
               wr_en_i <= 0;  // end start spi
               if (!busy_o)   // second byte finish
                 begin
                    spi_csn <= 1;
                    state <= 0;
                 end
            end

        endcase // case (state)
     end // always @ (posedge clock)

endmodule // fifo_ram
