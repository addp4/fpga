`timescale 1ns / 1ns

// `define LOG(msg) $display msg
`define LOG(msg)

typedef union packed {
   bit [31:0] raw;

   struct packed {
      bit[6:0] _7;
      bit [4:0] rs2;
      bit [4:0] rs1;
      bit [2:0] funct3;
      bit [4:0] rd;
      bit [6:0] opcode;
   } any_type;

   struct packed {
      bit[6:0] funct7;
      bit [4:0] rs2;
      bit [4:0] rs1;
      bit [2:0] funct3;
      bit [4:0] rd;
      bit [6:0] opcode;
   } r_type;

   struct packed {
      bit[11:0] imm;
      bit [4:0] rs1;
      bit [2:0] funct3;
      bit [4:0] rd;
      bit [6:0] opcode;
   } i_type;

   struct packed {
      bit [6:0] imm7;
      bit [4:0] rs2;
      bit [4:0] rs1;
      bit [2:0] funct3;
      bit [4:0] imm5;
      bit [6:0] opcode;
   } s_type;

   struct packed {
      bit [6:0] imm7;
      bit [4:0] rs2;
      bit [4:0] rs1;
      bit [2:0] funct3;
      bit [4:0] imm5;
      bit [6:0] opcode;
   } b_type;

   struct packed {
      bit [19:0] imm20;
      bit [4:0] rd;
      bit [6:0] opcode;
   } u_type;

   struct packed {
      bit [19:0] imm20;
      bit [4:0] rd;
      bit [6:0] opcode;
   } j_type;
} inst_t;

typedef enum [2:0]
  {
   BAD_TYPE, R_TYPE, I_TYPE, S_TYPE, B_TYPE, U_TYPE, J_TYPE
   } format_t;

typedef enum [5:0]
  { BAD_INST,
    ADD_INST,
    SUB_INST,
    XOR_INST,
    OR_INST,
    AND_INST,
    SLL_INST,
    SRL_INST,
    SRA_INST,
    SLT_INST,
    SLTU_INST,
    ADDI_INST,
    XORI_INST,
    ORI_INST,
    ANDI_INST,
    SLLI_INST,
    SRLI_INST,
    SRAI_INST,
    SLTI_INST,
    SLTIU_INST,
    LB_INST,
    LH_INST,
    LW_INST,
    LBU_INST,
    LHU_INST,
    SB_INST,
    SH_INST,
    SW_INST,
    BEQ_INST,
    BNE_INST,
    BLT_INST,
    BGE_INST,
    BLTU_INST,
    BGEU_INST,
    JAL_INST,
    JALR_INST,
    LUI_INST,
    AUIPC_INST,
    ECALL_INST,
    EBREAK_INST
} asm_t;

typedef struct {       // store to load forwarding
   logic valid;
   logic [4:0] rd;     // register num
   logic [31:0] rval;  // register value
} stlf_t;

typedef struct {
   logic [31:0] pc;
} if_id_t;

typedef struct {
   inst_t inst;
   format_t fmt;
   asm_t asm_op;
   logic [31:0] pc;
   logic signed [31:0] imm;
   logic               invalid;
} id_ex_t;

typedef struct {
   logic rd_valid;
   logic pmu_is_branch;
   logic pmu_is_call;
   logic pmu_is_load;
   logic pmu_is_store;
   logic pmu_is_alu;
   logic new_pc_valid;
   logic invalid;
   logic [4:0] rd;
   logic [31:0] rval;
   logic        rd_mem;
   logic [31:0] new_pc;
   logic [31:0] pc;
   logic [2:0]  wr_mem_len;
   logic [31:0] wr_mem_addr;
   logic [31:0] wr_mem_data;
} ex_wb_t;

typedef struct {
   logic new_pc_valid;
   logic [31:0] new_pc;
} wb_if_t;

typedef struct {
   logic invalid;
} wb_id_t;

typedef struct {
   logic invalid;
   stlf_t stlf;
} wb_ex_t;

typedef struct {
   logic [31:0] [31:0] gpr;
} regfile_t;

typedef struct {
   logic [31:0] cycles;
   logic [31:0] inst_retired;
   logic [31:0] reg_forwards;
   logic [31:0] br_retired;
   logic [31:0] alu_retired;
   logic [31:0] call_retired;
   logic [31:0] load_retired;
   logic [31:0] store_retired;
   logic [31:0] br_taken;
} pmu_t;


module ram_2r1w #(
) (
   input logic         clk,
   // Write Port
   input logic [3:0]   we,
   input logic [31:0]  waddr,
   input logic [31:0]  wdata,

    // Read Port A
   input logic [31:0]  raddr_a,
   output logic [31:0] rdata_a,

    // Read Port B
   input logic [31:0]  raddr_b,
   output logic [31:0] rdata_b
);

   logic [7:0] mem0[0:65535];
   logic [7:0] mem1[0:65535];
   logic [7:0] mem2[0:65535];
   logic [7:0] mem3[0:65535];

   initial begin
      $readmemh("mem0.hex", mem0);
      $readmemh("mem1.hex", mem1);
      $readmemh("mem2.hex", mem2);
      $readmemh("mem3.hex", mem3);
   end

   // Write the enabled byte lanes

   always_ff @(posedge clk) begin
      if (we[0]) begin
         mem0[waddr] <= wdata[7:0];
      end
   end
   always_ff @(posedge clk) begin
      if (we[1]) begin
         mem1[waddr] <= wdata[15:8];
      end
   end
   always_ff @(posedge clk) begin
      if (we[2]) begin
         mem2[waddr] <= wdata[23:16];
      end
   end
   always_ff @(posedge clk) begin
      if (we[3]) begin
         mem3[waddr] <= wdata[31:24];
      end
   end

   // Option 1: Synchronous Reads (1-cycle latency, maps cleanly to FPGA BRAM/M20K)
   always_ff @(posedge clk) begin
      `LOG(("RAM] raddr_a=0x%0x (byte 0x%0x) raddr_b=0x%0x (byte 0x%0x) we=0x%0x waddr=0x%0x (byte 0x%0x)",
            raddr_a, raddr_a << 2, raddr_b, raddr_b << 2, we, waddr, waddr << 2));
      rdata_a[7:0] <= mem0[raddr_a];
      rdata_b[7:0] <= mem0[raddr_b];
   end
   always_ff @(posedge clk) begin
      rdata_a[15:8] <= mem1[raddr_a];
      rdata_b[15:8] <= mem1[raddr_b];
   end
   always_ff @(posedge clk) begin
      rdata_a[23:16] <= mem2[raddr_a];
      rdata_b[23:16] <= mem2[raddr_b];
   end
   always_ff @(posedge clk) begin
      rdata_a[31:24] <= mem3[raddr_a];
      rdata_b[31:24] <= mem3[raddr_b];
   end

