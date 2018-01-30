//--------------------------------------------------------------------------------------------------
// Copyright (c) 2018 Marcus Geelnard
//
// This software is provided 'as-is', without any express or implied warranty. In no event will the
// authors be held liable for any damages arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose, including commercial
// applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not claim that you wrote
//     the original software. If you use this software in a product, an acknowledgment in the
//     product documentation would be appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be misrepresented as
//     being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//--------------------------------------------------------------------------------------------------

#include "cpu_simple.hpp"

#include <cstring>
#include <exception>

namespace {
struct id_in_t {
  uint32_t pc;     // PC for the current instruction.
  uint32_t instr;  // Instruction.
};

struct ex_in_t {
  uint32_t src_a;   // Source operand A.
  uint32_t src_b;   // Source operand B.
  uint32_t alu_op;  // ALU operation.
  uint32_t md_op;   // Mul/Div operation.
  uint32_t fpu_op;  // FPU operation.

  uint32_t mem_op;      // MEM operation.
  uint32_t store_data;  // Data to be stored in the mem step.

  uint32_t dst_reg;    // Target register for the instruction (0 = none).
  uint32_t dst_idx;    // Target register index (for vector registers).
  bool dst_is_vector;  // Target register is a vector register.
};

struct mem_in_t {
  uint32_t mem_op;      // MEM operation.
  uint32_t mem_addr;    // Address for the MEM operation.
  uint32_t store_data;  // Data to be stored in the MEM step.
  uint32_t dst_data;    // Data to be written in the WB step (result from ALU).
  uint32_t dst_reg;     // Target register for the instruction (0 = none).
  uint32_t dst_idx;     // Target register index (for vector registers).
  bool dst_is_vector;   // Target register is a vector register.
};

struct wb_in_t {
  uint32_t dst_data;   // Data to be written in the WB step.
  uint32_t dst_reg;    // Target register for the instruction (0 = none).
  uint32_t dst_idx;    // Target register index (for vector registers).
  bool dst_is_vector;  // Target register is a vector register.
};

struct vector_state_t {
  uint32_t idx;          // Current vector index.
  uint32_t addr_offset;  // Current address offset (incremented by load/store stride).
  bool active;           // True if a vector operation is currently active.
};

inline uint32_t add32(const uint32_t a, const uint32_t b) {
  return a + b;
}

inline uint32_t clz32(const uint32_t x) {
#if defined(__GNUC__) || defined(__clang__)
  return static_cast<uint32_t>(__builtin_clz(x));
#else
  uint32_t count = 0u;
  for (; (count != 32u) && ((x & (0x80000000u >> count)) == 0u); ++count)
    ;
  return count;
#endif
}

inline uint32_t rev32(const uint32_t x) {
  return ((x >> 31u) & 0x00000001u) | ((x >> 29u) & 0x00000002u) | ((x >> 27u) & 0x00000004u) |
         ((x >> 25u) & 0x00000008u) | ((x >> 23u) & 0x00000010u) | ((x >> 21u) & 0x00000020u) |
         ((x >> 19u) & 0x00000040u) | ((x >> 17u) & 0x00000080u) | ((x >> 15u) & 0x00000100u) |
         ((x >> 13u) & 0x00000200u) | ((x >> 11u) & 0x00000400u) | ((x >> 9u) & 0x00000800u) |
         ((x >> 7u) & 0x00001000u) | ((x >> 5u) & 0x00002000u) | ((x >> 3u) & 0x00004000u) |
         ((x >> 1u) & 0x00008000u) | ((x << 1u) & 0x00010000u) | ((x << 3u) & 0x00020000u) |
         ((x << 5u) & 0x00040000u) | ((x << 7u) & 0x00080000u) | ((x << 9u) & 0x00100000u) |
         ((x << 11u) & 0x00200000u) | ((x << 13u) & 0x00400000u) | ((x << 15u) & 0x00800000u) |
         ((x << 17u) & 0x01000000u) | ((x << 19u) & 0x02000000u) | ((x << 21u) & 0x04000000u) |
         ((x << 23u) & 0x08000000u) | ((x << 25u) & 0x10000000u) | ((x << 27u) & 0x20000000u) |
         ((x << 29u) & 0x40000000u) | ((x << 31u) & 0x80000000u);
}

inline uint32_t shuf32(const uint32_t x, const uint32_t idx) {
  uint8_t xv[4];
  xv[0] = static_cast<uint8_t>(x);
  xv[1] = static_cast<uint8_t>(x >> 8u);
  xv[2] = static_cast<uint8_t>(x >> 16u);
  xv[3] = static_cast<uint8_t>(x >> 24u);
  uint8_t idxv[4];
  idxv[0] = static_cast<uint8_t>(idx & 7u);
  idxv[1] = static_cast<uint8_t>((idx >> 3u) & 7u);
  idxv[2] = static_cast<uint8_t>((idx >> 6u) & 7u);
  idxv[3] = static_cast<uint8_t>((idx >> 9u) & 7u);

  uint8_t yv[4];
  yv[0] = (idxv[0] & 4u) ? 0u : xv[idxv[0]];
  yv[1] = (idxv[1] & 4u) ? 0u : xv[idxv[1]];
  yv[2] = (idxv[2] & 4u) ? 0u : xv[idxv[2]];
  yv[3] = (idxv[3] & 4u) ? 0u : xv[idxv[3]];

  return static_cast<uint32_t>(yv[0]) | (static_cast<uint32_t>(yv[1]) << 8u) |
         (static_cast<uint32_t>(yv[2]) << 16u) | (static_cast<uint32_t>(yv[3]) << 24u);
}

inline float as_f32(const uint32_t x) {
  float result;
  std::memcpy(&result, &x, sizeof(float));
  return result;
}

inline uint32_t as_u32(const float x) {
  uint32_t result;
  std::memcpy(&result, &x, sizeof(uint32_t));
  return result;
}

inline uint32_t s8_as_u32(const int8_t x) {
  return static_cast<uint32_t>(static_cast<int32_t>(x));
}

inline uint32_t u8_as_u32(const uint8_t x) {
  return static_cast<uint32_t>(x);
}

inline uint32_t s16_as_u32(const int16_t x) {
  return static_cast<uint32_t>(static_cast<int32_t>(x));
}

inline uint32_t u16_as_u32(const uint16_t x) {
  return static_cast<uint32_t>(x);
}

}  // namespace

