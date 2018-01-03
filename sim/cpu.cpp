#include "cpu.hpp"

#include <algorithm>
#include <iomanip>
#include <iostream>
#include <cstdio>

namespace {
// Simulator routines.
const uint32_t SIM_ROUTINE_EXIT = 0u;
const uint32_t SIM_ROUTINE_PUTC = 1u;

// Named registers.
const uint32_t REG_Z = 0u;
const uint32_t REG_PC = 1u;
const uint32_t REG_SP = 2u;
const uint32_t REG_LR = 3u;

// ALU operations.
const uint32_t ALU_OP_NONE = 0x00u;
const uint32_t ALU_OP_OR = 0x01u;
const uint32_t ALU_OP_NOR = 0x02u;
const uint32_t ALU_OP_AND = 0x03u;
const uint32_t ALU_OP_XOR = 0x04u;
const uint32_t ALU_OP_ADD = 0x05u;
const uint32_t ALU_OP_SUB = 0x06u;
const uint32_t ALU_OP_ADDC = 0x07u;
const uint32_t ALU_OP_SUBC = 0x08u;
const uint32_t ALU_OP_SHL = 0x09u;
const uint32_t ALU_OP_ASR = 0x0au;
const uint32_t ALU_OP_LSR = 0x0bu;
const uint32_t ALU_OP_EXTB = 0x0cu;
const uint32_t ALU_OP_EXTH = 0x0du;
const uint32_t ALU_OP_MIXH = 0x10u;

// Memory operations.
const uint32_t MEM_OP_NONE = 0x00u;
const uint32_t MEM_OP_LOAD8 = 0x10u;
const uint32_t MEM_OP_LOAD16 = 0x11u;
const uint32_t MEM_OP_LOAD32 = 0x12u;
const uint32_t MEM_OP_STORE8 = 0x14u;
const uint32_t MEM_OP_STORE16 = 0x15u;
const uint32_t MEM_OP_STORE32 = 0x16u;

struct id_in_t {
  uint32_t pc;      // PC for the current instruction.
  uint32_t instr;   // Instruction.
};

struct ex_in_t {
  uint32_t carry_in;
  uint32_t src_a;       // ALU source operand A.
  uint32_t src_b;       // ALU source operand B.
  uint32_t alu_op;      // ALU operation.

  uint32_t mem_op;      // MEM operation.
  uint32_t store_data;  // Data to be stored in the mem step.

  uint32_t dst_reg;     // Target register for the instruction (0 = none).
};

struct mem_in_t {
  uint32_t mem_op;      // MEM operation.
  uint32_t mem_addr;    // Address for the MEM operation.
  uint32_t store_data;  // Data to be stored in the MEM step.
  uint32_t dst_data;    // Data to be written in the WB step (result from ALU).
  uint32_t dst_reg;     // Target register for the instruction (0 = none).
};

struct wb_in_t {
  uint32_t dst_data;    // Data to be written in the WB step.
  uint32_t dst_reg;     // Target register for the instruction (0 = none).
};
}  // namespace

cpu_t::cpu_t(ram_t& ram) : m_ram(ram), m_icache(ram), m_dcache(ram) {
  reset();
}

void cpu_t::reset() {
  std::fill(m_regs.begin(), m_regs.end(), 0u);
  std::fill(m_fregs.begin(), m_fregs.end(), 0.0f);
  m_terminate = false;
  m_exit_code = 0u;
}

void cpu_t::dump_stats() {
  std::cout << "Cache stats:\n";
  std::cout << " ICACHE: " << m_icache.accesses() << " accesses " << m_icache.hits() << " hits\n";
  std::cout << " DCACHE: " << m_dcache.accesses() << " accesses " << m_dcache.hits() << " hits\n";
}

void cpu_t::call_sim_routine(const uint32_t routine_no) {
  switch (routine_no) {
    case SIM_ROUTINE_EXIT:
      m_terminate = true;
      m_exit_code = m_regs[4];
      break;
    case SIM_ROUTINE_PUTC:
      const int c = static_cast<int>(m_regs[4]);
      std::putc(c, stdout);
      break;
  }
}

