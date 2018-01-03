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

#ifndef SIM_CACHE_HPP_
#define SIM_CACHE_HPP_

#include "ram.hpp"

#include <algorithm>
#include <array>
#include <exception>
#include <cstdint>

/// @brief A memory cache.
///
/// This is a simple, direct-mapped, write-back cache. The size of the cache is controlled by the
/// template arguments.
///
/// @param LINE_SIZE The number of bytes in a cache line (e.g. 32).
/// @param NUM_LINES Number of cache lines.
template <uint32_t LINE_SIZE, uint32_t NUM_LINES>
class cache_t {
public:
  cache_t(ram_t& ram) : m_ram(ram), m_accesses(0), m_misses(0) {
    std::fill(m_tags.begin(), m_tags.end(), 0x00000000u);
  }

  /// @brief Invalidate all lines in the cache.
  ///
  /// Any lines that have not yet been written to RAM are flushed.
  void invalidate() {
    flush();
    std::fill(m_tags.begin(), m_tags.end(), 0x00000000u);
  }

  /// @brief Flush all lines in the cache.
  void flush() {
    // TODO(m): Implement me!
  }

  void write8(const uint32_t addr, const uint8_t value) {
    line_t& line = get_line(addr, true);
    const uint32_t line_offset = addr % LINE_SIZE;
    line[line_offset] = value;
  }

  void write16(const uint32_t addr, const uint16_t value) {
    if ((addr % 2u) != 0u) {
      throw std::runtime_error("Unaligned 16-bit write access.");
    }
    line_t& line = get_line(addr, true);
    const uint32_t line_offset = addr % LINE_SIZE;
    *reinterpret_cast<uint16_t*>(&line[line_offset]) = value;
  }

  void write32(const uint32_t addr, const uint32_t value) {
    if ((addr % 4u) != 0u) {
      throw std::runtime_error("Unaligned 32-bit write access.");
    }
    line_t& line = get_line(addr, true);
    const uint32_t line_offset = addr % LINE_SIZE;
    *reinterpret_cast<uint32_t*>(&line[line_offset]) = value;
  }

  uint8_t read8(const uint32_t addr) {
    line_t& line = get_line(addr, false);
    const uint32_t line_offset = addr % LINE_SIZE;
    return line[line_offset];
  }

  uint16_t read16(const uint32_t addr) {
    if ((addr % 2u) != 0u) {
      throw std::runtime_error("Unaligned 16-bit read access.");
    }
    line_t& line = get_line(addr, false);
    const uint32_t line_offset = addr % LINE_SIZE;
    return *reinterpret_cast<uint16_t*>(&line[line_offset]);
  }

  uint32_t read32(const uint32_t addr) {
    if ((addr % 4u) != 0u) {
      throw std::runtime_error("Unaligned 32-bit read access.");
    }
    line_t& line = get_line(addr, false);
    const uint32_t line_offset = addr % LINE_SIZE;
    return *reinterpret_cast<uint32_t*>(&line[line_offset]);
  }

  uint32_t accesses() const {
    return m_accesses;
  }

  uint32_t misses() const {
    return m_misses;
  }

  uint32_t hits() const {
    return m_accesses - m_misses;
  }

private:
  static_assert(LINE_SIZE >= ram_t::LINE_WIDTH, "Cache line size is too small");
  static_assert((LINE_SIZE % ram_t::LINE_WIDTH) == 0u,
                "Cache line size is not a multiple of the RAM line size");
  static const uint32_t RAM_LINES_PER_CACHE_LINE = LINE_SIZE / ram_t::LINE_WIDTH;

  static const uint32_t TAG_BIT_VALID = 1u;
  static const uint32_t TAG_BIT_MODIFIED = 2u;
  static const uint32_t NUM_TAG_STATUS_BITS = 2u;

  using line_t = std::array<uint8_t, LINE_SIZE>;

  line_t& get_line(const uint32_t byte_addr, const bool write) {
    ++m_accesses;

    // Find the relevant cache bin.
    const uint32_t line_no = byte_addr / LINE_SIZE;
    const uint32_t bin_no = line_no % NUM_LINES;
    const uint32_t tag = ((line_no / NUM_LINES) << NUM_TAG_STATUS_BITS) | TAG_BIT_VALID;
    const uint32_t old_tag = m_tags[bin_no];
    line_t& line = m_lines[bin_no];

    // Did we have a cache miss?
    if ((m_tags[bin_no] & ~TAG_BIT_MODIFIED) != tag) {
      ++m_misses;

      const uint32_t line_addr = line_no * LINE_SIZE;

      // Write back old data to RAM.
      if (old_tag & TAG_BIT_MODIFIED) {
        const uint32_t old_addr = ((old_tag >> NUM_TAG_STATUS_BITS) * NUM_LINES * LINE_SIZE) +
                                  (byte_addr & (LINE_SIZE - 1));
        cache_to_ram(old_addr, line);
      }

      // Read new data from RAM.
      ram_to_cache(line_addr, line);

      // Update the tag.
      m_tags[bin_no] = tag;
    }

    if (write) {
      m_tags[bin_no] |= TAG_BIT_MODIFIED;
    }

    return line;
  }

  void ram_to_cache(const uint32_t start_addr, line_t& line) {
    uint32_t ram_addr = start_addr;
    auto cache_it = line.begin();
    for (uint32_t k = 0; k < RAM_LINES_PER_CACHE_LINE; ++k) {
      ram_t::line_t& ram_line = m_ram[ram_addr];
      std::copy(&ram_line[0], &ram_line[0] + ram_t::LINE_WIDTH, cache_it);
      cache_it += ram_t::LINE_WIDTH;
      ram_addr += ram_t::LINE_WIDTH;
    }
  }

  void cache_to_ram(const uint32_t start_addr, line_t& line) {
    uint32_t ram_addr = start_addr;
    auto cache_it = line.begin();
    for (uint32_t k = 0; k < RAM_LINES_PER_CACHE_LINE; ++k) {
      ram_t::line_t& ram_line = m_ram[ram_addr];
      std::copy(cache_it, cache_it + ram_t::LINE_WIDTH, &ram_line[0]);
      cache_it += ram_t::LINE_WIDTH;
      ram_addr += ram_t::LINE_WIDTH;
    }
  }

  // RAM interface.
  ram_t& m_ram;

  // Cache data.
  std::array<line_t, NUM_LINES> m_lines;
  std::array<uint32_t, NUM_LINES> m_tags;

  // Stats.
  uint32_t m_accesses;
  uint32_t m_misses;

  // The cache object is non-copyable.
  cache_t(const cache_t&) = delete;
  cache_t& operator=(const cache_t&) = delete;
};

#endif  // SIM_CACHE_HPP_
