/*
 This module owns the memory (block ram for now) and the dequeue end of the fifo.
 */
typedef struct packed {
   logic       write_enable;
   logic [3:0] wstrb;
   logic [31:0] data;
   logic [15:0] address;
} transaction_t;
localparam integer TXN_WIDTH = $bits(transaction_t);


module fifo_ram
  (
   input wire         clock,
   input wire         reset_n,
   output wire        rd_en_o,
   input              transaction_t rd_data,
   input wire         rd_empty,
   output wire [31:0] data_o,
   output wire        data_valid_o
   );

   genvar             mem_byte_index;
   wire               mem_wren;
   wire               mem_rden;
   wire [13:0]        mem_address;
   reg [31:0]         data;
   reg                data_valid = 0;
   localparam integer SPI_FIFO_DELAY = 64;
   reg [7:0]          fifo_delay;
   reg                rd_en;
   assign rd_en_o = rd_en;

   always @(posedge clock)
     begin
        rd_en <= 0;
        data_valid <= 0;
        if (!rd_empty)
          begin
             if (fifo_delay == SPI_FIFO_DELAY)
               begin
                  rd_en <= 1; // assert fifo deq for 1 cycle
                  fifo_delay <= 0;
                  data_valid <= 1;
               end
             else
               begin
                  fifo_delay <= fifo_delay + 1;
               end
          end
        else                    // fifo is empty
          begin
             fifo_delay <= 0;
          end
     end

   assign data_o = data;
   assign data_valid_o = data_valid;
   assign mem_wren = !rd_empty && rd_data.write_enable;
   assign mem_rden = !rd_empty && !rd_data.write_enable;
   assign mem_address = rd_data.address[13:2];

   // AXI_DATA_WIDTH is 32, so mem_byte_index goes from [0..3]
   for (mem_byte_index = 0; mem_byte_index < 4; mem_byte_index = mem_byte_index+1)
     begin:BYTE_BRAM_GEN
	wire [8-1:0] d_in ;
	reg [8-1:0]  byte_ram [0 : 16383];

	//assigning 8 bit data
	assign d_in  = rd_data.data[(mem_byte_index*8+7) -: 8];

        always @( posedge clock )
          begin
	     if (mem_wren && rd_data.wstrb[mem_byte_index])
               begin
	          byte_ram[mem_address] <= d_in;
               end
          end
   always @( posedge clock )
     begin
	if (mem_rden)
	  begin
	     data[(mem_byte_index*8+7) -: 8] <= byte_ram[mem_address];
	  end
     end
end // block: BYTE_BRAM_GEN

endmodule // fifo_ram
