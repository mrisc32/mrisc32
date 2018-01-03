#ifndef SIM_RAM_HPP_
#define SIM_RAM_HPP_

#include <array>
#include <cstdint>

class ram_t {
public:
  // The memory interface width (smallest read/write operation), in bytes.
  static const uint32_t LINE_WIDTH = 16u;

  using line_t = uint8_t[LINE_WIDTH];

  ram_t();

  ~ram_t();

  line_t& at(const uint32_t byte_addr);

  line_t& operator[](const uint32_t addr) {
    return at(addr);
  }

private:
  // The total 4GB RAM is divided into smaller blocks in the simulator to avoid
  // using more host RAM than necessary. Each block is allocated on demand on
  // first use.
  static const uint32_t BLOCK_SIZE = 1048576u;  // 1 MB per block
  static const uint32_t NUM_BLOCKS = 4096u;     // ...for a total of 4 GB.

  using block_t = std::array<uint8_t, BLOCK_SIZE>;

  std::array<block_t*, NUM_BLOCKS> m_blocks;

  // The RAM object is non-copyable.
  ram_t(const ram_t&) = delete;
  ram_t& operator=(const ram_t&) = delete;
};

#endif  // SIM_RAM_HPP_
