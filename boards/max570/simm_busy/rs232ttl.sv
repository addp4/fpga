module rs232ttl
  // #(parameter BAUD=115200)
  #(parameter BAUD=921600)
   (input  clk,
    input  txd,
    output rxd
    );
   localparam CDIV = 50000000 / (2*BAUD);
   reg [15:0] cdiv = 0;
   reg [4:0]  state;
   reg [7:0] sendbyte;
   reg       baudclock;
   reg       sendbit = 0;
   reg       idle = 1; // sertxd (esc,"[32m") 'green
   reg [31:0] nsent;   // total bytes sent
   localparam ESC = 27;
   reg [7:0] fifo[23] = '{"H", "e", "l", "l", "o", ",", " ", "w", "o", "r", "l", "d", " ",  // 13 bytes
                          "0", "0", "0", "0", "0", "0", "0", "0", 13, 10};  // 10 bytes
   reg [7:0] hexchar[16] = '{"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"};
   reg [7:0] head = 0, tail = 23;

   assign rxd = idle | sendbit;
   
   always @(posedge clk) begin
      cdiv <= (cdiv == CDIV) ? 0 : cdiv + 1;
      if (cdiv == CDIV) baudclock <= baudclock + 1;
   end

   always @(posedge baudclock) begin
      if (idle) begin
         state <= 0;
         idle <= 0;
         sendbyte <= fifo[head];
         if (head == tail) head <= 0; // refill the fifo from the start
         else head <= head + 1;
         sendbit <= 1;
      end else begin
         state <= state + 1;
         case (state)
           0: begin
              sendbit <= 0;       // start bit
           end
           1,2,3,4,5,6,7,8: begin
              sendbit <= sendbyte & 1;
              sendbyte <= sendbyte >> 1;
           end
           9: begin  // stop bit
              sendbit <= 1;
              nsent <= nsent + 1;  // total bytes copied
              fifo[13] <= hexchar[nsent[31:28]];
              fifo[14] <= hexchar[nsent[27:24]];
              fifo[15] <= hexchar[nsent[23:20]];
              fifo[16] <= hexchar[nsent[19:16]];
              fifo[17] <= hexchar[nsent[15:12]];
              fifo[18] <= hexchar[nsent[11:8]];
              fifo[19] <= hexchar[nsent[7:4]];
              fifo[20] <= hexchar[nsent[3:0]];
              idle <= 1;
           end
           default: begin
              idle <= 1;
           end
         endcase // case (count)
      end // else: !if(idle)
   end // always @ (posedge baudclock)

endmodule // rs232ttl
