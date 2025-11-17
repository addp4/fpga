`timescale 1ns / 1ps

`include "/home/nomura/git/fpga/boards/qmtech/xc7a15t/modules/psram_fifo/psram_fifo.sv"
`include "/home/nomura/git/fpga/modules/woof_fifo/woof_fifo.sv"

module tb_psram_fifo() ;

   reg clock = 1;
   reg rst_n = 0;
   wire spi_csn_i;
   wire spi_csn_o;
   wire spi_csn_t;
   wire spi_sck_i;
   wire spi_sck_o;
   wire spi_sck_t;
   wire spi_mosi_i;
   wire spi_mosi_o;
   wire spi_mosi_t;
   wire spi_miso_i;
   wire spi_miso_o;
   wire spi_miso_t;
   reg  rd_en_i;
   reg  wr_en_i;
   reg [7:0] wr_data_i;
   reg [7:0] rd_data_o;
   wire      busy_o;
   reg       spi_csn;
   reg [31:0] psram_data;
   logic      psram_data_valid;
   wire       spi_mosi_io, spi_miso_io, spi_sck_io, spi_csn_io;
   IOBUF spi_mosi_iobuf
     (.I(spi_mosi_o),           // yes, o goes to i
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

   reg        fifo_wr_en;
   transaction_t fifo_wr_data;
   logic      fifo_wr_full;
   reg        fifo_rd_en;
   transaction_t fifo_rd_data;
   logic      fifo_rd_empty;
   logic      psram_clock_gate = 0;

   localparam integer TXN_WIDTH = $bits(transaction_t);

   woof_fifo #( .WIDTH(TXN_WIDTH) ) fif
     (
      .clock(clock),
      .reset_n(rst_n),
      .wr_en(fifo_wr_en),
      .wr_data(fifo_wr_data),
      .wr_full(fifo_wr_full),
      .rd_en(fifo_rd_en),
      .rd_data(fifo_rd_data),
      .rd_empty(fifo_rd_empty)
      );

   psram_fifo DUT
     (
      .clock(clock & psram_clock_gate),
      .reset_n(rst_n),
      .data_o(psram_data),
      .data_valid_o(psram_data_valid),
      .fifo_rd_en_o(fifo_rd_en),
      .fifo_rd_data(fifo_rd_data),
      .fifo_rd_empty(fifo_rd_empty),
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

   always #1 clock <= ~clock;

   reg spi_miso_q = 0;
   reg [31:0] some_indata = 32'hcafef00d;
   reg [1+4+32+24-1:0] fifo_test_data  = {1'b1, 4'b1111, 32'hbadc0ffe, 24'h112233};
   reg [1+4+32+24-1:0] fifo_test_data2 = {1'b0, 4'b1111, 32'h0, 24'h332211};
   assign spi_miso_io = spi_miso_q;
   // keep rotating these bits once per spi clock. assert the value
   // seen in each test according to where in the cycle it should be
   always @(posedge spi_sck_io)
     begin
        spi_miso_q <= some_indata[31];
        some_indata <= { some_indata[30:0], some_indata[31] };
     end

   // Put a read or write txn into FIFO
   // Watch the spi activity that comes out

   initial begin
      #10 rst_n = 1;
      #10;

      /*=========
       FIFO TEST
       ========*/

      // fifo test 1: push one entry into an empty fifo and confirm it's there
      fifo_wr_data = fifo_test_data;
      fifo_wr_en = 1;
      #2;
      fifo_wr_data = 'z;  // blank out the input data to ensure fifo latched it
      fifo_wr_en = 0;
      assert (!fifo_rd_empty);
      assert (fif.depth == 1);
      assert (fifo_rd_data == fifo_test_data); // check data can be seen at head
      $display("fifo basic push test passed");
      #2;

      // fifo test 2: pop entry from a fifo with one entry and confirm it goes empty
      fifo_rd_en = 1;
      #2 fifo_rd_en = 0;
      assert (fifo_rd_empty);
      $display("fifo basic pop test passed");
      #2;

      // fifo test 3: push two entries then pop one
      fifo_wr_data = fifo_test_data2;
      fifo_wr_en = 1;
      #2;
      fifo_wr_data = fifo_test_data;
      #2;
      fifo_wr_en = 0;
      assert (!fifo_rd_empty);
      assert (!fifo_wr_full);
      assert (fif.depth == 2);
      assert (fifo_rd_data == fifo_test_data2); // first data visible
      fifo_rd_en = 1;           // pop
      #2;
      fifo_rd_en = 0;
      assert (fifo_rd_data == fifo_test_data); // second data visible
      $display("fifo push 2 pop 1 test passed");

      // clear fifo for real use
      fifo_rd_en = 1;
      while (!fifo_rd_empty) #1;
      fifo_rd_en = 0;

      // ok fifo is ready for the real world

      psram_clock_gate = 1;     // turn on the psram (didn't want it to see fifo activity above)
      #10;

      /*===========
       PSRAM TEST
       ===========*/

      // test 32-bit write
      fifo_wr_data = {1'b1, 4'b1111, 32'hbadc0ffe, 24'h112233};
      fifo_wr_en = 1;
      #2;
      fifo_wr_data = {1'b0, 4'b1111, 32'hbadc0ffe, 24'h112233};
      #2 fifo_wr_en = 0;
      #2;

      while (!psram_data_valid) #1; // wait for psram to pop the fifo (after it's done)
      assert(psram_data == 32'hcafef00d);
      while (psram_data_valid) #1; // let it clear

      // test 32-bit fastread (the test was queued above)
      some_indata = 32'hcafef00d;
      while (!psram_data_valid) #1; // wait for psram to pop the fifo (after it's done)
      assert(psram_data == 32'hfef00dca); // due to dummy byte
      while (psram_data_valid) #1; // let it clear

      // test unaligned 8-bit write
      some_indata = 32'hcafef00d;
      fifo_wr_data = {1'b1, 4'b0001, 32'hbadc0ffe, 24'h112233};
      fifo_wr_en = 1;
      #2 fifo_wr_en = 0;

      while (fifo_rd_en == 0) #1; // wait for psram to pop the fifo
      assert(psram_data_valid);
      assert(psram_data == 32'hfef00dca);
      #2;

      some_indata = 32'hcafef00d;
      fifo_wr_data = {1'b1, 4'b1010, 32'hbadc0ffe, 24'h112233};
      fifo_wr_en = 1;
      #2 fifo_wr_en = 0;

      while (fifo_rd_en == 0) #1; // wait for psram to pop the fifo
      assert(psram_data_valid);
      assert(psram_data == 32'hf00dcafe);
      fifo_wr_en = 1;
      #2 fifo_wr_en = 0;

   end // initial begin


endmodule // tb_woof_simple_spi