uint32_t cpu_t::run(const uint32_t addr) {
  m_regs[REG_PC] = addr;
  m_terminate = false;
  m_exit_code = 0u;

  int32_t cycles = 0;
  while (!m_terminate) {
    // Simulator routine call handling.
    // Simulator routines start at PC = 0xffff0000.
    if ((m_regs[REG_PC] & 0xffff0000u) == 0xffff0000u) {
      // Call the routine.
      const uint32_t routine_no = (m_regs[REG_PC] - 0xffff0000u) >> 2u;
      call_sim_routine(routine_no);

      // Simulate jmp lr.
      m_regs[REG_PC] = m_regs[REG_LR];
    }

    int32_t instr_cycles = 1;
    uint32_t next_pc;

    // IF
    id_in_t id_in;
    {
      const uint32_t instr_pc = m_regs[REG_PC];

      // Read the instruction from the current (predicted) PC.
      id_in.pc = instr_pc;
      id_in.instr = m_icache.read32(instr_pc);
    }

    // ID
    ex_in_t ex_in;
    {
      // Detect encoding class (A, B, C or D).
      const bool op_class_A = ((id_in.instr & 0xff000000u) == 0x00000000u);
      const bool op_class_B = ((id_in.instr & 0xf0000000u) < 0x20000000u) && !op_class_A;
      const bool op_class_C = ((id_in.instr & 0xf0000000u) == 0x20000000u);
      const bool op_class_D = ((id_in.instr & 0xf0000000u) >= 0x30000000u);

      // Extract parts of the instruction.
      // NOTE: These may or may not be valid, depending on the instruction type.
      const uint32_t reg1 = (id_in.instr >> 19u) & 31u;
      const uint32_t reg2 = (id_in.instr >> 14u) & 31u;
      const uint32_t reg3 = (id_in.instr >> 9u) & 31u;
      const uint32_t imm14 =
          (id_in.instr & 0x00003fffu) | ((id_in.instr & 0x00002000u) ? 0xffffc000u : 0u);
      const uint32_t imm19 =
          (id_in.instr & 0x0007ffffu) | ((id_in.instr & 0x00040000u) ? 0xfff80000u : 0u);
      const uint32_t imm24 =
          (id_in.instr & 0x00ffffffu) | ((id_in.instr & 0x00800000u) ? 0xff000000u : 0u);


      // == BRANCH ==

      const bool is_bcc = ((id_in.instr & 0xf8000000u) == 0x20000000u);
      const bool is_jmp_jsr = ((id_in.instr & 0xff0001f0u) == 0x00000080u);
      const bool is_bra_bsr = ((id_in.instr & 0xf8000000u) == 0x30000000u);
      const bool is_branch = is_bcc || is_jmp_jsr || is_bra_bsr;
      const bool is_subroutine_branch = ((id_in.instr & 0xff0001ffu) == 0x00000081u) ||  // jsr
                                        ((id_in.instr & 0xff000000u) == 0x31000000u);    // bsr

      // Branch source register is reg1 (for b[cc] and jmp/jsr).
      const uint32_t branch_reg = (is_bcc || is_jmp_jsr) ? reg1 : REG_Z;
      const uint32_t branch_value = m_regs[branch_reg];

      bool branch_taken = false;
      uint32_t branch_target = 0u;

      // b[cc]?
      if (is_bcc) {
        switch (id_in.instr >> 24u) {
          case 0x20u:  // beq
            branch_taken = (branch_value == 0u);
            break;
          case 0x21u:  // bne
            branch_taken = (branch_value != 0u);
            break;
          case 0x22u:  // bge
            branch_taken = ((branch_value & 0x80000000u) == 0u);
            break;
          case 0x23u:  // bgt
            branch_taken = ((branch_value & 0x80000000u) == 0u) && (branch_value != 0u);
            break;
          case 0x24u:  // ble
            branch_taken = ((branch_value & 0x80000000u) != 0u) || (branch_value == 0u);
            break;
          case 0x25u:  // blt
            branch_taken = ((branch_value & 0x80000000u) != 0u);
            break;
        }
        branch_target = id_in.pc + (imm19 << 2u);
      }

      // bra/bsr?
      if (is_bra_bsr) {
        branch_taken = true;
        branch_target = id_in.pc + (imm24 << 2u);
      }

      // jmp/jsr?
      if (is_jmp_jsr) {
        branch_taken = true;
        branch_target = branch_value;
      }

      next_pc = branch_taken ? branch_target : (id_in.pc + 4u);


      // == DECODE ==

      // Is this a mem load/store operation?
      const bool is_ldx = (id_in.instr & 0xff0001fcu) == 0x00000010u;
      const bool is_ld = (id_in.instr & 0xfc000000u) == 0x10000000u;
      const bool is_mem_load = is_ldx || is_ld;
      const bool is_stx = ((id_in.instr & 0xff0001fcu) == 0x00000014u);
      const bool is_st = ((id_in.instr & 0xfc000000u) == 0x14000000u);
      const bool is_mem_store = is_stx || is_st;
      const bool is_ldihi = ((id_in.instr & 0xff000000u) == 0x29000000u);  // ldihi

      // Should we use reg1 as a source?
      const bool reg1_is_src = is_mem_store || is_jmp_jsr || is_ldihi;

      // Should we use reg2 as a source?
      const bool reg2_is_src = op_class_A || op_class_B;

      // Should we use reg3 as a source?
      const bool reg3_is_src = op_class_A;

      // Should we use reg1 as a destination?
      const bool reg1_is_dst = (is_ldihi || !reg1_is_src) && !is_branch;

      // Determine the source & destination register numbers (zero of none).
      const uint32_t src_reg_a =
          is_ldihi ? reg1 : (is_subroutine_branch ? REG_PC : (reg2_is_src ? reg2 : REG_Z));
      const uint32_t src_reg_b = reg3_is_src ? reg3 : REG_Z;
      const uint32_t src_reg_c = is_mem_store ? reg1 : REG_Z;
      const uint32_t dst_reg = is_subroutine_branch ? REG_LR : (reg1_is_dst ? reg1 : REG_Z);

      // Determine ALU operation.
      uint32_t alu_op = ALU_OP_NONE;
      if (is_subroutine_branch || is_mem_load || is_mem_store) {
        alu_op = ALU_OP_ADD;
      } else if (op_class_A && (id_in.instr & 0x000001ffu) <= 0x0000000du) {
        alu_op = id_in.instr & 0x000001ff;
      } else if (op_class_B && (id_in.instr & 0xff000000u) <= 0x0b000000u) {
        alu_op = id_in.instr >> 24u;
      } else if (op_class_C) {
        switch (id_in.instr & 0xff000000u) {
          case 0x28000000u:  // ldi
            alu_op = ALU_OP_OR;
            break;
          case 0x29000000u:  // ldihi
            alu_op = ALU_OP_MIXH;
            break;
        }
      }
      // ...and then some.

      // Determine MEM operation.
      uint32_t mem_op = MEM_OP_NONE;
      if (is_mem_load) {
        mem_op = (is_ldx ? (id_in.instr & 0x000001ffu) : (id_in.instr >> 24u));
      } else if (is_mem_store) {
        mem_op = (is_stx ? (id_in.instr & 0x000001ffu) : (id_in.instr >> 24u));
      }

      // Output of the ID step.
      ex_in.carry_in = 0u;  // TODO(m): Implement me!
      ex_in.src_a = m_regs[src_reg_a];
      ex_in.src_b = is_subroutine_branch
                        ? 4
                        : (op_class_B ? imm14 : (op_class_C ? imm19 : m_regs[src_reg_b]));
      ex_in.store_data = m_regs[src_reg_c];
      ex_in.dst_reg = dst_reg;
      ex_in.alu_op = alu_op;
      ex_in.mem_op = mem_op;
    }

    // EX
    mem_in_t mem_in;
    {
      uint32_t alu_result = 0u;
      switch (ex_in.alu_op) {
        case ALU_OP_OR:
          alu_result = ex_in.src_a | ex_in.src_b;
          break;
        case ALU_OP_NOR:
          alu_result = ~(ex_in.src_a | ex_in.src_b);
          break;
        case ALU_OP_AND:
          alu_result = ex_in.src_a & ex_in.src_b;
          break;
        case ALU_OP_XOR:
          alu_result = ex_in.src_a ^ ex_in.src_b;
          break;
        case ALU_OP_ADD:
          alu_result = ex_in.src_a + ex_in.src_b;
          break;
        case ALU_OP_SUB:
          alu_result = ex_in.src_a - ex_in.src_b;
          break;
        case ALU_OP_ADDC:
          alu_result = ex_in.src_a + ex_in.src_b + ex_in.carry_in;
          break;
        case ALU_OP_SUBC:
          alu_result = ex_in.src_a - ex_in.src_b + ex_in.carry_in;
          break;
        case ALU_OP_SHL:
          alu_result = ex_in.src_a << ex_in.src_b;
          break;
        case ALU_OP_ASR:
          alu_result = static_cast<uint32_t>(static_cast<int32_t>(ex_in.src_a) >>
                                             static_cast<int32_t>(ex_in.src_b));
          break;
        case ALU_OP_LSR:
          alu_result = ex_in.src_a >> ex_in.src_b;
          break;
        case ALU_OP_EXTB:
          alu_result = (ex_in.src_a & 0x000000ffu) | ((ex_in.src_a & 0x00000080u) ? 0xffffff00u : 0u);
          break;
        case ALU_OP_EXTH:
          alu_result =
              (ex_in.src_a & 0x0000ffffu) | ((ex_in.src_a & 0x00008000u) ? 0xffff0000u : 0u);
          break;
        case ALU_OP_MIXH:
          alu_result = (ex_in.src_a & 0x0000ffffu) | (ex_in.src_b << 16u);
          break;
      }

      mem_in.mem_addr = alu_result;
      mem_in.dst_data = alu_result;
      mem_in.dst_reg = ex_in.dst_reg;
      mem_in.mem_op = ex_in.mem_op;
      mem_in.store_data = ex_in.store_data;
    }

    // MEM
    wb_in_t wb_in;
    {
      uint32_t mem_result = 0u;
      switch (mem_in.mem_op) {
        case MEM_OP_LOAD8:
          mem_result = m_dcache.read8(mem_in.mem_addr);
          break;
        case MEM_OP_LOAD16:
          mem_result = m_dcache.read16(mem_in.mem_addr);
          break;
        case MEM_OP_LOAD32:
          mem_result = m_dcache.read32(mem_in.mem_addr);
          break;
        case MEM_OP_STORE8:
          m_dcache.write8(mem_in.mem_addr, static_cast<uint8_t>(mem_in.store_data));
          break;
        case MEM_OP_STORE16:
          m_dcache.write16(mem_in.mem_addr, static_cast<uint16_t>(mem_in.store_data));
          break;
        case MEM_OP_STORE32:
          m_dcache.write32(mem_in.mem_addr, mem_in.store_data);
          break;
      }

      wb_in.dst_data = (mem_in.mem_op != MEM_OP_NONE) ? mem_result : mem_in.dst_data;
      wb_in.dst_reg = mem_in.dst_reg;
    }

    // WB
    if (wb_in.dst_reg > REG_PC) {
      m_regs[wb_in.dst_reg] = wb_in.dst_data;
    }

    m_regs[REG_PC] = next_pc;
    cycles += instr_cycles;
  }

  return m_exit_code;
}
