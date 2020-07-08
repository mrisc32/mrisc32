//--------------------------------------------------------------------------------------------------
// Copyright (c) 2019 Marcus Geelnard
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

//--------------------------------------------------------------------------------------------------
// This is a simple implementation of 8-bit and 16-bit packed floating point support, which converts
// the packed floating point values to/from 32-bit floating point and performs all operations using
// 32-bit floating point arithmetic.
//
// NOTE: This implementation is not 100% compatible with the MRISC32-A1 hardware implementation, nor
// is it 100% IEEE 754 compatible. Its main purpose is to make it possible to run programs in the
// simulator and get reasonable (but not necessarily correct) results.
//--------------------------------------------------------------------------------------------------

#ifndef SIM_PACKED_FLOAT_HPP_
#define SIM_PACKED_FLOAT_HPP_

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <limits>

//--------------------------------------------------------------------------------------------------
// 16-bit x 2 implementation.
//--------------------------------------------------------------------------------------------------

class f16x2_t {
public:
  inline f16x2_t(const uint32_t x) {
    m_values[0] = f16_to_f32(x & 0x0000ffffu);
    m_values[1] = f16_to_f32((x >> 16) & 0x0000ffffu);
  }

  inline f16x2_t(const f16x2_t& x) {
    m_values[0] = x.m_values[0];
    m_values[1] = x.m_values[1];
  }

  static inline f16x2_t from_f32x2(const float a, const float b) {
    return f16x2_t(a, b);
  }

  static inline f16x2_t itof(const uint32_t x, const uint32_t scale) {
    return f16x2_t(i16_to_f32(x & 0x0000ffffu, scale), i16_to_f32((x >> 16) & 0x0000ffffu, scale));
  }

  static inline f16x2_t utof(const uint32_t x, const uint32_t scale) {
    return f16x2_t(u16_to_f32(x & 0x0000ffffu, scale), u16_to_f32((x >> 16) & 0x0000ffffu, scale));
  }

  inline uint32_t packf() const {
    return f32_to_f16(m_values[0]) | (f32_to_f16(m_values[1]) << 16);
  }

  inline uint32_t packi(const uint32_t scale) const {
    return f32_to_i16(m_values[0], scale) | (f32_to_i16(m_values[1], scale) << 16);
  }

  inline uint32_t packu(const uint32_t scale) const {
    return f32_to_u16(m_values[0], scale) | (f32_to_u16(m_values[1], scale) << 16);
  }

  inline uint32_t packir(const uint32_t scale) const {
    return f32_to_i16r(m_values[0], scale) | (f32_to_i16r(m_values[1], scale) << 16);
  }

  inline uint32_t packur(const uint32_t scale) const {
    return f32_to_u16r(m_values[0], scale) | (f32_to_u16r(m_values[1], scale) << 16);
  }

  inline float operator[](const int k) const {
    return m_values[k];
  }

  inline f16x2_t& operator=(const f16x2_t& x) {
    m_values[0] = x.m_values[0];
    m_values[1] = x.m_values[1];
    return *this;
  }

  inline f16x2_t& operator+=(const f16x2_t& y) {
    m_values[0] += y.m_values[0];
    m_values[1] += y.m_values[1];
    return *this;
  }

  inline f16x2_t& operator-=(const f16x2_t& y) {
    m_values[0] -= y.m_values[0];
    m_values[1] -= y.m_values[1];
    return *this;
  }

  inline f16x2_t& operator*=(const f16x2_t& y) {
    m_values[0] *= y.m_values[0];
    m_values[1] *= y.m_values[1];
    return *this;
  }

  inline f16x2_t& operator/=(const f16x2_t& y) {
    m_values[0] /= y.m_values[0];
    m_values[1] /= y.m_values[1];
    return *this;
  }

  inline f16x2_t sqrt() const {
    return f16x2_t(std::sqrt(m_values[0]), std::sqrt(m_values[1]));
  }

