module rs232ttl
  #(parameter BAUD=115200)
   (input  clk,
    input  txd,
    output rxd
    );
   localparam CDIV = 50000000 / (2*BAUD);
   reg [15:0] cdiv = 0;
   reg [4:0]  count;
   reg [7:0] sendbyte;
   reg       baudclock;
   reg       sendbit = 0;
   reg       idle = 1; // sertxd (esc,"[32m") 'green
   localparam ESC = 27;
   reg [7:0] fifo[14] = '{"H", "e", "l", "l", "o", ",", " ", "w", "o", "r", "l", "d", 13, 10};
   reg [3:0] head = 0, tail = 13;

   assign rxd = idle | sendbit;
   
   always @(posedge clk) begin
      cdiv <= (cdiv == CDIV) ? 0 : cdiv + 1;
      if (cdiv == CDIV) baudclock <= baudclock + 1;
   end

   always @(posedge baudclock) begin
      if (idle) begin
         count <= 0;
         idle <= 0;
         sendbyte <= fifo[head];
         if (head == tail) head <= 0; // refill the fifo from the start
         else head <= head + 1;
         sendbit <= 1;
      end else begin
         count <= count + 1;
         case (count)
           0: begin
              sendbit <= 0;       // start bit
           end
           1,2,3,4,5,6,7,8: begin
              sendbit <= sendbyte & 1;
              sendbyte <= sendbyte >> 1;
           end
           9: begin  // stop bit
              sendbit <= 1;
           end
           default: idle <= 1;
         endcase // case (count)
      end // else: !if(idle)
   end // always @ (posedge baudclock)

endmodule // rs232ttl

   

module spi #(parameter CLK_DIV = 1000000)(
                                    input        clk,
                                    input        rst,
                                    input        miso,
                                    output       mosi,
                                    output       sck,
                                    input        start,
                                    input [7:0] data_in,
                                    output [7:0] data_out,
                                    output       busy,
                                    output       new_data
  );
   
   localparam STATE_SIZE = 2;
   localparam IDLE = 2'd0,
     SCK_LO = 2'd1,
     SCK_HI = 2'd2;
   
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
           sck_d = 0;                 // reset clock counter
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
                 state_d = IDLE;                             // change state
                 data_out_d = data_q;                        // output data
                 new_data_d = 1'b1;                          // signal data is valid
              end
              else begin
                 sck_d = 0;
                 state_d = SCK_LO;
              end
           end
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


/*
 module max7219(input clk, input rst, input miso, output mosi, output sck, output load, input [7:0]addr, input [7:0]data, input start, output busy);
 
 wire new_data;
 reg [7:0] data_in;
 wire [7:0] data_out;
 
 endmodule // max7219
 */


