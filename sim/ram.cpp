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

#include "ram.hpp"

#include <cstring>
#include <stdexcept>

ram_t::ram_t() {
  // Clear all blocks (no RAM blocks have yet been allocated).
  std::fill(m_blocks.begin(), m_blocks.end(), static_cast<block_t*>(0));
}

ram_t::~ram_t() {
  // Free all allocated blocks.
  for (uint32_t block_no = 0u; block_no < NUM_BLOCKS; ++block_no) {
    block_t* block = m_blocks[block_no];
    if (block != static_cast<block_t*>(0)) {
      free(block);
    }
  }
}

uint8_t& ram_t::at8(const uint32_t byte_addr) {
  // Determine the allocated block no.
  const auto block_no = byte_addr / BLOCK_SIZE;

  // Allocate and clear a new block if this is the first time we access it.
  if (m_blocks[block_no] == nullptr) {
    m_blocks[block_no] = new block_t;
    std::memset(&m_blocks[block_no][0], 0, BLOCK_SIZE);
  }

  // Return a pointer to the requested RAM line.
  const auto block_offset = byte_addr - (block_no * BLOCK_SIZE);
  return reinterpret_cast<uint8_t&>((*m_blocks[block_no])[block_offset]);
}

uint16_t& ram_t::at16(const uint32_t byte_addr) {
  if ((byte_addr % 2u) != 0u) {
    throw std::runtime_error("Unaligned 16-bit memory access.");
  }
  auto& data8 = at8(byte_addr);
  return reinterpret_cast<uint16_t&>(data8);
}

uint32_t& ram_t::at32(const uint32_t byte_addr) {
  if ((byte_addr % 4u) != 0u) {
    throw std::runtime_error("Unaligned 32-bit memory access.");
  }
  auto& data8 = at8(byte_addr);
  return reinterpret_cast<uint32_t&>(data8);
}