uint32_t cpu_simple_t::run(const uint32_t addr, const uint32_t sp) {
  m_regs[REG_PC] = addr;
  m_regs[REG_SP] = sp;
  m_terminate = false;
  m_exit_code = 0u;
  m_fetched_instr_count = 0u;
  m_vector_loop_count = 0u;
  m_total_cycle_count = 0u;

  // Initialize the pipeline state.
  vector_state_t vector = vector_state_t();
  id_in_t id_in = id_in_t();
  ex_in_t ex_in = ex_in_t();
  mem_in_t mem_in = mem_in_t();
  wb_in_t wb_in = wb_in_t();

  while (!m_terminate) {
    uint32_t instr_cycles = 1u;
    uint32_t next_pc;
    bool next_cycle_continues_a_vector_loop;

    // Simulator routine call handling.
    // Simulator routines start at PC = 0xffff0000.
    if ((m_regs[REG_PC] & 0xffff0000u) == 0xffff0000u) {
      // Call the routine.
      const uint32_t routine_no = (m_regs[REG_PC] - 0xffff0000u) >> 2u;
      call_sim_routine(routine_no);

      // Simulate jmp lr.
      m_regs[REG_PC] = m_regs[REG_LR];
    }

    // We stall the IF stage when a vector operation is active.
    if (!vector.active) {
      // IF
      {
        const uint32_t instr_pc = m_regs[REG_PC];

        // Read the instruction from the current (predicted) PC.
        id_in.pc = instr_pc;
        uint32_t cache_cycles;
        id_in.instr = m_icache.read32(instr_pc, cache_cycles);
        instr_cycles += cache_cycles;

        ++m_fetched_instr_count;
      }
    } else {
      ++m_vector_loop_count;
    }

    // ID
    {
      // Get the scalar instruction (mask off vector control bits).
      const uint32_t sclar_instr = id_in.instr & 0x3fffffffu;

      // Is this a vector operation?
      const bool is_vector_op = ((id_in.instr & 0xc0000000u) != 0u);

      // Detect encoding class (A, B, C or D).
      const bool op_class_A = ((sclar_instr & 0x3f000000u) == 0x00000000u);
      const bool op_class_B = ((sclar_instr & 0x30000000u) < 0x20000000u) && !op_class_A;
      const bool op_class_C = ((sclar_instr & 0x20000000u) == 0x20000000u);

      // Extract parts of the instruction.
      // NOTE: These may or may not be valid, depending on the instruction type.
      const uint32_t reg1 = (sclar_instr >> 19u) & 31u;
      const uint32_t reg2 = (sclar_instr >> 14u) & 31u;
      const uint32_t reg3 = (sclar_instr >> 9u) & 31u;
      const uint32_t imm14 =
          (sclar_instr & 0x00003fffu) | ((sclar_instr & 0x00002000u) ? 0xffffc000u : 0u);
      const uint32_t imm19 =
          (sclar_instr & 0x0007ffffu) | ((sclar_instr & 0x00040000u) ? 0xfff80000u : 0u);

      // == VECTOR STATE HANDLING ==

      if (is_vector_op) {
        // Start a new or continue an ongoing vector operartion?
        if (!vector.active) {
          vector.idx = 0u;
          vector.addr_offset = 0u;
        } else {
          // Do vector offset increments in the ID stage (in a HW implementation we probably want to
          // prepare these values one cycle ahead of time).
          ++vector.idx;                 // 5- or 6-bit adder.
          vector.addr_offset += imm14;  // 19-bit adder + sign-extend to 32 bits.
        }
      }

      // Check if the next cycle will continue a vector loop (i.e. we should stall the IF stage).
      next_cycle_continues_a_vector_loop =
          is_vector_op && (vector.idx < (m_regs[REG_VC] & (NUM_VECTOR_ENTRIES - 1)));

      // == BRANCH & CONDITIONAL MOVES ==

      const bool is_bcc = ((sclar_instr & 0xf0000000u) == 0x20000000u);
      const bool is_bcc_and_link = ((sclar_instr & 0xf8000000u) == 0x28000000u);
      const bool is_jmp_jsr = ((sclar_instr & 0xff0001f0u) == 0x00000080u);
      const bool is_branch = is_bcc || is_jmp_jsr;
      const bool is_subroutine_branch = ((sclar_instr & 0xff0001ffu) == 0x00000081u) ||  // jsr
                                        is_bcc_and_link;

      const bool is_cond_move = ((sclar_instr & 0xff0001f0u) == 0x00000020u);

      // Branch source register is reg1 (for b[cc] and jmp/jsr), and reg2 for m[cc].
      const uint32_t branch_cond_reg =
          is_cond_move ? reg2 : ((is_bcc || is_jmp_jsr) ? reg1 : REG_Z);

      // Read the branch/condition register.
      // TODO(m): We should share a register read-port with the other register reads further down.
      const uint32_t branch_cond_value = m_regs[branch_cond_reg];

      // Evaluate condition (for b[cc] and m[cc]).
      const uint32_t condition = (is_cond_move ? sclar_instr : (sclar_instr >> 24u)) & 0x00000027u;
      bool condition_satisfied = false;
      switch (condition) {
        case 0x20u:  // beq/bleq/meq
          condition_satisfied = (branch_cond_value == 0u);
          break;
        case 0x21u:  // bne/blne/mne
          condition_satisfied = (branch_cond_value != 0u);
          break;
        case 0x22u:  // bge/blge/mge
          condition_satisfied = ((branch_cond_value & 0x80000000u) == 0u);
          break;
        case 0x23u:  // bgt/blgt/mgt
          condition_satisfied =
              ((branch_cond_value & 0x80000000u) == 0u) && (branch_cond_value != 0u);
          break;
        case 0x24u:  // ble/blle/mle
          condition_satisfied =
              ((branch_cond_value & 0x80000000u) != 0u) || (branch_cond_value == 0u);
          break;
        case 0x25u:  // blt/bllt/mlt
          condition_satisfied = ((branch_cond_value & 0x80000000u) != 0u);
          break;
      }

      bool branch_taken = false;
      uint32_t branch_target = 0u;

      // b[cc]/bl[cc]?
      if (is_bcc) {
        branch_taken = condition_satisfied;
        branch_target = id_in.pc + (imm19 << 2u);
      }

      // jmp/jsr?
      if (is_jmp_jsr) {
        branch_taken = true;
        branch_target = branch_cond_value;
      }

      next_pc = branch_taken ? branch_target : (id_in.pc + 4u);

      // == DECODE ==

      // Is this a mem load/store operation?
      const bool is_ldx = (sclar_instr & 0xff0001f8u) == 0x00000010u;
      const bool is_ld = (sclar_instr & 0xf8000000u) == 0x10000000u;
      const bool is_mem_load = is_ldx || is_ld;
      const bool is_stx = ((sclar_instr & 0xff0001f8u) == 0x00000018u);
      const bool is_st = ((sclar_instr & 0xf8000000u) == 0x18000000u);
      const bool is_mem_store = is_stx || is_st;
      const bool is_mem_op = (is_mem_load || is_mem_store);

      // Should we use reg1 as a source?
      const bool reg1_is_src = is_mem_store || is_jmp_jsr;

      // Should we use reg2 as a source?
      const bool reg2_is_src = (op_class_A || op_class_B) && !is_cond_move;

      // Should we use reg3 as a source?
      const bool reg3_is_src = op_class_A;

      // Should we use reg1 as a destination?
      const bool reg1_is_dst =
          !reg1_is_src && !is_branch && !(is_cond_move && !condition_satisfied);

      // Determine the source & destination register numbers (zero for none).
      const uint32_t src_reg_a = is_subroutine_branch ? REG_PC : (reg2_is_src ? reg2 : REG_Z);
      const uint32_t src_reg_b = reg3_is_src ? reg3 : REG_Z;
      const uint32_t src_reg_c = is_mem_store ? reg1 : REG_Z;
      const uint32_t dst_reg =
          (is_subroutine_branch && branch_taken) ? REG_LR : (reg1_is_dst ? reg1 : REG_Z);

      // Determine ALU operation.
      uint32_t alu_op = ALU_OP_NONE;
      if (is_subroutine_branch || is_mem_op) {
        alu_op = ALU_OP_ADD;
      } else if (op_class_A && (sclar_instr & 0x000001f0u) == 0x00000000u) {
        alu_op = sclar_instr & 0x000001ff;
      } else if (op_class_A && (sclar_instr & 0x000001f0u) == 0x00000050u) {
        alu_op = sclar_instr & 0x000001ff;
      } else if (op_class_B && (sclar_instr & 0xff000000u) <= 0x0b000000u) {
        alu_op = sclar_instr >> 24u;
      } else if (op_class_C) {
        switch (sclar_instr & 0xff000000u) {
          case 0x30000000u:  // ldi
            alu_op = ALU_OP_OR;
            break;
          case 0x31000000u:  // ldhi
            alu_op = ALU_OP_LDHI;
            break;
          case 0x32000000u:  // ldhio
            alu_op = ALU_OP_LDHIO;
            break;
        }
      } else if (is_cond_move && condition_satisfied) {
        alu_op = ALU_OP_OR;
      }

      // Determine MD operation.
      uint32_t md_op = MD_OP_NONE;
      if (op_class_A && (sclar_instr & 0x000001f8u) == 0x00000030u) {
        md_op = sclar_instr & 0x000001ff;
      }

      // Determine FPU operation.
      uint32_t fpu_op = FPU_OP_NONE;
      if (op_class_A && (sclar_instr & 0x000001f8u) == 0x00000038u) {
        fpu_op = sclar_instr & 0x000001ff;
      }

      // Determine MEM operation.
      uint32_t mem_op = MEM_OP_NONE;
      if (is_mem_load) {
        mem_op = (is_ldx ? (sclar_instr & 0x000001ffu) : (sclar_instr >> 24u));
      } else if (is_mem_store) {
        mem_op = (is_stx ? (sclar_instr & 0x000001ffu) : (sclar_instr >> 24u));
      }

      // Check what type of registers should be used (vector or scalar).
      const bool reg1_is_vector = is_vector_op;
      const bool reg2_is_vector = ((id_in.instr & 0x80000000u) != 0u) && !is_mem_op;
      const bool reg3_is_vector = ((id_in.instr & 0x40000000u) != 0u);

      // Read from the register files.
      const uint32_t reg_a_data =
          reg2_is_vector ? m_vregs[src_reg_a][vector.idx] : m_regs[src_reg_a];
      const uint32_t reg_b_data =
          reg3_is_vector ? m_vregs[src_reg_b][vector.idx] : m_regs[src_reg_b];
      const uint32_t reg_c_data =
          reg1_is_vector ? m_vregs[src_reg_c][vector.idx] : m_regs[src_reg_c];

      // Output of the ID step.
      ex_in.src_a = reg_a_data;
      ex_in.src_b = is_subroutine_branch
                        ? 4
                        : (op_class_B ? ((is_vector_op && is_mem_op) ? vector.addr_offset : imm14)
                                      : (op_class_C ? imm19 : reg_b_data));
      ex_in.store_data = reg_c_data;
      ex_in.dst_reg = dst_reg;
      ex_in.dst_idx = vector.idx;
      ex_in.dst_is_vector = is_vector_op;
      ex_in.alu_op = alu_op;
      ex_in.md_op = md_op;
      ex_in.fpu_op = fpu_op;
      ex_in.mem_op = mem_op;
    }

    // EX
    {
      uint32_t ex_result = 0u;

      // ALU (single-cycle integer operations).
      switch (ex_in.alu_op) {
        case ALU_OP_OR:
          ex_result = ex_in.src_a | ex_in.src_b;
          break;
        case ALU_OP_NOR:
          ex_result = ~(ex_in.src_a | ex_in.src_b);
          break;
        case ALU_OP_AND:
          ex_result = ex_in.src_a & ex_in.src_b;
          break;
        case ALU_OP_XOR:
          ex_result = ex_in.src_a ^ ex_in.src_b;
          break;
        case ALU_OP_ADD:
          ex_result = add32(ex_in.src_a, ex_in.src_b);
          break;
        case ALU_OP_SUB:
          ex_result = add32((~ex_in.src_a) + 1u, ex_in.src_b);
          break;
        case ALU_OP_SLT:
          ex_result =
              (static_cast<int32_t>(ex_in.src_a) < static_cast<int32_t>(ex_in.src_b)) ? 1u : 0u;
          break;
        case ALU_OP_SLTU:
          ex_result = (ex_in.src_a < ex_in.src_b) ? 1u : 0u;
          break;
        case ALU_OP_LSL:
          ex_result = ex_in.src_a << ex_in.src_b;
          break;
        case ALU_OP_ASR:
          ex_result = static_cast<uint32_t>(static_cast<int32_t>(ex_in.src_a) >>
                                            static_cast<int32_t>(ex_in.src_b));
          break;
        case ALU_OP_LSR:
          ex_result = ex_in.src_a >> ex_in.src_b;
          break;
        case ALU_OP_SHUF:
          ex_result = shuf32(ex_in.src_a, ex_in.src_b);
          break;
        case ALU_OP_CLZ:
          ex_result = clz32(ex_in.src_a);
          break;
        case ALU_OP_REV:
          ex_result = rev32(ex_in.src_a);
          break;
        case ALU_OP_EXTB:
          ex_result = s8_as_u32(static_cast<int8_t>(ex_in.src_a));
          break;
        case ALU_OP_EXTH:
          ex_result = s16_as_u32(static_cast<int16_t>(ex_in.src_a));
          break;
        case ALU_OP_LDHI:
          ex_result = ex_in.src_b << 13u;
          break;
        case ALU_OP_LDHIO:
          ex_result = (ex_in.src_b << 13u) | 0x1fffu;
          break;
      }

      // Mul/Div (multi-cycle integer operations).
      switch (ex_in.md_op) {
        case MD_OP_MUL:
          ex_result = ex_in.src_a * ex_in.src_b;
          break;
        case MD_OP_MULHI:
          ex_result =
              static_cast<uint32_t>((static_cast<int64_t>(static_cast<int32_t>(ex_in.src_a)) *
                                     static_cast<int64_t>(static_cast<int32_t>(ex_in.src_b))) >>
                                    32u);
          break;
        case MD_OP_MULHIU:
          ex_result = static_cast<uint32_t>(
              (static_cast<uint64_t>(ex_in.src_a) * static_cast<uint64_t>(ex_in.src_b)) >> 32u);
          break;
        case MD_OP_DIV:
          ex_result = static_cast<uint32_t>(static_cast<int32_t>(ex_in.src_a) /
                                            static_cast<int32_t>(ex_in.src_b));
          break;
        case MD_OP_DIVU:
          ex_result = ex_in.src_a / ex_in.src_b;
          break;
        case MD_OP_REM:
          // TODO(m): Implement me!
          throw std::runtime_error("REM is not yet implemented.");
        case MD_OP_REMU:
          // TODO(m): Implement me!
          throw std::runtime_error("REMU is not yet implemented.");
      }

      // FPU (multi-cycle floating point operations).
      switch (ex_in.fpu_op) {
        case FPU_OP_ITOF:
          ex_result = as_u32(static_cast<float>(static_cast<int32_t>(ex_in.src_a)));
          break;
        case FPU_OP_FTOI:
          ex_result = static_cast<uint32_t>((static_cast<int32_t>(as_f32(ex_in.src_a))));
          break;
        case FPU_OP_ADD:
          ex_result = static_cast<uint32_t>(as_u32(as_f32(ex_in.src_a) + as_f32(ex_in.src_b)));
          break;
        case FPU_OP_SUB:
          ex_result = static_cast<uint32_t>(as_u32(as_f32(ex_in.src_a) - as_f32(ex_in.src_b)));
          break;
        case FPU_OP_MUL:
          ex_result = static_cast<uint32_t>(as_u32(as_f32(ex_in.src_a) * as_f32(ex_in.src_b)));
          break;
        case FPU_OP_DIV:
          ex_result = static_cast<uint32_t>(as_u32(as_f32(ex_in.src_a) / as_f32(ex_in.src_b)));
          break;
      }

      mem_in.mem_addr = ex_result;
      mem_in.dst_data = ex_result;
      mem_in.dst_reg = ex_in.dst_reg;
      mem_in.dst_idx = ex_in.dst_idx;
      mem_in.dst_is_vector = ex_in.dst_is_vector;
      mem_in.mem_op = ex_in.mem_op;
      mem_in.store_data = ex_in.store_data;
    }

    // MEM
    {
      uint32_t mem_result = 0u;
      uint32_t cache_cycles = 0u;
      switch (mem_in.mem_op) {
        case MEM_OP_LOAD8:
          mem_result =
              s8_as_u32(static_cast<int8_t>(m_dcache.read8(mem_in.mem_addr, cache_cycles)));
          break;
        case MEM_OP_LOADU8:
          mem_result = u8_as_u32(m_dcache.read8(mem_in.mem_addr, cache_cycles));
          break;
        case MEM_OP_LOAD16:
          mem_result =
              s16_as_u32(static_cast<int16_t>(m_dcache.read16(mem_in.mem_addr, cache_cycles)));
          break;
        case MEM_OP_LOADU16:
          mem_result = u16_as_u32(m_dcache.read16(mem_in.mem_addr, cache_cycles));
          break;
        case MEM_OP_LOAD32:
          mem_result = m_dcache.read32(mem_in.mem_addr, cache_cycles);
          break;
        case MEM_OP_STORE8:
          m_dcache.write8(mem_in.mem_addr, static_cast<uint8_t>(mem_in.store_data), cache_cycles);
          break;
        case MEM_OP_STORE16:
          m_dcache.write16(mem_in.mem_addr, static_cast<uint16_t>(mem_in.store_data), cache_cycles);
          break;
        case MEM_OP_STORE32:
          m_dcache.write32(mem_in.mem_addr, mem_in.store_data, cache_cycles);
          break;
      }
      instr_cycles += cache_cycles;

      wb_in.dst_data = (mem_in.mem_op != MEM_OP_NONE) ? mem_result : mem_in.dst_data;
      wb_in.dst_reg = mem_in.dst_reg;
      wb_in.dst_idx = mem_in.dst_idx;
      wb_in.dst_is_vector = mem_in.dst_is_vector;
    }

    // WB
    if (wb_in.dst_reg != REG_Z) {
      if (wb_in.dst_is_vector) {
        m_vregs[wb_in.dst_reg][wb_in.dst_idx] = wb_in.dst_data;
      } else if (wb_in.dst_reg != REG_PC) {
        m_regs[wb_in.dst_reg] = wb_in.dst_data;
      }
    }

    // Update the vector operation state.
    vector.active = next_cycle_continues_a_vector_loop;

    // Only update the PC if no vector operation is active.
    if (!next_cycle_continues_a_vector_loop) {
      m_regs[REG_PC] = next_pc;
    }

    m_total_cycle_count += instr_cycles;
  }

  return m_exit_code;
}
