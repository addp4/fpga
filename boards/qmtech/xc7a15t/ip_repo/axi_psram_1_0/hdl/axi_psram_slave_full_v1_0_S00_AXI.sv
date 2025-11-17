`timescale 1 ns / 1 ps

`include "/home/nomura/git/fpga/modules/woof_fifo/woof_fifo.sv"
`include "/home/nomura/git/fpga/boards/qmtech/xc7a15t/modules/psram_fifo/psram_fifo.sv"

module axi_psram_slave_full_v1_0_S00_AXI #
  (
   // Users to add parameters here

   // User parameters ends
   // Do not modify the parameters beyond this line

   // Width of ID for for write address, write data, read address and read data
   parameter integer C_S_AXI_ID_WIDTH = 1,
   // Width of S_AXI data bus
   parameter integer C_S_AXI_DATA_WIDTH = 32,
   // Width of S_AXI address bus
   parameter integer C_S_AXI_ADDR_WIDTH = 10,
   // Width of optional user defined signal in write address channel
   parameter integer C_S_AXI_AWUSER_WIDTH = 0,
   // Width of optional user defined signal in read address channel
   parameter integer C_S_AXI_ARUSER_WIDTH = 0,
   // Width of optional user defined signal in write data channel
   parameter integer C_S_AXI_WUSER_WIDTH = 0,
   // Width of optional user defined signal in read data channel
   parameter integer C_S_AXI_RUSER_WIDTH = 0,
   // Width of optional user defined signal in write response channel
   parameter integer C_S_AXI_BUSER_WIDTH = 0
   )
   (
    // Users to add ports here
    input wire                                spi_csn_i,
    output wire                               spi_csn_o,
    output wire                               spi_csn_t,
    input wire                                spi_sck_i,
    output wire                               spi_sck_o,
    output wire                               spi_sck_t,
    input wire                                spi_mosi_i,
    output wire                               spi_mosi_o,
    output wire                               spi_mosi_t,
    input wire                                spi_miso_i,
    output wire                               spi_miso_o,
    output wire                               spi_miso_t,

    // User ports ends
    // Do not modify the ports beyond this line

    // Global Clock Signal
    input wire                                S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input wire                                S_AXI_ARESETN,
    // Write Address ID
    input wire [C_S_AXI_ID_WIDTH-1 : 0]       S_AXI_AWID,
    // Write address
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_AWADDR,
    // Burst length. The burst length gives the exact number of transfers in a burst
    input wire [7 : 0]                        S_AXI_AWLEN,
    // Burst size. This signal indicates the size of each transfer in the burst
    input wire [2 : 0]                        S_AXI_AWSIZE,
    // Burst type. The burst type and the size information,
    // determine how the address for each transfer within the burst is calculated.
    input wire [1 : 0]                        S_AXI_AWBURST,
    // Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
    input wire                                S_AXI_AWLOCK,
    // Memory type. This signal indicates how transactions
    // are required to progress through a system.
    input wire [3 : 0]                        S_AXI_AWCACHE,
    // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
    input wire [2 : 0]                        S_AXI_AWPROT,
    // Quality of Service, QoS identifier sent for each
    // write transaction.
    input wire [3 : 0]                        S_AXI_AWQOS,
    // Region identifier. Permits a single physical interface
    // on a slave to be used for multiple logical interfaces.
    input wire [3 : 0]                        S_AXI_AWREGION,
    // Optional User-defined signal in the write address channel.
    input wire [C_S_AXI_AWUSER_WIDTH-1 : 0]   S_AXI_AWUSER,
    // Write address valid. This signal indicates that
    // the channel is signaling valid write address and
    // control information.
    input wire                                S_AXI_AWVALID,
    // Write address ready. This signal indicates that
    // the slave is ready to accept an address and associated
    // control signals.
    output wire                               S_AXI_AWREADY,
    // Write Data
    input wire [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_WDATA,
    // Write strobes. This signal indicates which byte
    // lanes hold valid data. There is one write strobe
    // bit for each eight bits of the write data bus.
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    // Write last. This signal indicates the last transfer
    // in a write burst.
    input wire                                S_AXI_WLAST,
    // Optional User-defined signal in the write data channel.
    input wire [C_S_AXI_WUSER_WIDTH-1 : 0]    S_AXI_WUSER,
    // Write valid. This signal indicates that valid write
    // data and strobes are available.
    input wire                                S_AXI_WVALID,
    // Write ready. This signal indicates that the slave
    // can accept the write data.
    output wire                               S_AXI_WREADY,
    // Response ID tag. This signal is the ID tag of the
    // write response.
    output wire [C_S_AXI_ID_WIDTH-1 : 0]      S_AXI_BID,
    // Write response. This signal indicates the status
    // of the write transaction.
    output wire [1 : 0]                       S_AXI_BRESP,
    // Optional User-defined signal in the write response channel.
    output wire [C_S_AXI_BUSER_WIDTH-1 : 0]   S_AXI_BUSER,
    // Write response valid. This signal indicates that the
    // channel is signaling a valid write response.
    output wire                               S_AXI_BVALID,
    // Response ready. This signal indicates that the master
    // can accept a write response.
    input wire                                S_AXI_BREADY,
    // Read address ID. This signal is the identification
    // tag for the read address group of signals.
    input wire [C_S_AXI_ID_WIDTH-1 : 0]       S_AXI_ARID,
    // Read address. This signal indicates the initial
    // address of a read burst transaction.
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_ARADDR,
    // Burst length. The burst length gives the exact number of transfers in a burst
    input wire [7 : 0]                        S_AXI_ARLEN,
    // Burst size. This signal indicates the size of each transfer in the burst
    input wire [2 : 0]                        S_AXI_ARSIZE,
    // Burst type. The burst type and the size information,
    // determine how the address for each transfer within the burst is calculated.
    input wire [1 : 0]                        S_AXI_ARBURST,
    // Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
    input wire                                S_AXI_ARLOCK,
    // Memory type. This signal indicates how transactions
    // are required to progress through a system.
    input wire [3 : 0]                        S_AXI_ARCACHE,
    // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
    input wire [2 : 0]                        S_AXI_ARPROT,
    // Quality of Service, QoS identifier sent for each
    // read transaction.
    input wire [3 : 0]                        S_AXI_ARQOS,
    // Region identifier. Permits a single physical interface
    // on a slave to be used for multiple logical interfaces.
    input wire [3 : 0]                        S_AXI_ARREGION,
    // Optional User-defined signal in the read address channel.
    input wire [C_S_AXI_ARUSER_WIDTH-1 : 0]   S_AXI_ARUSER,
    // Write address valid. This signal indicates that
    // the channel is signaling valid read address and
    // control information.
    input wire                                S_AXI_ARVALID,
    // Read address ready. This signal indicates that
    // the slave is ready to accept an address and associated
    // control signals.
    output wire                               S_AXI_ARREADY,
    // Read ID tag. This signal is the identification tag
    // for the read data group of signals generated by the slave.
    output wire [C_S_AXI_ID_WIDTH-1 : 0]      S_AXI_RID,
    // Read Data
    output wire [C_S_AXI_DATA_WIDTH-1 : 0]    S_AXI_RDATA,
    // Read response. This signal indicates the status of
    // the read transfer.
    output wire [1 : 0]                       S_AXI_RRESP,
    // Read last. This signal indicates the last transfer
    // in a read burst.
    output wire                               S_AXI_RLAST,
    // Optional User-defined signal in the read address channel.
    output wire [C_S_AXI_RUSER_WIDTH-1 : 0]   S_AXI_RUSER,
    // Read valid. This signal indicates that the channel
    // is signaling the required read data.
    output wire                               S_AXI_RVALID,
    // Read ready. This signal indicates that the master can
    // accept the read data and response information.
    input wire                                S_AXI_RREADY
    );

   // AXI4FULL signals
   reg [C_S_AXI_ADDR_WIDTH-1 : 0]             axi_awaddr;
   reg                                        axi_awready;
   reg                                        axi_wready;
   reg [1 : 0]                                axi_bresp;
   reg [C_S_AXI_BUSER_WIDTH-1 : 0]            axi_buser;
   reg                                        axi_bvalid;
   reg [C_S_AXI_ADDR_WIDTH-1 : 0]             axi_araddr;
   reg                                        axi_arready;
   reg [C_S_AXI_DATA_WIDTH-1 : 0]             axi_rdata;
   reg [1 : 0]                                axi_rresp;
   reg                                        axi_rlast;
   reg [C_S_AXI_RUSER_WIDTH-1 : 0]            axi_ruser;
   reg                                        axi_rvalid;
   // aw_wrap_en determines wrap boundary and enables wrapping
   wire                                       aw_wrap_en;
   // ar_wrap_en determines wrap boundary and enables wrapping
   wire                                       ar_wrap_en;
   // aw_wrap_size is the size of the write transfer, the
   // write address wraps to a lower address if upper address
   // limit is reached
   wire [31:0]                                aw_wrap_size ;
   // ar_wrap_size is the size of the read transfer, the
   // read address wraps to a lower address if upper address
   // limit is reached
   wire [31:0]                                ar_wrap_size ;
   // The axi_awv_awr_flag flag marks the presence of write address valid
   reg                                        axi_awv_awr_flag;
   //The axi_arv_arr_flag flag marks the presence of read address valid
   reg                                        axi_arv_arr_flag;
   // The axi_awlen_cntr internal write address counter to keep track of beats in a burst transaction
   reg [7:0]                                  axi_awlen_cntr;
   //The axi_arlen_cntr internal read address counter to keep track of beats in a burst transaction
   reg [7:0]                                  axi_arlen_cntr;
   reg [1:0]                                  axi_arburst;
   reg [1:0]                                  axi_awburst;
   reg [7:0]                                  axi_arlen;
   reg [7:0]                                  axi_awlen;
   //local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
   //ADDR_LSB is used for addressing 32/64 bit registers/memories
   //ADDR_LSB = 2 for 32 bits (n downto 2)
   //ADDR_LSB = 3 for 42 bits (n downto 3)

   localparam integer                         ADDR_LSB = (C_S_AXI_DATA_WIDTH/32)+ 1;
   localparam integer                         OPT_MEM_ADDR_BITS = 13;

   //----------------------------------------------
   //-- Signals for user logic memory space example
   //------------------------------------------------
   // wire [OPT_MEM_ADDR_BITS:0] mem_address;
   // reg [C_S_AXI_DATA_WIDTH-1:0] mem_data_out;
   // localparam integer      SPI_FIFO_DELAY = 64;
   wire                                       spi_fifo_empty;

   reg [31:0]                                 axi_counter = 0;
   reg [31:0]                                 status_word = 0;

   typedef struct                             packed {
      logic                                   write_enable;
      logic [3:0]                             wstrb;
      logic [31:0]                            data;
      logic [23:0]                            address;
   } transaction_t;
   localparam integer                         TXN_WIDTH = $bits(transaction_t);

   transaction_t txn;
   reg [4:0]                                  state_txn = 0;
   reg [4:0]                                  state_txn_next = 0;

   /*
    &&& WOOF FIFO &&&
    */
   transaction_t   fifo_wr_data;
   transaction_t   fifo_rd_data;
   reg                                        wr_txn_busy = 0;
   reg                                        rd_txn_busy = 0;

   reg                                        fifo_rd_en;
   wire                                       fifo_rd_empty;
   reg                                        fifo_wr_en;
   wire                                       fifo_wr_full;

   assign fifo_wr_data = txn;
   woof_fifo #( .WIDTH(TXN_WIDTH) ) fif
     (
      .clock(S_AXI_ACLK),
      .reset_n(S_AXI_ARESETN),
      .wr_en(fifo_wr_en),          // this module uses the write side of the fifo for enqueue
      .wr_data(fifo_wr_data),
      .wr_full(fifo_wr_full),
      .rd_en(fifo_rd_en),
      .rd_data(fifo_rd_data),
      .rd_empty(fifo_rd_empty)
      );

   wire [31:0]                                psram_data_o;
   wire                                       psram_data_valid;
   reg [31:0]                                 psram_data_latch;

   psram_fifo ram_fifo
     (
      .clock(S_AXI_ACLK),
      .reset_n(S_AXI_ARESETN),
      .data_o(psram_data_o),
      .data_valid_o(psram_data_valid),
      .fifo_rd_en_o(fifo_rd_en),   // psram gets the read side of the fifo for dequeue
      .fifo_rd_data(fifo_rd_data),
      .fifo_rd_empty(fifo_rd_empty),
      .spi_csn_i(spi_csn_i),    // 4 pins, each has 3 tristate signals _i, _o, _t
      .spi_csn_o(spi_csn_o),    // top level combines with IOBUF to a true tristate pin
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

   // I/O Connections assignments

   assign S_AXI_AWREADY	= axi_awready;
   assign S_AXI_WREADY	= axi_wready;
   assign S_AXI_BRESP	= axi_bresp;
   assign S_AXI_BUSER	= axi_buser;
   assign S_AXI_BVALID	= axi_bvalid;
   assign S_AXI_ARREADY	= axi_arready;
   assign S_AXI_RDATA	= axi_rdata;
   assign S_AXI_RRESP	= axi_rresp;
   assign S_AXI_RLAST	= axi_rlast;
   assign S_AXI_RUSER	= axi_ruser;
   assign S_AXI_RVALID	= axi_rvalid;
   assign S_AXI_BID = S_AXI_AWID;
   assign S_AXI_RID = S_AXI_ARID;
   assign  aw_wrap_size = (C_S_AXI_DATA_WIDTH/8 * (axi_awlen));
   assign  ar_wrap_size = (C_S_AXI_DATA_WIDTH/8 * (axi_arlen));
   assign  aw_wrap_en = ((axi_awaddr & aw_wrap_size) == aw_wrap_size)? 1'b1: 1'b0;
   assign  ar_wrap_en = ((axi_araddr & ar_wrap_size) == ar_wrap_size)? 1'b1: 1'b0;

   // Implement axi_awready generation

   // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
   // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
   // de-asserted when reset is low.

   always @( posedge S_AXI_ACLK )
     begin
	if ( S_AXI_ARESETN == 1'b0 )
	  begin
	     axi_awready <= 1'b0;
	     axi_awv_awr_flag <= 1'b0;
	  end
	else
	  begin
	     if (~axi_awready && S_AXI_AWVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag && state_txn == 0)
	       begin
	          // slave is ready to accept an address and
	          // associated control signals
	          axi_awready <= 1'b1;
	          axi_awv_awr_flag  <= 1'b1;
	          // used for generation of bresp() and bvalid
	       end
	     else if (S_AXI_WLAST && axi_wready)
	       // preparing to accept next address after current write burst tx completion
	       begin
	          axi_awv_awr_flag  <= 1'b0;
	       end
	     else
	       begin
	          axi_awready <= 1'b0;
	       end
	  end
     end
   // Implement axi_awaddr latching

   // This process is used to latch the address when both
   // S_AXI_AWVALID and S_AXI_WVALID are valid.

   always @( posedge S_AXI_ACLK )
     begin
	if ( S_AXI_ARESETN == 1'b0 )
	  begin
	     axi_awaddr <= 0;
	     axi_awlen_cntr <= 0;
	     axi_awburst <= 0;
	     axi_awlen <= 0;
	  end
	else
	  begin
	     if (~axi_awready && S_AXI_AWVALID && ~axi_awv_awr_flag)
	       begin
	          // address latching
	          axi_awaddr <= S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH - 1:0];
	          axi_awburst <= S_AXI_AWBURST;
	          axi_awlen <= S_AXI_AWLEN;
	          // start address of transfer
	          axi_awlen_cntr <= 0;

                  /*
                   0x04090408
                   read burst len 3       4 transfers
                   read burst size 2      4 bytes per transfer
                   write burst len 3, 0   4 or 1 transfers
                   write burst size 2     4 bytes per transfer

                   AxLEN[7:0] has 8 bits, which specifies a range of 1-256 data transfers in a transaction.
                   AxSize[2:0] describes the maximum number of bytes to transfer in each data transfer. Three bits of encoding indicate 1, 2, 4, 8, 16, 32, 64, or 128 bytes per transfer.
                   */

                  // set Nth bit (at offset 8) for write burst length N in 0..7
                  status_word[16 + S_AXI_ARLEN[2:0]] <= 1;
                  // set Nth bit (at offset 12) for write burst size N in 0..7
                  status_word[24 + S_AXI_ARSIZE[2:0]] <= 1;
	       end
	     else if ((axi_awlen_cntr < axi_awlen) && axi_wready && S_AXI_WVALID)
	       begin
	          axi_awlen_cntr <= axi_awlen_cntr + 1;

	          case (axi_awburst)
	            2'b00: // fixed burst
	              // The write address for all the beats in the transaction are fixed
	              begin
	                 axi_awaddr <= axi_awaddr;
	                 //for awsize = 4 bytes (010)
	              end
	            2'b01: //incremental burst
	              // The write address for all the beats in the transaction are increments by awsize
	              begin
	                 axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
	                 //awaddr aligned to 4 byte boundary
	                 axi_awaddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};
	                 //for awsize = 4 bytes (010)
	              end
	            2'b10: //Wrapping burst
	              // The write address wraps when the address reaches wrap boundary
	              if (aw_wrap_en)
	                begin
	                   axi_awaddr <= (axi_awaddr - aw_wrap_size);
	                end
	              else
	                begin
	                   axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
	                   axi_awaddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};
	                end
	            default: //reserved (incremental burst for example)
	              begin
	                 axi_awaddr <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
	                 //for awsize = 4 bytes (010)
	              end
	          endcase
	       end // if ((axi_awlen_cntr < axi_awlen) && axi_wready && S_AXI_WVALID)
	  end // else: !if( S_AXI_ARESETN == 1'b0 )
     end // always @ ( posedge S_AXI_ACLK )

   // Implement axi_wready generation

   // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
   // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is
   // de-asserted when reset is low.

   always @( posedge S_AXI_ACLK )
     begin
	if ( S_AXI_ARESETN == 1'b0 )
	  begin
	     axi_wready <= 1'b0;
	  end
	else
	  begin
	     if ( ~axi_wready && S_AXI_WVALID && axi_awv_awr_flag && state_txn == 4)
	       begin
	          // slave can accept the write data
	          axi_wready <= 1'b1;
	       end
	     //else if (~axi_awv_awr_flag)
	     else if (axi_wready)  // if (S_AXI_WLAST && axi_wready)
	       begin
	          axi_wready <= 1'b0;
	       end
	  end
     end
   // Implement write response logic generation

   // The write response and response valid signals are asserted by the slave
   // when axi_wready, S_AXI_WVALID, S_AXI_WLAST are asserted.
   // This marks the acceptance of address and indicates the status of
   // write transaction.

   always @( posedge S_AXI_ACLK )
     begin
	if ( S_AXI_ARESETN == 1'b0 )
	  begin
	     axi_bvalid <= 0;
	     axi_bresp <= 2'b0;
	     axi_buser <= 0;
	  end
	else
	  begin
	     if (axi_awv_awr_flag && axi_wready && S_AXI_WVALID && ~axi_bvalid && S_AXI_WLAST)
	       begin
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0;
                  // 'OKAY' response
	       end
	     if (axi_bvalid && S_AXI_BREADY)
	       //check if bready is asserted while bvalid is high)
	       //(there is a possibility that bready is always asserted high)
	       begin
	          axi_bvalid <= 1'b0;
	       end
	  end
     end
   // Implement axi_arready generation

   // axi_arready is asserted for one S_AXI_ACLK clock cycle when
   // S_AXI_ARVALID is asserted. axi_awready is
   // de-asserted when reset (active low) is asserted.
   // The read address is also latched when S_AXI_ARVALID is
   // asserted. axi_araddr is reset to zero on reset assertion.

   always @( posedge S_AXI_ACLK )
     begin
	if ( S_AXI_ARESETN == 1'b0 )
	  begin
	     axi_arready <= 1'b0;
	     axi_arv_arr_flag <= 1'b0;
	  end
	else
	  begin
	     if (~axi_arready && S_AXI_ARVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag && state_txn == 0)
	       begin
	          axi_arready <= 1'b1;
	          axi_arv_arr_flag <= 1'b1;
	       end
	     else if (axi_rvalid && S_AXI_RREADY && axi_arlen_cntr == axi_arlen)
	       // preparing to accept next address after current read completion
	       begin
	          axi_arv_arr_flag  <= 1'b0;
	       end
	     else
	       begin
	          axi_arready <= 1'b0;
	       end
	  end
     end
   // Implement axi_araddr latching

   //This process is used to latch the address when both
   //S_AXI_ARVALID and S_AXI_RVALID are valid.
   always @( posedge S_AXI_ACLK )
     begin
	if ( S_AXI_ARESETN == 1'b0 )
	  begin
	     axi_araddr <= 0;
	     axi_arlen_cntr <= 0;
	     axi_arburst <= 0;
	     axi_arlen <= 0;
	     axi_rlast <= 1'b0;
	     axi_ruser <= 0;
	  end
	else
	  begin
	     if (~axi_arready && S_AXI_ARVALID && ~axi_arv_arr_flag)
	       begin
	          // address latching
	          axi_araddr <= S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH - 1:0];
	          axi_arburst <= S_AXI_ARBURST;
	          axi_arlen <= S_AXI_ARLEN;
	          // start address of transfer
	          axi_arlen_cntr <= 0;
	          axi_rlast <= 1'b0;
                  // set Nth bit (at offset 0) for read burst length N in 0..15
                  status_word[0 + S_AXI_ARLEN[2:0]] <= 1;
                  // set Nth bit (at offset 16) for read burst size N in 0..7
                  status_word[8 + S_AXI_ARSIZE[2:0]] <= 1;
	       end
	     else if((axi_arlen_cntr < axi_arlen) && axi_rvalid && S_AXI_RREADY)
	       begin
	          axi_arlen_cntr <= axi_arlen_cntr + 1;
	          axi_rlast <= 1'b0;

	          case (axi_arburst)
	            2'b00: // fixed burst
	              // The read address for all the beats in the transaction are fixed
	              begin
	                 axi_araddr       <= axi_araddr;
	                 //for arsize = 4 bytes (010)
	              end
	            2'b01: //incremental burst
	              // The read address for all the beats in the transaction are increments by awsize
	              begin
	                 axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
	                 //araddr aligned to 4 byte boundary
	                 axi_araddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};
	                 //for awsize = 4 bytes (010)
	              end
	            2'b10: //Wrapping burst
	              // The read address wraps when the address reaches wrap boundary
	              if (ar_wrap_en)
	                begin
	                   axi_araddr <= (axi_araddr - ar_wrap_size);
	                end
	              else
	                begin
	                   axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
	                   //araddr aligned to 4 byte boundary
	                   axi_araddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};
	                end
	            default: //reserved (incremental burst for example)
	              begin
	                 axi_araddr <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB]+1;
	                 //for arsize = 4 bytes (010)
	              end
	          endcase
	       end
	     else if((axi_arlen_cntr == axi_arlen) && ~axi_rlast && axi_arv_arr_flag)
	       begin
	          axi_rlast <= 1'b1;
	       end
	     else if (!S_AXI_RREADY)
	       begin
	          axi_rlast <= 1'b0;
	       end
	  end
     end
   // Implement axi_rvalid generation

   // axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both
   // S_AXI_ARVALID and axi_arready are asserted. The slave registers
   // data are available on the axi_rdata bus at this instance. The
   // assertion of axi_rvalid marks the validity of read data on the
   // bus and axi_rresp indicates the status of read transaction.axi_rvalid
   // is deasserted on reset (active low). axi_rresp and axi_rdata are
   // cleared to zero on reset (active low).

   always @( posedge S_AXI_ACLK )
     begin
	if ( S_AXI_ARESETN == 1'b0 )
	  begin
	     axi_rvalid <= 0;
	     axi_rresp  <= 0;
	  end
	else
	  begin
	     if (axi_arv_arr_flag && ~axi_rvalid && state_txn == 8)
	       begin
                  axi_rvalid <= 1'b1;
                  axi_rresp  <= 2'b0;
                  // 'OKAY' response
	       end
	     if (axi_rvalid && S_AXI_RREADY)
	       begin
	          axi_rvalid <= 1'b0;
	       end
	  end // else: !if( S_AXI_ARESETN == 1'b0 )

     end
   // ------------------------------------------
   // -- Example code to access user logic memory region
   // ------------------------------------------

   assign spi_fifo_empty = fifo_rd_empty && ~fifo_wr_en;

   /* Latch all read or write parameters. We may need to wait for
    memory to be ready and meanwhile incoming axi requests could
    overwrite the parameters.  */

   always @(posedge S_AXI_ACLK)
     begin
        axi_counter <= axi_counter + 1;
        case (state_txn)
          0:                    // accept new requests
            begin
               if (axi_awready)
                 state_txn <= 1;
               if (axi_arready)
                 state_txn <= 5;
            end
          1:             // write; wait for data
            begin
               if (S_AXI_WVALID)
                 begin
                    txn.address <= axi_awaddr;
                    txn.data <= S_AXI_WDATA;
                    txn.write_enable <= 1;
                    txn.wstrb <= S_AXI_WSTRB;
                    fifo_wr_en <= 1;
                    state_txn <= 2;
                 end
            end
          2:                    // enqueue cur request
            begin
               // wait for fifo to change to nonempty as an ack
               if (!spi_fifo_empty)
                 begin
                    fifo_wr_en <= 0;
                    state_txn <= 3;
                 end
            end
          3:                    // wait for request to finish (serialized)
            begin
               if (spi_fifo_empty)
                 state_txn <= 4;
            end
          4:
            begin
               if (axi_wready)
                 begin
                    if (axi_awlen_cntr < axi_awlen && !S_AXI_WLAST)
                      state_txn <= 1; // continue burst
                    else
                      state_txn <= 0;
                 end
            end

          5:                    // read; enqueue request
            begin
               txn.address <= axi_araddr;
               txn.data <= 0;
               txn.write_enable <= 0;
               txn.wstrb <= 0;
               fifo_wr_en <= 1;
               state_txn <= 6;
            end
          6:                    // enqueue cur request
            begin
               // wait for fifo to change to nonempty as an ack
               if (!spi_fifo_empty)
                 begin
                    fifo_wr_en <= 0;
                    state_txn <= 7;
                 end
            end
          7:                    // wait for request to finish (serialized)
            begin
               if (spi_fifo_empty)
                 state_txn <= 8;
            end
          8:                    // sync with rvalid
            begin
               if (axi_rvalid)
                 begin
                    if (axi_arlen_cntr < axi_arlen)
                      state_txn <= 5; // continue burst
                    else
                      state_txn <= 0;
                 end
            end
        endcase
     end // always @ (posedge S_AXI_ACLK)


   //Output register or memory read data

   always @( posedge S_AXI_ACLK )
     begin
        if (psram_data_valid)   // latch data soon as it arrives
          psram_data_latch <= psram_data_o;
     end

   always @( psram_data_latch, axi_rvalid)
     begin
	if (axi_rvalid)
          axi_rdata <= psram_data_latch;
	  //begin
          //   case (axi_araddr)
          //     16'hfff0: axi_rdata <= status_word;
          //     default: axi_rdata <= mem_data_out;
          //   endcase // case (axi_araddr)
	  //end
	else
	  begin
	     axi_rdata <= 32'hdeafbabe;
	  end
     end

   // Add user logic here

   // User logic ends

endmodule