module max7219(input clk, input rst_n, output max_din, output max_load, output max_clk, input [31:0]display_value);

   wire [7:0] data_out;
   reg [7:0]  data;
   wire       busy;
   wire       miso_ignored, new_data_ignored;
   reg        spi_start;
   wire       rst;
   enum { INIT, INIT1, INIT1_WAIT, INIT2, INIT2_WAIT, INIT_HOLD, INIT_DONE, DISP1, DISP2 } state_t;
   reg [3:0]    state;
   reg [4:0]    addr;
   reg [31:0]   disp_dig;
   reg [7:0]    LED_out;
   
   localparam DECODEMODE_ADDR = 9;
   localparam BRIGHTNESS_ADDR = 10;
   localparam SCANLIMIT_ADDR = 11;
   localparam SHUTDOWN_ADDR = 12;
   localparam DISPLAYTEST_ADDR = 13;
   
   localparam INITBYTES = 14;
   reg [7:0]  maxinit[0:INITBYTES-1] = 
                '{0, 0,         // nop; this may help recover a random state
                  DISPLAYTEST_ADDR, 0,
                  SCANLIMIT_ADDR, 7,
                  DECODEMODE_ADDR, 0,
                  SHUTDOWN_ADDR, 1,
                  BRIGHTNESS_ADDR, 7,
                  1, 8'h0      // byte 12-13
                  };
   reg [4:0]    pinit;

   spi #(10) max7219(.clk(clk),
                    .rst(rst),
                    .miso(miso_ignored),
                    .mosi(max_din),
                    .sck(max_clk),
                    .new_data(new_data_ignored),
                    .start(spi_start),
                    .data_in(data),
                    .data_out(data_out),
                    .busy(busy)
                    );
   reg [31:0]   cycles;
   
   assign rst = ~rst_n;

   always @(posedge clk) begin
      cycles <= cycles + 1;
      
      case (state)
        INIT: begin
           pinit <= 0;
           state <= INIT1;
           max_load <= 0;
           addr <= 1;           // for displaying digits (optional)
           disp_dig <= 0;
        end
        INIT1: begin
           max_load <= 0;
           data <= maxinit[pinit];
           pinit <= pinit + 4'b1;
           spi_start <= 1;
           state <= INIT1_WAIT;
        end
        INIT1_WAIT: begin     // 1
          spi_start <= 0;
          if (busy == 0) state <= INIT2;
        end
        INIT2: begin
           data <= maxinit[pinit];
           pinit <= pinit + 4'b1;
           spi_start <= 1;
           state <= INIT2_WAIT;
        end
        INIT2_WAIT: begin     // 1
           spi_start <= 0;
           if (busy == 0) state <= INIT_HOLD;
        end
        INIT_HOLD: begin
           max_load <= 1;
           state <= (pinit < 12) ? INIT1 : INIT_DONE;
        end
        // Formally, we're done with init here. But use the loop to
        // iterate through numbers as well. We'll update only one
        // digit per cycle. The digit is selected by addr, where 1 is
        // the rightmost digit on the display, hence the low 4 bits of
        // disp_num. After doing all the digits, we increment
        // disp_num.
        INIT_DONE: begin
           pinit <= 12;
           maxinit[12] <= addr;
           maxinit[13] <= LED_out;

           if (addr < 8) begin
              addr <= addr + 4'b1;
              disp_dig <= disp_dig >> 4;
           end else begin
              addr <= 1;
              disp_dig <= display_value;  // cycles;
              // disp_dig <= cycles;
           end
           state <= rst ? INIT : INIT1;
        end // case: INIT_DONE
        
      endcase // case (state)
   end // always @ (posedge clk)

   always @(*) begin
           case(disp_dig & 4'hf)
             4'b0000: LED_out = 7'b1111110; // "0"     
             4'b0001: LED_out = 7'b0110000; // "1" 
             4'b0010: LED_out = 7'b1101101; // "2" 
             4'b0011: LED_out = 7'b1111001; // "3" 
             4'b0100: LED_out = 7'b0110011; // "4" 
             4'b0101: LED_out = 7'b1011011; // "5" 
             4'b0110: LED_out = 7'b1011111; // "6" 
             4'b0111: LED_out = 7'b1110000; // "7" 
             4'b1000: LED_out = 7'b1111111; // "8"     
             4'b1001: LED_out = 7'b1111011; // "9" 
             4'b1010: LED_out = 7'b1110111; // "A" 
             4'b1011: LED_out = 7'b0011111; // "b" 
             4'b1100: LED_out = 7'b1001110; // "C" 
             4'b1101: LED_out = 7'b0111101; // "d" 
             4'b1110: LED_out = 7'b1001111; // "E" 
             4'b1111: LED_out = 7'b1000111; // "F"
             default: LED_out = 7'b0000000; // can't happen
           endcase // case (disp_dig & 8'hf)
   end
endmodule // max7219


module dff(input d, input clk, input rst_n, output reg q);
   
   always @(posedge clk or negedge rst_n)
     q <= !rst_n ? 0 : d;

endmodule // dff

   
module mc68008
  #(parameter ADDRLEN=20)
   (input       sysclk,
    input               rst_n,
    input [ADDRLEN-1:0] addr_bus,
    input [2:0]         fc,
    input               rw_,
    input               ds_,
    input               as_,
    input [7:0]         data_in,
    output [7:0]        data_out,
    output              data_oe,
    output              data_dir,  // high=A->B, low=B->A
    output              cpuclk,
    output              cpurst_n,
    output              dtack_,
    output [31:0]       status,
    output [31:0]       status2
               );
   
   reg [5:0]                cpuclk_div;
   reg [31:0]               cpu_cycles;
   reg [15:0]               reset_ctr = 0;
   reg [2:0]                fc_latch;
   reg [7:0]                iomap[4];
   reg                      cpuclk_d;
   reg [ADDRLEN-1:0]        addr_latch[8];
   reg [7:0]                data_latch;
   reg                      data_latch_valid;

   reg [7:0]                ram[65536];
   initial begin
      $readmemh("mc68000_ram.data", ram, 0, 65535);
   end

   
   assign status2[31:24] = iomap[0];
   assign status2[23:16] = iomap[1];
   assign status2[15:8] = iomap[2];
   assign status2[7:0] = iomap[3];
   
   assign status[31:12] = addr_latch[5];
   assign status[11:4] = data_latch_valid ? data_latch : data_out;
   assign status[3:0] = fc_latch;
   //assign status[3] = reset_oe; // 8 = Reset
   //assign status[2] = ~as_;     // 4 = AS
   //assign status[1] = ~ds_;     // 2 = DS
   //assign status[0] = rw_;      // 1 = Read
   // assign status[31:24] = cpu_cycles[27:20];
   assign data_oe = rw_ == 1 && ds_ == 0;
   assign data_dir = ~rw_;
   assign cpuclk = cpuclk_d;
   assign dtack_ = 0;
   
   always @(posedge sysclk) begin
      if (cpuclk_div == 1) begin
         cpuclk_div <= 0;
         cpuclk_d <= ~cpuclk_d;
      end else
        cpuclk_div <= cpuclk_div + 1'b1;
   end

   always @(posedge cpuclk) begin
      cpu_cycles <= cpu_cycles + 1;
      if (!rst_n) reset_ctr <= 0;
      case (reset_ctr)
         16'hffff: cpurst_n <= 1;
         default:  begin
            cpurst_n <= 0;
            reset_ctr <= reset_ctr + 1'b1;
         end
      endcase // case (reset_ctr)
   end

   always @(negedge ds_) begin
      case (rw_)
        // Write cycle. Store data on data_in in "RAM".
        0: begin 
           //if (addr_bus[19] == 0)
             addr_latch[fc] <= addr_bus;
           data_latch <= data_in;
           data_latch_valid <= 1;
           case (addr_bus[19])
             0: ram[addr_bus[15:0]] = data_in;
             1: if ((addr_bus[19:0] & 20'hffffc) == 20'h80034) iomap[addr_bus[1:0]] = data_in;
             // 1: iomap[addr_bus[1:0]] = data_in;
           endcase // case addr_bus[16]
        end
        
        // Read cycle. Fetch "RAM" and send it to the CPU on data_out.
        1: begin
           //if (addr_bus[19] == 0)
             addr_latch[fc] <= addr_bus;
 `ifndef XX
           data_out <= ram[addr_bus[15:0]];
           data_latch_valid <= 0;
 `else
           // data_out <= addr_bus[0] == 0 ? 8'hc4 : 8'hc0;
           // data_out <= addr_bus[0] == 0 ? 8'hd4 : 8'h40;
           case (addr_bus[0:0])  // 0640 1234
             0: data_out <= 8'h52;
             1: data_out <= 8'h84;
             //2: data_out <= 8'h23;
             //3: data_out <= 8'hc4;
             // 4: data_out <= 8'h00;
             // 5: data_out <= 8'h08;
             // 6: data_out <= 8'h12;
             // 7: data_out <= 8'h23;
           endcase // case (addr_bus[1:0])
           data_latch <= 0;
           data_latch_valid <= 0;
 `endif
           fc_latch <= fc;
        end
      endcase // case (rw_)
   end // always @ (negedge ds_)
   
endmodule // mc68008

                           
                           
                           
module main(input CLOCK_50, input [1:0]KEY, inout [33:0]GPIO_0, inout [0:33]GPIO_1);

   wire [31:0] status, status2;
   reg [31:0] display_value, display_value2;
   wire       max_din, max_load, max_clk;
   
   max7219 disp(.clk(CLOCK_50), .rst_n(KEY[0]), 
                .max_din(GPIO_1[0]), .max_load(GPIO_1[1]), .max_clk(GPIO_1[2]),
                .display_value(display_value));
   
   max7219 disp2(.clk(CLOCK_50), .rst_n(KEY[0]), 
                 .max_din(GPIO_1[3]), .max_load(GPIO_1[4]), .max_clk(GPIO_1[5]),
                 .display_value(display_value2));


   wire       rxd;
   rs232ttl uart(.clk(CLOCK_50), .txd(GPIO_1[7]), .rxd(rxd));
   assign GPIO_1[6] = rxd;
   // assign GPIO_1[6] = !rxd ? 0 : 1'bz;
   
   reg        data_oe;
   reg [31:0] cycles;
   reg [7:0]  data_out;
   reg        cpurst_n;
   
   mc68008 cpu(
               .sysclk(CLOCK_50),
               .rst_n(KEY[1]),
               .addr_bus(GPIO_1[14:33]),  // pin 14 is MSB, pin 33 is LSB
               // .data_in(GPIO_0[23:16]),  // pin 23 is MSB, pin 16 is LSB
               .data_in(GPIO_0[23:16]),  // pin 23 is MSB, pin 16 is LSB
               .data_out(data_out),
               .data_oe(data_oe),
               .data_dir(GPIO_0[15]),
               .dtack_(GPIO_0[24]),
               .cpuclk(GPIO_0[25]),
               .fc(GPIO_0[28:26]),
               .cpurst_n(cpurst_n),
               .rw_(GPIO_0[31]),
               .ds_(GPIO_0[32]),
               .as_(GPIO_0[33]),
               // .status(display_value)
               .status(status),
               .status2(status2)
               );
   
   // assign GPIO_0[33:29] = datadir ? dataout : 8'bz;
   assign GPIO_0[33:26] = 8'bz;
   assign GPIO_0[13:0] = 14'bz;
   assign GPIO_1[6:33] = 28'bz;

   assign GPIO_0[23:16] = data_oe ? data_out : 8'bz;
   //assign GPIO_0[23:16] = data_out;
   
   // gpio29 and 30 are unused. they used to be reset and halt when the
   // level shifter was bidirectional, but now it is cpu output only.
   // the halt line is tied manually.
   assign GPIO_0[29] = 1'bz;
   assign GPIO_0[30] = 1'bz;
   
   assign GPIO_0[14] = cpurst_n;  // cpu reset line
   // assign GPIO_0[30] = reset_oe ? 1'b0 : 1'b1; // halt

   always @(posedge CLOCK_50) begin
      cycles <= cycles + 1;
   end

   always @(posedge cycles[20]) display_value <= status;
   // always @(posedge cycles[22]) display_value <= status;
   always @(posedge cycles[20]) display_value2 <= status2;
   
endmodule // main
