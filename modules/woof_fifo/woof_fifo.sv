`default_nettype none

module woof_fifo #(parameter DEPTH = 4, LOG2_DEPTH = 2, WIDTH = 32)
   (
    input  wire clock,
    input  wire reset_n,
    input  wire wr_en,
    input  wire [WIDTH-1:0] wr_data,
    output wire wr_full,
    input  wire rd_en,
    output wire [WIDTH-1:0] rd_data,
    output wire rd_empty
    );

   reg [LOG2_DEPTH-1:0] head;
   reg [LOG2_DEPTH-1:0] tail;
   reg [WIDTH-1:0]      mem[0:DEPTH-1];
   reg                  full;
   wire [LOG2_DEPTH:0]  depth;
   
   // basing full/empty on depth avoids carry issues and supports non powers-of-2
   assign depth = full ? DEPTH : (tail - head) & (DEPTH - 1);
   assign rd_empty = (depth == 0);
   assign wr_full = full;
   // rd_data updates to head immediately as in "last word fallthrough"
   assign rd_data = mem[head];
                    
   always_ff @(posedge clock)
     if (!reset_n)
       begin
          full <= 0;
          head <= 0;
          tail <= 0;
       end

   always_ff @(posedge clock)
     if (wr_en && !full)
       begin
          mem[tail] <= wr_data;
          tail <= tail + 1;
          full <= (depth == DEPTH-1);
       end
   
   always_ff @(posedge clock)
     if (rd_en && !rd_empty)
       begin
          head <= head + 1;
          full <= 0;
       end
   
endmodule // woof_fifo
