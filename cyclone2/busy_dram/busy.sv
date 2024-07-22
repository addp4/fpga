module busybeaver_37B
  (
   input 	 clk,
   input 	 rst_n,
   output [31:0] count,
   output 	 m_write, // DRAM
   output 	 m_ena,
   output [3:0]  wr_data,
   input [3:0] 	 rd_data,
   input 	 m_busy,
   input 	 m_ack,
   output [17:0] m_addr
   );

   // BB state machine
   localparam
     A = 2'd0,
     B = 2'd1,
     C = 2'd2,
     H = 2'd3,
     L = 1'd0,
     R = 1'd1;
   reg [1:0] 	 state = A, next = A;
   // Turing machine
   reg 		 dir = 0, latch_dir;
   reg [31:0] 	 count_d = 1;
   reg [3:0] 	 sym = 0;
   reg [3:0] 	 newsym = 0;
   reg [17:0] 	 pos = 0;
   // DRAM state machine
   typedef enum { M_INIT1, M_INIT2, M_INIT3, M_R1, M_R2, M_W1, M_W2, M_TM1, M_TM2 } m_t;
   reg [3:0] 	m_state = M_INIT1;

   // reg [2:0] 	tape[128];  // size is power of 2 so pos can wrap
   // assign sym = tape[pos];
   // always @(posedge clk) begin
   //   tape[pos] = newsym;
   // end

   assign count = count_d;

   always @(posedge clk) begin
      case (m_state)
	M_INIT1: begin
	   m_addr <= 18'h3ffff;
	   m_ena <= 0;
	   if (!m_busy) m_state <= M_INIT2; // wait for dram init
	end
	M_INIT2: begin
	   wr_data <= 0;
	   m_write <= 1;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_INIT3;
	end
	M_INIT3: begin
	   m_ena <= 0;
	   if (!m_busy) begin
	      m_addr <= m_addr - 18'd1;
	      m_state <= (m_addr == 18'd0) ? M_R1 : M_INIT2;
	   end
	end
	M_R1: begin
	   // Each tape pos in a different row of DRAM.
	   m_addr <= (pos << 8) + pos;
	   m_write <= 0;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_R2;
	end
	M_R2: begin
	   m_ena <= 0;
	   sym <= rd_data;
	   wr_data <= newsym;
	   latch_dir <= dir;
	   if (!m_busy) m_state <= M_TM1;
	end
	M_TM1: begin
	   if (!rst_n) state <= A;
	   else state <= next;
	   m_state <= M_W1;
	end
	M_W1: begin
	   // Each tape pos in a different row of DRAM.
	   m_addr <= (pos << 8) + pos;
	   m_write <= 1;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_W2;
	end
	M_W2: begin
	   m_ena <= 0;
	   if (!m_busy) m_state <= M_TM2;
	end
	M_TM2: begin
	   if (state != H) begin
	      pos <= (latch_dir == L) ? pos - 18'd1 : pos + 18'd1;
	      count_d <= count_d + 1;
	      m_state <= M_R1;
	   end
	end
      endcase // case (m_state)
   end // always @ (posedge clk)

   // A0  A1  A2  A3  A4  B0  B1  B2  B3  B4   s(M)            σ(M)
   // 1RB 4LA 1LA 1RH 2RB 2LB 3LA 1LB 2RA 0RB  7,021,292,621   37
   // >>> hex(7021292621) = 1_a280_6c4d
   always @(*) begin
      newsym <= 0;
      next <= A;
      dir <= R;
      case (state)
        A: begin
           case (sym)
             0: begin newsym <= 1; dir <= R; next <= B; end
             1: begin newsym <= 4; dir <= L; next <= A; end
             2: begin newsym <= 1; dir <= L; next <= A; end
             3: begin newsym <= 1; dir <= R; next <= H; end
             4: begin newsym <= 2; dir <= R; next <= B; end
             default: begin newsym <= 0; dir <= R; next <= H; end
           endcase // case (sym)
        end // case: A
        B: begin
	   case (sym)
             0: begin newsym <= 2; dir <= L; next <= B; end
             1: begin newsym <= 3; dir <= L; next <= A; end
             2: begin newsym <= 1; dir <= L; next <= B; end
             3: begin newsym <= 2; dir <= R; next <= A; end
             4: begin newsym <= 0; dir <= R; next <= B; end
             default: begin newsym <= 0; dir <= R; next <= H; end
           endcase // case (sym)
        end // case: B
	default: begin newsym <= 0; dir <= R; next <= H; end
      endcase // case (state)
   end // always @ (*)
endmodule // busybeaver_37B


module busybeaver_43KB
  (
   input 	 clk,
   input 	 rst_n,
   output [31:0] count,
   output 	 m_write, // DRAM
   output 	 m_ena,
   output [3:0]  wr_data,
   input [3:0] 	 rd_data,
   input 	 m_busy,
   input 	 m_ack,
   output [17:0] m_addr
   );

   // BB state machine
   localparam
     A = 2'd0,
     B = 2'd1,
     C = 2'd2,
     H = 2'd3,
     L = 1'd0,
     R = 1'd1;
   reg [1:0] 	 state = A, next = A;
   // Turing machine
   reg 		 dir = 0, latch_dir;
   reg [31:0] 	 count_d = 1;
   reg [3:0] 	 sym = 0;
   reg [3:0] 	 newsym = 0;
   reg [17:0] 	 pos = 0;
   // DRAM state machine
   typedef enum { M_INIT1, M_INIT2, M_INIT3, M_R1, M_R2, M_W1, M_W2, M_TM1, M_TM2 } m_t;
   reg [3:0] 	m_state = M_INIT1;

   // reg [2:0] 	tape[128];  // size is power of 2 so pos can wrap
   // assign sym = tape[pos];
   // always @(posedge clk) begin
   //   tape[pos] = newsym;
   // end

   assign count = count_d;

   always @(posedge clk) begin
      case (m_state)
	M_INIT1: begin
	   m_addr <= 18'h3ffff;
	   m_ena <= 0;
	   if (!m_busy) m_state <= M_INIT2; // wait for dram init
	end
	M_INIT2: begin
	   wr_data <= 0;
	   m_write <= 1;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_INIT3;
	end
	M_INIT3: begin
	   m_ena <= 0;
	   if (!m_busy) begin
	      m_addr <= m_addr - 18'd1;
	      m_state <= (m_addr == 18'd0) ? M_R1 : M_INIT2;
	   end
	end
	M_R1: begin
	   m_addr <= pos;
	   m_write <= 0;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_R2;
	end
	M_R2: begin
	   m_ena <= 0;
	   sym <= rd_data;
	   wr_data <= newsym;
	   latch_dir <= dir;
	   if (!m_busy) m_state <= M_TM1;
	end
	M_TM1: begin
	   if (!rst_n) state <= A;
	   else state <= next;
	   m_state <= M_W1;
	end
	M_W1: begin
	   m_addr <= pos;
	   m_write <= 1;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_W2;
	end
	M_W2: begin
	   m_ena <= 0;
	   if (!m_busy) m_state <= M_TM2;
	end
	M_TM2: begin
	   if (state != H) begin
	      pos <= (latch_dir == L) ? pos - 18'd1 : pos + 18'd1;
	      count_d <= count_d + 1;
	      m_state <= M_R1;
	   end
	end
      endcase // case (m_state)
   end // always @ (posedge clk)

   // A0  A1  A2  B0  B1  B2  C1  C2  C3    s(M)            σ(M)
   // 1RB 2LA 1RA 1LB 1LA 2RC 1RH 1LC 2RB   1,808,669,066   43,925
   // >>> hex(1808669066) = 6bce_198a
   always @(*) begin
      newsym <= 0;
      next <= A;
      dir <= R;
      case (state)
        A: begin
           case (sym)
             0: begin newsym <= 1; dir <= R; next <= B; end
             1: begin newsym <= 2; dir <= L; next <= A; end
             2: begin newsym <= 1; dir <= R; next <= A; end
             default: begin newsym <= 0; dir <= R; next <= A; end
           endcase // case (sym)
        end // case: A
        B: begin
	   case (sym)
             0: begin newsym <= 1; dir <= L; next <= B; end
             1: begin newsym <= 1; dir <= L; next <= A; end
             2: begin newsym <= 2; dir <= R; next <= C; end
             default: begin newsym <= 0; dir <= R; next <= A; end
           endcase // case (sym)
        end // case: B
        C: begin
	   case (sym)
             0: begin newsym <= 1; dir <= R; next <= H; end
             1: begin newsym <= 1; dir <= L; next <= C; end
             2: begin newsym <= 2; dir <= R; next <= B; end
             default: begin newsym <= 0; dir <= R; next <= A; end
           endcase // case (sym)
        end // case: B
	default: begin newsym <= 0; dir <= R; next <= H; end
      endcase // case (state)
   end // always @ (*)
endmodule // busybeaver_43KB


module busybeaver_11KB
  (
   input 	 clk,
   input 	 rst_n,
   output [31:0] count,
   output 	 m_write, // DRAM
   output 	 m_ena,
   output [3:0]  wr_data,
   input [3:0] 	 rd_data,
   input 	 m_busy,
   input 	 m_ack,
   output [17:0] m_addr
   );

   // BB state machine
   localparam
     A = 2'd0,
     B = 2'd1,
     H = 2'd2,
     L = 1'd0,
     R = 1'd1;
   reg [1:0] 	 state = A, next = A;
   // Turing machine
   reg 		 dir = 0, latch_dir;
   reg [31:0] 	 count_d = 1;
   reg [3:0] 	 sym = 0;
   reg [3:0] 	 newsym = 0;
   reg [17:0] 	 pos = 0;
   // DRAM state machine
   typedef enum { M_INIT1, M_INIT2, M_INIT3, M_R1, M_R2, M_W1, M_W2, M_TM1, M_TM2 } m_t;
   reg [3:0] 	m_state = M_INIT1;

   // reg [2:0] 	tape[128];  // size is power of 2 so pos can wrap
   // assign sym = tape[pos];
   // always @(posedge clk) begin
   //   tape[pos] = newsym;
   // end

   assign count = count_d;

   always @(posedge clk) begin
      case (m_state)
	M_INIT1: begin
	   m_addr <= 18'h3ffff;
	   m_ena <= 0;
	   if (!m_busy) m_state <= M_INIT2; // wait for dram init
	end
	M_INIT2: begin
	   wr_data <= 0;
	   m_write <= 1;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_INIT3;
	end
	M_INIT3: begin
	   m_ena <= 0;
	   if (!m_busy) begin
	      m_addr <= m_addr - 18'd1;
	      m_state <= (m_addr == 18'd0) ? M_R1 : M_INIT2;
	   end
	end
	M_R1: begin
	   m_addr <= pos;
	   m_write <= 0;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_R2;
	end
	M_R2: begin
	   m_ena <= 0;
	   sym <= rd_data;
	   wr_data <= newsym;
	   latch_dir <= dir;
	   if (!m_busy) m_state <= M_TM1;
	end
	M_TM1: begin
	   if (!rst_n) state <= A;
	   else state <= next;
	   m_state <= M_W1;
	end
	M_W1: begin
	   m_addr <= pos;
	   m_write <= 1;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_W2;
	end
	M_W2: begin
	   m_ena <= 0;
	   if (!m_busy) m_state <= M_TM2;
	end
	M_TM2: begin
	   if (state != H) begin
	      pos <= (latch_dir == L) ? pos - 18'd1 : pos + 18'd1;
	      count_d <= count_d + 1;
	      m_state <= M_R1;
	   end
	end
      endcase // case (m_state)
   end // always @ (posedge clk)

   // A0  A1  A2  A3  A4  B0  B1  B2  B3  B4    s(M)            σ(M)
   // 1RB 3LA 4LA 1RA 1LA 2LA 1RH 4RA 3RB 1RA   148,304,214     11,120
   // >>> hex(148304214) = 0x8d6f156
   always @(*) begin
      newsym <= 0;
      next <= A;
      dir <= R;
      case (state)
        A: begin
           case (sym)
             0: begin newsym <= 1; dir <= R; next <= B; end
             1: begin newsym <= 3; dir <= L; next <= A; end
             2: begin newsym <= 4; dir <= L; next <= A; end
             3: begin newsym <= 1; dir <= R; next <= A; end
             4: begin newsym <= 1; dir <= L; next <= A; end
             default: begin newsym <= 0; dir <= R; next <= A; end
           endcase // case (sym)
        end // case: A
        B: begin
	   case (sym)
             0: begin newsym <= 2; dir <= L; next <= A; end
             1: begin newsym <= 1; dir <= R; next <= H; end
             2: begin newsym <= 4; dir <= R; next <= A; end
             3: begin newsym <= 3; dir <= R; next <= B; end
             4: begin newsym <= 1; dir <= R; next <= A; end
             default: begin newsym <= 0; dir <= R; next <= A; end
           endcase // case (sym)
        end // case: B
	default: begin newsym <= 0; dir <= R; next <= H; end
      endcase // case (state)
   end // always @ (*)
endmodule // busybeaver_11KB


module busybeaver_99KB
  (
   input 	 clk,
   input 	 rst_n,
   output [31:0] count,
   output 	 m_write, // DRAM
   output 	 m_ena,
   output [3:0]  wr_data,
   input [3:0] 	 rd_data,
   input 	 m_busy,
   input 	 m_ack,
   output [17:0] m_addr
   );

   // BB state machine
   localparam
     A = 2'd0,
     B = 2'd1,
     C = 2'd2,
     H = 2'd3,
     L = 1'd0,
     R = 1'd1;
   reg [1:0] 	 state = A, next = A;
   // Turing machine
   reg 		 dir = 0, latch_dir;
   reg [31:0] 	 count_d = 1;
   reg [3:0] 	 sym = 0;
   reg [3:0] 	 newsym = 0;
   reg [17:0] 	 pos = 0;
   // DRAM state machine
   typedef enum { M_INIT1, M_INIT2, M_INIT3, M_R1, M_R2, M_W1, M_W2, M_TM1, M_TM2 } m_t;
   reg [3:0] 	m_state = M_INIT1;

   // reg [2:0] 	tape[128];  // size is power of 2 so pos can wrap
   // assign sym = tape[pos];
   // always @(posedge clk) begin
   //   tape[pos] = newsym;
   // end

   assign count = count_d;

   always @(posedge clk) begin
      case (m_state)
	M_INIT1: begin
	   m_addr <= 18'h3ffff;
	   m_ena <= 0;
	   if (!m_busy) m_state <= M_INIT2; // wait for dram init
	end
	M_INIT2: begin
	   wr_data <= 0;
	   m_write <= 1;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_INIT3;
	end
	M_INIT3: begin
	   m_ena <= 0;
	   if (!m_busy) begin
	      m_addr <= m_addr - 18'd1;
	      m_state <= (m_addr == 18'd0) ? M_R1 : M_INIT2;
	   end
	end
	M_R1: begin
	   m_addr <= pos;
	   m_write <= 0;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_R2;
	end
	M_R2: begin
	   m_ena <= 0;
	   sym <= rd_data;
	   wr_data <= newsym;
	   latch_dir <= dir;
	   if (!m_busy) m_state <= M_TM1;
	end
	M_TM1: begin
	   if (!rst_n) state <= A;
	   else state <= next;
	   m_state <= M_W1;
	end
	M_W1: begin
	   m_addr <= pos;
	   m_write <= 1;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_W2;
	end
	M_W2: begin
	   m_ena <= 0;
	   if (!m_busy) m_state <= M_TM2;
	end
	M_TM2: begin
	   if (state != H) begin
	      pos <= (latch_dir == L) ? pos - 18'd1 : pos + 18'd1;
	      count_d <= count_d + 1;
	      m_state <= M_R1;
	   end
	end
      endcase // case (m_state)
   end // always @ (posedge clk)

   // A0  A1  A2  A3  A4  B0  B1  B2  B3  B4   s(M)            σ(M)
   // 1RB 3LA 1LB 1RA 3RA 2LB 3LA 3RA 4RB 1RH  8,619,024,596   90,604
   // >>> hex(1808669066) = 6bce_198a
   always @(*) begin
      newsym <= 0;
      next <= A;
      dir <= R;
      case (state)
        A: begin
           case (sym)
             0: begin newsym <= 1; dir <= R; next <= B; end
             1: begin newsym <= 3; dir <= L; next <= A; end
             2: begin newsym <= 1; dir <= L; next <= B; end
             3: begin newsym <= 1; dir <= R; next <= A; end
             4: begin newsym <= 3; dir <= R; next <= A; end
             default: begin newsym <= 0; dir <= R; next <= A; end
           endcase // case (sym)
        end // case: A
        B: begin
	   case (sym)
             0: begin newsym <= 2; dir <= L; next <= B; end
             1: begin newsym <= 3; dir <= L; next <= A; end
             2: begin newsym <= 3; dir <= R; next <= A; end
             3: begin newsym <= 4; dir <= R; next <= B; end
             4: begin newsym <= 1; dir <= R; next <= H; end
             default: begin newsym <= 0; dir <= R; next <= A; end
           endcase // case (sym)
        end // case: B
	default: begin newsym <= 0; dir <= R; next <= H; end
      endcase // case (state)
   end // always @ (*)
endmodule // busybeaver_99KB


module busy
  (
   input 	clk, // 50 MHz system clock
   input 	rst_n,
   output [8:0] ram_addr, // 256k x 4 DRAM
   inout [3:0] 	ram_dq,
   output 	ram_we_,
   output 	ram_oe_,
   output 	ram_ras_,
   output 	ram_cas_,
   output 	max_clk, // max7219 8-digit SPI
   output 	max_din,
   output 	max_ce_
   );

   reg [31:0] 	display_value, bb_count;
   assign display_value = bb_count;
   max7219 max0(.clk(clk), .rst_n(rst_n),
		.max_din(max_din), .ce_(max_ce_), .max_clk(max_clk),
		.display_value(display_value)
		);

   reg 		m_write, m_ena, m_busy, m_ack;
   reg [3:0] 	rd_data;
   reg [3:0] 	wr_data;
   reg [17:0] 	m_addr;
   hm515264 ram(.clk(clk), .addr(m_addr), .rd_data(rd_data),
	       .busy(m_busy), .ack(m_ack), .write(m_write), .ena(m_ena),
	       .ram_addr(ram_addr), .ram_dq(ram_dq),
	       .ram_we_(ram_we_), .ram_oe_(ram_oe_),
	       .ram_ras_(ram_ras_), .ram_cas_(ram_cas_)
	       );
   assign ram_dq = (!ram_we_ ? wr_data : 4'hz);

   // Busybeaver module
   busybeaver_99KB bb(.clk(clk), .rst_n(rst_n), .count(bb_count),
		     .m_write(m_write), .m_ena(m_ena), .m_busy(m_busy), .m_ack(m_ack),
		     .wr_data(wr_data), .rd_data(rd_data), .m_addr(m_addr)
		     );
endmodule // busy
