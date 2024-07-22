/*
  Busy beaver with tape in DRAM
 */
module useless
  (
   input 	 clk,
   input 	 rst_n,
   output [11:0] ram_addr,
   inout [7:0] 	 ram_dq,
   output 	 ram_we_,
   output 	 ram_ras_,
   output 	 ram_cas_,
   output 	 dq_dir,
   output 	 max_clk,
   output 	 max_din,
   output 	 max_ce_
   );

   // DRAM device
   reg 		m_write = 0, m_ena = 0;
   reg [7:0] 	wr_data = 0;
   reg [7:0] 	rd_data = 0;
   reg 		m_busy;
   reg 		m_ack = 0;
   reg [23:0] 	m_addr = 0;
   simm_16mb ram(.clk(clk), .addr(m_addr), .rd_data(rd_data),
		 .busy(m_busy), .ack(m_ack), .write(m_write), .ena(m_ena),
		 .ram_addr(ram_addr), .ram_dq(ram_dq),
		 .ram_we_(ram_we_), .ram_ras_(ram_ras_), .ram_cas_(ram_cas_)
		 );
   assign ram_dq = (!ram_we_ ? wr_data : 4'hz);
   assign dq_dir = !ram_we_;

   // 8-digit SPI display
   reg [31:0] 	max_display;
   max7219 max(.clk(clk), .rst_n(rst_n), .max_din(max_din), .ce_(max_ce_),
	       .max_clk(max_clk), .display_value(max_display[31:0]));

   // Busybeaver module
   reg [31:0] 	bb_count;
   busybeaver bb(.clk(clk), .rst_n(rst_n), .count(bb_count),
		 .m_write(m_write), .m_ena(m_ena), .m_busy(m_busy), .m_ack(m_ack),
		 .wr_data(wr_data), .rd_data(rd_data), .m_addr(m_addr)
		 );
   assign max_display = bb_count;

endmodule // useless


module busybeaver
  (
   input 	 clk,
   input 	 rst_n,
   output [31:0] count,
   output 	 m_write, // DRAM
   output 	 m_ena,
   output [7:0]  wr_data,
   input [7:0] 	 rd_data,
   input 	 m_busy,
   input 	 m_ack,
   output [23:0] m_addr
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
   reg [31:0] 	 count_d;
   reg [7:0] 	 sym = 0;
   reg [7:0] 	 newsym = 0;
   // DRAM state machine
   typedef enum  { M_INIT1, M_INIT2, M_INIT3, M_INIT4,
		   M_R1, M_R2, M_W1, M_W2, M_TM1, M_TM2 } m_t;
   reg [3:0] 	m_state = M_INIT1;
   reg 		countdn = 1;
   
   // reg [2:0] 	tape[128];  // size is power of 2 so pos can wrap
   // assign sym = tape[pos];
   // always @(posedge clk) begin
   //   tape[pos] = newsym;
   // end
   
   assign count = count_d;
   
   always @(posedge clk) begin
      case (m_state)
	M_INIT1: begin
	   m_addr <= 0;
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
	      m_addr <= m_addr - 24'd1;
	      m_state <= (m_addr == 24'd1) ? M_INIT4 : M_INIT2;
	   end
	end
	M_INIT4: begin
	   countdn = !countdn;
	   state <= A;
	   m_state <= M_R1;
	end
	M_R1: begin
	   m_write <= 0;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_R2;
	end
	M_R2: begin
	   m_ena <= 0;
	   if (!m_busy) begin
	      sym <= rd_data;
	      m_state <= M_TM1;
	   end
	end
	M_TM1: begin
	   latch_dir <= dir;
	   wr_data <= newsym;
	   state <= (!rst_n) ? A : next;
	   count_d <= countdn ? count_d - 1 : count_d + 1;
	   m_state <= M_W1;
	end
	M_W1: begin
	   m_write <= 1;
	   m_ena <= 1;
	   if (m_ack) m_state <= M_W2;
	end
	M_W2: begin
	   m_ena <= 0;
	   if (!m_busy) m_state <= M_TM2;
	end
	M_TM2: begin
	   m_addr <= (latch_dir == L) ? m_addr - 24'd1 : m_addr + 24'd1;
	   m_state <= (state != H) ? M_R1 : M_TM2;  // stop when halt
	   // m_state <= (state != H) ? M_R1 : M_INIT1;
	end
      endcase // case (m_state)
   end // always @ (posedge clk)

`define BIG 1
`ifdef SMALL   
   // A0  A1  A2  A3  A4  B0  B1  B2  B3  B4    s(M)            σ(M)
   // 1RB 3RB 2LA 0RB 1RH 2LA 4RB 3LB 2RB 3RB   15,754,273      4,099
   // >>> hex(15754273) = 0xf06421
   always @(*) begin
      newsym <= 0;
      next <= A;
      dir <= R;
      case (state)
        A: begin
           case (sym)
             0: begin newsym <= 1; dir <= R; next <= B; end
             1: begin newsym <= 3; dir <= R; next <= B; end
             2: begin newsym <= 2; dir <= L; next <= A; end
             3: begin newsym <= 0; dir <= R; next <= B; end
             4: begin newsym <= 1; dir <= R; next <= H; end
             default: begin newsym <= 0; dir <= R; next <= A; end
           endcase // case (sym)
        end // case: A
        B: begin
	   case (sym)
             0: begin newsym <= 2; dir <= L; next <= A; end
             1: begin newsym <= 4; dir <= R; next <= B; end
             2: begin newsym <= 3; dir <= L; next <= B; end
             3: begin newsym <= 2; dir <= R; next <= B; end
             4: begin newsym <= 3; dir <= R; next <= B; end
             default: begin newsym <= 0; dir <= R; next <= A; end
           endcase // case (sym)
        end // case: B
	default: begin newsym <= 0; dir <= R; next <= H; end
      endcase // case (state)
   end // always @ (*)

`elsif MED // !`ifdef SMALL

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

`elsif BIG

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
   
`else
error   
`endif
endmodule // busybeaver

