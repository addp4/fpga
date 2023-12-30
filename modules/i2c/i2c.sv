`timescale 1ns / 1ps
// `default_nettype none                        // Require all nets to be declared before used.
// https://www.ti.com/lit/ds/symlink/pcf8574.pdf?ts=1703307030725
// https://www.ti.com/lit/an/slva704/slva704.pdf?ts=1703257669779

// `define SIMULATION
`define DELAY_THEN(next) \
   begin \
    delay <= delay - 1; \
    if (delay[15]) state <= next; \
   end
`define SDA_SET(x) sda <= x; sda_out_ena <= 1
`define SDA_HIGH sda <= 1; sda_out_ena <= 1
`define SDA_LOW sda <= 0; sda_out_ena <= 1
`define SCL_HIGH scl <= 1; scl_out_ena <= 1
`define SCL_LOW scl <= 0; scl_out_ena <= 1
`define INIT_DELAY_CTR delay <= delay_cycles-2
   
module simple_i2c(
    input      clk,
    input      rst_n,
    input      read_ena,
    input      write_ena,
    input      sda_in,
    input      scl_in,
    output     sda_out,
    output     scl_out,
    output     busy,
    output reg error
    );
   localparam us = 100;         // cycles per microsecond @ 100MHz
`ifdef SIMULATION   
   // localparam delay_cycles = 2;