  inline f16x2_t& min(const f16x2_t& y) {
    m_values[0] = std::min(m_values[0], y.m_values[0]);
    m_values[1] = std::min(m_values[1], y.m_values[1]);
    return *this;
  }

  inline f16x2_t& max(const f16x2_t& y) {
    m_values[0] = std::max(m_values[0], y.m_values[0]);
    m_values[1] = std::max(m_values[1], y.m_values[1]);
    return *this;
  }

  inline uint32_t fseq(const f16x2_t& y) {
    return ((m_values[0] == y.m_values[0]) ? 0x0000ffffu : 0u) |
           ((m_values[1] == y.m_values[1]) ? 0xffff0000u : 0u);
  }

  inline uint32_t fsne(const f16x2_t& y) {
    return ((m_values[0] != y.m_values[0]) ? 0x0000ffffu : 0u) |
           ((m_values[1] != y.m_values[1]) ? 0xffff0000u : 0u);
  }

  inline uint32_t fslt(const f16x2_t& y) {
    return ((m_values[0] < y.m_values[0]) ? 0x0000ffffu : 0u) |
           ((m_values[1] < y.m_values[1]) ? 0xffff0000u : 0u);
  }

  inline uint32_t fsle(const f16x2_t& y) {
    return ((m_values[0] <= y.m_values[0]) ? 0x0000ffffu : 0u) |
           ((m_values[1] <= y.m_values[1]) ? 0xffff0000u : 0u);
  }

  inline uint32_t fsunord(const f16x2_t& y) {
    return ((std::isnan(m_values[0]) || std::isnan(y.m_values[0])) ? 0x0000ffffu : 0u) |
           ((std::isnan(m_values[1]) || std::isnan(y.m_values[1])) ? 0xffff0000u : 0u);
  }

  inline uint32_t fsord(const f16x2_t& y) {
    return ((!std::isnan(m_values[0]) && !std::isnan(y.m_values[0])) ? 0x0000ffffu : 0u) |
           ((!std::isnan(m_values[1]) && !std::isnan(y.m_values[1])) ? 0xffff0000u : 0u);
  }

private:
  inline f16x2_t(const float a, const float b) {
    m_values[0] = a;
    m_values[1] = b;
  }

  static inline float i16_to_f32(const uint32_t x, const uint32_t scale) {
    return std::ldexp(static_cast<float>(static_cast<int16_t>(static_cast<uint16_t>(x))),
                      -static_cast<int32_t>(scale));
  }

  static inline float u16_to_f32(const uint32_t x, const uint32_t scale) {
    return std::ldexp(static_cast<float>(x), -static_cast<int32_t>(scale));
  }

  static inline uint32_t f32_to_i16(const float x, const uint32_t scale) {
    const auto f = std::ldexp(x, static_cast<int32_t>(scale));
    return static_cast<uint32_t>(static_cast<uint16_t>(static_cast<int16_t>(f)));
  }

  static inline uint32_t f32_to_u16(const float x, const uint32_t scale) {
    const auto f = std::ldexp(x, static_cast<int32_t>(scale));
    return static_cast<uint32_t>(static_cast<uint16_t>(f));
  }

  static inline uint32_t f32_to_i16r(const float x, const uint32_t scale) {
    const auto f = std::ldexp(x, static_cast<int32_t>(scale));
    return static_cast<uint32_t>(static_cast<uint16_t>(static_cast<int16_t>(std::round(f))));
  }

  static inline uint32_t f32_to_u16r(const float x, const uint32_t scale) {
    const auto f = std::ldexp(x, static_cast<int32_t>(scale));
    return static_cast<uint32_t>(static_cast<uint16_t>(std::round(f)));
  }

