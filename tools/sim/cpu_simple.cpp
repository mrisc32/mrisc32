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

#include "packed_float.hpp"

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

inline std::string as_hex32(const uint32_t x) {
  char str[16];
  std::snprintf(str, sizeof(str) - 1, "0x%08x", x);
  return std::string(&str[0]);
}

template <typename T>
inline std::string as_dec(const T x) {
  char str[32];
  std::snprintf(str, sizeof(str) - 1, "%d", static_cast<int>(x));
  return std::string(&str[0]);
}

inline uint32_t index_scale_factor(const uint32_t packed_mode) {
  return uint32_t(1u) << packed_mode;
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
  const auto s1 = (b >> 16) & 15;
  const auto s0 = b & 15;
  const auto h1 = static_cast<uint32_t>(static_cast<uint16_t>(static_cast<int16_t>(a >> 16) >> s1));
  const auto h0 = static_cast<uint32_t>(static_cast<uint16_t>(static_cast<int16_t>(a) >> s0));
  return (h1 << 16) | h0;
}

inline uint32_t asr8x4(const uint32_t a, const uint32_t b) {
  const auto s3 = (b >> 24) & 7;
  const auto s2 = (b >> 16) & 7;
  const auto s1 = (b >> 8) & 7;
  const auto s0 = b & 7;
  const auto b3 = static_cast<uint32_t>(static_cast<uint8_t>(static_cast<int8_t>(a >> 24) >> s3));
  const auto b2 = static_cast<uint32_t>(static_cast<uint8_t>(static_cast<int8_t>(a >> 16) >> s2));
  const auto b1 = static_cast<uint32_t>(static_cast<uint8_t>(static_cast<int8_t>(a >> 8) >> s1));
  const auto b0 = static_cast<uint32_t>(static_cast<uint8_t>(static_cast<int8_t>(a) >> s0));
  return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
}

inline uint32_t lsl32(const uint32_t a, const uint32_t b) {
  return a << b;
}

inline uint32_t lsl16x2(const uint32_t a, const uint32_t b) {
  const auto s1 = (b >> 16) & 15;
  const auto s0 = b & 15;
  const auto h1 = (a & 0xffff0000u) << s1;
  const auto h0 = (a << s0) & 0x0000ffffu;
  return h1 | h0;
}

inline uint32_t lsl8x4(const uint32_t a, const uint32_t b) {
  const auto s3 = (b >> 24) & 7;
  const auto s2 = (b >> 16) & 7;
  const auto s1 = (b >> 8) & 7;
  const auto s0 = b & 7;
  const auto b3 = (a & 0xff000000u) << s3;
  const auto b2 = ((a & 0x00ff0000u) << s2) & 0x00ff0000u;
  const auto b1 = ((a & 0x0000ff00u) << s1) & 0x0000ff00u;
  const auto b0 = (a << s0) & 0x000000ffu;
  return b3 | b2 | b1 | b0;
}

inline uint32_t lsr32(const uint32_t a, const uint32_t b) {
  return a >> b;
}

inline uint32_t lsr16x2(const uint32_t a, const uint32_t b) {
  const auto s1 = (b >> 16) & 15;
  const auto s0 = b & 15;
  const auto h1 = (a >> s1) & 0xffff0000u;
  const auto h0 = (a & 0x0000ffffu) >> s0;
  return h1 | h0;
}

inline uint32_t lsr8x4(const uint32_t a, const uint32_t b) {
  const auto s3 = (b >> 24) & 7;
  const auto s2 = (b >> 16) & 7;
  const auto s1 = (b >> 8) & 7;
  const auto s0 = b & 7;
  const auto b3 = (a >> s3) & 0xff000000u;
  const auto b2 = ((a & 0x00ff0000u) >> s2) & 0x00ff0000u;
  const auto b1 = ((a & 0x0000ff00u) >> s1) & 0x0000ff00u;
  const auto b0 = (a & 0x000000ffu) >> s0;
  return b3 | b2 | b1 | b0;
}

inline uint32_t saturate32(const int64_t x) {
  return (x > INT64_C(0x000000007fffffff))
             ? 0x7fffffffu
             : ((x < INT64_C(-0x0000000080000000)) ? 0x80000000u : static_cast<uint32_t>(x));
}

inline uint32_t saturate16(const int32_t x) {
  return (x > 0x00007fff)
             ? 0x7fffu
             : ((x < -0x00008000) ? 0x8000u : (static_cast<uint32_t>(x) & 0x0000ffffu));
}

inline uint32_t saturate8(const int16_t x) {
  return (x > 0x007f) ? 0x7fu : ((x < -0x0080) ? 0x80u : (static_cast<uint32_t>(x) & 0x00ffu));
}

inline uint32_t saturate4(const int8_t x) {
  return (x > 0x07) ? 0x7u : ((x < -0x08) ? 0x8u : (static_cast<uint32_t>(x) & 0x0fu));
}

inline uint32_t saturateu32(const uint64_t x) {
  return (x > UINT64_C(0x8000000000000000))
             ? 0x00000000u
             : ((x > UINT64_C(0x00000000ffffffff)) ? 0xffffffffu : static_cast<uint32_t>(x));
}

inline uint32_t saturateu16(const uint32_t x) {
  return (x > 0x80000000u) ? 0x0000u : ((x > 0x0000ffffu) ? 0xffffu : static_cast<uint32_t>(x));
}

inline uint32_t saturateu8(const uint16_t x) {
  return (x > 0x8000u) ? 0x00u : ((x > 0x00ffu) ? 0xffu : static_cast<uint32_t>(x));
}

inline uint32_t saturateu16_no_uf(const uint32_t x) {
  return (x > 0x0000ffffu) ? 0xffffu : static_cast<uint32_t>(x);
}

inline uint32_t saturateu8_no_uf(const uint16_t x) {
  return (x > 0x00ffu) ? 0xffu : static_cast<uint32_t>(x);
}

inline uint32_t saturateu4_no_uf(const uint8_t x) {
  return (x > 0x0fu) ? 0xfu : static_cast<uint32_t>(x);
}

inline uint32_t saturating_op_32(const uint32_t a,
                                 const uint32_t b,
                                 int64_t (*op)(int64_t, int64_t)) {
  const auto a64 = static_cast<int64_t>(static_cast<int32_t>(a));
  const auto b64 = static_cast<int64_t>(static_cast<int32_t>(b));
  return saturate32(op(a64, b64));
}

inline uint32_t saturating_op_16x2(const uint32_t a,
                                   const uint32_t b,
                                   int32_t (*op)(int32_t, int32_t)) {
  const auto a1 = static_cast<int32_t>(static_cast<int16_t>(a >> 16));
  const auto a2 = static_cast<int32_t>(static_cast<int16_t>(a));
  const auto b1 = static_cast<int32_t>(static_cast<int16_t>(b >> 16));
  const auto b2 = static_cast<int32_t>(static_cast<int16_t>(b));
  const auto c1 = saturate16(op(a1, b1));
  const auto c2 = saturate16(op(a2, b2));
  return (c1 << 16) | c2;
}

inline uint32_t saturating_op_8x4(const uint32_t a,
                                  const uint32_t b,
                                  int16_t (*op)(int16_t, int16_t)) {
  const auto a1 = static_cast<int16_t>(static_cast<int8_t>(a >> 24));
  const auto a2 = static_cast<int16_t>(static_cast<int8_t>(a >> 16));
  const auto a3 = static_cast<int16_t>(static_cast<int8_t>(a >> 8));
  const auto a4 = static_cast<int16_t>(static_cast<int8_t>(a));
  const auto b1 = static_cast<int16_t>(static_cast<int8_t>(b >> 24));
  const auto b2 = static_cast<int16_t>(static_cast<int8_t>(b >> 16));
  const auto b3 = static_cast<int16_t>(static_cast<int8_t>(b >> 8));
  const auto b4 = static_cast<int16_t>(static_cast<int8_t>(b));
  const auto c1 = saturate8(op(a1, b1));
  const auto c2 = saturate8(op(a2, b2));
  const auto c3 = saturate8(op(a3, b3));
  const auto c4 = saturate8(op(a4, b4));
  return (c1 << 24) | (c2 << 16) | (c3 << 8) | c4;
}

