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

#ifndef SIM_RAM_HPP_
#define SIM_RAM_HPP_

#include <cstdint>
#include <sstream>
#include <stdexcept>
#include <vector>

// Convert a word between host endianity and MRISC32 endianity (little endian).
static inline uint32_t convert_endianity(const uint32_t x) {
#if defined(__BYTE_ORDER__) && (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
  return x;
#elif (defined(__GNUC__) || defined(__llvm__)) && defined(__BYTE_ORDER__) && \
    (__BYTE_ORDER__ == __ORDER_BIG_ENDIAN__)
  return __builtin_bswap32(x);
#else
  return (x >> 24) | ((x >> 8) & 0x0000ff00u) | ((x << 8) & 0x00ff0000u) | (x << 24);
#endif
}

// Convert a half-word between host endianity and MRISC32 endianity (little endian).
static inline uint16_t convert_endianity(const uint16_t x) {
#if defined(__BYTE_ORDER__) && (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
  return x;
#elif (defined(__GNUC__) || defined(__llvm__)) && defined(__BYTE_ORDER__) && \
    (__BYTE_ORDER__ == __ORDER_BIG_ENDIAN__)
  return __builtin_bswap16(x);
#else
  return (x >> 8) | (x << 8);
#endif
}

/// @brief Simulated RAM.
///
/// The memory is 32-bit addressable. All memory is allocated up front from the host machine.
class ram_t {
public:
  ram_t(const uint64_t ram_size) : m_memory(ram_size, 0u) {
  }

  uint8_t& at(const uint32_t byte_addr) {
    check_addr(byte_addr, sizeof(uint8_t));
    return m_memory[byte_addr];
  }

  uint32_t load8(const uint32_t addr) {
    check_addr(addr, sizeof(uint8_t));
    return m_memory[addr];
  }

  uint32_t load8signed(const uint32_t addr) {
    return s8_as_u32(load8(addr));
  }

  void store8(const uint32_t addr, const uint32_t value) {
    check_addr(addr, sizeof(uint8_t));
    check_align(addr, sizeof(uint8_t));
    m_memory[addr] = static_cast<uint8_t>(value);
  }

  uint32_t load16(const uint32_t addr) const {
    check_addr(addr, sizeof(uint16_t));
    check_align(addr, sizeof(uint16_t));
    return convert_endianity(reinterpret_cast<const uint16_t&>(m_memory[addr]));
  }

  uint32_t load16signed(const uint32_t addr) const {
    return s16_as_u32(load16(addr));
  }

  void store16(const uint32_t addr, const uint32_t value) {
    check_addr(addr, sizeof(uint16_t));
    check_align(addr, sizeof(uint16_t));
    reinterpret_cast<uint16_t&>(m_memory[addr]) = convert_endianity(static_cast<uint16_t>(value));
  }

  uint32_t load32(const uint32_t addr) {
    check_addr(addr, sizeof(uint32_t));
    check_align(addr, sizeof(uint32_t));
    return convert_endianity(reinterpret_cast<const uint32_t&>(m_memory[addr]));
  }

  void store32(const uint32_t addr, const uint32_t value) {
    check_addr(addr, sizeof(uint32_t));
    check_align(addr, sizeof(uint32_t));
    reinterpret_cast<uint32_t&>(m_memory[addr]) = convert_endianity(value);
  }

  bool valid_range(const uint32_t addr, const uint32_t size) const {
    const auto addr_first = static_cast<std::vector<uint8_t>::size_type>(addr);
    const auto addr_last = static_cast<std::vector<uint8_t>::size_type>(addr + size - 1);
    const auto mem_size = m_memory.size();
    return (addr_first < mem_size && addr_last < mem_size);
  }

private:
  static std::string as_hex32(const uint32_t x) {
    char str[16];
    std::snprintf(str, sizeof(str) - 1, "0x%08x", x);
    return std::string(&str[0]);
  }

  void check_addr(const uint32_t addr, const uint32_t size) const {
    if (!valid_range(addr, size)) {
      std::ostringstream ss;
      ss << "Out of range memory access: " << as_hex32(addr) << " >= " << m_memory.size();
      throw std::runtime_error(ss.str());
    }
  }

  void check_align(const uint32_t addr, const uint32_t size) const {
    if ((addr % size) != 0u) {
      std::ostringstream ss;
      ss << "Unaligned " << (8 * size) << "-bit memory access: " << as_hex32(addr);
      throw std::runtime_error(ss.str().c_str());
    }
  }

  static uint32_t s8_as_u32(const uint32_t x) {
    return static_cast<uint32_t>(static_cast<int32_t>(static_cast<int8_t>(x)));
  }

  static uint32_t s16_as_u32(const uint32_t x) {
    return static_cast<uint32_t>(static_cast<int32_t>(static_cast<int16_t>(x)));
  }

  std::vector<uint8_t> m_memory;

  // The RAM object is non-copyable.
  ram_t(const ram_t&) = delete;
  ram_t& operator=(const ram_t&) = delete;
};

#endif  // SIM_RAM_HPP_