endmodule // ram_2r1w


module byte_read #(
) (
   // Physical interface towards RAM
   output logic [31:0] raddr,
   input logic [31:0]  rdata,

   // Logical interface towards CPU
   input logic [31:0]  byte_addr,
   input logic [2:0]   byte_len,
   output logic [31:0] word_out
);
   // Read the word that contains the target byte(s) and right justify
   // The data appears one cycle later
   logic [31:0] word_addr = byte_addr >> 2;
   logic [31:0] word_offset = byte_addr & 3;
   logic [31:0] word_shift = word_offset << 3;
   assign raddr = word_addr;
   always @(*) begin
      case (byte_len)
        1: word_out = (rdata >> word_shift) & 32'h000000ff;
        2: word_out = (rdata >> word_shift) & 32'h0000ffff;
        default: word_out = rdata;
      endcase // case (byte_len)
   end
endmodule // byte_read


module byte_write #(
) (
   // Physical interface towards RAM
   output logic [3:0]  we,
   output logic [31:0] waddr,
   output logic [31:0] wdata,

   // Logical interface towards CPU
   input logic [31:0]  byte_addr,
   input logic [2:0]   byte_len,
   output logic [31:0] byte_data
);
   // Shift the bytes to be written and enable the we bits.
   logic [31:0] word_addr = byte_addr >> 2;
   logic [31:0] word_offset = byte_addr & 3;
   logic [31:0] word_shift = word_offset << 3;

   always @(*) begin
      we = 0;
      case (byte_len)
        1: we = 4'b0001 << word_offset;
        2: we = 4'b0011 << word_offset;
        4: we = 4'b1111;
      endcase // case (byte_len)
   end
   assign wdata = byte_data << word_shift;
   // clear waddr if not writing. this is optional but looks better in traces.
   assign waddr = we == 0 ? 0 : word_addr;
endmodule // byte_write


module IF1(input         clk,
           input         wb_if_t wb_if,
           output [31:0] raddr,
           output        if_id_t if_id
           );
   logic [31:0] pc;
   wire [31:0] this_pc;
   assign this_pc = wb_if.new_pc_valid ? wb_if.new_pc : pc;
   assign raddr = this_pc >> 2;
   always @(posedge clk) begin
      if (wb_if.new_pc_valid)
        `LOG(("IF1] resteer from pc=0x%0x to this_pc=0x%0x", pc, this_pc));
      `LOG(("IF1] pc=0x%0x this_pc=0x%0x raddr=0x%0x", pc, this_pc, raddr));
      if_id.pc <= this_pc;
      pc <= this_pc + 4;
   end
endmodule


