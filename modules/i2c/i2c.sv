`timescale 1ns / 1ps
// `default_nettype none                        // Require all nets to be declared before used.
// https://www.ti.com/lit/ds/symlink/pcf8574.pdf?ts=1703307030725
// https://www.ti.com/lit/an/slva704/slva704.pdf?ts=1703257669779

`define I2C_DELAY_THEN(next) \
   begin \
    delay <= delay - 1; \
    if (signed'(delay) < 0) state <= next; \
   end

`define SDA_SET(v) sda <= v; sda_out_ena <= !v
`define SDA_HIGH sda <= 1; sda_out_ena <= 0
`define SDA_LOW sda <= 0; sda_out_ena <= 1
`define SCL_HIGH scl <= 1; scl_out_ena <= 0
`define SCL_LOW scl <= 0; scl_out_ena <= 1
`define INIT_DELAY_CTR delay <= (delay_cycles << delay_shift) -2

`ifdef XX
module i2c_send_byte(input clk,
                 input       we,
                 input       sda_in,
                 input       scl_in,
                 output      sda_out,
                 output      scl_out,
                 input [7:0] data,
                 input [7:0] address,
                 output      busy);

   enum bit[4:0] {
                  START, S1, S2, S3, S4, S5, S6, S7, S8,
                  SA, SA1,
                  IDLE
                  } state = IDLE;

   always_ff @(posedge clk) begin
      case (state)
        IDLE: state <= IDLE;

        START: begin
           `SCL_LOW;
           `INIT_DELAY_CTR;
           state <= S1;
        end
        S1: `I2C_DELAY_THEN(S2)

        // The start condition is indicated by a high-to-low transition of SDA with SCL high
        S2: begin               // sda <= 1
           `SDA_HIGH;
           `INIT_DELAY_CTR;
           state <= S3;
           error <= 0;
        end
        S3: `I2C_DELAY_THEN(S4)
        S4: begin     // scl <= 1
           `SCL_HIGH;
           `INIT_DELAY_CTR;
           state <= S5;
        end
        S5: `I2C_DELAY_THEN(S6)
        S6: begin     // sda <= 0
           `SDA_LOW;
           `INIT_DELAY_CTR;
           state <= S7;
        end
        S7: `I2C_DELAY_THEN(S8)
        S8: begin     // scl <= 0
           `SCL_LOW;
           state <= SA;
        end

        SA: begin
           data <= address << 1;
           // state <= SA1;
        end


      endcase // case (state)
   end

endmodule // send_byte
`endif