  static inline float f16_to_f32(const uint32_t x) {
    if ((x & 0xfc00u) == 0u) {
      return 0.0f;
    } else if ((x & 0xfc00u) == 0x8000u) {
      return -0.0f;
    } else if (x == 0x7c00u) {
      return std::numeric_limits<float>::quiet_NaN();
    } else if (x == 0xfc00u) {
      return -std::numeric_limits<float>::quiet_NaN();
    } else if ((x & 0xfc00u) == 0x7c00u) {
      return std::numeric_limits<float>::infinity();
    } else if ((x & 0xfc00u) == 0xfc00u) {
      return -std::numeric_limits<float>::infinity();
    }
    const uint32_t f32u = ((x & 0x8000u) << 16) | ((((x & 0x7c00u) >> 10) - 15u + 127u) << 23) |
                          ((x & 0x03ffu) << 13);
    float f32;
    std::memcpy(&f32, &f32u, sizeof(f32));
    return f32;
  }

  static inline uint32_t f32_to_f16(const float x) {
    uint32_t f32u;
    std::memcpy(&f32u, &x, sizeof(f32u));
    const uint32_t sign = ((f32u & 0x80000000u) >> 16);
    if ((f32u & 0x7f800000u) == 0u) {
      // Zero (we flush denormals to zero)
      return sign | 0u;
    } else if (std::isnan(x)) {
      // NaN
      return sign | 0x7c00u;
    } else if (std::isinf(x)) {
      // Inf
      return sign | 0x7fffu;
    }
    int32_t exp = static_cast<int32_t>((f32u >> 23) & 0x00ffu) - 127 + 15;
    uint32_t significand = (f32u & 0x007fffffu) + 0x00801000u;
    if ((significand & 0x01000000u) != 0u) {
      significand = significand >> 14;
      exp += 1;
    } else {
      significand = significand >> 13;
    }
    if (exp >= 31) {
      // Inf
      return sign | 0x7fffu;
    } else if (exp <= 0) {
      // Zero
      return sign | 0u;
    }
    return sign | (static_cast<uint32_t>(exp) << 10) | (significand & 0x3ffu);
  }

  float m_values[2];
};

inline f16x2_t operator+(const f16x2_t& a, const f16x2_t& b) {
  f16x2_t result(a);
  result += b;
  return result;
}

inline f16x2_t operator-(const f16x2_t& a, const f16x2_t& b) {
  f16x2_t result(a);
  result -= b;
  return result;
}

inline f16x2_t operator*(const f16x2_t& a, const f16x2_t& b) {
  f16x2_t result(a);
  result *= b;
  return result;
}

inline f16x2_t operator/(const f16x2_t& a, const f16x2_t& b) {
  f16x2_t result(a);
  result /= b;
  return result;
}

inline f16x2_t min(const f16x2_t& a, const f16x2_t& b) {
  f16x2_t result(a);
  result.min(b);
  return result;
}

inline f16x2_t max(const f16x2_t& a, const f16x2_t& b) {
  f16x2_t result(a);
  result.max(b);
  return result;
}

//--------------------------------------------------------------------------------------------------
// 8-bit x 4 implementation.
//--------------------------------------------------------------------------------------------------

class f8x4_t {
public:
  inline f8x4_t(const uint32_t x) {
    m_values[0] = f8_to_f32(x & 0x000000ffu);
    m_values[1] = f8_to_f32((x >> 8) & 0x000000ffu);
    m_values[2] = f8_to_f32((x >> 16) & 0x000000ffu);
    m_values[3] = f8_to_f32((x >> 24) & 0x000000ffu);
  }

  inline f8x4_t(const f8x4_t& x) {
    m_values[0] = x.m_values[0];
    m_values[1] = x.m_values[1];
    m_values[2] = x.m_values[2];
    m_values[3] = x.m_values[3];
  }

  static inline f8x4_t from_f16x4(const f16x2_t a, const f16x2_t b) {
    return f8x4_t(a[0], b[0], a[1], b[1]);
  }

  static inline f8x4_t itof(const uint32_t x, const uint32_t scale) {
    return f8x4_t(i8_to_f32(x & 0x000000ffu, scale),
                  i8_to_f32((x >> 8) & 0x000000ffu, scale),
                  i8_to_f32((x >> 16) & 0x000000ffu, scale),
                  i8_to_f32((x >> 24) & 0x000000ffu, scale));
  }