module IF2(input [31:0] rdata,
           input        if_id_t if_id,
           input        wb_id_t wb_id,
           output       id_ex_t id_ex);
   assign id_ex.inst = rdata;
   assign id_ex.pc = if_id.pc;

   always @(*) begin
      // case (id_ex.inst.r_type.opcode)
      id_ex.asm_op = BAD_INST;
      id_ex.fmt = BAD_TYPE;
      id_ex.invalid = wb_id.invalid;

      case (rdata[6:0])
        7'b0110011: begin
           id_ex.fmt = R_TYPE;
           if (id_ex.inst.r_type.funct3 == 0 && id_ex.inst.r_type.funct7 == 0)
             id_ex.asm_op = ADD_INST;
           else if (id_ex.inst.r_type.funct3 == 0 && id_ex.inst.r_type.funct7 == 'h20)
             id_ex.asm_op = SUB_INST;
           else if (id_ex.inst.r_type.funct3 == 4 && id_ex.inst.r_type.funct7 == 0)
             id_ex.asm_op = XOR_INST;
           else if (id_ex.inst.r_type.funct3 == 6 && id_ex.inst.r_type.funct7 == 0)
             id_ex.asm_op = OR_INST;
           else if (id_ex.inst.r_type.funct3 == 7 && id_ex.inst.r_type.funct7 == 0)
             id_ex.asm_op = AND_INST;
           else if (id_ex.inst.r_type.funct3 == 1 && id_ex.inst.r_type.funct7 == 0)
             id_ex.asm_op = SLL_INST;
           else if (id_ex.inst.r_type.funct3 == 5 && id_ex.inst.r_type.funct7 == 0)
             id_ex.asm_op = SRL_INST;
           else if (id_ex.inst.r_type.funct3 == 5 && id_ex.inst.r_type.funct7 == 'h20)
             id_ex.asm_op = SRA_INST;
           else if (id_ex.inst.r_type.funct3 == 2 && id_ex.inst.r_type.funct7 == 0)
             id_ex.asm_op = SLT_INST;
           else if (id_ex.inst.r_type.funct3 == 3 && id_ex.inst.r_type.funct7 == 0)
             id_ex.asm_op = SLTU_INST;
        end
        7'b0010011: begin
           id_ex.fmt = I_TYPE;
           case (id_ex.inst.i_type.funct3)
             0: id_ex.asm_op = ADDI_INST;
             4: id_ex.asm_op = XORI_INST;
             6: id_ex.asm_op = ORI_INST;
             7: id_ex.asm_op = ANDI_INST;
             1: begin
                if (id_ex.inst.i_type.imm[11:5] == 0)
                  id_ex.asm_op = SLLI_INST;
             end
             5: begin
                if (id_ex.inst.i_type.imm[11:5] == 0)
                  id_ex.asm_op = SRLI_INST;
                else if (id_ex.inst.i_type.imm[11:5] == 'h20)
                  id_ex.asm_op = SRAI_INST;
             end
             2: id_ex.asm_op = SLTI_INST;
             3: id_ex.asm_op = SLTIU_INST;
           endcase
        end
        7'b0000011: begin
           id_ex.fmt = I_TYPE;
           case (id_ex.inst.i_type.funct3)
             0: id_ex.asm_op = LB_INST;
             1: id_ex.asm_op = LH_INST;
             2: id_ex.asm_op = LW_INST;
             4: id_ex.asm_op = LBU_INST;
             5: id_ex.asm_op = LHU_INST;
           endcase
        end
        7'b0100011: begin
           id_ex.fmt = S_TYPE;
           case (id_ex.inst.s_type.funct3)
             0: id_ex.asm_op = SB_INST;
             1: id_ex.asm_op = SH_INST;
             2: id_ex.asm_op = SW_INST;
           endcase // case (id_ex.inst.s_type.funct3)
        end
        7'b1100011: begin
           id_ex.fmt = B_TYPE;
           case (id_ex.inst.b_type.funct3)
             0: id_ex.asm_op = BEQ_INST;
             1: id_ex.asm_op = BNE_INST;
             4: id_ex.asm_op = BLT_INST;
             5: id_ex.asm_op = BGE_INST;
             6: id_ex.asm_op = BLTU_INST;
             7: id_ex.asm_op = BGEU_INST;
           endcase // case (id_ex.inst.b_type.funct3)
        end // case: 7'b1100011
        7'b1101111: begin
           id_ex.fmt = J_TYPE;
           id_ex.asm_op = JAL_INST;
        end
        7'b1100111: begin
           id_ex.fmt = I_TYPE;
           if (id_ex.inst.i_type.funct3 == 0)
             id_ex.asm_op = JALR_INST;
        end
        7'b0110111: begin
           id_ex.fmt = U_TYPE;
           id_ex.asm_op = LUI_INST;
        end
        7'b0010111: begin
           id_ex.fmt = U_TYPE;
           id_ex.asm_op = AUIPC_INST;
        end
        7'b1110011: begin
           id_ex.fmt = I_TYPE;
           if (id_ex.inst.i_type.imm == 0)
             id_ex.asm_op = ECALL_INST;
           else if (id_ex.inst.i_type.imm == 1)
             id_ex.asm_op = EBREAK_INST;
        end

        default: id_ex.fmt = BAD_TYPE;
      endcase // case (inst.r_type.opcode)

      case (id_ex.fmt)
        R_TYPE: id_ex.imm = 0;
        I_TYPE: id_ex.imm = { {20{id_ex.inst.i_type.imm[11]}}, id_ex.inst.i_type.imm };
        S_TYPE: id_ex.imm = { {20{id_ex.inst.s_type.imm7[6]}},
                              id_ex.inst.s_type.imm7, id_ex.inst.s_type.imm5 };
        B_TYPE: id_ex.imm = { {20{id_ex.inst.raw[31]}},
                              id_ex.inst.raw[31], // bit 12
                              id_ex.inst.raw[7], // bit 11
                              id_ex.inst.raw[30:25], // bit 10:5
                              id_ex.inst.raw[11:8] // bit 4:1
                              };
        U_TYPE: id_ex.imm = { {12{id_ex.inst.u_type.imm20[19]}}, id_ex.inst.u_type.imm20 };
        J_TYPE: id_ex.imm = { {12{id_ex.inst.raw[31]}},
                              id_ex.inst.raw[31], // bit 20
                              id_ex.inst.raw[19:12], // bits 19:12
                              id_ex.inst.raw[20], // bit 11
                              id_ex.inst.raw[30:21]  // bits 10:1
                              };
        default: `LOG(("bad type, pc=0x%0x opcode=0x%0x", if_id.pc, rdata[6:0]));
      endcase // case (id_ex.fmt)

      /* verilator lint_off CASEINCOMPLETE */
      case (id_ex.fmt)
        R_TYPE: begin
           `LOG(("IF2] pc=0x%0x inst=%0x fmt=%0d asm=%0d rs1=%0d rs2=%0d rd=%0d",
                    id_ex.pc, id_ex.inst, id_ex.fmt, id_ex.asm_op,
                    id_ex.inst.r_type.rs1, id_ex.inst.r_type.rs2, id_ex.inst.r_type.rd));
        end
        I_TYPE: begin
           `LOG(("IF2] pc=0x%0x inst=%0x fmt=%0d asm=%0d rs1=%0d imm=%0d rd=%0d",
                    id_ex.pc, id_ex.inst, id_ex.fmt, id_ex.asm_op,
                    id_ex.inst.i_type.rs1, id_ex.imm, id_ex.inst.i_type.rd));
        end
        S_TYPE: begin
           `LOG(("IF2] pc=0x%0x inst=%0x fmt=%0d asm=%0d rs1=%0d rs2=%0d imm=%0d",
                    id_ex.pc, id_ex.inst, id_ex.fmt, id_ex.asm_op,
                    id_ex.inst.s_type.rs1, id_ex.inst.s_type.rs2, id_ex.imm));
        end
        B_TYPE: begin
           `LOG(("IF2] pc=0x%0x inst=%0x fmt=%0d asm=%0d rs1=%0d rs2=%0d imm=%0d",
                    id_ex.pc, id_ex.inst, id_ex.fmt, id_ex.asm_op,
                    id_ex.inst.s_type.rs1, id_ex.inst.s_type.rs2, id_ex.imm));
        end
        U_TYPE: begin
           `LOG(("IF2] pc=0x%0x inst=%0x fmt=%0d asm=%0d imm=%0d rd=%0d",
                    id_ex.pc, id_ex.inst, id_ex.fmt, id_ex.asm_op,
                    id_ex.imm, id_ex.inst.u_type.rd));
        end
        J_TYPE: begin
           `LOG(("IF2] pc=0x%0x inst=%0x fmt=%0d asm=%0d imm=%0d rd=%0d",
                    id_ex.pc, id_ex.inst, id_ex.fmt, id_ex.asm_op,
                    id_ex.imm, id_ex.inst.j_type.rd));
        end
        default: begin
           `LOG(("IF2] decode error! pc=0x%0x inst=%0x fmt=%0d asm=%0d",
                    id_ex.pc, id_ex.inst, id_ex.fmt, id_ex.asm_op));

        end
      endcase

   end
endmodule // Decode

module EX(input         clk,
          input         id_ex_t id_ex,
          input         regfile_t regs,
          input         fwd_valid,
          input [4:0]   fwd_reg,
          input [31:0]  fwd_data,
          output        pmu_t pmu,
          output        ex_wb_t ex_wb,
          output        wb_ex_t wb_ex,
          output [31:0] raddr,
          output [2:0]  rlen
);
   inst_t i;
   assign i = id_ex.inst;
   // calculate rs1 and rs2 register values with stlf bypass. we read the ex_wb we
   // wrote in the previous cycle. it works if reg writeback is 1 stage away,
   // else it should be sent back in each xx_ex and read in increasing distance order
   wire [31:0] gpr_rs1;
   wire        gpr_rs1_forward;
   // assign gpr_rs1_forward = ex_wb.rd_valid && ex_wb.rd == i.any_type.rs1 && ex_wb.rd != 0;
   // assign gpr_rs1 = gpr_rs1_forward ? ex_wb.rval : regs.gpr[i.any_type.rs1];
   assign gpr_rs1_forward = fwd_valid && fwd_reg == i.any_type.rs1;
   assign gpr_rs1 = gpr_rs1_forward ? fwd_data : regs.gpr[i.any_type.rs1];
   logic [31:0] gpr_rs2;
   wire         gpr_rs2_forward;
   // assign gpr_rs2_forward = ex_wb.rd_valid && ex_wb.rd == i.any_type.rs2 && ex_wb.rd != 0;
   // assign gpr_rs2 = gpr_rs2_forward ? ex_wb.rval : regs.gpr[i.any_type.rs2];
   assign gpr_rs2_forward = fwd_valid && fwd_reg == i.any_type.rs2;
   assign gpr_rs2 = gpr_rs2_forward ? fwd_data : regs.gpr[i.any_type.rs2];
   // address generation for loads
   wire [31:0] rs1_plus_imm;
   assign rs1_plus_imm = gpr_rs1 + id_ex.imm;

   always @(*) begin
      raddr = 0;
      rlen = 0;
      case (id_ex.asm_op)
        LB_INST: begin raddr = rs1_plus_imm; rlen = 1; end
        LH_INST: begin raddr = rs1_plus_imm; rlen = 2; end
        LW_INST: begin raddr = rs1_plus_imm; rlen = 4; end
        LBU_INST: begin raddr = rs1_plus_imm; rlen = 1; end
        LHU_INST: begin raddr = rs1_plus_imm; rlen = 2; end
      endcase // case (id_ex.asm_op)
   end

   always @(posedge clk) begin
      `LOG(("EX ] pc=0x%0x rs1_forward=%0d (r%0d=0x%0x) rs2_forward=%0d (r%0d=0x%0x)",
            id_ex.pc, gpr_rs1_forward, i.any_type.rs1, gpr_rs1,
            gpr_rs2_forward, i.any_type.rs2, gpr_rs2));

      ex_wb.new_pc_valid <= 0;
      ex_wb.rd_valid <= 0;
      ex_wb.rd_mem <= 0;        // not reading memory
      ex_wb.wr_mem_len <= 0;
      ex_wb.rval <= 0;
      ex_wb.pc <= id_ex.pc;
      ex_wb.pmu_is_branch <= 0;
      ex_wb.pmu_is_call <= 0;
      ex_wb.pmu_is_load <= 0;
      ex_wb.pmu_is_store <= 0;
      ex_wb.pmu_is_alu <= 0;
      ex_wb.invalid <= wb_ex.invalid;

      if ((gpr_rs1_forward || gpr_rs2_forward) && !wb_ex.invalid)
        pmu.reg_forwards <= pmu.reg_forwards + 1;

      case (id_ex.asm_op)
        // R-type

        ADD_INST: begin
           `LOG(("EX ] eval r%0d <- r%0d + r%0d = %0d", i.r_type.rd, i.r_type.rs1, i.r_type.rs2, gpr_rs1 + gpr_rs1));
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= gpr_rs1 + gpr_rs2;
           ex_wb.pmu_is_alu <= 1;
        end
        SUB_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= gpr_rs1 - gpr_rs2;
           ex_wb.pmu_is_alu <= 1;
        end
        XOR_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= gpr_rs1 ^ gpr_rs2;
           ex_wb.pmu_is_alu <= 1;
        end
        OR_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= gpr_rs1 | gpr_rs2;
           ex_wb.pmu_is_alu <= 1;
        end
        AND_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= gpr_rs1 & gpr_rs2;
           ex_wb.pmu_is_alu <= 1;
        end
        SLL_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= gpr_rs1 << gpr_rs2;
           ex_wb.pmu_is_alu <= 1;
        end
        SRL_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= gpr_rs1 >> gpr_rs2;
           ex_wb.pmu_is_alu <= 1;
        end
        SRA_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= $signed(gpr_rs1) >>> gpr_rs2;
           ex_wb.pmu_is_alu <= 1;
        end
        SLT_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= $signed(gpr_rs1) < $signed(gpr_rs2) ? 1 : 0;
           ex_wb.pmu_is_alu <= 1;
        end
        SLTU_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= gpr_rs1 < gpr_rs2 ? 1 : 0;
           ex_wb.pmu_is_alu <= 1;
        end

        // I-type

        ADDI_INST: begin
           `LOG(("EX ] eval r%0d <- r%0d + %0d = %0d", i.i_type.rd, i.i_type.rs1, id_ex.imm, rs1_plus_imm));
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.rval <= rs1_plus_imm;
           ex_wb.pmu_is_alu <= 1;
        end
        XORI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.rval <= gpr_rs1 ^ id_ex.imm;
           ex_wb.pmu_is_alu <= 1;
        end
        ORI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.rval <= gpr_rs1 | id_ex.imm;
           ex_wb.pmu_is_alu <= 1;
        end
        ANDI_INST: begin
           `LOG(("ANDI 0x%0x & 0x%0x = 0x%0x", gpr_rs1, id_ex.imm, gpr_rs1 & id_ex.imm));
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.rval <= gpr_rs1 & id_ex.imm;
           ex_wb.pmu_is_alu <= 1;
        end
        SLLI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.rval <= gpr_rs1 << id_ex.imm;
           ex_wb.pmu_is_alu <= 1;
        end
        SRLI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.rval <= gpr_rs1 >> id_ex.imm;
           ex_wb.pmu_is_alu <= 1;
        end
        SRAI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.rval <= $signed(gpr_rs1) >>> id_ex.imm;
           ex_wb.pmu_is_alu <= 1;
        end
        SLTI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.rval <= $signed(gpr_rs1) < $signed(id_ex.imm) ? 1 : 0;
           ex_wb.pmu_is_alu <= 1;
        end
        SLTIU_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.rval <= gpr_rs1 < id_ex.imm ? 1 : 0;
           ex_wb.pmu_is_alu <= 1;
        end

        // Load (I-type)

        LB_INST: begin
           `LOG(("EX ] load len=%0d addr=0x%0x to r%0d", 1, rs1_plus_imm, i.i_type.rd));
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.pmu_is_load <= 1;
           ex_wb.rd_mem <= 1;
        end
        LH_INST: begin
           `LOG(("EX ] load len=%0d addr=0x%0x to r%0d", 2, rs1_plus_imm, i.i_type.rd));
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.pmu_is_load <= 1;
           ex_wb.rd_mem <= 1;
        end
        LW_INST: begin
           `LOG(("EX ] load len=%0d addr=0x%0x to r%0d", 4, rs1_plus_imm, i.i_type.rd));
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.pmu_is_load <= 1;
           ex_wb.rd_mem <= 1;
        end
        LBU_INST: begin
           `LOG(("EX ] load unsigned len=%0d addr=0x%0x", 1, rs1_plus_imm));
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.pmu_is_load <= 1;
           ex_wb.rd_mem <= 1;
        end
        LHU_INST: begin
           `LOG(("EX ] load unsigned len=%0d addr=0x%0x", 2, rs1_plus_imm));
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.pmu_is_load <= 1;
           ex_wb.rd_mem <= 1;
        end

        // Store (S-type)

        SB_INST: begin
           ex_wb.pmu_is_store <= 1;
           ex_wb.wr_mem_len <= 1;
           ex_wb.wr_mem_addr <= rs1_plus_imm;
           ex_wb.wr_mem_data <= gpr_rs2;
        end
        SH_INST: begin
           ex_wb.pmu_is_store <= 1;
           ex_wb.wr_mem_len <= 2;
           ex_wb.wr_mem_addr <= rs1_plus_imm;
           ex_wb.wr_mem_data <= gpr_rs2;
        end
        SW_INST: begin
           ex_wb.pmu_is_store <= 1;
           ex_wb.wr_mem_len <= 4;
           ex_wb.wr_mem_addr <= rs1_plus_imm;
           ex_wb.wr_mem_data <= gpr_rs2;
        end

        // Branch

        BEQ_INST: begin
           if (gpr_rs1 == gpr_rs2) begin
              `LOG(("EX ] eval  beq r%0d == r%0d, pc <- 0x%0x + %0d = 0x%0x",
                       i.b_type.rs1, i.b_type.rs2, id_ex.pc, id_ex.imm << 1,
                       id_ex.pc + (id_ex.imm << 1)));
              ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
              ex_wb.new_pc_valid <= 1;
           end
           ex_wb.pmu_is_branch <= 1;
        end
        BNE_INST: begin
           if (gpr_rs1 != gpr_rs2) begin
              `LOG(("EX ] eval  bne r%0d < r%0d, pc <- 0x%0x + %0d = 0x%0x",
                       i.b_type.rs1, i.b_type.rs2, id_ex.pc, id_ex.imm << 1,
                       id_ex.pc + (id_ex.imm << 1)));
              ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
              ex_wb.new_pc_valid <= 1;
           end
           ex_wb.pmu_is_branch <= 1;
        end
        BLT_INST: begin
              `LOG(("EX ] eval  blt r%0d < r%0d, pc <- 0x%0x + %0d = 0x%0x",
                       i.b_type.rs1, i.b_type.rs2, id_ex.pc, id_ex.imm << 1,
                       id_ex.pc + (id_ex.imm << 1)));
           if ($signed(gpr_rs1) < $signed(gpr_rs2)) begin
              ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
              ex_wb.new_pc_valid <= 1;
           end
           ex_wb.pmu_is_branch <= 1;
        end
        BGE_INST: begin
           if ($signed(gpr_rs1) >= $signed(gpr_rs2)) begin
              `LOG(("EX ] eval  bge r%0d < r%0d, pc <- 0x%0x + %0d = 0x%0x",
                       i.b_type.rs1, i.b_type.rs2, id_ex.pc, id_ex.imm << 1,
                       id_ex.pc + (id_ex.imm << 1)));
              ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
              ex_wb.new_pc_valid <= 1;
           end
           ex_wb.pmu_is_branch <= 1;
        end
        BLTU_INST: begin
           if (gpr_rs1 < gpr_rs2) begin
              `LOG(("EX ] eval  bltu r%0d < r%0d, pc <- 0x%0x + %0d = 0x%0x",
                       i.b_type.rs1, i.b_type.rs2, id_ex.pc, id_ex.imm << 1,
                       id_ex.pc + (id_ex.imm << 1)));
              ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
              ex_wb.new_pc_valid <= 1;
           end
           ex_wb.pmu_is_branch <= 1;
        end
        BGEU_INST: begin
           if (gpr_rs1 >= gpr_rs2) begin
              `LOG(("EX ] eval  bgeu r%0d < r%0d, pc <- 0x%0x + 0x%0x = 0x%0x",
                       i.b_type.rs1, i.b_type.rs2, id_ex.pc, id_ex.imm << 1,
                       id_ex.pc + (id_ex.imm << 1)));
              ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
              ex_wb.new_pc_valid <= 1;
           end
           ex_wb.pmu_is_branch <= 1;
        end
        JAL_INST: begin
           `LOG(("EX ] eval  jal r%0d <- r0x%0x, pc <- pc (0x%0x) + 0x%0x = 0x%0x",
                 i.j_type.rd, id_ex.pc + 4,
                 id_ex.pc, id_ex.imm << 1, id_ex.pc + (id_ex.imm << 1)));
           ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
           ex_wb.new_pc_valid <= 1;
           ex_wb.rd <= i.j_type.rd;
           ex_wb.rd_valid <= 1;
           ex_wb.rval <= id_ex.pc + 4;
           ex_wb.pmu_is_call <= 1;
        end
        JALR_INST: begin
           `LOG(("EX ] eval  jalr r%0d <- r0x%0x, pc <- r%0d (0x%0x) + 0x%0x = 0x%0x",
                 i.i_type.rd, id_ex.pc + 4,
                 i.i_type.rs1, gpr_rs1, id_ex.imm << 1, gpr_rs1 + (id_ex.imm << 1)));
           ex_wb.new_pc <= gpr_rs1 + (id_ex.imm << 1);
           ex_wb.new_pc_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.rd_valid <= 1;
           ex_wb.rval <= id_ex.pc + 4;
           ex_wb.pmu_is_call <= 1;
        end
        LUI_INST: begin
           `LOG(("lui"));
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.u_type.rd;
           ex_wb.rval <= id_ex.imm << 12;
        end
        AUIPC_INST: begin
           `LOG(("auipc"));
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.u_type.rd;
           ex_wb.rval <= id_ex.pc + (id_ex.imm << 12);
        end
        ECALL_INST: begin
           `LOG(("not impl"));
        end
        EBREAK_INST: begin
           `LOG(("not impl"));
        end
        default:
          `LOG(("bad inst"));
      endcase // case (id_ex.asm_op)
   end // always @ (posedge clk)

endmodule // Execute


module WB(input         clk,
          input         ex_wb_t ex_wb,
          input [31:0]  rdata,
          input [31:0]  rdata_raw,
          output        wb_if_t wb_if,
          output        wb_id_t wb_id,
          output        wb_ex_t wb_ex,
          output        regfile_t regs,
          output        pmu_t pmu,
          output        fwd_valid,
          output [31:0] fwd_data,
          output [4:0]  fwd_reg,
          output [2:0]  wlen,
          output [31:0] waddr,
          output [31:0] wdata
          );

   assign fwd_valid = ! ex_wb.invalid && ! wb_ex.invalid && ex_wb.rd_valid && ex_wb.rd != 0;
   assign fwd_reg = ex_wb.rd;
   assign fwd_data = ex_wb.rd_mem ? rdata_raw : ex_wb.rval;

   always @(posedge clk) begin
      if (fwd_valid) begin
        `LOG(("WB ] mem=%0d fwd_reg=%0d fwd_data=0x%0x", ex_wb.rd_mem, fwd_reg, fwd_data));
      end
      wb_if.new_pc_valid <= 0;
      wb_id.invalid <= 0;
      wb_ex.invalid <= 0;
      wlen <= 0;

      if (! ex_wb.invalid && ! wb_ex.invalid) begin

         `LOG(("WB ] pc=0x%0x new_pc_valid=%0d new_pc=0x%0x rd_valid=%0d rd=%0d rval=%0d",
                  ex_wb.pc, ex_wb.new_pc_valid, ex_wb.new_pc,
                  ex_wb.rd_valid, ex_wb.rd, ex_wb.rval));
         pmu.inst_retired <= pmu.inst_retired + 1;

         if (ex_wb.new_pc_valid) begin
            `LOG(("WB ] commit pc <- 0x%0x and flush pipe", ex_wb.new_pc));
            wb_if.new_pc_valid <= 1;
            wb_if.new_pc <= ex_wb.new_pc;
            wb_id.invalid <= 1;
            wb_ex.invalid <= 1;
            pmu.br_taken <= pmu.br_taken + 1;
         end

         if (ex_wb.rd_valid && ex_wb.rd != 0) begin
            regs.gpr[ex_wb.rd] <= ex_wb.rd_mem ? rdata : ex_wb.rval;
            if (ex_wb.rd_mem) begin
               `LOG(("WB ] commit mem load r%0d <- 0x%0x (%0d)", ex_wb.rd, rdata, rdata));
            end else begin
               `LOG(("WB ] commit r%0d <- 0x%0x (%0d)", ex_wb.rd, ex_wb.rval, ex_wb.rval));
            end
         end

         if (ex_wb.wr_mem_len != 0) begin
            `LOG(("WB ] store len=%0d addr=0x%0x data=0x%x",
                  ex_wb.wr_mem_len, ex_wb.wr_mem_addr, ex_wb.wr_mem_data));
            wlen <= ex_wb.wr_mem_len;
            waddr <= ex_wb.wr_mem_addr;
            wdata <= ex_wb.wr_mem_data;
         end

         if (ex_wb.pmu_is_alu) pmu.alu_retired <= pmu.alu_retired + 1;
         if (ex_wb.pmu_is_call) pmu.call_retired <= pmu.call_retired + 1;
         if (ex_wb.pmu_is_branch) pmu.br_retired <= pmu.br_retired + 1;
         if (ex_wb.pmu_is_load) pmu.load_retired <= pmu.load_retired + 1;
         if (ex_wb.pmu_is_store) pmu.store_retired <= pmu.store_retired + 1;

      end // if (! ex_wb.invalid && ! wb_ex.invalid)
      else begin
         `LOG(("WB ] pc=0x%0x new_pc_valid=%0d new_pc=0x%0x rd_valid=%0d rd=%0d rval=%0d invalid",
                  ex_wb.pc, ex_wb.new_pc_valid, ex_wb.new_pc,
                  ex_wb.rd_valid, ex_wb.rd, ex_wb.rval));
      end
   end
endmodule // WB


module CPU(input         clk,
           output [31:0] r10,
           output [31:0] cycle_cnt,
           output [31:0] inst_retired,
           output [31:0] br_taken,
           output [31:0] br_retired,
           output [31:0] call_retired,
           output [31:0] alu_retired,
           output [31:0] load_retired,
           output [31:0] store_retired,
           output [31:0] reg_forwards
);
   logic [31:0] new_pc;
   logic [31:0] mem_raddr_a, mem_raddr_b;
   logic [31:0] mem_rdata_a, mem_rdata_b;
   logic [3:0]  mem_we;
   logic [31:0] mem_waddr, mem_wdata;

   ram_2r1w  mem(.clk(clk),
                 .we(mem_we),
                 .waddr(mem_waddr),
                 .wdata(mem_wdata),
                 .raddr_a(mem_raddr_a),
                 .rdata_a(mem_rdata_a),
                 .raddr_b(mem_raddr_b),
                 .rdata_b(mem_rdata_b)
                 );

   logic [31:0] ex_raddr;
   logic [2:0]  ex_rlen;
   logic [31:0] ex_rdata;
   byte_read ex_read(.raddr(mem_raddr_b),
                     .rdata(mem_rdata_b),
                     .byte_addr(ex_raddr),
                     .byte_len(ex_rlen),
                     .word_out(ex_rdata)
                     );

   logic [31:0] wb_addr;
   logic [2:0]  wb_len;
   logic [31:0] wb_data;
   byte_write wb_write(.we(mem_we),
                       .waddr(mem_waddr),
                       .wdata(mem_wdata),
                       .byte_addr(wb_addr),
                       .byte_len(wb_len),
                       .byte_data(wb_data)
                       );
   regfile_t regs;
   if_id_t if_id;
   id_ex_t id_ex;
   ex_wb_t ex_wb;
   wb_if_t wb_if;
   wb_id_t wb_id;
   wb_ex_t wb_ex;
   pmu_t pmu;
   logic wb_fwd_valid;
   logic [4:0] wb_fwd_reg;
   logic [31:0] wb_fwd_data;

   initial begin
      id_ex.invalid = 1;
      ex_wb.invalid = 1;
      wb_id.invalid = 1;
   end

   IF1 fetch(.clk(clk), .raddr(mem_raddr_a), .if_id(if_id), .wb_if(wb_if));
   IF2 decode(.rdata(mem_rdata_a), .if_id(if_id), .id_ex(id_ex), .wb_id(wb_id));
   EX execute(.clk(clk), .id_ex(id_ex), .ex_wb(ex_wb), .wb_ex(wb_ex),
              .raddr(ex_raddr), .rlen(ex_rlen),
              .fwd_valid(wb_fwd_valid), .fwd_reg(wb_fwd_reg), .fwd_data(wb_fwd_data),
              .regs(regs), .pmu(pmu)
              );
   WB wback(.clk(clk), .ex_wb(ex_wb), .wb_id(wb_id), .wb_if(wb_if), .wb_ex(wb_ex),
            .regs(regs), .rdata(ex_rdata), .rdata_raw(mem_rdata_b),
            .waddr(wb_addr), .wdata(wb_data), .wlen(wb_len),
            .fwd_valid(wb_fwd_valid), .fwd_reg(wb_fwd_reg), .fwd_data(wb_fwd_data),
            .pmu(pmu));

   assign cycle_cnt = pmu.cycles;
   assign inst_retired = pmu.inst_retired;
   assign br_taken = pmu.br_taken;
   assign br_retired = pmu.br_retired;
   assign call_retired = pmu.call_retired;
   assign alu_retired = pmu.alu_retired;
   assign load_retired = pmu.load_retired;
   assign store_retired = pmu.store_retired;
   assign reg_forwards = pmu.reg_forwards;
   assign r10 = regs.gpr[10];

   always @(posedge clk)
     begin
        `LOG(("==================== cycle %d", pmu.cycles));
        pmu.cycles <= pmu.cycles + 1;
     end
endmodule
