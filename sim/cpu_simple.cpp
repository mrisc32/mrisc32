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

#include <cmath>
#include <cstring>
#include <exception>

namespace {
struct id_in_t {
  uint32_t pc;     // PC for the current instruction.
  uint32_t instr;  // Instruction.
};

struct ex_in_t {
  uint32_t src_a;        // Source operand A.
  uint32_t src_b;        // Source operand B.
  uint32_t src_c;        // Source operand C / Data to be stored in the mem step.
  uint32_t ex_op;        // EX operation.
  uint32_t packed_mode;  // Packed operation mode.

  uint32_t mem_op;  // MEM operation.

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
  uint32_t stride;       // Stride for vector memory address calculations.
  uint32_t addr_offset;  // Current address offset (incremented by load/store stride).
  bool folding;          // True if this is a folding vector op.
  bool active;           // True if a vector operation is currently active.
};

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

inline uint32_t add32(const uint32_t a, const uint32_t b) {
  return a + b;
}

inline uint32_t add16x2(const uint32_t a, const uint32_t b) {
  const uint32_t hi = (a & 0xffff0000u) + (b & 0xffff0000u);
  const uint32_t lo = (a + b) & 0x0000ffffu;
  return hi | lo;
}

inline uint32_t add8x4(const uint32_t a, const uint32_t b) {
  const uint32_t hi = ((a & 0xff00ff00u) + (b & 0xff00ff00u)) & 0xff00ff00u;
  const uint32_t lo = ((a & 0x00ff00ffu) + (b & 0x00ff00ffu)) & 0x00ff00ffu;
  return hi | lo;
}

inline uint32_t sub32(const uint32_t a, const uint32_t b) {
  return add32((~a) + 1u, b);
}

inline uint32_t sub16x2(const uint32_t a, const uint32_t b) {
  return add16x2(add16x2(~a, 0x00010001u), b);
}

inline uint32_t sub8x4(const uint32_t a, const uint32_t b) {
  return add8x4(add8x4(~a, 0x01010101u), b);
}

inline uint32_t set32(const uint32_t a, const uint32_t b, bool (*cmp)(uint32_t, uint32_t)) {
  return cmp(a, b) ? 0xffffffffu : 0u;
}

inline uint32_t set16x2(const uint32_t a, const uint32_t b, bool (*cmp)(uint16_t, uint16_t)) {
  const uint32_t h1 =
      (cmp(static_cast<uint16_t>(a >> 16), static_cast<uint16_t>(b >> 16)) ? 0xffff0000u : 0u);
  const uint32_t h0 = (cmp(static_cast<uint16_t>(a), static_cast<uint16_t>(b)) ? 0x0000ffffu : 0u);
  return h1 | h0;
}

inline uint32_t set8x4(const uint32_t a, const uint32_t b, bool (*cmp)(uint8_t, uint8_t)) {
  const uint32_t b3 =
      (cmp(static_cast<uint8_t>(a >> 24), static_cast<uint8_t>(b >> 24)) ? 0xff000000u : 0u);
  const uint32_t b2 =
      (cmp(static_cast<uint8_t>(a >> 16), static_cast<uint8_t>(b >> 16)) ? 0x00ff0000u : 0u);
  const uint32_t b1 =
      (cmp(static_cast<uint8_t>(a >> 8), static_cast<uint8_t>(b >> 8)) ? 0x0000ff00u : 0u);
  const uint32_t b0 = (cmp(static_cast<uint8_t>(a), static_cast<uint8_t>(b)) ? 0x000000ffu : 0u);
  return b3 | b2 | b1 | b0;
}

inline uint32_t sel32(const uint32_t a, const uint32_t b, const uint32_t mask) {
  return (a & mask) | (b & ~mask);
}

inline uint32_t asr32(const uint32_t a, const uint32_t b) {
  return static_cast<uint32_t>(static_cast<int32_t>(a) >> static_cast<int32_t>(b));
}

inline uint32_t asr16x2(const uint32_t a, const uint32_t b) {
  const auto h1 = static_cast<uint32_t>(static_cast<uint16_t>(static_cast<int16_t>(a >> 16) >> b));
  const auto h0 = static_cast<uint32_t>(static_cast<uint16_t>(static_cast<int16_t>(a) >> b));
  return (h1 << 16) | h0;
}

inline uint32_t asr8x4(const uint32_t a, const uint32_t b) {
  const auto b3 = static_cast<uint32_t>(static_cast<uint8_t>(static_cast<int8_t>(a >> 24) >> b));
  const auto b2 = static_cast<uint32_t>(static_cast<uint8_t>(static_cast<int8_t>(a >> 16) >> b));
  const auto b1 = static_cast<uint32_t>(static_cast<uint8_t>(static_cast<int8_t>(a >> 8) >> b));
  const auto b0 = static_cast<uint32_t>(static_cast<uint8_t>(static_cast<int8_t>(a) >> b));
  return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
}

inline uint32_t lsl32(const uint32_t a, const uint32_t b) {
  return a << b;
}

inline uint32_t lsl16x2(const uint32_t a, const uint32_t b) {
  const auto h1 = (a & 0xffff0000u) << b;
  const auto h0 = (a << b) & 0x0000ffffu;
  return h1 | h0;
}

inline uint32_t lsl8x4(const uint32_t a, const uint32_t b) {
  const auto b3 = (a & 0xff000000u) << b;
  const auto b2 = ((a & 0x00ff0000u) << b) & 0x00ff0000u;
  const auto b1 = ((a & 0x0000ff00u) << b) & 0x0000ff00u;
  const auto b0 = (a << b) & 0x000000ffu;
  return b3 | b2 | b1 | b0;
}

inline uint32_t lsr32(const uint32_t a, const uint32_t b) {
  return a >> b;
}

inline uint32_t lsr16x2(const uint32_t a, const uint32_t b) {
  const auto h1 = (a >> b) & 0xffff0000u;
  const auto h0 = (a & 0x0000ffffu) >> b;
  return h1 | h0;
}

inline uint32_t lsr8x4(const uint32_t a, const uint32_t b) {
  const auto b3 = (a >> b) & 0xff000000u;
  const auto b2 = ((a & 0x00ff0000u) >> b) & 0x00ff0000u;
  const auto b1 = ((a & 0x0000ff00u) >> b) & 0x0000ff00u;
  const auto b0 = (a & 0x000000ffu) >> b;
  return b3 | b2 | b1 | b0;
}

inline uint32_t mulq31(const uint32_t a, const uint32_t b) {
  const int64_t p =
      static_cast<int64_t>(static_cast<int32_t>(a)) * static_cast<int64_t>(static_cast<int32_t>(b));
  return static_cast<uint32_t>(p >> 31u);
}

inline uint32_t mulq15x2(const uint32_t a, const uint32_t b) {
  const auto a1 = static_cast<int32_t>(static_cast<int16_t>(a >> 16u));
  const auto a0 = static_cast<int32_t>(static_cast<int16_t>(a));
  const auto b1 = static_cast<int32_t>(static_cast<int16_t>(b >> 16u));
  const auto b0 = static_cast<int32_t>(static_cast<int16_t>(b));
  const auto c1 = static_cast<uint32_t>((a1 * b1) << 1) & 0xffff0000u;
  const auto c0 = static_cast<uint32_t>(a0 * b0) >> 15u;
  return c1 | c0;
}

inline uint32_t mulq7x4(const uint32_t a, const uint32_t b) {
  const auto a3 = static_cast<int32_t>(static_cast<int8_t>(a >> 24u));
  const auto a2 = static_cast<int32_t>(static_cast<int8_t>(a >> 16u));
  const auto a1 = static_cast<int32_t>(static_cast<int8_t>(a >> 8u));
  const auto a0 = static_cast<int32_t>(static_cast<int8_t>(a));
  const auto b3 = static_cast<int32_t>(static_cast<int8_t>(b >> 24u));
  const auto b2 = static_cast<int32_t>(static_cast<int8_t>(b >> 16u));
  const auto b1 = static_cast<int32_t>(static_cast<int8_t>(b >> 8u));
  const auto b0 = static_cast<int32_t>(static_cast<int8_t>(b));
  const auto c3 = (static_cast<uint32_t>(a3 * b3) & 0x00007f80u) << 17u;
  const auto c2 = (static_cast<uint32_t>(a2 * b2) & 0x00007f80u) << 9u;
  const auto c1 = (static_cast<uint32_t>(a1 * b1) & 0x00007f80u) << 1u;
  const auto c0 = (static_cast<uint32_t>(a0 * b0) & 0x00007f80u) >> 7u;
  return c3 | c2 | c1 | c0;
}

inline uint32_t mul32(const uint32_t a, const uint32_t b) {
  return a * b;
}

inline uint32_t mul16x2(const uint32_t a, const uint32_t b) {
  const auto h1 = (a >> 16) * (b >> 16) << 16;
  const auto h0 = (a * b) & 0x0000ffffu;
  return h1 | h0;
}

inline uint32_t mul8x4(const uint32_t a, const uint32_t b) {
  const auto b3 = (a >> 24) * (b >> 24) << 24;
  const auto b2 = (((a >> 16) * (b >> 16)) & 0x000000ffu) << 16;
  const auto b1 = (((a >> 8) * (b >> 8)) & 0x000000ffu) << 8;
  const auto b0 = (a * b) & 0x000000ffu;
  return b3 | b2 | b1 | b0;
}

inline uint32_t mulhi32(const uint32_t a, const uint32_t b) {
  const int64_t p =
      static_cast<int64_t>(static_cast<int32_t>(a)) * static_cast<int64_t>(static_cast<int32_t>(b));
  return static_cast<uint32_t>(p >> 32u);
}

inline uint32_t mulhi16x2(const uint32_t a, const uint32_t b) {
  const auto a1 = static_cast<int32_t>(static_cast<int16_t>(a >> 16u));
  const auto a0 = static_cast<int32_t>(static_cast<int16_t>(a));
  const auto b1 = static_cast<int32_t>(static_cast<int16_t>(b >> 16u));
  const auto b0 = static_cast<int32_t>(static_cast<int16_t>(b));
  const auto c1 = static_cast<uint32_t>(a1 * b1) & 0xffff0000u;
  const auto c0 = static_cast<uint32_t>(a0 * b0) >> 16u;
  return c1 | c0;
}

inline uint32_t mulhi8x4(const uint32_t a, const uint32_t b) {
  const auto a3 = static_cast<int32_t>(static_cast<int8_t>(a >> 24u));
  const auto a2 = static_cast<int32_t>(static_cast<int8_t>(a >> 16u));
  const auto a1 = static_cast<int32_t>(static_cast<int8_t>(a >> 8u));
  const auto a0 = static_cast<int32_t>(static_cast<int8_t>(a));
  const auto b3 = static_cast<int32_t>(static_cast<int8_t>(b >> 24u));
  const auto b2 = static_cast<int32_t>(static_cast<int8_t>(b >> 16u));
  const auto b1 = static_cast<int32_t>(static_cast<int8_t>(b >> 8u));
  const auto b0 = static_cast<int32_t>(static_cast<int8_t>(b));
  const auto c3 = (static_cast<uint32_t>(a3 * b3) & 0x0000ff00u) << 16u;
  const auto c2 = (static_cast<uint32_t>(a2 * b2) & 0x0000ff00u) << 8u;
  const auto c1 = (static_cast<uint32_t>(a1 * b1) & 0x0000ff00u);
  const auto c0 = (static_cast<uint32_t>(a0 * b0) & 0x0000ff00u) >> 8u;
  return c3 | c2 | c1 | c0;
}

inline uint32_t mulhiu32(const uint32_t a, const uint32_t b) {
  const uint64_t p = static_cast<uint64_t>(a) * static_cast<uint64_t>(b);
  return static_cast<uint32_t>(p >> 32u);
}

inline uint32_t mulhiu16x2(const uint32_t a, const uint32_t b) {
  const auto h1 = (a >> 16) * (b >> 16) & 0xffff0000u;
  const auto h0 = ((a & 0x0000ffffu) * (b & 0x0000ffffu)) >> 16;
  return h1 | h0;
}

inline uint32_t mulhiu8x4(const uint32_t a, const uint32_t b) {
  const auto b3 = ((a & 0xff000000u) >> 16u) * ((b & 0xff000000u) >> 16u) & 0xff000000u;
  const auto b2 = (((a & 0x00ff0000u) >> 12u) * ((b & 0x00ff0000u) >> 12u)) & 0x00ff0000u;
  const auto b1 = ((a & 0x0000ff00u) >> 8u) * ((b & 0x0000ff00u) >> 8u) & 0x0000ff00u;
  const auto b0 = ((a & 0x000000ffu) * (b & 0x000000ffu)) >> 8u;
  return b3 | b2 | b1 | b0;
}

inline uint32_t div32(const uint32_t a, const uint32_t b) {
  return static_cast<uint32_t>(static_cast<int32_t>(a) / static_cast<int32_t>(b));
}

inline uint32_t div16x2(const uint32_t a, const uint32_t b) {
  const auto a1 = static_cast<int32_t>(static_cast<int16_t>(a >> 16u));
  const auto a0 = static_cast<int32_t>(static_cast<int16_t>(a));
  const auto b1 = static_cast<int32_t>(static_cast<int16_t>(b >> 16u));
  const auto b0 = static_cast<int32_t>(static_cast<int16_t>(b));
  const auto c1 = (static_cast<uint32_t>(a1 / b1) & 0x0000ffffu) << 16u;
  const auto c0 = static_cast<uint32_t>(a0 / b0) & 0x0000ffffu;
  return c1 | c0;
}

inline uint32_t div8x4(const uint32_t a, const uint32_t b) {
  const auto a3 = static_cast<int32_t>(static_cast<int8_t>(a >> 24u));
  const auto a2 = static_cast<int32_t>(static_cast<int8_t>(a >> 16u));
  const auto a1 = static_cast<int32_t>(static_cast<int8_t>(a >> 8u));
  const auto a0 = static_cast<int32_t>(static_cast<int8_t>(a));
  const auto b3 = static_cast<int32_t>(static_cast<int8_t>(b >> 24u));
  const auto b2 = static_cast<int32_t>(static_cast<int8_t>(b >> 16u));
  const auto b1 = static_cast<int32_t>(static_cast<int8_t>(b >> 8u));
  const auto b0 = static_cast<int32_t>(static_cast<int8_t>(b));
  const auto c3 = (static_cast<uint32_t>(a3 / b3) & 0x000000ffu) << 24u;
  const auto c2 = (static_cast<uint32_t>(a2 / b2) & 0x000000ffu) << 16u;
  const auto c1 = (static_cast<uint32_t>(a1 / b1) & 0x000000ffu) << 8u;
  const auto c0 = static_cast<uint32_t>(a0 / b0) & 0x000000ffu;
  return c3 | c2 | c1 | c0;
}

inline uint32_t divu32(const uint32_t a, const uint32_t b) {
  return a / b;
}

inline uint32_t divu16x2(const uint32_t a, const uint32_t b) {
  const auto a1 = a >> 16u;
  const auto a0 = a & 0x0000ffff;
  const auto b1 = b >> 16u;
  const auto b0 = b & 0x0000ffff;
  const auto c1 = (a1 / b1) << 16u;
  const auto c0 = a0 / b0;
  return c1 | c0;
}

inline uint32_t divu8x4(const uint32_t a, const uint32_t b) {
  const auto a3 = a >> 24u;
  const auto a2 = (a >> 16u) & 0x000000ff;
  const auto a1 = (a >> 8u) & 0x000000ff;
  const auto a0 = a & 0x000000ff;
  const auto b3 = b >> 24u;
  const auto b2 = (b >> 16u) & 0x000000ff;
  const auto b1 = (b >> 8u) & 0x000000ff;
  const auto b0 = b & 0x000000ff;
  const auto c3 = (a3 / b3) << 24u;
  const auto c2 = (a2 / b2) << 16u;
  const auto c1 = (a1 / b1) << 8u;
  const auto c0 = a0 / b0;
  return c3 | c2 | c1 | c0;
}

inline uint32_t rem32(const uint32_t a, const uint32_t b) {
  return static_cast<uint32_t>(static_cast<int32_t>(a) % static_cast<int32_t>(b));
}

inline uint32_t rem16x2(const uint32_t a, const uint32_t b) {
  const auto a1 = static_cast<int32_t>(static_cast<int16_t>(a >> 16u));
  const auto a0 = static_cast<int32_t>(static_cast<int16_t>(a));
  const auto b1 = static_cast<int32_t>(static_cast<int16_t>(b >> 16u));
  const auto b0 = static_cast<int32_t>(static_cast<int16_t>(b));
  const auto c1 = (static_cast<uint32_t>(a1 % b1) & 0x0000ffffu) << 16u;
  const auto c0 = static_cast<uint32_t>(a0 % b0) & 0x0000ffffu;
  return c1 | c0;
}

inline uint32_t rem8x4(const uint32_t a, const uint32_t b) {
  const auto a3 = static_cast<int32_t>(static_cast<int8_t>(a >> 24u));
  const auto a2 = static_cast<int32_t>(static_cast<int8_t>(a >> 16u));
  const auto a1 = static_cast<int32_t>(static_cast<int8_t>(a >> 8u));
  const auto a0 = static_cast<int32_t>(static_cast<int8_t>(a));
  const auto b3 = static_cast<int32_t>(static_cast<int8_t>(b >> 24u));
  const auto b2 = static_cast<int32_t>(static_cast<int8_t>(b >> 16u));
  const auto b1 = static_cast<int32_t>(static_cast<int8_t>(b >> 8u));
  const auto b0 = static_cast<int32_t>(static_cast<int8_t>(b));
  const auto c3 = (static_cast<uint32_t>(a3 % b3) & 0x000000ffu) << 24u;
  const auto c2 = (static_cast<uint32_t>(a2 % b2) & 0x000000ffu) << 16u;
  const auto c1 = (static_cast<uint32_t>(a1 % b1) & 0x000000ffu) << 8u;
  const auto c0 = static_cast<uint32_t>(a0 % b0) & 0x000000ffu;
  return c3 | c2 | c1 | c0;
}

inline uint32_t remu32(const uint32_t a, const uint32_t b) {
  return a % b;
}

inline uint32_t remu16x2(const uint32_t a, const uint32_t b) {
  const auto a1 = a >> 16u;
  const auto a0 = a & 0x0000ffff;
  const auto b1 = b >> 16u;
  const auto b0 = b & 0x0000ffff;
  const auto c1 = (a1 % b1) << 16u;
  const auto c0 = a0 % b0;
  return c1 | c0;
}

inline uint32_t remu8x4(const uint32_t a, const uint32_t b) {
  const auto a3 = a >> 24u;
  const auto a2 = (a >> 16u) & 0x000000ff;
  const auto a1 = (a >> 8u) & 0x000000ff;
  const auto a0 = a & 0x000000ff;
  const auto b3 = b >> 24u;
  const auto b2 = (b >> 16u) & 0x000000ff;
  const auto b1 = (b >> 8u) & 0x000000ff;
  const auto b0 = b & 0x000000ff;
  const auto c3 = (a3 % b3) << 24u;
  const auto c2 = (a2 % b2) << 16u;
  const auto c1 = (a1 % b1) << 8u;
  const auto c0 = a0 % b0;
  return c3 | c2 | c1 | c0;
}

inline uint32_t fadd32(const uint32_t a, const uint32_t b) {
  return as_u32(as_f32(a) + as_f32(b));
}

inline uint32_t fadd16x2(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 16-bit FADD.");
}

inline uint32_t fadd8x4(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 8-bit FADD.");
}

inline uint32_t fsub32(const uint32_t a, const uint32_t b) {
  return as_u32(as_f32(a) - as_f32(b));
}

inline uint32_t fsub16x2(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 16-bit FSUB.");
}

inline uint32_t fsub8x4(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 8-bit FSUB.");
}

inline uint32_t fmul32(const uint32_t a, const uint32_t b) {
  return as_u32(as_f32(a) * as_f32(b));
}

inline uint32_t fmul16x2(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 16-bit FMUL.");
}

inline uint32_t fmul8x4(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 8-bit FMUL.");
}

inline uint32_t fdiv32(const uint32_t a, const uint32_t b) {
  return as_u32(as_f32(a) / as_f32(b));
}

inline uint32_t fdiv16x2(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 16-bit FDIV.");
}

inline uint32_t fdiv8x4(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 8-bit FDIV.");
}

inline uint32_t fsqrt32(const uint32_t a, const uint32_t b) {
  (void)b;
  return as_u32(std::sqrt(as_f32(a)));
}

inline uint32_t fsqrt16x2(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 16-bit FDIV.");
}

inline uint32_t fsqrt8x4(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 8-bit FDIV.");
}

inline uint32_t fmin32(const uint32_t a, const uint32_t b) {
  return as_u32(std::min(as_f32(a), as_f32(b)));
}

inline uint32_t fmin16x2(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 16-bit FMIN.");
}

inline uint32_t fmin8x4(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 8-bit FMIN.");
}

inline uint32_t fmax32(const uint32_t a, const uint32_t b) {
  return as_u32(std::max(as_f32(a), as_f32(b)));
}

inline uint32_t fmax16x2(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 16-bit FMAX.");
}

inline uint32_t fmax8x4(const uint32_t a, const uint32_t b) {
  throw std::runtime_error("Not yet implemented: Packed 8-bit FMAX.");
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

inline uint8_t shuf_op(const uint8_t x, const bool fill, const bool sign_fill) {
  const uint8_t fill_bits = (sign_fill && ((x & 0x80u) != 0u)) ? 0xffu : 0x00u;
  return fill ? fill_bits : x;
}

inline uint32_t shuf32(const uint32_t x, const uint32_t idx) {
  // Extract the four bytes from x.
  uint8_t xv[4];
  xv[0] = static_cast<uint8_t>(x);
  xv[1] = static_cast<uint8_t>(x >> 8u);
  xv[2] = static_cast<uint8_t>(x >> 16u);
  xv[3] = static_cast<uint8_t>(x >> 24u);

  // Extract the four indices from idx.
  uint8_t idxv[4];
  idxv[0] = static_cast<uint8_t>(idx & 3u);
  idxv[1] = static_cast<uint8_t>((idx >> 3u) & 3u);
  idxv[2] = static_cast<uint8_t>((idx >> 6u) & 3u);
  idxv[3] = static_cast<uint8_t>((idx >> 9u) & 3u);

  // Extract the four fill operation descriptions from idx.
  bool fillv[4];
  fillv[0] = ((idx & 4u) != 0u);
  fillv[1] = ((idx & (4u << 3u)) != 0u);
  fillv[2] = ((idx & (4u << 6u)) != 0u);
  fillv[3] = ((idx & (4u << 9u)) != 0u);

  // Sign-fill or zero-fill?
  const bool sign_fill = (((idx >> 12u) & 1u) != 0u);

  // Combine the parts into four new bytes.
  uint8_t yv[4];
  yv[0] = shuf_op(xv[idxv[0]], fillv[0], sign_fill);
  yv[1] = shuf_op(xv[idxv[1]], fillv[1], sign_fill);
  yv[2] = shuf_op(xv[idxv[2]], fillv[2], sign_fill);
  yv[3] = shuf_op(xv[idxv[3]], fillv[3], sign_fill);

  // Combine the four bytes into a 32-bit word.
  return static_cast<uint32_t>(yv[0]) | (static_cast<uint32_t>(yv[1]) << 8u) |
         (static_cast<uint32_t>(yv[2]) << 16u) | (static_cast<uint32_t>(yv[3]) << 24u);
}

inline uint32_t packb32(const uint32_t a, const uint32_t b) {
  return ((a & 0x00ff0000u) << 8u) | ((a & 0x000000ffu) << 16u) | ((b & 0x00ff0000u) >> 8u) |
         (b & 0x000000ffu);
}

inline uint32_t packh32(const uint32_t a, const uint32_t b) {
  return ((a & 0x0000ffffu) << 16) | (b & 0x0000ffffu);
}

inline bool float32_isnan(const uint32_t x) {
  return ((x & 0x7F800000u) == 0x7F800000u) && ((x & 0x007fffffu) != 0u);
}

inline uint32_t itof32(const uint32_t a, const uint32_t b) {
  const float f = static_cast<float>(static_cast<int32_t>(a));
  return as_u32(std::ldexp(f, static_cast<int32_t>(b)));
}

inline uint32_t ftoi32(const uint32_t a, const uint32_t b) {
  const float f = std::ldexp(as_f32(a), static_cast<int32_t>(b));
  return static_cast<uint32_t>((static_cast<int32_t>(f)));
}
}  // namespace

uint32_t cpu_simple_t::cpuid32(const uint32_t a, const uint32_t b) {
  switch (a) {
    case 0x00000000u:
      // Number of vector elements
      if (b == 0x00000000u) {
        return NUM_VECTOR_ELEMENTS;
      } else if (b == 0x00000001u) {
        return LOG2_NUM_VECTOR_ELEMENTS;
      }

    case 0x00000001u:
      // CPU features:
      //   VEC (vector processor) = 1 << 0
      //   PO (packed operations) = 1 << 1
      //   MUL (integer mul)      = 1 << 2
      //   DIV (integer mul)      = 1 << 3
      //   FP (floating point)    = 1 << 4
      return 0x0000001fu;

    default:
      return 0u;
  }

  return 0u;
}

uint32_t cpu_simple_t::run() {
  m_regs[REG_PC] = RESET_PC;
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
        id_in.instr = m_ram.at32(instr_pc);

        // We terminate the simulation when we encounter a jump to address zero.
        if (instr_pc == 0x00000000) {
          m_terminate = true;
        }

        ++m_fetched_instr_count;
      }
    } else {
      ++m_vector_loop_count;
    }

    // ID/RF
    {
      // Get the scalar instruction (mask off vector control bits).
      const uint32_t sclar_instr = id_in.instr & 0x3fffffffu;

      // Is this a vector operation?
      const uint32_t vector_mode = id_in.instr >> 30u;
      const bool is_vector_op = (vector_mode != 0u);
      const bool is_folding_vector_op = (vector_mode == 1u);

      // Detect encoding class (A, B or C).
      const bool op_class_A = ((sclar_instr & 0x3f000000u) == 0x00000000u);
      const bool op_class_C = ((sclar_instr & 0x30000000u) == 0x30000000u);
      const bool op_class_B = !op_class_A && !op_class_C;

      // Is this a packed operation?
      const uint32_t packed_mode = (op_class_A ? ((sclar_instr & 0x00000180u) >> 7) : 0u);

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
        const uint32_t vector_stride = op_class_B ? imm14 : m_regs[reg3];

        // Start a new or continue an ongoing vector operartion?
        if (!vector.active) {
          vector.idx = 0u;
          vector.stride = vector_stride;
          vector.addr_offset = 0u;
          vector.folding = is_folding_vector_op;
        } else {
          // Do vector offset increments in the ID/RF stage.
          ++vector.idx;
          vector.addr_offset += vector.stride;
        }
      }

      // Check if the next cycle will continue a vector loop (i.e. we should stall the IF stage).
      next_cycle_continues_a_vector_loop =
          is_vector_op && ((vector.idx + 1) < (m_regs[REG_VL] & (2 * NUM_VECTOR_ELEMENTS - 1)));

      // == BRANCH ==

      const bool is_bcc = ((sclar_instr & 0x38000000u) == 0x30000000u);
      const bool is_j = ((sclar_instr & 0x3e000000u) == 0x38000000u);
      const bool is_subroutine_branch = ((sclar_instr & 0x3f000000u) == 0x39000000u);
      const bool is_branch = is_bcc || is_j;

      // Branch source register is reg1 (for b[cc] and j/jl/b/bl).
      const uint32_t branch_cond_reg = is_branch ? reg1 : REG_Z;

      // Read the branch/condition register.
      // TODO(m): We should share a register read-port with the other register reads further down.
      const uint32_t branch_cond_value = m_regs[branch_cond_reg];

      // Evaluate condition (for b[cc]).
      const uint32_t condition = (sclar_instr >> 24u) & 0x0000003fu;
      bool condition_satisfied = false;
      switch (condition) {
        case 0x30u:  // bz
          condition_satisfied = (branch_cond_value == 0u);
          break;
        case 0x31u:  // bnz
          condition_satisfied = (branch_cond_value != 0u);
          break;
        case 0x32u:  // bs
          condition_satisfied = (branch_cond_value == 0xffffffffu);
          break;
        case 0x33u:  // bns
          condition_satisfied = (branch_cond_value != 0xffffffffu);
          break;
        case 0x34u:  // blt
          condition_satisfied = ((branch_cond_value & 0x80000000u) != 0u);
          break;
        case 0x35u:  // bge
          condition_satisfied = ((branch_cond_value & 0x80000000u) == 0u);
          break;
        case 0x36u:  // ble
          condition_satisfied =
              ((branch_cond_value & 0x80000000u) != 0u) || (branch_cond_value == 0u);
          break;
        case 0x37u:  // bgt
          condition_satisfied =
              ((branch_cond_value & 0x80000000u) == 0u) && (branch_cond_value != 0u);
          break;
      }

      bool branch_taken = false;
      uint32_t branch_target = 0u;

      // b[cc]?
      if (is_bcc) {
        branch_taken = condition_satisfied;
        branch_target = id_in.pc + (imm19 << 2u);
      }

      // j/jl/b/bl?
      if (is_j) {
        branch_taken = true;
        branch_target = branch_cond_value + (imm19 << 2u);
      }

      next_pc = branch_taken ? branch_target : (id_in.pc + 4u);

      // == DECODE ==

      // Is this a mem load/store operation?
      const bool is_ldx = ((sclar_instr & 0x3f0001f8u) == 0x00000000u) &&
                          ((sclar_instr & 0x00000007u) != 0x00000000u);
      const bool is_ld = ((sclar_instr & 0x38000000u) == 0x00000000u) &&
                         ((sclar_instr & 0x07000000u) != 0x00000000u);
      const bool is_mem_load = is_ldx || is_ld;
      const bool is_stx = ((sclar_instr & 0x3f0001f8u) == 0x00000008u);
      const bool is_st = ((sclar_instr & 0x38000000u) == 0x08000000u);
      const bool is_mem_store = is_stx || is_st;
      const bool is_mem_op = (is_mem_load || is_mem_store);

      // Should we use reg1 as a source (special case)?
      const bool reg1_is_src = is_mem_store || is_branch;

      // Should we use reg2 as a source?
      const bool reg2_is_src = op_class_A || op_class_B;

      // Should we use reg3 as a source?
      const bool reg3_is_src = op_class_A;

      // Should we use reg1 as a destination?
      const bool reg1_is_dst = !reg1_is_src;

      // Determine the source & destination register numbers (zero for none).
      const uint32_t src_reg_a = is_subroutine_branch ? REG_PC : (reg2_is_src ? reg2 : REG_Z);
      const uint32_t src_reg_b = reg3_is_src ? reg3 : REG_Z;
      const uint32_t src_reg_c = reg1_is_src ? reg1 : REG_Z;
      const uint32_t dst_reg = is_subroutine_branch ? REG_LR : (reg1_is_dst ? reg1 : REG_Z);

      // Determine EX operation.
      uint32_t ex_op = EX_OP_CPUID;
      if (is_subroutine_branch || is_mem_op) {
        ex_op = EX_OP_ADD;
      } else if (op_class_A && ((sclar_instr & 0x000001f0u) != 0x00000000u)) {
        ex_op = sclar_instr & 0x000001ffu;
      } else if (op_class_B && ((sclar_instr & 0x30000000u) != 0x00000000u)) {
        ex_op = sclar_instr >> 24u;
      } else if (op_class_C) {
        switch (sclar_instr & 0x3f000000u) {
          case 0x3a000000u:  // ldi
            ex_op = EX_OP_OR;
            break;
          case 0x3b000000u:  // ldhi
            ex_op = EX_OP_LDHI;
            break;
          case 0x3c000000u:  // ldhio
            ex_op = EX_OP_LDHIO;
            break;
        }
      }

      // Mask away packed op from the EX operation.
      if (packed_mode != PACKED_NONE) {
        ex_op = ex_op & ~0x00000180u;
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
      const bool reg2_is_vector = is_vector_op && !is_mem_op;
      const bool reg3_is_vector = ((vector_mode & 1u) != 0u);

      // Read from the register files.
      const uint32_t reg_a_data =
          reg2_is_vector ? m_vregs[src_reg_a][vector.idx] : m_regs[src_reg_a];
      const uint32_t vector_idx_b = vector.folding ? (vector.idx + m_regs[REG_VL]) : vector.idx;
      const uint32_t reg_b_data =
          reg3_is_vector ? m_vregs[src_reg_b][vector_idx_b] : m_regs[src_reg_b];
      const uint32_t reg_c_data =
          reg1_is_vector ? m_vregs[src_reg_c][vector.idx] : m_regs[src_reg_c];

      // Select gather-scatter offset or stride offset for vector memory operations.
      const uint32_t vector_addr_offset = (vector_mode == 3u) ? reg_b_data : vector.addr_offset;

      // Output of the ID step.
      ex_in.src_a = reg_a_data;
      ex_in.src_b = is_subroutine_branch
                        ? 4
                        : ((is_vector_op && is_mem_op)
                               ? vector_addr_offset
                               : (op_class_B ? imm14 : (op_class_C ? imm19 : reg_b_data)));
      ex_in.src_c = reg_c_data;
      ex_in.dst_reg = dst_reg;
      ex_in.dst_idx = vector.idx;
      ex_in.dst_is_vector = is_vector_op;
      ex_in.ex_op = ex_op;
      ex_in.packed_mode = packed_mode;
      ex_in.mem_op = mem_op;
    }

    // EX
    {
      uint32_t ex_result = 0u;

      // Do the operation.
      switch (ex_in.ex_op) {
        case EX_OP_CPUID:
          ex_result = cpuid32(ex_in.src_a, ex_in.src_b);
          break;

        case EX_OP_LDHI:
          ex_result = ex_in.src_b << 13u;
          break;
        case EX_OP_LDHIO:
          ex_result = (ex_in.src_b << 13u) | 0x1fffu;
          break;

        case EX_OP_OR:
          ex_result = ex_in.src_a | ex_in.src_b;
          break;
        case EX_OP_NOR:
          ex_result = ~(ex_in.src_a | ex_in.src_b);
          break;
        case EX_OP_AND:
          ex_result = ex_in.src_a & ex_in.src_b;
          break;
        case EX_OP_BIC:
          ex_result = ex_in.src_a & ~ex_in.src_b;
          break;
        case EX_OP_XOR:
          ex_result = ex_in.src_a ^ ex_in.src_b;
          break;
        case EX_OP_ADD:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = add8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = add16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = add32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_SUB:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = sub8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = sub16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = sub32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_SEQ:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result =
                  set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t a, uint8_t b) { return a == b; });
              break;
            case PACKED_HALF_WORD:
              ex_result =
                  set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t a, uint16_t b) { return a == b; });
              break;
            default:
              ex_result =
                  set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) { return a == b; });
          }
          break;
        case EX_OP_SNE:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result =
                  set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t a, uint8_t b) { return a != b; });
              break;
            case PACKED_HALF_WORD:
              ex_result =
                  set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t a, uint16_t b) { return a != b; });
              break;
            default:
              ex_result =
                  set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) { return a != b; });
          }
          break;
        case EX_OP_SLT:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t a, uint8_t b) {
                return static_cast<int8_t>(b) < static_cast<int8_t>(a);
              });
              break;
            case PACKED_HALF_WORD:
              ex_result = set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t a, uint16_t b) {
                return static_cast<int16_t>(b) < static_cast<int16_t>(a);
              });
              break;
            default:
              ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                return static_cast<int32_t>(b) < static_cast<int32_t>(a);
              });
          }
          break;
        case EX_OP_SLTU:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result =
                  set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t a, uint8_t b) { return b < a; });
              break;
            case PACKED_HALF_WORD:
              ex_result =
                  set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t a, uint16_t b) { return b < a; });
              break;
            default:
              ex_result =
                  set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) { return b < a; });
          }
          break;
        case EX_OP_SLE:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t a, uint8_t b) {
                return static_cast<int8_t>(b) <= static_cast<int8_t>(a);
              });
              break;
            case PACKED_HALF_WORD:
              ex_result = set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t a, uint16_t b) {
                return static_cast<int16_t>(b) <= static_cast<int16_t>(a);
              });
              break;
            default:
              ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                return static_cast<int32_t>(b) <= static_cast<int32_t>(a);
              });
          }
          break;
        case EX_OP_SLEU:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result =
                  set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t a, uint8_t b) { return b <= a; });
              break;
            case PACKED_HALF_WORD:
              ex_result =
                  set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t a, uint16_t b) { return b <= a; });
              break;
            default:
              ex_result =
                  set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) { return b <= a; });
          }
          break;
        case EX_OP_MIN:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = sel32(ex_in.src_a,
                                ex_in.src_b,
                                set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t x, uint8_t y) {
                                  return static_cast<int8_t>(x) < static_cast<int8_t>(y);
                                }));
              break;
            case PACKED_HALF_WORD:
              ex_result = sel32(ex_in.src_a,
                                ex_in.src_b,
                                set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t x, uint16_t y) {
                                  return static_cast<int16_t>(x) < static_cast<int16_t>(y);
                                }));
              break;
            default:
              ex_result = sel32(ex_in.src_a,
                                ex_in.src_b,
                                set32(ex_in.src_a, ex_in.src_b, [](uint32_t x, uint32_t y) {
                                  return static_cast<int32_t>(x) < static_cast<int32_t>(y);
                                }));
          }
          break;
        case EX_OP_MAX:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = sel32(ex_in.src_a,
                                ex_in.src_b,
                                set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t x, uint8_t y) {
                                  return static_cast<int8_t>(x) > static_cast<int8_t>(y);
                                }));
              break;
            case PACKED_HALF_WORD:
              ex_result = sel32(ex_in.src_a,
                                ex_in.src_b,
                                set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t x, uint16_t y) {
                                  return static_cast<int16_t>(x) > static_cast<int16_t>(y);
                                }));
              break;
            default:
              ex_result = sel32(ex_in.src_a,
                                ex_in.src_b,
                                set32(ex_in.src_a, ex_in.src_b, [](uint32_t x, uint32_t y) {
                                  return static_cast<int32_t>(x) > static_cast<int32_t>(y);
                                }));
          }
          break;
        case EX_OP_MINU:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = sel32(
                  ex_in.src_a,
                  ex_in.src_b,
                  set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t x, uint8_t y) { return x < y; }));
              break;
            case PACKED_HALF_WORD:
              ex_result = sel32(
                  ex_in.src_a,
                  ex_in.src_b,
                  set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t x, uint16_t y) { return x < y; }));
              break;
            default:
              ex_result = sel32(
                  ex_in.src_a,
                  ex_in.src_b,
                  set32(ex_in.src_a, ex_in.src_b, [](uint32_t x, uint32_t y) { return x < y; }));
          }
          break;
        case EX_OP_MAXU:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = sel32(
                  ex_in.src_a,
                  ex_in.src_b,
                  set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t x, uint8_t y) { return x > y; }));
              break;
            case PACKED_HALF_WORD:
              ex_result = sel32(
                  ex_in.src_a,
                  ex_in.src_b,
                  set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t x, uint16_t y) { return x > y; }));
              break;
            default:
              ex_result = sel32(
                  ex_in.src_a,
                  ex_in.src_b,
                  set32(ex_in.src_a, ex_in.src_b, [](uint32_t x, uint32_t y) { return x > y; }));
          }
          break;
        case EX_OP_ASR:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = asr8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = asr16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = asr32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_LSL:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = lsl8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = lsl16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = lsl32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_LSR:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = lsr8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = lsr16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = lsr32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_SHUF:
          ex_result = shuf32(ex_in.src_a, ex_in.src_b);
          break;
        case EX_OP_CLZ:
          ex_result = clz32(ex_in.src_a);
          break;
        case EX_OP_REV:
          ex_result = rev32(ex_in.src_a);
          break;
        case EX_OP_PACKB:
          ex_result = packb32(ex_in.src_a, ex_in.src_b);
          break;
        case EX_OP_PACKH:
          ex_result = packh32(ex_in.src_a, ex_in.src_b);
          break;

        case EX_OP_MULQ:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = mulq7x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = mulq15x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = mulq31(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_MUL:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = mul8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = mul16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = mul32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_MULHI:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = mulhi8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = mulhi16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = mulhi32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_MULHIU:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = mulhiu8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = mulhiu16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = mulhiu32(ex_in.src_a, ex_in.src_b);
          }
          break;

        case EX_OP_DIV:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = div8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = div16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = div32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_DIVU:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = divu8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = divu16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = divu32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_REM:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = rem8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = rem16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = rem32(ex_in.src_a, ex_in.src_b);
          }
        case EX_OP_REMU:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = remu8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = remu16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = remu32(ex_in.src_a, ex_in.src_b);
          }

        case EX_OP_ITOF:
          ex_result = itof32(ex_in.src_a, ex_in.src_b);
          break;
        case EX_OP_FTOI:
          ex_result = ftoi32(ex_in.src_a, ex_in.src_b);
          break;
        case EX_OP_FADD:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = fadd8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = fadd16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = fadd32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_FSUB:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = fsub8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = fsub16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = fsub32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_FMUL:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = fmul8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = fmul16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = fmul32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_FDIV:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = fdiv8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = fdiv16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = fdiv32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_FSQRT:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = fsqrt8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = fsqrt16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = fsqrt32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_FSEQ:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              throw std::runtime_error("Not yet implemented: Packed 8-bit FSEQ.");
            case PACKED_HALF_WORD:
              throw std::runtime_error("Not yet implemented: Packed 16-bit FSEQ.");
            default:
              ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                return as_f32(a) == as_f32(b);
              });
          }
          break;
        case EX_OP_FSNE:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              throw std::runtime_error("Not yet implemented: Packed 8-bit FSNE.");
            case PACKED_HALF_WORD:
              throw std::runtime_error("Not yet implemented: Packed 16-bit FSNE.");
            default:
              ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                return as_f32(a) != as_f32(b);
              });
          }
          break;
        case EX_OP_FSLT:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              throw std::runtime_error("Not yet implemented: Packed 8-bit FSLT.");
            case PACKED_HALF_WORD:
              throw std::runtime_error("Not yet implemented: Packed 16-bit FSLT.");
            default:
              ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                return as_f32(a) < as_f32(b);
              });
          }
          break;
        case EX_OP_FSLE:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              throw std::runtime_error("Not yet implemented: Packed 8-bit FSLE.");
            case PACKED_HALF_WORD:
              throw std::runtime_error("Not yet implemented: Packed 16-bit FSLE.");
            default:
              ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                return as_f32(a) <= as_f32(b);
              });
          }
          break;
        case EX_OP_FSNAN:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              throw std::runtime_error("Not yet implemented: Packed 8-bit FSNAN.");
            case PACKED_HALF_WORD:
              throw std::runtime_error("Not yet implemented: Packed 16-bit FSNAN.");
            default:
              ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                return float32_isnan(a) || float32_isnan(b);
              });
          }
          break;
        case EX_OP_FMIN:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = fmin8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = fmin16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = fmin32(ex_in.src_a, ex_in.src_b);
          }
          break;
        case EX_OP_FMAX:
          switch (ex_in.packed_mode) {
            case PACKED_BYTE:
              ex_result = fmax8x4(ex_in.src_a, ex_in.src_b);
              break;
            case PACKED_HALF_WORD:
              ex_result = fmax16x2(ex_in.src_a, ex_in.src_b);
              break;
            default:
              ex_result = fmax32(ex_in.src_a, ex_in.src_b);
          }
          break;
      }

      mem_in.mem_addr = ex_result;
      mem_in.dst_data = ex_result;
      mem_in.dst_reg = ex_in.dst_reg;
      mem_in.dst_idx = ex_in.dst_idx;
      mem_in.dst_is_vector = ex_in.dst_is_vector;
      mem_in.mem_op = ex_in.mem_op;
      mem_in.store_data = ex_in.src_c;
    }

    // MEM
    {
      uint32_t mem_result = 0u;
      switch (mem_in.mem_op) {
        case MEM_OP_LOAD8:
          mem_result = s8_as_u32(static_cast<int8_t>(m_ram.at8(mem_in.mem_addr)));
          break;
        case MEM_OP_LOADU8:
          mem_result = u8_as_u32(m_ram.at8(mem_in.mem_addr));
          break;
        case MEM_OP_LOAD16:
          mem_result = s16_as_u32(static_cast<int16_t>(m_ram.at16(mem_in.mem_addr)));
          break;
        case MEM_OP_LOADU16:
          mem_result = u16_as_u32(m_ram.at16(mem_in.mem_addr));
          break;
        case MEM_OP_LOAD32:
          mem_result = m_ram.at32(mem_in.mem_addr);
          break;
        case MEM_OP_STORE8:
          m_ram.at8(mem_in.mem_addr) = static_cast<uint8_t>(mem_in.store_data);
          break;
        case MEM_OP_STORE16:
          m_ram.at16(mem_in.mem_addr) = static_cast<uint16_t>(mem_in.store_data);
          break;
        case MEM_OP_STORE32:
          m_ram.at32(mem_in.mem_addr) = mem_in.store_data;
          break;
      }

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