  static inline f8x4_t utof(const uint32_t x, const uint32_t scale) {
    return f8x4_t(u8_to_f32(x & 0x000000ffu, scale),
                  u8_to_f32((x >> 8) & 0x000000ffu, scale),
                  u8_to_f32((x >> 16) & 0x000000ffu, scale),
                  u8_to_f32((x >> 24) & 0x000000ffu, scale));
  }

  inline uint32_t packf() const {
    return f32_to_f8(m_values[0]) | (f32_to_f8(m_values[1]) << 8) | (f32_to_f8(m_values[2]) << 16) |
           (f32_to_f8(m_values[3]) << 24);
  }

  inline uint32_t packi(const uint32_t scale) const {
    return f32_to_i8(m_values[0], scale) | (f32_to_i8(m_values[1], scale) << 8) |
           (f32_to_i8(m_values[2], scale) << 16) | (f32_to_i8(m_values[3], scale) << 24);
  }

  inline uint32_t packu(const uint32_t scale) const {
    return f32_to_u8(m_values[0], scale) | (f32_to_u8(m_values[1], scale) << 8) |
           (f32_to_u8(m_values[2], scale) << 16) | (f32_to_u8(m_values[3], scale) << 24);
  }

  inline uint32_t packir(const uint32_t scale) const {
    return f32_to_i8r(m_values[0], scale) | (f32_to_i8r(m_values[1], scale) << 8) |
           (f32_to_i8r(m_values[2], scale) << 16) | (f32_to_i8r(m_values[3], scale) << 24);
  }

  inline uint32_t packur(const uint32_t scale) const {
    return f32_to_u8r(m_values[0], scale) | (f32_to_u8r(m_values[1], scale) << 8) |
           (f32_to_u8r(m_values[2], scale) << 16) | (f32_to_u8r(m_values[3], scale) << 24);
  }

  inline float operator[](const int k) const {
    return m_values[k];
  }

  inline f8x4_t& operator=(const f8x4_t& x) {
    m_values[0] = x.m_values[0];
    m_values[1] = x.m_values[1];
    m_values[2] = x.m_values[2];
    m_values[3] = x.m_values[3];
    return *this;
  }

  inline f8x4_t& operator+=(const f8x4_t& y) {
    m_values[0] += y.m_values[0];
    m_values[1] += y.m_values[1];
    m_values[2] += y.m_values[2];
    m_values[3] += y.m_values[3];
    return *this;
  }

  inline f8x4_t& operator-=(const f8x4_t& y) {
    m_values[0] -= y.m_values[0];
    m_values[1] -= y.m_values[1];
    m_values[2] -= y.m_values[2];
    m_values[3] -= y.m_values[3];
    return *this;
  }

  inline f8x4_t& operator*=(const f8x4_t& y) {
    m_values[0] *= y.m_values[0];
    m_values[1] *= y.m_values[1];
    m_values[2] *= y.m_values[2];
    m_values[3] *= y.m_values[3];
    return *this;
  }

  inline f8x4_t& operator/=(const f8x4_t& y) {
    m_values[0] /= y.m_values[0];
    m_values[1] /= y.m_values[1];
    m_values[2] /= y.m_values[2];
    m_values[3] /= y.m_values[3];
    return *this;
  }

  inline f8x4_t sqrt() const {
    return f8x4_t(std::sqrt(m_values[0]),
                  std::sqrt(m_values[1]),
                  std::sqrt(m_values[2]),
                  std::sqrt(m_values[3]));
  }

  inline f8x4_t& min(const f8x4_t& y) {
    m_values[0] = std::min(m_values[0], y.m_values[0]);
    m_values[1] = std::min(m_values[1], y.m_values[1]);
    m_values[2] = std::min(m_values[2], y.m_values[2]);
    m_values[3] = std::min(m_values[3], y.m_values[3]);
    return *this;
  }

