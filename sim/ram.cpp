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

ram_t::line_t& ram_t::at(const uint32_t byte_addr) {
  // Ignore the least significant bits of the memory address to find the start of the corresponding
  // RAM line.
  const uint32_t line_addr = byte_addr & ~(LINE_WIDTH - 1u);

  // Determine the allocated block no.
  const uint32_t block_no = line_addr / BLOCK_SIZE;

  // Allocate and clear a new block if this is the first time we access it.
  if (m_blocks[block_no] == static_cast<block_t*>(0)) {
    m_blocks[block_no] = new block_t;
    std::memset(&m_blocks[block_no][0], 0, BLOCK_SIZE);
  }

  // Return a pointer to the requested RAM line.
  uint32_t block_offset = line_addr - (block_no * BLOCK_SIZE);
  return reinterpret_cast<line_t&>((*m_blocks[block_no])[block_offset]);
}
