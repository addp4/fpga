`timescale 1ns / 1ps

module tb_woof_simple_spi() ;
   
   reg clock = 0;
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
   
   simple_spi DUT
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
   
   task spi_send_byte;
      input [7:0] data;
      begin
         #2;
         wr_data_i <= data;
         wr_en_i <= 1;
         #2;
         wr_en_i <= 0;
         while (busy_o)
           #2;
      end
   endtask

   task spi_send_word;
      input [31:0] data;
      begin
         spi_send_byte(data[31:24]);
         spi_send_byte(data[23:16]);
         spi_send_byte(data[15:8]);
         spi_send_byte(data[7:0]);
      end
   endtask // spi_send_word
   
   always #1 clock <= ~clock;

   always @(negedge busy_o)
     begin
        $display("incoming byte: %x\n", rd_data_o);
     end

   /* Inject bits on MISO as incrementing byte values
    */
   reg [7:0]  some_indata = 8'hf0;
   int cnt = 0;
   assign spi_miso_i = some_indata[0];
   always @(posedge spi_sck_o)
     begin
        if (cnt == 7)
          begin
             cnt <= 0;
             some_indata = {some_indata[6:0], some_indata[7]} + 1;
          end
        else
          begin
             cnt <= cnt + 1;
             some_indata = {some_indata[6:0], some_indata[7]};
          end
     end
   
   initial begin
      spi_csn = 1;
      #6
        rst_n = 1;

      #2
        spi_csn = 0;
      
      spi_send_byte(8'h0b);
      spi_send_word(32'h12345670);
      spi_send_word(32'hbadc0ffe);
      
      spi_csn = 1;

      #20
        ;
      

   end // initial begin
   
   
endmodule // tb_woof_simple_spi