  inline f8x4_t& max(const f8x4_t& y) {
    m_values[0] = std::max(m_values[0], y.m_values[0]);
    m_values[1] = std::max(m_values[1], y.m_values[1]);
    m_values[2] = std::max(m_values[2], y.m_values[2]);
    m_values[3] = std::max(m_values[3], y.m_values[3]);
    return *this;
  }

  inline uint32_t fseq(const f8x4_t& y) {
    return ((m_values[0] == y.m_values[0]) ? 0x000000ffu : 0u) |
           ((m_values[1] == y.m_values[1]) ? 0x0000ff00u : 0u) |
           ((m_values[2] == y.m_values[2]) ? 0x00ff0000u : 0u) |
           ((m_values[3] == y.m_values[3]) ? 0xff000000u : 0u);
  }

  inline uint32_t fsne(const f8x4_t& y) {
    return ((m_values[0] != y.m_values[0]) ? 0x000000ffu : 0u) |
           ((m_values[1] != y.m_values[1]) ? 0x0000ff00u : 0u) |
           ((m_values[2] != y.m_values[2]) ? 0x00ff0000u : 0u) |
           ((m_values[3] != y.m_values[3]) ? 0xff000000u : 0u);
  }

  inline uint32_t fslt(const f8x4_t& y) {
    return ((m_values[0] < y.m_values[0]) ? 0x000000ffu : 0u) |
           ((m_values[1] < y.m_values[1]) ? 0x0000ff00u : 0u) |
           ((m_values[2] < y.m_values[2]) ? 0x00ff0000u : 0u) |
           ((m_values[3] < y.m_values[3]) ? 0xff000000u : 0u);
  }

  inline uint32_t fsle(const f8x4_t& y) {
    return ((m_values[0] <= y.m_values[0]) ? 0x000000ffu : 0u) |
           ((m_values[1] <= y.m_values[1]) ? 0x0000ff00u : 0u) |
           ((m_values[2] <= y.m_values[2]) ? 0x00ff0000u : 0u) |
           ((m_values[3] <= y.m_values[3]) ? 0xff000000u : 0u);
  }

  inline uint32_t fsunord(const f8x4_t& y) {
    return ((std::isnan(m_values[0]) || std::isnan(y.m_values[0])) ? 0x000000ffu : 0u) |
           ((std::isnan(m_values[1]) || std::isnan(y.m_values[1])) ? 0x0000ff00u : 0u) |
           ((std::isnan(m_values[2]) || std::isnan(y.m_values[2])) ? 0x00ff0000u : 0u) |
           ((std::isnan(m_values[3]) || std::isnan(y.m_values[3])) ? 0xff000000u : 0u);
  }

  inline uint32_t fsord(const f8x4_t& y) {
    return ((!std::isnan(m_values[0]) && !std::isnan(y.m_values[0])) ? 0x000000ffu : 0u) |
           ((!std::isnan(m_values[1]) && !std::isnan(y.m_values[1])) ? 0x0000ff00u : 0u) |
           ((!std::isnan(m_values[2]) && !std::isnan(y.m_values[2])) ? 0x00ff0000u : 0u) |
           ((!std::isnan(m_values[3]) && !std::isnan(y.m_values[3])) ? 0xff000000u : 0u);
  }

private:
  inline f8x4_t(const float a, const float b, const float c, const float d) {
    m_values[0] = a;
    m_values[1] = b;
    m_values[2] = c;
    m_values[3] = d;
  }

  static inline float i8_to_f32(const uint32_t x, const uint32_t scale) {
    return std::ldexp(static_cast<float>(static_cast<int8_t>(static_cast<uint8_t>(x))),
                      -static_cast<int32_t>(scale));
  }

  static inline float u8_to_f32(const uint32_t x, const uint32_t scale) {
    return std::ldexp(static_cast<float>(x), -static_cast<int32_t>(scale));
  }

