`timescale 1ns / 1ns

`ifdef ENABLE_DEBUG_PRINT
    `define LOG(msg) $display msg
`else
    `define LOG(msg)
`endif

typedef union packed {
   bit [31:0] raw;

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
   logic rd_mem_signed;
   logic [2:0] rd_mem_bytes;
   logic [4:0] rd_mem_shift;
   logic [4:0] rd;
   logic [31:0] rval;
   logic new_pc_valid;
   logic [31:0] new_pc;
   logic [31:0] pc;
   logic        invalid;
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
} wb_ex_t;

typedef struct {
   logic [31:0] [31:0] gpr;
} regfile_t;

typedef struct {
   logic [31:0] inst_retired;
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
      `LOG(("RAM] raddr_a=%0d raddr_b=%0d", raddr_a, raddr_b));
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
        default: `LOG(("bad type"));
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
          output        ex_wb_t ex_wb,
          output        wb_ex_t wb_ex,
          output [31:0] raddr
);
   inst_t i;
   assign i = id_ex.inst;
   wire [31:0] rs1_plus_imm;
   assign rs1_plus_imm = regs.gpr[i.i_type.rs1] + id_ex.imm;

   always @(posedge clk) begin
      `LOG(("EX ] pc=0x%0x", id_ex.pc));

      ex_wb.new_pc_valid <= 0;
      ex_wb.rd_valid <= 0;
      ex_wb.rd_mem_bytes <= 0;
      ex_wb.rd_mem_signed <= 0;
      ex_wb.rval <= 0;
      ex_wb.pc <= id_ex.pc;
      ex_wb.invalid <= wb_ex.invalid;

      case (id_ex.asm_op)
        // R-type

        ADD_INST: begin
           `LOG(("EX ] eval r%0d <- r%0d + r%0d = %0d", i.r_type.rd, i.r_type.rs1, i.r_type.rs2, regs.gpr[i.r_type.rs1] + regs.gpr[i.r_type.rs2]));
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.r_type.rs1] + regs.gpr[i.r_type.rs2];
        end
        SUB_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.r_type.rs1] - regs.gpr[i.r_type.rs2];
        end
        XOR_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.r_type.rs1] ^ regs.gpr[i.r_type.rs2];
        end
        OR_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.r_type.rs1] | regs.gpr[i.r_type.rs2];
        end
        AND_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.r_type.rs1] & regs.gpr[i.r_type.rs2];
        end
        SLL_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.r_type.rs1] << regs.gpr[i.r_type.rs2];
        end
        SRL_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.r_type.rs1] >> regs.gpr[i.r_type.rs2];
        end
        SRA_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= $signed(regs.gpr[i.r_type.rs1]) >>> regs.gpr[i.r_type.rs2];
        end
        SLT_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= $signed(regs.gpr[i.r_type.rs1]) < $signed(regs.gpr[i.r_type.rs2]) ? 1 : 0;
        end
        SLTU_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.r_type.rs1] < regs.gpr[i.r_type.rs2] ? 1 : 0;
        end

        // I-type

        ADDI_INST: begin
           `LOG(("EX ] eval r%0d <- r%0d + %0d = %0d", i.r_type.rd, i.r_type.rs1, id_ex.imm, rs1_plus_imm));
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= rs1_plus_imm;
        end
        XORI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.i_type.rs1] ^ id_ex.imm;
        end
        ORI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.i_type.rs1] | id_ex.imm;
        end
        ANDI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.i_type.rs1] & id_ex.imm;
        end
        SLLI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.i_type.rs1] << id_ex.imm;
        end
        SRLI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.i_type.rs1] >> id_ex.imm;
        end
        SRAI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= $signed(regs.gpr[i.i_type.rs1]) >>> id_ex.imm;
        end
        SLTI_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= $signed(regs.gpr[i.i_type.rs1]) < $signed(id_ex.imm) ? 1 : 0;
        end
        SLTIU_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd <= i.r_type.rd;
           ex_wb.rval <= regs.gpr[i.i_type.rs1] < id_ex.imm ? 1 : 0;
        end

        // Load (I-type)

        LB_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd_mem_bytes <= 1;
           ex_wb.rd_mem_shift <= 2'((rs1_plus_imm) & 3) << 3;
           ex_wb.rd_mem_signed <= 1;
           ex_wb.rd <= i.r_type.rd;
           raddr <= (rs1_plus_imm) & 32'hfffffffc;
        end
        LH_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd_mem_bytes <= 2;
           ex_wb.rd_mem_shift <= 2'((rs1_plus_imm) & 3) << 3;
           ex_wb.rd_mem_signed <= 1;
           ex_wb.rd <= i.r_type.rd;
           raddr <= rs1_plus_imm;
        end
        LW_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd_mem_bytes <= 4;
           ex_wb.rd_mem_shift <= 2'((rs1_plus_imm) & 3) << 3;
           ex_wb.rd_mem_signed <= 0;
           ex_wb.rd <= i.r_type.rd;
           raddr <= rs1_plus_imm;
        end
        LBU_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd_mem_bytes <= 1;
           ex_wb.rd_mem_shift <= 2'((rs1_plus_imm) & 3) << 3;
           ex_wb.rd_mem_signed <= 0;
           ex_wb.rd <= i.r_type.rd;
           raddr <= rs1_plus_imm;
        end
        LHU_INST: begin
           ex_wb.rd_valid <= 1;
           ex_wb.rd_mem_bytes <= 2;
           ex_wb.rd_mem_shift <= 2'((rs1_plus_imm) & 3) << 3;
           ex_wb.rd_mem_signed <= 0;
           ex_wb.rd <= i.r_type.rd;
           raddr <= rs1_plus_imm;
        end

        // Store (S-type)

        SB_INST: begin
        end
        SH_INST: begin
        end
        SW_INST: begin
        end

        // Branch

        BEQ_INST: begin
           if (regs.gpr[i.b_type.rs1] == regs.gpr[i.b_type.rs2]) begin
              `LOG(("EX ] eval  beq r%0d == r%0d, pc <- 0x%0x + %0d = 0x%0x",
                       i.b_type.rs1, i.b_type.rs2, id_ex.pc, id_ex.imm << 1,
                       id_ex.pc + (id_ex.imm << 1)));
              ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
              ex_wb.new_pc_valid <= 1;
           end
        end
        BNE_INST: begin
           if (regs.gpr[i.b_type.rs1] != regs.gpr[i.b_type.rs2]) begin
              `LOG(("EX ] eval  bne r%0d < r%0d, pc <- 0x%0x + %0d = 0x%0x",
                       i.b_type.rs1, i.b_type.rs2, id_ex.pc, id_ex.imm << 1,
                       id_ex.pc + (id_ex.imm << 1)));
              ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
              ex_wb.new_pc_valid <= 1;
           end
        end
        BLT_INST: begin
              `LOG(("EX ] eval  blt r%0d < r%0d, pc <- 0x%0x + %0d = 0x%0x",
                       i.b_type.rs1, i.b_type.rs2, id_ex.pc, id_ex.imm << 1,
                       id_ex.pc + (id_ex.imm << 1)));
           if ($signed(regs.gpr[i.b_type.rs1]) < $signed(regs.gpr[i.b_type.rs2])) begin
              ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
              ex_wb.new_pc_valid <= 1;
           end
        end
        BGE_INST: begin
           if ($signed(regs.gpr[i.b_type.rs1]) >= $signed(regs.gpr[i.b_type.rs2])) begin
              `LOG(("EX ] eval  bge r%0d < r%0d, pc <- 0x%0x + %0d = 0x%0x",
                       i.b_type.rs1, i.b_type.rs2, id_ex.pc, id_ex.imm << 1,
                       id_ex.pc + (id_ex.imm << 1)));
              ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
              ex_wb.new_pc_valid <= 1;
           end
        end
        BLTU_INST: begin
           if (regs.gpr[i.b_type.rs1] < regs.gpr[i.b_type.rs2]) begin
              `LOG(("EX ] eval  bltu r%0d < r%0d, pc <- 0x%0x + %0d = 0x%0x",
                       i.b_type.rs1, i.b_type.rs2, id_ex.pc, id_ex.imm << 1,
                       id_ex.pc + (id_ex.imm << 1)));
              ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
              ex_wb.new_pc_valid <= 1;
           end
        end
        BGEU_INST: begin
           if (regs.gpr[i.b_type.rs1] >= regs.gpr[i.b_type.rs2]) begin
              `LOG(("EX ] eval  bgeu r%0d < r%0d, pc <- 0x%0x + %0d = 0x%0x",
                       i.b_type.rs1, i.b_type.rs2, id_ex.pc, id_ex.imm << 1,
                       id_ex.pc + (id_ex.imm << 1)));
              ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
              ex_wb.new_pc_valid <= 1;
           end
        end
        JAL_INST: begin
           `LOG(("jal"));
           ex_wb.new_pc <= id_ex.pc + (id_ex.imm << 1);
           ex_wb.new_pc_valid <= 1;
           ex_wb.rd <= i.j_type.rd;
           ex_wb.rd_valid <= 1;
           ex_wb.rval <= id_ex.pc + 4;
        end
        JALR_INST: begin
           `LOG(("jalr"));
           ex_wb.new_pc <= regs.gpr[i.i_type.rs1] + (id_ex.imm << 1);
           ex_wb.new_pc_valid <= 1;
           ex_wb.rd <= i.i_type.rd;
           ex_wb.rd_valid <= 1;
           ex_wb.rval <= id_ex.pc + 4;
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
          output        wb_if_t wb_if,
          output        wb_id_t wb_id,
          output        wb_ex_t wb_ex,
          output        regfile_t regs,
          output        pmu_t pmu,
          output [31:0] waddr,
          output [31:0] wdata
          );

   always @(posedge clk) begin

      wb_if.new_pc_valid <= 0;
      wb_id.invalid <= 0;
      wb_ex.invalid <= 0;

      if (! ex_wb.invalid && ! wb_ex.invalid) begin

         `LOG(("WB ] pc=0x%0x new_pc_valid=%0d new_pc=0x%0x rd_valid=%0d rd=%0d rval=%0d",
                  ex_wb.pc, ex_wb.new_pc_valid, ex_wb.new_pc,
                  ex_wb.rd_valid, ex_wb.rd, ex_wb.rval));
         pmu.inst_retired <= pmu.inst_retired + 1;

         if (ex_wb.new_pc_valid) begin
            `LOG(("WB ] commit pc <- 0x%0x", ex_wb.new_pc));
            wb_if.new_pc_valid <= 1;
            wb_if.new_pc <= ex_wb.new_pc;
            wb_id.invalid <= 1;
            wb_ex.invalid <= 1;
         end

         if (ex_wb.rd_valid && ex_wb.rd != 0) begin
            case (ex_wb.rd_mem_bytes)
              0: begin
                 `LOG(("WB ] commit r%d <- %0d", ex_wb.rd, ex_wb.rval));
                 regs.gpr[ex_wb.rd] <= ex_wb.rval;
              end
              1: begin
                 `LOG(("WB ] load bytes=%d shift=%d signed=%d",
                          ex_wb.rd_mem_bytes, ex_wb.rd_mem_shift, ex_wb.rd_mem_signed));
                 if (ex_wb.rd_mem_signed)
                   regs.gpr[ex_wb.rd] <= { {24{rdata[ex_wb.rd_mem_shift + 7]}},
                                           8'(rdata >> ex_wb.rd_mem_shift) };
                 else
                   regs.gpr[ex_wb.rd] <= { 24'b0, 8'(rdata >> ex_wb.rd_mem_shift) };
              end
              2: begin
                 `LOG(("WB ] load bytes=%d shift=%d signed=%d",
                          ex_wb.rd_mem_bytes, ex_wb.rd_mem_shift, ex_wb.rd_mem_signed));
                 if (ex_wb.rd_mem_signed)
                   regs.gpr[ex_wb.rd] <= { {16{rdata[ex_wb.rd_mem_shift + 15]}},
                                           16'(rdata >> ex_wb.rd_mem_shift) };
                 else
                   regs.gpr[ex_wb.rd] <= { 16'b0, 16'(rdata >> ex_wb.rd_mem_shift) };
                 if (ex_wb.rd_mem_shift >= 2)
                   `LOG(("WB ] misaligned!"));
              end
              4: begin
                 `LOG(("WB ] load bytes=%d shift=%d signed=%d",
                          ex_wb.rd_mem_bytes, ex_wb.rd_mem_shift, ex_wb.rd_mem_signed));
                 regs.gpr[ex_wb.rd] <= rdata;
                 if (ex_wb.rd_mem_shift > 0)
                   `LOG(("WB ] misaligned!"));
              end
            endcase // case (ex_wb.rd_mem_shift)
         end

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
           output [31:0] inst_retired
);
   logic [31:0] new_pc;
   logic [31:0] mem_raddr_a = -1, mem_raddr_b;
   logic [31:0] mem_rdata_a, mem_rdata_b;
   logic [3:0]  mem_we;
   logic [31:0] mem_waddr, mem_wdata;
   logic [31:0] cycles;

   ram_2r1w  mem(.clk(clk),
                 .we(mem_we),
                 .waddr(mem_waddr),
                 .wdata(mem_wdata),
                 .raddr_a(mem_raddr_a),
                 .rdata_a(mem_rdata_a),
                 .raddr_b(mem_raddr_b),
                 .rdata_b(mem_rdata_b)
                 );
   regfile_t regs;
   if_id_t if_id;
   id_ex_t id_ex;
   ex_wb_t ex_wb;
   wb_if_t wb_if;
   wb_id_t wb_id;
   wb_ex_t wb_ex;
   pmu_t pmu;

   initial begin
      id_ex.invalid = 1;
      ex_wb.invalid = 1;
      wb_id.invalid = 1;
   end

   IF1 fetch(.clk(clk), .raddr(mem_raddr_a), .if_id(if_id), .wb_if(wb_if));
   IF2 decode(.rdata(mem_rdata_a), .if_id(if_id), .id_ex(id_ex), .wb_id(wb_id));
   EX execute(.clk(clk), .id_ex(id_ex), .ex_wb(ex_wb), .wb_ex(wb_ex),
              .regs(regs), .raddr(mem_raddr_b)
              );
   WB wback(.clk(clk), .ex_wb(ex_wb), .wb_id(wb_id), .wb_if(wb_if), .wb_ex(wb_ex),
            .regs(regs), .rdata(mem_rdata_b),
            .waddr(mem_waddr), .wdata(mem_wdata),
            .pmu(pmu));

   assign cycle_cnt = cycles;
   assign inst_retired = pmu.inst_retired;
   assign r10 = regs.gpr[10];

   always @(posedge clk)
     begin
        `LOG(("==================== cycle %d", cycles));
        cycles <= cycles + 1;
     end
endmodule
