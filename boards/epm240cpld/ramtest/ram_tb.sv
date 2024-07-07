`timescale 1ns/1ns

module dram256k(input clk,
                input            rst_n,
                input [1:0]      cmd,
                output           busy,
                input [11:0]     local_addr,
                output reg [3:0] local_din,
                input [3:0]      local_dout,
                output reg [5:0]     mem_addr,
                input [3:0]      mem_din,
                output reg [3:0]     mem_dout,
                output reg          mem_oe_,
                output  reg         mem_we_,
                output  reg         mem_ras_,
                output reg          mem_cas_
                );
   typedef enum              { NOP, CMD_READ, CMD_WRITE } cmd_t;
   typedef enum              { IDLE, READ, R2, R3, R4, R5, R6, WRITE, W2, W3, W4, W5 } state_t;
             
   reg [3:0]                 state=IDLE, next=IDLE;
   reg [5:0]                 addr_q;
   reg [2:0]                 count;
   
   assign busy = (state != IDLE);
   
   always @(posedge clk) begin
      if (!rst_n) state <= IDLE;
      else state <= next;
      if (state == R5)       // latch read data
        local_din <= mem_din;
   end

   always @(*) begin
      mem_ras_ <= 1;
      mem_cas_ <= 1;
      mem_oe_ <= 1;
      mem_we_ <= 1;
      mem_addr <= 0;
      mem_dout <= 0;
      count <= 0;
      // next <= IDLE;
      
      case (state)
        IDLE: begin
           if (cmd == CMD_READ) next <= READ;
           else if (cmd == CMD_WRITE) next <= WRITE;
           else next <= IDLE;
        end
        READ: begin
           mem_addr <= local_addr[11:6];
           mem_ras_ <= 0;
           next <= R2;
        end
        R2: begin
           mem_addr <= local_addr[5:0];
           mem_ras_ <= 0;
           mem_cas_ <= 0;
           next <= R3;
        end
        R3: begin
           mem_ras_ <= 0;
           mem_cas_ <= 0;
           next <= R4;
        end
        R4: begin
           mem_ras_ <= 0;
           mem_cas_ <= 0;
           mem_oe_ <= 0;
           next <= R5;
        end
        R5: next <= R6;        // deassert OE, CAS, RAS and wait for precharge
        R6: next <= IDLE;
        
        WRITE: begin
           mem_addr <= local_addr[11:6];
           mem_ras_ <= 0;
           count <= 2;
           next <= W2;
        end
        W2: begin
           mem_addr <= local_addr[5:0];
           mem_dout <= local_dout;
           mem_we_ <= 0;
           mem_ras_ <= 0;
           mem_cas_ <= 0;
           next <= W3;
        end
        W3: begin
           mem_addr <= local_addr[5:0];
           mem_dout <= local_dout;
           mem_we_ <= 0;
           mem_ras_ <= 0;
           mem_cas_ <= 0;
           next <= W4;
        end
        W4: next <= W5;  // deassert WE, CAS, RAS and wait for precharge
        W5: next <= IDLE;
           
      endcase // case (state)
      
   end
endmodule // dram256k

module ram_tb(output clk_q);
   reg clk=0;
   assign clk_q = clk;
   reg [31:0] count=7;
   
   reg rst_n=1, mem_ras_, mem_cas_, mem_we_, mem_oe_;
   reg [3:0] mem_dq, mem_din, mem_dout;
   reg [5:0] mem_addr;
   
   wire        local_busy;
   reg [1:0]  local_cmd = 0;
   reg [11:0]  local_addr;
   reg [3:0]   local_din, local_dout;
   assign mem_dq = (mem_we_ == 0) ? mem_dout : 4'bz;
   dram256k ram(.clk(clk), .rst_n(rst_n), .mem_addr(mem_addr), .mem_din(mem_din), .mem_dout(mem_dout),
                .mem_oe_(mem_oe_), .mem_we_(mem_we_), .mem_ras_(mem_ras_), .mem_cas_(mem_cas_),
                .busy(local_busy), .cmd(local_cmd), .local_addr(local_addr), .local_din(local_din),
                .local_dout(local_dout));

   // Run the clock
   always #1 clk++;

   integer     next_addr = 12'h123;
   integer     ras_low=0, cas_low=0, ras_high=0, cas_high=0, t_oe_low;
   integer     t_rcd, t_cas, t_csh, t_rsh, t_ras, t_rc, t_rp, t_cac, t_aa;
`ifdef CONTINUOUS_READS   
   initial begin
      while (1) begin
         if (!local_busy) begin
            local_cmd = 1;
            local_addr = next_addr++;
            #1;
         end
         else #1;
      end
      // #(t_oe_low + 2) mem_din = 4;
   end