inline uint32_t saturating_op_u32(const uint32_t a,
                                  const uint32_t b,
                                  uint64_t (*op)(uint64_t, uint64_t)) {
  return saturateu32(op(static_cast<uint64_t>(a), static_cast<uint64_t>(b)));
}

inline uint32_t saturating_op_u16x2(const uint32_t a,
                                    const uint32_t b,
                                    uint32_t (*op)(uint32_t, uint32_t)) {
  const auto a1 = static_cast<uint32_t>(static_cast<uint16_t>(a >> 16));
  const auto a2 = static_cast<uint32_t>(static_cast<uint16_t>(a));
  const auto b1 = static_cast<uint32_t>(static_cast<uint16_t>(b >> 16));
  const auto b2 = static_cast<uint32_t>(static_cast<uint16_t>(b));
  const auto c1 = saturateu16(op(a1, b1));
  const auto c2 = saturateu16(op(a2, b2));
  return (c1 << 16) | c2;
}

inline uint32_t saturating_op_u8x4(const uint32_t a,
                                   const uint32_t b,
                                   uint16_t (*op)(uint16_t, uint16_t)) {
  const auto a1 = static_cast<uint16_t>(static_cast<uint8_t>(a >> 24));
  const auto a2 = static_cast<uint16_t>(static_cast<uint8_t>(a >> 16));
  const auto a3 = static_cast<uint16_t>(static_cast<uint8_t>(a >> 8));
  const auto a4 = static_cast<uint16_t>(static_cast<uint8_t>(a));
  const auto b1 = static_cast<uint16_t>(static_cast<uint8_t>(b >> 24));
  const auto b2 = static_cast<uint16_t>(static_cast<uint8_t>(b >> 16));
  const auto b3 = static_cast<uint16_t>(static_cast<uint8_t>(b >> 8));
  const auto b4 = static_cast<uint16_t>(static_cast<uint8_t>(b));
  const auto c1 = saturateu8(op(a1, b1));
  const auto c2 = saturateu8(op(a2, b2));
  const auto c3 = saturateu8(op(a3, b3));
  const auto c4 = saturateu8(op(a4, b4));
  return (c1 << 24) | (c2 << 16) | (c3 << 8) | c4;
}

inline uint32_t halve32(const int64_t x) {
  return static_cast<uint32_t>(x >> 1);
}

inline uint32_t halve16(const int32_t x) {
  return static_cast<uint32_t>(static_cast<uint16_t>(x >> 1));
}

inline uint32_t halve8(const int16_t x) {
  return static_cast<uint32_t>(static_cast<uint8_t>(x >> 1));
}

inline uint32_t halveu32(const uint64_t x) {
  return static_cast<uint32_t>(x >> 1);
}

inline uint32_t halveu16(const uint32_t x) {
  return static_cast<uint32_t>(static_cast<uint16_t>(x >> 1));
}

inline uint32_t halveu8(const uint16_t x) {
  return static_cast<uint32_t>(static_cast<uint8_t>(x >> 1));
}

inline uint32_t halving_op_32(const uint32_t a, const uint32_t b, int64_t (*op)(int64_t, int64_t)) {
  const auto a64 = static_cast<int64_t>(static_cast<int32_t>(a));
  const auto b64 = static_cast<int64_t>(static_cast<int32_t>(b));
  return halve32(op(a64, b64));
}

inline uint32_t halving_op_16x2(const uint32_t a,
                                const uint32_t b,
                                int32_t (*op)(int32_t, int32_t)) {
  const auto a1 = static_cast<int32_t>(static_cast<int16_t>(a >> 16));
  const auto a2 = static_cast<int32_t>(static_cast<int16_t>(a));
  const auto b1 = static_cast<int32_t>(static_cast<int16_t>(b >> 16));
  const auto b2 = static_cast<int32_t>(static_cast<int16_t>(b));
  const auto c1 = halve16(op(a1, b1));
  const auto c2 = halve16(op(a2, b2));
  return (c1 << 16) | c2;
}

inline uint32_t halving_op_8x4(const uint32_t a,
                               const uint32_t b,
                               int16_t (*op)(int16_t, int16_t)) {
  const auto a1 = static_cast<int16_t>(static_cast<int8_t>(a >> 24));
  const auto a2 = static_cast<int16_t>(static_cast<int8_t>(a >> 16));
  const auto a3 = static_cast<int16_t>(static_cast<int8_t>(a >> 8));
  const auto a4 = static_cast<int16_t>(static_cast<int8_t>(a));
  const auto b1 = static_cast<int16_t>(static_cast<int8_t>(b >> 24));
  const auto b2 = static_cast<int16_t>(static_cast<int8_t>(b >> 16));
  const auto b3 = static_cast<int16_t>(static_cast<int8_t>(b >> 8));
  const auto b4 = static_cast<int16_t>(static_cast<int8_t>(b));
  const auto c1 = halve8(op(a1, b1));
  const auto c2 = halve8(op(a2, b2));
  const auto c3 = halve8(op(a3, b3));
  const auto c4 = halve8(op(a4, b4));
  return (c1 << 24) | (c2 << 16) | (c3 << 8) | c4;
}

inline uint32_t halving_op_u32(const uint32_t a,
                               const uint32_t b,
                               uint64_t (*op)(uint64_t, uint64_t)) {
  return halveu32(op(static_cast<uint64_t>(a), static_cast<uint64_t>(b)));
}

inline uint32_t halving_op_u16x2(const uint32_t a,
                                 const uint32_t b,
                                 uint32_t (*op)(uint32_t, uint32_t)) {
  const auto a1 = static_cast<uint32_t>(static_cast<uint16_t>(a >> 16));
  const auto a2 = static_cast<uint32_t>(static_cast<uint16_t>(a));
  const auto b1 = static_cast<uint32_t>(static_cast<uint16_t>(b >> 16));
  const auto b2 = static_cast<uint32_t>(static_cast<uint16_t>(b));
  const auto c1 = halveu16(op(a1, b1));
  const auto c2 = halveu16(op(a2, b2));
  return (c1 << 16) | c2;
}

