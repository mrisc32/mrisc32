#include "ram.hpp"

#include <cstring>

ram_t::ram_t() {
  for (uint32_t block_no = 0u; block_no < NUM_BLOCKS; ++block_no) {
    m_blocks[block_no] = static_cast<block_t*>(0);
  }
}

ram_t::~ram_t() {
  for (uint32_t block_no = 0u; block_no < NUM_BLOCKS; ++block_no) {
    block_t* block = m_blocks[block_no];
    if (block != static_cast<block_t*>(0)) {
      free(block);
    }
  }
}

ram_t::line_t& ram_t::at(const uint32_t byte_addr) {
  // Ignore the least significant bits of the memory address to find the start
  // of the corresponding RAM line.
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