`else // !`ifdef CONTINUOUS_READS
   initial begin
      #1 local_cmd = 2;
      local_dout = 5;
      local_addr = next_addr++;
      // while (!local_busy) #1;
      // while (local_busy) #1;
   end
   
`endif // !`ifdef CONTINUOUS_READS
   
   
   integer cycle_ns = 10;  // ns per sim step (one "clk" cycle is two steps)
   localparam
     T_CAS_MIN = 20,
     T_RAS_MIN = 60,
     T_RP_MIN = 50,
     T_RC_MIN = 120,
     T_RAH_MIN = 10,
     T_CAH_MIN = 15,
     T_RCD_MIN = 20,
     T_RCD_MAX = 40,
     T_RAD_MIN = 15,
     T_RAD_MAX = 30,
     T_RSH_MIN = 20,
     T_CSH_MIN = 60,
     T_CRP_MIN = 10,
     T_ODD_MIN = 20,
     T_RAC_MAX = 60,
     T_CAC_MAX = 20,
     T_AA_MAX = 30,
     T_OAC_MAX = 20,
     T_RRH_MIN = 10,
     T_RAL_MIN = 30,
     T_OFF1_MAX = 20,
     T_OFF2_MAX = 20,
     T_CDD_MIN = 20,
     T_WCH_MIN = 15,
     T_WP_MIN = 10,
     T_RWL_MIN = 20,
     T_CWL_MIN = 20,
     T_DH_MIN = 15,
     T_RWC_MIN = 170,
     T_RWD_MIN = 85,
     T_CWD_MIN = 45,
     T_AWD_MIN = 55,
     T_OWH_MIN = 20,
     T_CSR_MIN = 10,
     T_CHR_MIN = 15,
     T_RPC_MIN = 10,
     T_PC_MIN = 45,
     T_CP_MIN = 10,
     T_RHCP_MIN = 40,
     T_PCM_MIN = 95;
   
   always @(negedge mem_ras_) begin
      t_rc = ($realtime - ras_low) * cycle_ns;
      assert(ras_low > 0 && t_rc >= T_RC_MIN) else $display("expect t_rc >= %g, got %g", T_RC_MIN, t_rc);
      t_rp = ($realtime - ras_high) * cycle_ns;
      assert(ras_high > 0 && t_rp >= T_RP_MIN) else $display("expect t_rp >= %g, got %g", T_RP_MIN, t_rp);
      ras_low = $realtime;
   end
   always @(negedge mem_cas_) begin
      cas_low = $realtime;
      t_rcd = (cas_low - ras_low) * cycle_ns;
      assert(t_rcd >= T_RCD_MIN) else $display("expect t_rcd >= %g, got %g", T_RCD_MIN, t_rcd);
      assert(t_rcd <= T_RCD_MAX) else $display("expect t_rcd <= %g, got %g", T_RCD_MAX, t_rcd);
   end
   always @(posedge mem_cas_) begin
      cas_high = $realtime;
      t_cas = (cas_high - cas_low) * cycle_ns;
      t_csh = (cas_high - ras_low) * cycle_ns;
      assert(t_csh >= T_CSH_MIN) else $display("expect t_csh >= %g, got %g", T_CSH_MIN, t_csh);
      assert(t_cas >= T_CAS_MIN) else $display("expect t_cas >= %g, got %g", T_CAS_MIN, t_cas);
   end
   always @(posedge mem_ras_) begin
      ras_high = $realtime;
      t_rsh = (ras_high - cas_low) * cycle_ns;
      t_ras = (ras_high - ras_low) * cycle_ns;
      assert(t_rsh >= T_RSH_MIN) else $display("expect t_rsh >= %g, got %g, ras_high=%g cas_low=%g ras_low=%g", T_RSH_MIN, t_rsh, ras_high, cas_low, ras_low);
      assert(t_ras >= T_RAS_MIN) else $display("expect t_ras >= %g, got %g, ras_high=%g cas_low=%g ras_low=%g", T_RAS_MIN, t_ras, ras_high, cas_low, ras_low);
   end
   always @(mem_din) begin
      t_cac = ($realtime - cas_low) * cycle_ns;
      t_aa = ($realtime - cas_low) * cycle_ns;
      assert(t_cac >= T_CAC_MAX) else $display("expect t_cac >= %g, got %g", T_CAC_MAX, t_cac);
      assert(t_aa >= T_AA_MAX) else $display("expect t_aa >= %g, got %g", T_AA_MAX, t_aa);
   end
   always @(negedge mem_oe_) begin
      t_oe_low = $realtime;
      mem_din = count;
   end
   always @(posedge clk) begin
      count <= count + 1;
      
   end
endmodule // ram_tb