inline uint32_t halving_op_u8x4(const uint32_t a,
                                const uint32_t b,
                                uint16_t (*op)(uint16_t, uint16_t)) {
  const auto a1 = static_cast<uint16_t>(static_cast<uint8_t>(a >> 24));
  const auto a2 = static_cast<uint16_t>(static_cast<uint8_t>(a >> 16));
  const auto a3 = static_cast<uint16_t>(static_cast<uint8_t>(a >> 8));
  const auto a4 = static_cast<uint16_t>(static_cast<uint8_t>(a));
  const auto b1 = static_cast<uint16_t>(static_cast<uint8_t>(b >> 24));
  const auto b2 = static_cast<uint16_t>(static_cast<uint8_t>(b >> 16));
  const auto b3 = static_cast<uint16_t>(static_cast<uint8_t>(b >> 8));
  const auto b4 = static_cast<uint16_t>(static_cast<uint8_t>(b));
  const auto c1 = halveu8(op(a1, b1));
  const auto c2 = halveu8(op(a2, b2));
  const auto c3 = halveu8(op(a3, b3));
  const auto c4 = halveu8(op(a4, b4));
  return (c1 << 24) | (c2 << 16) | (c3 << 8) | c4;
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
  const auto c0 = (static_cast<uint32_t>(a0 * b0) >> 15u) & 0x0000ffffu;
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

template <typename T>
inline T div_allow_zero(const T a, const T b) {
  return b != static_cast<T>(0) ? (a / b) : static_cast<T>(-1);
}

template <typename T>
inline T mod_allow_zero(const T a, const T b) {
  return b != static_cast<T>(0) ? (a % b) : a;
}

inline uint32_t div32(const uint32_t a, const uint32_t b) {
  return static_cast<uint32_t>(div_allow_zero(static_cast<int32_t>(a), static_cast<int32_t>(b)));
}

inline uint32_t div16x2(const uint32_t a, const uint32_t b) {
  const auto a1 = static_cast<int32_t>(static_cast<int16_t>(a >> 16u));
  const auto a0 = static_cast<int32_t>(static_cast<int16_t>(a));
  const auto b1 = static_cast<int32_t>(static_cast<int16_t>(b >> 16u));
  const auto b0 = static_cast<int32_t>(static_cast<int16_t>(b));
  const auto c1 = (static_cast<uint32_t>(div_allow_zero(a1, b1)) & 0x0000ffffu) << 16u;
  const auto c0 = static_cast<uint32_t>(div_allow_zero(a0, b0)) & 0x0000ffffu;
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
  const auto c3 = (static_cast<uint32_t>(div_allow_zero(a3, b3)) & 0x000000ffu) << 24u;
  const auto c2 = (static_cast<uint32_t>(div_allow_zero(a2, b2)) & 0x000000ffu) << 16u;
  const auto c1 = (static_cast<uint32_t>(div_allow_zero(a1, b1)) & 0x000000ffu) << 8u;
  const auto c0 = static_cast<uint32_t>(div_allow_zero(a0, b0)) & 0x000000ffu;
  return c3 | c2 | c1 | c0;
}

inline uint32_t divu32(const uint32_t a, const uint32_t b) {
  return div_allow_zero(a, b);
}

inline uint32_t divu16x2(const uint32_t a, const uint32_t b) {
  const auto a1 = a >> 16u;
  const auto a0 = a & 0x0000ffff;
  const auto b1 = b >> 16u;
  const auto b0 = b & 0x0000ffff;
  const auto c1 = div_allow_zero(a1, b1) << 16u;
  const auto c0 = div_allow_zero(a0, b0);
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
  const auto c3 = div_allow_zero(a3, b3) << 24u;
  const auto c2 = div_allow_zero(a2, b2) << 16u;
  const auto c1 = div_allow_zero(a1, b1) << 8u;
  const auto c0 = div_allow_zero(a0, b0);
  return c3 | c2 | c1 | c0;
}

inline uint32_t rem32(const uint32_t a, const uint32_t b) {
  return static_cast<uint32_t>(mod_allow_zero(static_cast<int32_t>(a), static_cast<int32_t>(b)));
}

inline uint32_t rem16x2(const uint32_t a, const uint32_t b) {
  const auto a1 = static_cast<int32_t>(static_cast<int16_t>(a >> 16u));
  const auto a0 = static_cast<int32_t>(static_cast<int16_t>(a));
  const auto b1 = static_cast<int32_t>(static_cast<int16_t>(b >> 16u));
  const auto b0 = static_cast<int32_t>(static_cast<int16_t>(b));
  const auto c1 = (static_cast<uint32_t>(mod_allow_zero(a1, b1)) & 0x0000ffffu) << 16u;
  const auto c0 = static_cast<uint32_t>(mod_allow_zero(a0, b0)) & 0x0000ffffu;
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
  const auto c3 = (static_cast<uint32_t>(mod_allow_zero(a3, b3)) & 0x000000ffu) << 24u;
  const auto c2 = (static_cast<uint32_t>(mod_allow_zero(a2, b2)) & 0x000000ffu) << 16u;
  const auto c1 = (static_cast<uint32_t>(mod_allow_zero(a1, b1)) & 0x000000ffu) << 8u;
  const auto c0 = static_cast<uint32_t>(mod_allow_zero(a0, b0)) & 0x000000ffu;
  return c3 | c2 | c1 | c0;
}

inline uint32_t remu32(const uint32_t a, const uint32_t b) {
  return mod_allow_zero(a, b);
}

inline uint32_t remu16x2(const uint32_t a, const uint32_t b) {
  const auto a1 = a >> 16u;
  const auto a0 = a & 0x0000ffff;
  const auto b1 = b >> 16u;
  const auto b0 = b & 0x0000ffff;
  const auto c1 = mod_allow_zero(a1, b1) << 16u;
  const auto c0 = mod_allow_zero(a0, b0);
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
  const auto c3 = mod_allow_zero(a3, b3) << 24u;
  const auto c2 = mod_allow_zero(a2, b2) << 16u;
  const auto c1 = mod_allow_zero(a1, b1) << 8u;
  const auto c0 = mod_allow_zero(a0, b0);
  return c3 | c2 | c1 | c0;
}

inline uint32_t fpack32(const uint32_t a, const uint32_t b) {
  return f16x2_t::from_f32x2(a, b).packf();
}

inline uint32_t fpack16x2(const uint32_t a, const uint32_t b) {
  return f8x4_t::from_f16x4(f16x2_t(a), f16x2_t(b)).packf();
}

inline uint32_t fadd32(const uint32_t a, const uint32_t b) {
  return as_u32(as_f32(a) + as_f32(b));
}

inline uint32_t fadd16x2(const uint32_t a, const uint32_t b) {
  return (f16x2_t(a) + f16x2_t(b)).packf();
}

inline uint32_t fadd8x4(const uint32_t a, const uint32_t b) {
  return (f8x4_t(a) + f8x4_t(b)).packf();
}

inline uint32_t fsub32(const uint32_t a, const uint32_t b) {
  return as_u32(as_f32(a) - as_f32(b));
}

inline uint32_t fsub16x2(const uint32_t a, const uint32_t b) {
  return (f16x2_t(a) - f16x2_t(b)).packf();
}

inline uint32_t fsub8x4(const uint32_t a, const uint32_t b) {
  return (f8x4_t(a) - f8x4_t(b)).packf();
}

inline uint32_t fmul32(const uint32_t a, const uint32_t b) {
  return as_u32(as_f32(a) * as_f32(b));
}

inline uint32_t fmul16x2(const uint32_t a, const uint32_t b) {
  return (f16x2_t(a) * f16x2_t(b)).packf();
}

inline uint32_t fmul8x4(const uint32_t a, const uint32_t b) {
  return (f8x4_t(a) * f8x4_t(b)).packf();
}

inline uint32_t fdiv32(const uint32_t a, const uint32_t b) {
  return as_u32(as_f32(a) / as_f32(b));
}

inline uint32_t fdiv16x2(const uint32_t a, const uint32_t b) {
  return (f16x2_t(a) / f16x2_t(b)).packf();
}

inline uint32_t fdiv8x4(const uint32_t a, const uint32_t b) {
  return (f8x4_t(a) / f8x4_t(b)).packf();
}

inline uint32_t fsqrt32(const uint32_t a, const uint32_t b) {
  (void)b;
  return as_u32(std::sqrt(as_f32(a)));
}

inline uint32_t fsqrt16x2(const uint32_t a, const uint32_t b) {
  (void)b;
  return f16x2_t(a).sqrt().packf();
}

inline uint32_t fsqrt8x4(const uint32_t a, const uint32_t b) {
  (void)b;
  return f8x4_t(a).sqrt().packf();
}

inline uint32_t fmin32(const uint32_t a, const uint32_t b) {
  return as_u32(std::min(as_f32(a), as_f32(b)));
}

inline uint32_t fmin16x2(const uint32_t a, const uint32_t b) {
  return min(f16x2_t(a), f16x2_t(b)).packf();
}

inline uint32_t fmin8x4(const uint32_t a, const uint32_t b) {
  return min(f8x4_t(a), f8x4_t(b)).packf();
}

inline uint32_t fmax32(const uint32_t a, const uint32_t b) {
  return as_u32(std::max(as_f32(a), as_f32(b)));
}

inline uint32_t fmax16x2(const uint32_t a, const uint32_t b) {
  return max(f16x2_t(a), f16x2_t(b)).packf();
}

inline uint32_t fmax8x4(const uint32_t a, const uint32_t b) {
  return max(f8x4_t(a), f8x4_t(b)).packf();
}

inline uint32_t clz32(const uint32_t x) {
#if defined(__GNUC__) || defined(__clang__)
  return (x == 0u) ? 32u : static_cast<uint32_t>(__builtin_clz(x));
#else
  uint32_t count = 0u;
  for (; (count != 32u) && ((x & (0x80000000u >> count)) == 0u); ++count)
    ;
  return count;
#endif
}

inline uint32_t clz16x2(const uint32_t x) {
  return (clz32(x | 0x00008000u) << 16u) | (clz32((x << 16u) | 0x00008000u));
}

inline uint32_t clz8x4(const uint32_t x) {
  return (clz32(x | 0x00800000u) << 24u) | (clz32((x << 8u) | 0x00800000u) << 16u) |
         (clz32((x << 16u) | 0x00800000u) << 8u) | (clz32((x << 24u) | 0x00800000u));
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

inline uint32_t rev16x2(const uint32_t x) {
  return ((x >> 15u) & 0x00010001u) | ((x >> 13u) & 0x00020002u) | ((x >> 11u) & 0x00040004u) |
         ((x >> 9u) & 0x00080008u) | ((x >> 7u) & 0x00100010u) | ((x >> 5u) & 0x00200020u) |
         ((x >> 3u) & 0x00400040u) | ((x >> 1u) & 0x00800080u) | ((x << 1u) & 0x01000100u) |
         ((x << 3u) & 0x02000200u) | ((x << 5u) & 0x04000400u) | ((x << 7u) & 0x08000800u) |
         ((x << 9u) & 0x10001000u) | ((x << 11u) & 0x20002000u) | ((x << 13u) & 0x40004000u) |
         ((x << 15u) & 0x80008000u);
}

inline uint32_t rev8x4(const uint32_t x) {
  return ((x >> 7u) & 0x01010101u) | ((x >> 5u) & 0x02020202u) | ((x >> 3u) & 0x04040404u) |
         ((x >> 1u) & 0x08080808u) | ((x << 1u) & 0x10101010u) | ((x << 3u) & 0x20202020u) |
         ((x << 5u) & 0x40404040u) | ((x << 7u) & 0x80808080u);
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

inline uint32_t pack32(const uint32_t a, const uint32_t b) {
  return ((a & 0x0000ffffu) << 16) | (b & 0x0000ffffu);
}

inline uint32_t pack16x2(const uint32_t a, const uint32_t b) {
  return ((a & 0x00ff00ffu) << 8u) | (b & 0x00ff00ffu);
}

inline uint32_t pack8x4(const uint32_t a, const uint32_t b) {
  return ((a & 0x0f0f0f0fu) << 4u) | (b & 0x0f0f0f0fu);
}

inline uint32_t packs32(const uint32_t a, const uint32_t b) {
  return pack32(saturate16(static_cast<int32_t>(a)), saturate16(static_cast<int32_t>(b)));
}

inline uint32_t packs16x2(const uint32_t a, const uint32_t b) {
  const auto a1 = saturate8(static_cast<int16_t>(a >> 16));
  const auto a0 = saturate8(static_cast<int16_t>(a));
  const auto b1 = saturate8(static_cast<int16_t>(b >> 16));
  const auto b0 = saturate8(static_cast<int16_t>(b));
  return (a1 << 24) | (a0 << 8) | (b1 << 16) | b0;
}

inline uint32_t packs8x4(const uint32_t a, const uint32_t b) {
  const auto a3 = saturate4(static_cast<int8_t>(a >> 24));
  const auto a2 = saturate4(static_cast<int8_t>(a >> 16));
  const auto a1 = saturate4(static_cast<int8_t>(a >> 8));
  const auto a0 = saturate4(static_cast<int8_t>(a));
  const auto b3 = saturate4(static_cast<int8_t>(b >> 24));
  const auto b2 = saturate4(static_cast<int8_t>(b >> 16));
  const auto b1 = saturate4(static_cast<int8_t>(b >> 8));
  const auto b0 = saturate4(static_cast<int8_t>(b));
  return (a3 << 28) | (a2 << 20) | (a1 << 12) | (a0 << 4) | (b3 << 24) | (b2 << 16) | (b1 << 8) |
         b0;
}

inline uint32_t packsu32(const uint32_t a, const uint32_t b) {
  return pack32(saturateu16_no_uf(a), saturateu16_no_uf(b));
}

inline uint32_t packsu16x2(const uint32_t a, const uint32_t b) {
  const auto a1 = saturateu8_no_uf(static_cast<uint16_t>(a >> 16));
  const auto a0 = saturateu8_no_uf(static_cast<uint16_t>(a));
  const auto b1 = saturateu8_no_uf(static_cast<uint16_t>(b >> 16));
  const auto b0 = saturateu8_no_uf(static_cast<uint16_t>(b));
  return (a1 << 24) | (a0 << 8) | (b1 << 16) | b0;
}

inline uint32_t packsu8x4(const uint32_t a, const uint32_t b) {
  const auto a3 = saturateu4_no_uf(static_cast<uint8_t>(a >> 24));
  const auto a2 = saturateu4_no_uf(static_cast<uint8_t>(a >> 16));
  const auto a1 = saturateu4_no_uf(static_cast<uint8_t>(a >> 8));
  const auto a0 = saturateu4_no_uf(static_cast<uint8_t>(a));
  const auto b3 = saturateu4_no_uf(static_cast<uint8_t>(b >> 24));
  const auto b2 = saturateu4_no_uf(static_cast<uint8_t>(b >> 16));
  const auto b1 = saturateu4_no_uf(static_cast<uint8_t>(b >> 8));
  const auto b0 = saturateu4_no_uf(static_cast<uint8_t>(b));
  return (a3 << 28) | (a2 << 20) | (a1 << 12) | (a0 << 4) | (b3 << 24) | (b2 << 16) | (b1 << 8) |
         b0;
}

inline bool float32_isnan(const uint32_t x) {
  return ((x & 0x7F800000u) == 0x7F800000u) && ((x & 0x007fffffu) != 0u);
}

inline uint32_t itof32(const uint32_t a, const uint32_t b) {
  const float f = static_cast<float>(static_cast<int32_t>(a));
  return as_u32(std::ldexp(f, -static_cast<int32_t>(b)));
}

inline uint32_t itof16x2(const uint32_t a, const uint32_t b) {
  return f16x2_t::itof(a, b).packf();
}

inline uint32_t itof8x4(const uint32_t a, const uint32_t b) {
  return f8x4_t::itof(a, b).packf();
}

inline uint32_t utof32(const uint32_t a, const uint32_t b) {
  const float f = static_cast<float>(a);
  return as_u32(std::ldexp(f, -static_cast<int32_t>(b)));
}

inline uint32_t utof16x2(const uint32_t a, const uint32_t b) {
  return f16x2_t::utof(a, b).packf();
}

inline uint32_t utof8x4(const uint32_t a, const uint32_t b) {
  return f8x4_t::utof(a, b).packf();
}

inline uint32_t ftoi32(const uint32_t a, const uint32_t b) {
  const float f = std::ldexp(as_f32(a), static_cast<int32_t>(b));
  return static_cast<uint32_t>(static_cast<int32_t>(f));
}

inline uint32_t ftoi16x2(const uint32_t a, const uint32_t b) {
  return f16x2_t(a).packi(b);
}

inline uint32_t ftoi8x4(const uint32_t a, const uint32_t b) {
  return f8x4_t(a).packi(b);
}

inline uint32_t ftou32(const uint32_t a, const uint32_t b) {
  const float f = std::ldexp(as_f32(a), static_cast<int32_t>(b));
  return static_cast<uint32_t>(f);
}

inline uint32_t ftou16x2(const uint32_t a, const uint32_t b) {
  return f16x2_t(a).packu(b);
}

inline uint32_t ftou8x4(const uint32_t a, const uint32_t b) {
  return f8x4_t(a).packu(b);
}

inline uint32_t ftoir32(const uint32_t a, const uint32_t b) {
  const float f = std::ldexp(as_f32(a), static_cast<int32_t>(b));
  return static_cast<uint32_t>(static_cast<int32_t>(std::round(f)));
}

inline uint32_t ftoir16x2(const uint32_t a, const uint32_t b) {
  return f16x2_t(a).packir(b);
}

inline uint32_t ftoir8x4(const uint32_t a, const uint32_t b) {
  return f8x4_t(a).packir(b);
}

inline uint32_t ftour32(const uint32_t a, const uint32_t b) {
  const float f = std::ldexp(as_f32(a), static_cast<int32_t>(b));
  return static_cast<uint32_t>(std::round(f));
}

inline uint32_t ftour16x2(const uint32_t a, const uint32_t b) {
  return f16x2_t(a).packur(b);
}

inline uint32_t ftour8x4(const uint32_t a, const uint32_t b) {
  return f8x4_t(a).packur(b);
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
      } else {
        return 0u;
      }

    case 0x00000001u:
      if (b == 0x00000000u) {
        // CPU features:
        //   VEC (vector processor)     = 1 << 0
        //   PO (packed operations)     = 1 << 1
        //   MUL (integer mul)          = 1 << 2
        //   DIV (integer mul)          = 1 << 3
        //   SA (saturating arithmetic) = 1 << 4
        //   FP (floating point)        = 1 << 5
        //   SQRT (float sqrt)          = 1 << 6
        return 0x0000007fu;
      } else {
        return 0u;
      }

    default:
      return 0u;
  }
}

uint32_t cpu_simple_t::run(const int64_t max_cycles) {
  m_syscalls.clear();
  m_regs[REG_PC] = RESET_PC;
  m_fetched_instr_count = 0u;
  m_vector_loop_count = 0u;
  m_total_cycle_count = 0u;

  // Initialize the pipeline state.
  vector_state_t vector = vector_state_t();
  id_in_t id_in = id_in_t();
  ex_in_t ex_in = ex_in_t();
  mem_in_t mem_in = mem_in_t();
  wb_in_t wb_in = wb_in_t();

  try {
    while (!m_syscalls.terminate() && !m_terminate_requested) {
      uint32_t next_pc;
      bool next_cycle_continues_a_vector_loop;

      // Simulator routine call handling.
      // Simulator routines start at PC = 0xffff0000.
      if ((m_regs[REG_PC] & 0xffff0000u) == 0xffff0000u) {
        // Call the routine.
        const uint32_t routine_no = (m_regs[REG_PC] - 0xffff0000u) >> 2u;
        m_syscalls.call(routine_no, m_regs);

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
          id_in.instr = m_ram.load32(instr_pc);

          // We terminate the simulation when we encounter a jump to address zero.
          if (instr_pc == 0x00000000) {
            m_regs[1] = 1;
            m_syscalls.call(static_cast<uint32_t>(syscalls_t::routine_t::EXIT), m_regs);
          }

          ++m_fetched_instr_count;
        }
      } else {
        ++m_vector_loop_count;
      }

      // ID/RF
      {
        // Get the instruction word.
        const uint32_t iword = id_in.instr;

        // Detect encoding class (A, B or C).
        const bool op_class_B = ((iword & 0xfc00007cu) == 0x0000007cu);
        const bool op_class_A = ((iword & 0xfc000000u) == 0x00000000u) && !op_class_B;
        const bool op_class_D = ((iword & 0xc0000000u) == 0xc0000000u);
        const bool op_class_C = !op_class_A && !op_class_B && !op_class_D;

        // Is this a vector operation?
        const uint32_t vec_mask = op_class_A ? 3u : (op_class_B || op_class_C ? 2u : 0u);
        const uint32_t vector_mode = (iword >> 14u) & vec_mask;
        const bool is_vector_op = (vector_mode != 0u);
        const bool is_folding_vector_op = (vector_mode == 1u);

        // Is this a packed operation?
        const uint32_t packed_mode = (op_class_A || op_class_B ? ((iword & 0x00000180u) >> 7) : 0u);

        // Extract parts of the instruction.
        // NOTE: These may or may not be valid, depending on the instruction type.
        const uint32_t reg1 = (iword >> 21u) & 31u;
        const uint32_t reg2 = (iword >> 16u) & 31u;
        const uint32_t reg3 = (iword >> 9u) & 31u;
        const uint32_t imm15 = (iword & 0x00007fffu) | ((iword & 0x00004000u) ? 0xffff8000u : 0u);
        const uint32_t imm21 = (iword & 0x001fffffu) | ((iword & 0x00100000u) ? 0xffe00000u : 0u);

        // == VECTOR STATE HANDLING ==

        const uint32_t vector_len = m_regs[REG_VL] & (2 * NUM_VECTOR_ELEMENTS - 1);
        if (is_vector_op) {
          const uint32_t vector_stride = op_class_C ? imm15 : m_regs[reg3];

          // Start a new or continue an ongoing vector operartion?
          if (!vector.active) {
            if (vector_len == 0u) {
              // Skip this cycle (NOP) if the vector length is zero.
              vector.active = false;
              m_regs[REG_PC] = id_in.pc + 4u;
              continue;
            }

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
        next_cycle_continues_a_vector_loop = is_vector_op && ((vector.idx + 1) < vector_len);

        // == BRANCH HANDLING ==

        const bool is_bcc = ((iword & 0xe0000000u) == 0xc0000000u);
        const bool is_j = ((iword & 0xf8000000u) == 0xe0000000u);
        const bool is_subroutine_branch = ((iword & 0xfc000000u) == 0xe4000000u);
        const bool is_branch = is_bcc || is_j;

        if (is_bcc) {
          // b[cc]: Evaluate condition (for b[cc]).
          bool branch_taken = false;
          const uint32_t branch_condition_value = m_regs[reg1];
          const uint32_t condition = (iword >> 26u) & 0x0000003fu;
          switch (condition) {
            case 0x30u:  // bz
              branch_taken = (branch_condition_value == 0u);
              break;
            case 0x31u:  // bnz
              branch_taken = (branch_condition_value != 0u);
              break;
            case 0x32u:  // bs
              branch_taken = (branch_condition_value == 0xffffffffu);
              break;
            case 0x33u:  // bns
              branch_taken = (branch_condition_value != 0xffffffffu);
              break;
            case 0x34u:  // blt
              branch_taken = ((branch_condition_value & 0x80000000u) != 0u);
              break;
            case 0x35u:  // bge
              branch_taken = ((branch_condition_value & 0x80000000u) == 0u);
              break;
            case 0x36u:  // ble
              branch_taken =
                  ((branch_condition_value & 0x80000000u) != 0u) || (branch_condition_value == 0u);
              break;
            case 0x37u:  // bgt
              branch_taken =
                  ((branch_condition_value & 0x80000000u) == 0u) && (branch_condition_value != 0u);
              break;
          }
          next_pc = branch_taken ? (id_in.pc + (imm21 << 2u)) : (id_in.pc + 4u);
        } else if (is_j) {
          // j/jl
          const uint32_t base_address = m_regs[reg1];
          next_pc = base_address + (imm21 << 2u);
        } else {
          // No branch: Increment the PC by 4.
          next_pc = id_in.pc + 4u;
        }

        // == DECODE ==

        // Is this a mem load/store operation?
        const bool is_ldx =
            ((iword & 0xfc000078u) == 0x00000000u) && ((iword & 0x00000007u) != 0x00000000u);
        const bool is_ld =
            ((iword & 0xe0000000u) == 0x00000000u) && ((iword & 0x1c000000u) != 0x00000000u);
        const bool is_mem_load = is_ldx || is_ld;
        const bool is_stx = ((iword & 0xfc000078u) == 0x00000008u);
        const bool is_st = ((iword & 0xe0000000u) == 0x20000000u);
        const bool is_mem_store = is_stx || is_st;
        const bool is_mem_op = (is_mem_load || is_mem_store);

        // Is this ADDPCHI?
        const bool is_addpchi = ((iword & 0xfc000000u) == 0xf4000000u);

        // Should we use reg1 as a source (special case)?
        const bool reg1_is_src = is_mem_store || is_branch;

        // Should we use reg2 as a source?
        const bool reg2_is_src = op_class_A || op_class_B || op_class_C;

        // Should we use reg3 as a source?
        const bool reg3_is_src = op_class_A;

        // Should we use reg1 as a destination?
        const bool reg1_is_dst = !reg1_is_src;

        // Determine the source & destination register numbers (zero for none).
        const uint32_t src_reg_a =
            (is_subroutine_branch || is_addpchi) ? REG_PC : (reg2_is_src ? reg2 : REG_Z);
        const uint32_t src_reg_b = reg3_is_src ? reg3 : REG_Z;
        const uint32_t src_reg_c = reg1_is_src ? reg1 : REG_Z;
        const uint32_t dst_reg = is_subroutine_branch ? REG_LR : (reg1_is_dst ? reg1 : REG_Z);

        // Determine EX operation.
        uint32_t ex_op = EX_OP_CPUID;
        if (is_subroutine_branch) {
          ex_op = EX_OP_ADD;
        } else if (op_class_A && ((iword & 0x000001f0u) != 0x00000000u)) {
          ex_op = iword & 0x0000007fu;
        } else if (op_class_B) {
          ex_op = ((iword >> 1) & 0x00003f00u) | (iword & 0x0000007fu);
        } else if (op_class_C && ((iword & 0xc0000000u) != 0x00000000u)) {
          ex_op = iword >> 26u;
        } else if (op_class_D) {
          switch (iword & 0xfc000000u) {
            case 0xe8000000u:  // ldli
              ex_op = EX_OP_OR;
              break;
            case 0xec000000u:  // ldhi
              ex_op = EX_OP_LDHI;
              break;
            case 0xf0000000u:  // ldhio
              ex_op = EX_OP_LDHIO;
              break;
            case 0xf4000000u:  // addpchi
              ex_op = EX_OP_ADDPCHI;
              break;
          }
        }

        // Determine MEM operation.
        uint32_t mem_op = MEM_OP_NONE;
        if (is_mem_load) {
          mem_op = (is_ldx ? (iword & 0x0000007fu) : (iword >> 26u));
        } else if (is_mem_store) {
          mem_op = (is_stx ? (iword & 0x0000007fu) : (iword >> 26u));
        }

        // Check what type of registers should be used (vector or scalar).
        const bool reg1_is_vector = is_vector_op;
        const bool reg2_is_vector = is_vector_op && !is_mem_op;
        const bool reg3_is_vector = ((vector_mode & 1u) != 0u);

        // Read from the register files.
        const uint32_t reg_a_data =
            reg2_is_vector ? m_vregs[src_reg_a][vector.idx] : m_regs[src_reg_a];
        const uint32_t vector_idx_b = vector.folding ? (vector.idx + m_regs[REG_VL]) : vector.idx;
        uint32_t reg_b_data = reg3_is_vector ? m_vregs[src_reg_b][vector_idx_b] : m_regs[src_reg_b];
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
                                 : (op_class_C ? imm15 : (op_class_D ? imm21 : reg_b_data)));
        ex_in.src_c = reg_c_data;
        ex_in.dst_reg = dst_reg;
        ex_in.dst_idx = vector.idx;
        ex_in.dst_is_vector = is_vector_op;
        ex_in.ex_op = ex_op;
        ex_in.packed_mode = packed_mode;
        ex_in.mem_op = mem_op;

        // Debug trace.
        {
          debug_trace_t trace;
          trace.valid = true;
          trace.src_a_valid = reg2_is_src;
          trace.src_b_valid = reg3_is_src;
          trace.src_c_valid = reg1_is_src;
          trace.pc = id_in.pc;
          trace.src_a = ex_in.src_a;
          trace.src_b = ex_in.src_b;
          trace.src_c = ex_in.src_c;
          append_debug_trace(trace);
        }
      }

      // EX
      {
        uint32_t ex_result = 0u;

        // Do the operation.
        if (ex_in.mem_op != MEM_OP_NONE) {
          // AGU - Address Generation Unit.
          ex_result = ex_in.src_a + ex_in.src_b * index_scale_factor(ex_in.packed_mode);
        } else {
          switch (ex_in.ex_op) {
            case EX_OP_CPUID:
              ex_result = cpuid32(ex_in.src_a, ex_in.src_b);
              break;

            case EX_OP_LDHI:
              ex_result = ex_in.src_b << 11u;
              break;
            case EX_OP_LDHIO:
              ex_result = (ex_in.src_b << 11u) | 0x7ffu;
              break;
            case EX_OP_ADDPCHI:
              ex_result = ex_in.src_a + (ex_in.src_b << 11u);
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
                  ex_result = set16x2(
                      ex_in.src_a, ex_in.src_b, [](uint16_t a, uint16_t b) { return a == b; });
                  break;
                default:
                  ex_result = set32(
                      ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) { return a == b; });
              }
              break;
            case EX_OP_SNE:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result =
                      set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t a, uint8_t b) { return a != b; });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = set16x2(
                      ex_in.src_a, ex_in.src_b, [](uint16_t a, uint16_t b) { return a != b; });
                  break;
                default:
                  ex_result = set32(
                      ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) { return a != b; });
              }
              break;
            case EX_OP_SLT:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t a, uint8_t b) {
                    return static_cast<int8_t>(a) < static_cast<int8_t>(b);
                  });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t a, uint16_t b) {
                    return static_cast<int16_t>(a) < static_cast<int16_t>(b);
                  });
                  break;
                default:
                  ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                    return static_cast<int32_t>(a) < static_cast<int32_t>(b);
                  });
              }
              break;
            case EX_OP_SLTU:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result =
                      set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t a, uint8_t b) { return a < b; });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = set16x2(
                      ex_in.src_a, ex_in.src_b, [](uint16_t a, uint16_t b) { return a < b; });
                  break;
                default:
                  ex_result =
                      set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) { return a < b; });
              }
              break;
            case EX_OP_SLE:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t a, uint8_t b) {
                    return static_cast<int8_t>(a) <= static_cast<int8_t>(b);
                  });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t a, uint16_t b) {
                    return static_cast<int16_t>(a) <= static_cast<int16_t>(b);
                  });
                  break;
                default:
                  ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                    return static_cast<int32_t>(a) <= static_cast<int32_t>(b);
                  });
              }
              break;
            case EX_OP_SLEU:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result =
                      set8x4(ex_in.src_a, ex_in.src_b, [](uint8_t a, uint8_t b) { return a <= b; });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = set16x2(
                      ex_in.src_a, ex_in.src_b, [](uint16_t a, uint16_t b) { return a <= b; });
                  break;
                default:
                  ex_result = set32(
                      ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) { return a <= b; });
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
                  ex_result = sel32(ex_in.src_a,
                                    ex_in.src_b,
                                    set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t x, uint16_t y) {
                                      return x < y;
                                    }));
                  break;
                default:
                  ex_result = sel32(ex_in.src_a,
                                    ex_in.src_b,
                                    set32(ex_in.src_a, ex_in.src_b, [](uint32_t x, uint32_t y) {
                                      return x < y;
                                    }));
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
                  ex_result = sel32(ex_in.src_a,
                                    ex_in.src_b,
                                    set16x2(ex_in.src_a, ex_in.src_b, [](uint16_t x, uint16_t y) {
                                      return x > y;
                                    }));
                  break;
                default:
                  ex_result = sel32(ex_in.src_a,
                                    ex_in.src_b,
                                    set32(ex_in.src_a, ex_in.src_b, [](uint32_t x, uint32_t y) {
                                      return x > y;
                                    }));
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
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = clz8x4(ex_in.src_a);
                  break;
                case PACKED_HALF_WORD:
                  ex_result = clz16x2(ex_in.src_a);
                  break;
                default:
                  ex_result = clz32(ex_in.src_a);
              }
              break;
            case EX_OP_REV:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = rev8x4(ex_in.src_a);
                  break;
                case PACKED_HALF_WORD:
                  ex_result = rev16x2(ex_in.src_a);
                  break;
                default:
                  ex_result = rev32(ex_in.src_a);
              }
              break;
            case EX_OP_PACK:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = pack8x4(ex_in.src_a, ex_in.src_b);
                  break;
                case PACKED_HALF_WORD:
                  ex_result = pack16x2(ex_in.src_a, ex_in.src_b);
                  break;
                default:
                  ex_result = pack32(ex_in.src_a, ex_in.src_b);
              }
              break;
            case EX_OP_PACKS:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = packs8x4(ex_in.src_a, ex_in.src_b);
                  break;
                case PACKED_HALF_WORD:
                  ex_result = packs16x2(ex_in.src_a, ex_in.src_b);
                  break;
                default:
                  ex_result = packs32(ex_in.src_a, ex_in.src_b);
              }
              break;
            case EX_OP_PACKSU:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = packsu8x4(ex_in.src_a, ex_in.src_b);
                  break;
                case PACKED_HALF_WORD:
                  ex_result = packsu16x2(ex_in.src_a, ex_in.src_b);
                  break;
                default:
                  ex_result = packsu32(ex_in.src_a, ex_in.src_b);
              }
              break;

            case EX_OP_ADDS:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = saturating_op_8x4(
                      ex_in.src_a, ex_in.src_b, [](int16_t x, int16_t y) -> int16_t {
                        return x + y;
                      });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = saturating_op_16x2(
                      ex_in.src_a, ex_in.src_b, [](int32_t x, int32_t y) -> int32_t {
                        return x + y;
                      });
                  break;
                default:
                  ex_result = saturating_op_32(
                      ex_in.src_a, ex_in.src_b, [](int64_t x, int64_t y) -> int64_t {
                        return x + y;
                      });
              }
              break;
            case EX_OP_ADDSU:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = saturating_op_u8x4(
                      ex_in.src_a, ex_in.src_b, [](uint16_t x, uint16_t y) -> uint16_t {
                        return x + y;
                      });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = saturating_op_u16x2(
                      ex_in.src_a, ex_in.src_b, [](uint32_t x, uint32_t y) -> uint32_t {
                        return x + y;
                      });
                  break;
                default:
                  ex_result = saturating_op_u32(
                      ex_in.src_a, ex_in.src_b, [](uint64_t x, uint64_t y) -> uint64_t {
                        return x + y;
                      });
              }
              break;
            case EX_OP_ADDH:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = halving_op_8x4(ex_in.src_a,
                                             ex_in.src_b,
                                             [](int16_t x, int16_t y) -> int16_t { return x + y; });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = halving_op_16x2(
                      ex_in.src_a, ex_in.src_b, [](int32_t x, int32_t y) -> int32_t {
                        return x + y;
                      });
                  break;
                default:
                  ex_result = halving_op_32(ex_in.src_a,
                                            ex_in.src_b,
                                            [](int64_t x, int64_t y) -> int64_t { return x + y; });
              }
              break;
            case EX_OP_ADDHU:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = halving_op_u8x4(
                      ex_in.src_a, ex_in.src_b, [](uint16_t x, uint16_t y) -> uint16_t {
                        return x + y;
                      });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = halving_op_u16x2(
                      ex_in.src_a, ex_in.src_b, [](uint32_t x, uint32_t y) -> uint32_t {
                        return x + y;
                      });
                  break;
                default:
                  ex_result = halving_op_u32(
                      ex_in.src_a, ex_in.src_b, [](uint64_t x, uint64_t y) -> uint64_t {
                        return x + y;
                      });
              }
              break;
            case EX_OP_SUBS:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = saturating_op_8x4(
                      ex_in.src_a, ex_in.src_b, [](int16_t x, int16_t y) -> int16_t {
                        return x - y;
                      });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = saturating_op_16x2(
                      ex_in.src_a, ex_in.src_b, [](int32_t x, int32_t y) -> int32_t {
                        return x - y;
                      });
                  break;
                default:
                  ex_result = saturating_op_32(
                      ex_in.src_a, ex_in.src_b, [](int64_t x, int64_t y) -> int64_t {
                        return x - y;
                      });
              }
              break;
            case EX_OP_SUBSU:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = saturating_op_u8x4(
                      ex_in.src_a, ex_in.src_b, [](uint16_t x, uint16_t y) -> uint16_t {
                        return x - y;
                      });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = saturating_op_u16x2(
                      ex_in.src_a, ex_in.src_b, [](uint32_t x, uint32_t y) -> uint32_t {
                        return x - y;
                      });
                  break;
                default:
                  ex_result = saturating_op_u32(
                      ex_in.src_a, ex_in.src_b, [](uint64_t x, uint64_t y) -> uint64_t {
                        return x - y;
                      });
              }
              break;
            case EX_OP_SUBH:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = halving_op_8x4(ex_in.src_a,
                                             ex_in.src_b,
                                             [](int16_t x, int16_t y) -> int16_t { return x - y; });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = halving_op_16x2(
                      ex_in.src_a, ex_in.src_b, [](int32_t x, int32_t y) -> int32_t {
                        return x - y;
                      });
                  break;
                default:
                  ex_result = halving_op_32(ex_in.src_a,
                                            ex_in.src_b,
                                            [](int64_t x, int64_t y) -> int64_t { return x - y; });
              }
              break;
            case EX_OP_SUBHU:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = halving_op_u8x4(
                      ex_in.src_a, ex_in.src_b, [](uint16_t x, uint16_t y) -> uint16_t {
                        return x - y;
                      });
                  break;
                case PACKED_HALF_WORD:
                  ex_result = halving_op_u16x2(
                      ex_in.src_a, ex_in.src_b, [](uint32_t x, uint32_t y) -> uint32_t {
                        return x - y;
                      });
                  break;
                default:
                  ex_result = halving_op_u32(
                      ex_in.src_a, ex_in.src_b, [](uint64_t x, uint64_t y) -> uint64_t {
                        return x - y;
                      });
              }
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
              break;
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
              break;

            case EX_OP_ITOF:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = itof8x4(ex_in.src_a, ex_in.src_b);
                  break;
                case PACKED_HALF_WORD:
                  ex_result = itof16x2(ex_in.src_a, ex_in.src_b);
                  break;
                default:
                  ex_result = itof32(ex_in.src_a, ex_in.src_b);
              }
              break;
            case EX_OP_UTOF:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = utof8x4(ex_in.src_a, ex_in.src_b);
                  break;
                case PACKED_HALF_WORD:
                  ex_result = utof16x2(ex_in.src_a, ex_in.src_b);
                  break;
                default:
                  ex_result = utof32(ex_in.src_a, ex_in.src_b);
              }
              break;
            case EX_OP_FTOI:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = ftoi8x4(ex_in.src_a, ex_in.src_b);
                  break;
                case PACKED_HALF_WORD:
                  ex_result = ftoi16x2(ex_in.src_a, ex_in.src_b);
                  break;
                default:
                  ex_result = ftoi32(ex_in.src_a, ex_in.src_b);
              }
              break;
            case EX_OP_FTOU:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = ftou8x4(ex_in.src_a, ex_in.src_b);
                  break;
                case PACKED_HALF_WORD:
                  ex_result = ftou16x2(ex_in.src_a, ex_in.src_b);
                  break;
                default:
                  ex_result = ftou32(ex_in.src_a, ex_in.src_b);
              }
              break;
            case EX_OP_FTOIR:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = ftoir8x4(ex_in.src_a, ex_in.src_b);
                  break;
                case PACKED_HALF_WORD:
                  ex_result = ftoir16x2(ex_in.src_a, ex_in.src_b);
                  break;
                default:
                  ex_result = ftoir32(ex_in.src_a, ex_in.src_b);
              }
              break;
            case EX_OP_FTOUR:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = ftour8x4(ex_in.src_a, ex_in.src_b);
                  break;
                case PACKED_HALF_WORD:
                  ex_result = ftour16x2(ex_in.src_a, ex_in.src_b);
                  break;
                default:
                  ex_result = ftour32(ex_in.src_a, ex_in.src_b);
              }
              break;
            case EX_OP_FPACK:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  // Nothing to do here!
                  break;
                case PACKED_HALF_WORD:
                  ex_result = fpack16x2(ex_in.src_a, ex_in.src_b);
                  break;
                default:
                  ex_result = fpack32(ex_in.src_a, ex_in.src_b);
              }
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
            case EX_OP_FSEQ:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = f8x4_t(ex_in.src_a).fseq(f8x4_t(ex_in.src_b));
                  break;
                case PACKED_HALF_WORD:
                  ex_result = f16x2_t(ex_in.src_a).fseq(f16x2_t(ex_in.src_b));
                  break;
                default:
                  ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                    return as_f32(a) == as_f32(b);
                  });
              }
              break;
            case EX_OP_FSNE:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = f8x4_t(ex_in.src_a).fsne(f8x4_t(ex_in.src_b));
                  break;
                case PACKED_HALF_WORD:
                  ex_result = f16x2_t(ex_in.src_a).fsne(f16x2_t(ex_in.src_b));
                  break;
                default:
                  ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                    return as_f32(a) != as_f32(b);
                  });
              }
              break;
            case EX_OP_FSLT:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = f8x4_t(ex_in.src_a).fsle(f8x4_t(ex_in.src_b));
                  break;
                case PACKED_HALF_WORD:
                  ex_result = f16x2_t(ex_in.src_a).fslt(f16x2_t(ex_in.src_b));
                  break;
                default:
                  ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                    return as_f32(a) < as_f32(b);
                  });
              }
              break;
            case EX_OP_FSLE:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = f8x4_t(ex_in.src_a).fsle(f8x4_t(ex_in.src_b));
                  break;
                case PACKED_HALF_WORD:
                  ex_result = f16x2_t(ex_in.src_a).fsle(f16x2_t(ex_in.src_b));
                  break;
                default:
                  ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                    return as_f32(a) <= as_f32(b);
                  });
              }
              break;
            case EX_OP_FSUNORD:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = f8x4_t(ex_in.src_a).fsunord(f8x4_t(ex_in.src_b));
                  break;
                case PACKED_HALF_WORD:
                  ex_result = f16x2_t(ex_in.src_a).fsunord(f16x2_t(ex_in.src_b));
                  break;
                default:
                  ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                    return float32_isnan(a) || float32_isnan(b);
                  });
              }
              break;
            case EX_OP_FSORD:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  ex_result = f8x4_t(ex_in.src_a).fsord(f8x4_t(ex_in.src_b));
                  break;
                case PACKED_HALF_WORD:
                  ex_result = f16x2_t(ex_in.src_a).fsord(f16x2_t(ex_in.src_b));
                  break;
                default:
                  ex_result = set32(ex_in.src_a, ex_in.src_b, [](uint32_t a, uint32_t b) {
                    return !float32_isnan(a) && !float32_isnan(b);
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
            case EX_OP_FUNPL:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  // Nothing to do here.
                  break;
                case PACKED_HALF_WORD:
                  ex_result =
                      f16x2_t::from_f32x2(f8x4_t(ex_in.src_a)[0], f8x4_t(ex_in.src_a)[2]).packf();
                  break;
                default:
                  ex_result = as_u32(f16x2_t(ex_in.src_a)[0]);
              }
              break;
            case EX_OP_FUNPH:
              switch (ex_in.packed_mode) {
                case PACKED_BYTE:
                  // Nothing to do here.
                  break;
                case PACKED_HALF_WORD:
                  ex_result =
                      f16x2_t::from_f32x2(f8x4_t(ex_in.src_a)[1], f8x4_t(ex_in.src_a)[3]).packf();
                  break;
                default:
                  ex_result = as_u32(f16x2_t(ex_in.src_a)[1]);
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
          }
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
            mem_result = m_ram.load8signed(mem_in.mem_addr);
            break;
          case MEM_OP_LOADU8:
            mem_result = m_ram.load8(mem_in.mem_addr);
            break;
          case MEM_OP_LOAD16:
            mem_result = m_ram.load16signed(mem_in.mem_addr);
            break;
          case MEM_OP_LOADU16:
            mem_result = m_ram.load16(mem_in.mem_addr);
            break;
          case MEM_OP_LOAD32:
            mem_result = m_ram.load32(mem_in.mem_addr);
            break;
          case MEM_OP_LDEA:
            mem_result = mem_in.mem_addr;
            break;
          case MEM_OP_STORE8:
            m_ram.store8(mem_in.mem_addr, mem_in.store_data);
            break;
          case MEM_OP_STORE16:
            m_ram.store16(mem_in.mem_addr, mem_in.store_data);
            break;
          case MEM_OP_STORE32:
            m_ram.store32(mem_in.mem_addr, mem_in.store_data);
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

      ++m_total_cycle_count;
      if (max_cycles >= 0 && static_cast<int64_t>(m_total_cycle_count) >= max_cycles) {
        m_terminate_requested = true;
      }
    }
  } catch (std::exception& e) {
    std::string dump("\n");
    for (int i = 1; i <= 25; ++i) {
      dump += "S" + as_dec(i) + ": " + as_hex32(m_regs[i]) + "\n";
    }
    dump += "FP: " + as_hex32(m_regs[REG_FP]) + "\n";
    dump += "TP: " + as_hex32(m_regs[REG_TP]) + "\n";
    dump += "SP: " + as_hex32(m_regs[REG_SP]) + "\n";
    dump += "VL: " + as_hex32(m_regs[REG_VL]) + "\n";
    dump += "LR: " + as_hex32(m_regs[REG_LR]) + "\n";
    dump += "PC: " + as_hex32(m_regs[REG_PC]) + "\n";
    throw std::runtime_error(e.what() + dump);
  }

  return m_syscalls.exit_code();
}