`else
   localparam delay_cycles = 10 * us; // 100 KHz
`endif
   reg [7:0] address;
   reg [7:0] data, shift_data;
   reg [15:0] delay;
   reg       scl, sda_out_ena;
   reg       sda, scl_out_ena;
   reg       ack;
   enum      bit[3:0] {
                       DO_IDLE,
                       DO_START
                       } action;
   enum      bit[2:0] { CMD_NONE, CMD_RESET, CMD_WRITE } cmd;
   enum      bit[4:0] {
                       IDLE,
                       RESET,        RESET_1,
                       SEND_START,   SEND_START_2, SEND_START_3, SEND_START_4,
                       SEND_START_5, SEND_START_6, SEND_START_7,
                       SEND_DATA,    SEND_DATA_1,  SEND_DATA_2,  SEND_DATA_3,
                       SEND_DATA_4,  SEND_DATA_5,  SEND_DATA_6,  SEND_DATA_7,
                       READ_ACK_1,   READ_ACK_2,   READ_ACK_3,   READ_ACK_4,
                       READ_ACK_5,   READ_ACK_6,
                       SEND_STOP_1,  SEND_STOP_2,  SEND_STOP_3,  SEND_STOP_4,
                       SEND_STOP_5,  SEND_STOP_6,  SEND_STOP_7                  
             } state = IDLE;
   reg [3:0] shift_count;
   // reg [4:0] state = IDLE;

   assign sda_out = sda_out_ena && sda == 0 ? 0 : 1'bz; 
   assign scl_out = scl_out_ena && scl == 0 ? 0 : 1'bz;
   assign busy = (state != IDLE);

   always_ff @(posedge clk) begin
      if (!rst_n) begin
         cmd <= CMD_RESET;
         shift_data <= address << 1;
      end
      else if (write_ena) begin
         cmd <= CMD_WRITE;
         shift_data <= data;
      end
      else if (!busy)
        cmd <= CMD_NONE;

      case (state)
        IDLE: begin
           case (cmd)
             CMD_RESET: state <= RESET;
             CMD_WRITE: state <= SEND_DATA;
           endcase // case (cmd)
        end
        
        RESET: begin
           `SCL_LOW;
           `INIT_DELAY_CTR;
           state <= RESET_1;
        end
        RESET_1: `DELAY_THEN(SEND_START)

        // The start condition is indicated by a high-to-low transition of SDA with SCL high
        SEND_START: begin       // sda <= 1
           `SDA_HIGH;
           `INIT_DELAY_CTR;
           state <= SEND_START_2;
           error <= 0;
        end
        SEND_START_2: `DELAY_THEN(SEND_START_3)
        SEND_START_3: begin     // scl <= 1
           `SCL_HIGH;
           `INIT_DELAY_CTR;
           state <= SEND_START_4;
        end
        SEND_START_4: `DELAY_THEN(SEND_START_5)
        SEND_START_5: begin     // sda <= 0
           `SDA_LOW;
           `INIT_DELAY_CTR;
           state <= SEND_START_6;
        end
        SEND_START_6: `DELAY_THEN(SEND_START_7)
        SEND_START_7: begin     // scl <= 0
           `SCL_LOW;
           state <= SEND_DATA;
        end

        // The address and the data bytes are sent most significant bit first
        SEND_DATA: begin        // invariant: scl == 0
           shift_count <= 7;
           state <= SEND_DATA_1;
        end
        SEND_DATA_1: begin
           // `SDA_SET(shift_data[7]);   // send msb
           sda <= shift_data[7];
           sda_out_ena <= 1;
           // `SDA_SET(1);   // send msb
           
           shift_count <= shift_count - 1;
           `INIT_DELAY_CTR;
           state <= SEND_DATA_2;
        end
        SEND_DATA_2: `DELAY_THEN(SEND_DATA_3)
        SEND_DATA_3: begin
           `SCL_HIGH;
           `INIT_DELAY_CTR;
           state <= SEND_DATA_4;
        end
        SEND_DATA_4: `DELAY_THEN(SEND_DATA_5)
        SEND_DATA_5: begin      // while (scl == 0) ; clock stretching
           if (scl !== 0) state <= SEND_DATA_6;
           `INIT_DELAY_CTR;
        end
        SEND_DATA_6: `DELAY_THEN(SEND_DATA_7)
        SEND_DATA_7: begin
           if (sda_in != data[7]) error <= 1;
           `SCL_LOW;
           shift_data <= shift_data << 1;
           state <= (shift_count[3]) ? READ_ACK_1 : SEND_DATA_1;
        end

        // Each byte of data (including the address byte) is followed
        // by one ACK bit from the receiver.  Before the receiver can
        // send an ACK, the transmitter must release the SDA line. To
        // send an ACK bit, the receiver shall pull down the SDA line
        // during the low phase of the ACK/NACK-related clock period
        // (period 9), so that the SDA line is stable low during the
        // high phase of the ACK/NACK-related clock period. Setup and
        // hold times must be taken into account. When the SDA line
        // remains high during the ACK/NACK-related clock period, this
        // is interpreted as a NACK.
        READ_ACK_1: begin
           `SDA_HIGH;           // release SDA line; scl is low
           `INIT_DELAY_CTR;
           state <= READ_ACK_2;
        end
        READ_ACK_2: `DELAY_THEN(READ_ACK_3)  // time for slave to set ack/nack
        READ_ACK_3: begin
           `SCL_HIGH;           // release SCL
           state <= READ_ACK_4;  // check SCL starting next clock
        end
        READ_ACK_4: begin // while self.read_SCL() == 0 ;
           /* if (scl_in !== 0) */ state <= READ_ACK_5;
        end
        READ_ACK_5: `DELAY_THEN(READ_ACK_6)
        READ_ACK_6: begin
           ack <= sda_in;
           $display("ack: %0d", sda_in);
           `SCL_LOW;
           state <= IDLE;
        end
        
        // the stop condition is indicated by a low-to-high transition of SDA with SCL high
        SEND_STOP_1: begin
           `SDA_LOW;
           `INIT_DELAY_CTR;
           state <= SEND_STOP_2;
           error <= 0;
        end
        SEND_STOP_2: `DELAY_THEN(SEND_STOP_3)
        SEND_STOP_3: begin
           `SCL_HIGH;
           `INIT_DELAY_CTR;
           state <= SEND_STOP_4;
        end
        SEND_STOP_4: `DELAY_THEN(SEND_STOP_5)
        SEND_STOP_5: begin
           `SDA_HIGH;
           `INIT_DELAY_CTR;
           state <= SEND_STOP_6;
        end
        SEND_STOP_6: `DELAY_THEN(SEND_STOP_7)
        SEND_STOP_7: begin
           `SCL_LOW;
           if (sda_in == 0) error <= 1;
           state <= IDLE;
        end
        
      endcase // case (state)
   end // always @ (posedge clk)
endmodule
