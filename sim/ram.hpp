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

#include <array>
#include <cstdint>

/// @brief Simulated RAM.
///
/// The memory is 32-bit addressable, and is 4GB in size (all elements are zero upon creation). The
/// memory is allocated on demand from the host machine.
class ram_t {
public:
  // The memory interface width (smallest read/write operation), in bytes.
  static const uint32_t LINE_WIDTH = 16u;

  using line_t = uint8_t[LINE_WIDTH];

  ram_t();

  ~ram_t();

  line_t& at(const uint32_t byte_addr);

  uint8_t& at8(const uint32_t byte_addr);

  // Note: These functions are host machine endian dependent. Consider converting them to read/write
  // methods instead.
  uint16_t& at16(const uint32_t byte_addr);
  uint32_t& at32(const uint32_t byte_addr);

  line_t& operator[](const uint32_t addr) {
    return at(addr);
  }

private:
  // The total 4GB RAM is divided into smaller blocks in the simulator to avoid using more host RAM
  // than necessary. Each block is allocated on demand on first use.
  static const uint32_t BLOCK_SIZE = 1048576u;  // 1 MB per block
  static const uint32_t NUM_BLOCKS = 4096u;     // ...for a total of 4 GB.

  using block_t = std::array<uint8_t, BLOCK_SIZE>;

  std::array<block_t*, NUM_BLOCKS> m_blocks;

  // The RAM object is non-copyable.
  ram_t(const ram_t&) = delete;
  ram_t& operator=(const ram_t&) = delete;
};

#endif  // SIM_RAM_HPP_