module simple_i2c #(parameter SIM=0) (
    input      clk,
    input      rst_n,
    input      write_ena,
    input      sda_in,
    input      scl_in,
    output     sda_out,
    output     scl_out,
    output     busy,
    output reg error
    );
   localparam us = 100;         // cycles per microsecond @ 100MHz
   localparam delay_cycles = SIM ? 2 : 37 * us;
   reg [7:0]   address;
   reg [7:0]   data, shift_data;
   reg [31:0]  delay;
   reg [4:0]   delay_shift;
   reg       scl, sda_out_ena;
   reg       sda, scl_out_ena;
   reg       ack;
   enum      bit[2:0] { CMD_NONE, CMD_RESET, CMD_WRITE } cmd;
   enum      bit[4:0] {
                       /*0x0*/ WRITE_BYTE,    WRITE_BYTE_1,  WRITE_BYTE_2,  WRITE_BYTE_3,
                       /*0x4*/ WRITE_BYTE_4,  WRITE_BYTE_5,  WRITE_BYTE_6,  WRITE_BYTE_UNUSED,
                       /*0x8*/ READ_ACK_1,   READ_ACK_2,   READ_ACK_3,   READ_ACK_4,
                       /*0xc*/ READ_ACK_5,   READ_ACK_6,
                       /*0xe*/ SEND_START,   SEND_START_2, SEND_START_3, SEND_START_4,
                       /*0x12*/ SEND_START_5, SEND_START_6, SEND_START_7,
                       /*0x15*/ IDLE,         RESET,        RESET_1,
                       SEND_STOP_1,  SEND_STOP_2,  SEND_STOP_3,  SEND_STOP_4,
                       SEND_STOP_5,  SEND_STOP_6,  SEND_STOP_7
             } state = IDLE;
   reg [4:0] shift_count;

   assign sda_out = sda_out_ena && sda == 0 ? 0 : 1'bz;
   assign scl_out = scl_out_ena && scl == 0 ? 0 : 1'bz;
   //assign sda_out = sda == 0 ? 0 : 1'bz;
   // assign scl_out = scl == 0 ? 0 : 1'bz;
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
      else if (busy)
        cmd <= CMD_NONE;

      case (state)
        IDLE: begin
           case (cmd)
             CMD_RESET: state <= RESET;
             CMD_WRITE: state <= WRITE_BYTE;
           endcase // case (cmd)
        end

        RESET: begin
           `SCL_LOW;
           `INIT_DELAY_CTR;
           state <= RESET_1;
        end
        RESET_1: `I2C_DELAY_THEN(SEND_START)

        // The start condition is indicated by a high-to-low transition of SDA with SCL high
        SEND_START: begin       // sda <= 1
           `SDA_HIGH;
           `INIT_DELAY_CTR;
           state <= SEND_START_2;
           error <= 0;
        end
        SEND_START_2: `I2C_DELAY_THEN(SEND_START_3)
        SEND_START_3: begin     // scl <= 1
           `SCL_HIGH;
           `INIT_DELAY_CTR;
           state <= SEND_START_4;
        end
        SEND_START_4: `I2C_DELAY_THEN(SEND_START_5)
        SEND_START_5: begin     // sda <= 0
           `SDA_LOW;
           `INIT_DELAY_CTR;
           state <= SEND_START_6;
        end
        SEND_START_6: `I2C_DELAY_THEN(SEND_START_7)
        SEND_START_7: begin     // scl <= 0
           `SCL_LOW;
           state <= WRITE_BYTE;
        end

        // The address and the data bytes are sent most significant bit first
        WRITE_BYTE: begin        // invariant: scl == 0
           `SCL_LOW;
           shift_count <= 7;
           state <= WRITE_BYTE_1;
        end
        WRITE_BYTE_1: begin
           `SDA_SET(shift_data[7]);   // send msb
           shift_count <= shift_count - 1;
           `INIT_DELAY_CTR;
           state <= WRITE_BYTE_2;
        end
        WRITE_BYTE_2: `I2C_DELAY_THEN(WRITE_BYTE_3)
        WRITE_BYTE_3: begin
           `SCL_HIGH;
           `INIT_DELAY_CTR;
           state <= WRITE_BYTE_4;
        end
        WRITE_BYTE_4: `I2C_DELAY_THEN(WRITE_BYTE_5)
        WRITE_BYTE_5: begin      // while (scl == 0) ; clock stretching
           if (scl_in != 0) state <= WRITE_BYTE_6;
        end
        WRITE_BYTE_6: begin
           if (sda_in != shift_data[7]) error <= 1;
           `SCL_LOW;
           shift_data <= shift_data << 1;
           state <= (signed'(shift_count) < 0) ? READ_ACK_1 : WRITE_BYTE_1;
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
        READ_ACK_2: `I2C_DELAY_THEN(READ_ACK_3)  // time for slave to set ack/nack
        READ_ACK_3: begin
           `SCL_HIGH;           // release SCL
           state <= READ_ACK_4;  // check SCL starting next clock
        end
        READ_ACK_4: begin // while self.read_SCL() == 0 ;
           `INIT_DELAY_CTR;
           if (scl_in != 0) state <= READ_ACK_5;
        end
        READ_ACK_5: `I2C_DELAY_THEN(READ_ACK_6)
        READ_ACK_6: begin
           ack <= sda_in;
           $display("ack: %0d", sda_in);
           `SCL_LOW;
           state <= sda_in ? SEND_START : IDLE; // reset if nack
        end

      endcase // case (state)
   end // always @ (posedge clk)
endmodule