  static inline uint32_t f32_to_i8(const float x, const uint32_t scale) {
    const auto f = std::ldexp(x, static_cast<int32_t>(scale));
    return static_cast<uint32_t>(static_cast<uint8_t>(static_cast<int8_t>(f)));
  }

  static inline uint32_t f32_to_u8(const float x, const uint32_t scale) {
    const auto f = std::ldexp(x, static_cast<int32_t>(scale));
    return static_cast<uint32_t>(static_cast<uint8_t>(f));
  }

  static inline uint32_t f32_to_i8r(const float x, const uint32_t scale) {
    const auto f = std::ldexp(x, static_cast<int32_t>(scale));
    return static_cast<uint32_t>(static_cast<uint8_t>(static_cast<int8_t>(std::round(f))));
  }

  static inline uint32_t f32_to_u8r(const float x, const uint32_t scale) {
    const auto f = std::ldexp(x, static_cast<int32_t>(scale));
    return static_cast<uint32_t>(static_cast<uint8_t>(std::round(f)));
  }

  static inline float f8_to_f32(const uint32_t x) {
    if ((x & 0xf8u) == 0u) {
      return 0.0f;
    } else if ((x & 0xf8u) == 0x80u) {
      return -0.0f;
    } else if (x == 0x78u) {
      return std::numeric_limits<float>::quiet_NaN();
    } else if (x == 0xf8u) {
      return -std::numeric_limits<float>::quiet_NaN();
    } else if ((x & 0xf8u) == 0x78u) {
      return std::numeric_limits<float>::infinity();
    } else if ((x & 0xf8u) == 0xf8u) {
      return -std::numeric_limits<float>::infinity();
    }
    const uint32_t f32u = ((x & 0x80u) << 24) | ((((x & 0x78u) >> 3) - 7u + 127u) << 23) |
                          ((x & 0x07u) << 20);
    float f32;
    std::memcpy(&f32, &f32u, sizeof(f32));
    return f32;
  }

  static inline uint32_t f32_to_f8(const float x) {
    uint32_t f32u;
    std::memcpy(&f32u, &x, sizeof(f32u));
    const uint32_t sign = ((f32u & 0x80000000u) >> 24);
    if ((f32u & 0x7f800000u) == 0u) {
      // Zero (we flush denormals to zero)
      return sign | 0u;
    } else if (std::isnan(x)) {
      // NaN
      return sign | 0x78u;
    } else if (std::isinf(x)) {
      // Inf
      return sign | 0x7fu;
    }
    int32_t exp = static_cast<int32_t>((f32u >> 23) & 0x00ffu) - 127 + 7;
    uint32_t significand = (f32u & 0x007fffffu) + 0x00880000u;
    if ((significand & 0x01000000u) != 0u) {
      significand = significand >> 21;
      exp += 1;
    } else {
      significand = significand >> 20;
    }
    if (exp >= 15) {
      // Inf
      return sign | 0x7fu;
    } else if (exp <= 0) {
      // Zero
      return sign | 0u;
    }
    return sign | (static_cast<uint32_t>(exp) << 3) | (significand & 0x07u);
  }

  float m_values[4];
};

inline f8x4_t operator+(const f8x4_t& a, const f8x4_t& b) {
  f8x4_t result(a);
  result += b;
  return result;
}

inline f8x4_t operator-(const f8x4_t& a, const f8x4_t& b) {
  f8x4_t result(a);
  result -= b;
  return result;
}

inline f8x4_t operator*(const f8x4_t& a, const f8x4_t& b) {
  f8x4_t result(a);
  result *= b;
  return result;
}

inline f8x4_t operator/(const f8x4_t& a, const f8x4_t& b) {
  f8x4_t result(a);
  result /= b;
  return result;
}

inline f8x4_t min(const f8x4_t& a, const f8x4_t& b) {
  f8x4_t result(a);
  result.min(b);
  return result;
}

inline f8x4_t max(const f8x4_t& a, const f8x4_t& b) {
  f8x4_t result(a);
  result.max(b);
  return result;
}

#endif  // SIM_PACKED_FLOAT_HPP_
