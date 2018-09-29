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
#include <stdexcept>
#include <vector>

/// @brief Simulated RAM.
///
/// The memory is 32-bit addressable. All memory is allocated up front from the host machine.
class ram_t {
public:
  ram_t(const uint32_t ram_size) : m_memory(ram_size, 0u) {
  }

  uint8_t& at8(const uint32_t byte_addr) {
    if (static_cast<std::vector<uint8_t>::size_type>(byte_addr) >= m_memory.size()) {
      throw std::runtime_error("Out of range memory access.");
    }
    return m_memory[byte_addr];
  }

  // Note: These functions are host machine endian dependent. Consider converting them to read/write
  // methods instead.
  uint16_t& at16(const uint32_t byte_addr) {
    if ((byte_addr % 2u) != 0u) {
      throw std::runtime_error("Unaligned 16-bit memory access.");
    }
    auto& data8 = at8(byte_addr);
    return reinterpret_cast<uint16_t&>(data8);
  }

  uint32_t& at32(const uint32_t byte_addr) {
    if ((byte_addr % 4u) != 0u) {
      throw std::runtime_error("Unaligned 32-bit memory access.");
    }
    auto& data8 = at8(byte_addr);
    return reinterpret_cast<uint32_t&>(data8);
  }

private:
  std::vector<uint8_t> m_memory;

  // The RAM object is non-copyable.
  ram_t(const ram_t&) = delete;
  ram_t& operator=(const ram_t&) = delete;
};

#endif  // SIM_RAM_HPP_
