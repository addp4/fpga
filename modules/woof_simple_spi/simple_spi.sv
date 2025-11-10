`timescale 1ns / 1ps
`default_nettype none

/* 
 One of these deals with a gazillion signals...
 
 Only top-level can have tristate signals. We can't predict what the
 top level of the client application looks like, but we can provide a
 thin wrapper of simple_spi_wrapper's core.
 */

module simple_spi_wrapper
(
 // The outside world needs multiplexed inout pins, not separate
 // in/out and certainly not a tristate enable.
 input wire        clock,
 input wire        rst_n,
 inout wire        spi_mosi_io,
 inout wire        spi_miso_io,
 inout wire        spi_sck_io,
 inout wire        spi_csn_io
 );

   // Internal modules use these individual signals instead of "inout"
   wire            spi_csn_i;
   wire            spi_csn_o;
   wire            spi_csn_t;
   wire            spi_sck_i;
   wire            spi_sck_o;
   wire            spi_sck_t;
   wire            spi_mosi_i;
   wire            spi_mosi_o;
   wire            spi_mosi_t;
   wire            spi_miso_i;
   wire            spi_miso_o;
   wire            spi_miso_t;
   wire            spi_csn;
   wire            rd_en_i;
   wire            wr_en_i;
   wire [7:0]      wr_data_i;
   wire [7:0]      rd_data_o;
   wire            busy_o;
                   
   IOBUF spi_mosi_iobuf
     (.I(spi_mosi_o),
      .IO(spi_mosi_io),
      .O(spi_mosi_i),
      .T(spi_mosi_t));
   IOBUF spi_miso_iobuf
     (.I(spi_miso_o),
      .IO(spi_miso_io),
      .O(spi_miso_i),
      .T(spi_miso_t));
   IOBUF spi_sck_iobuf
     (.I(spi_sck_o),
      .IO(spi_sck_io),
      .O(spi_sck_i),
      .T(spi_sck_t));
   IOBUF spi_csn_iobuf
     (.I(spi_csn_o),
      .IO(spi_csn_io),
      .O(spi_csn_i),
      .T(spi_csn_t));

   simple_spi spi
     (
      .clock(clock),
      .rst_n(rst_n),            
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
   
endmodule // simple_spi_wrapper

module simple_spi
  (
   input wire        clock,
   input wire        rst_n,
   input wire        spi_csn,
   input wire        rd_en_i,
   input wire        wr_en_i,
   input wire [7:0]  wr_data_i,
   output wire [7:0] rd_data_o,
   output wire       busy_o,
   input wire        spi_csn_i,
   output wire       spi_csn_o,
   output wire       spi_csn_t,
   input wire        spi_sck_i,
   output wire       spi_sck_o,
   output wire       spi_sck_t,
   input wire        spi_mosi_i,
   output wire       spi_mosi_o,
   output wire       spi_mosi_t,
   input wire        spi_miso_i,
   output wire       spi_miso_o,
   output wire       spi_miso_t
   );
   
   wire              busy;
   reg [7:0]         rd_data;
   reg [7:0]         wr_data;
   reg               spi_sck;
   reg [5:0]         shift_count;
   reg               start;

   assign spi_miso_t = 1;  // miso in input mode

   // csn is the caller's responsibility. we enable output mode here.
   assign spi_csn_t = 0;    // ss in output mode
   assign spi_csn_o = spi_csn;

   assign spi_mosi_t = 0;  // mosi in output mode
   assign spi_mosi_o = wr_data[7]; // write msb to mosi

   assign spi_sck_t = 0;  // sck in output mode
   assign spi_sck_o = spi_sck;

   assign busy = start | (shift_count > 0);
   assign busy_o = busy;

   assign rd_data_o = rd_data;
   
   always @(posedge clock)
     begin
        start <= 0;
        if (wr_en_i && !busy)
          begin
             wr_data <= wr_data_i; // latch data to be sent
             start <= 1;
          end
        else if (rd_en_i && !busy)
          begin
             wr_data <= 0;
             start <= 1;
          end
     end // always @ (posedge clock)

   always @(posedge clock)
     begin
        if (!rst_n)
          begin
             spi_sck <= 0;
             shift_count <= 0;
          end
        if (start)
          shift_count <= 16;
        if (shift_count != 0)
          begin
             if ((shift_count & 1) == 0)
               begin            // even beat - setup data, spi clock low
                  spi_sck <= 1;
                  shift_count <= shift_count - 1;
               end
             else
               begin   // odd beat - spi clock high
                  spi_sck <= 0;
                  rd_data <= {rd_data[6:0], spi_miso_i};
                  wr_data <= {wr_data[6:0], 1'b0};
                  shift_count <= shift_count - 1;
               end // else: !if((shift_count & 1) == 0)
          end
     end // always @ (posedge clock)
   
endmodule
