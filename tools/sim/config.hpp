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

#ifndef SIM_CONFIG_HPP_
#define SIM_CONFIG_HPP_

#include <cstdint>
#include <string>

class config_t {
public:
  static config_t& instance();

  uint64_t ram_size() const {
    return m_ram_size;
  }

  void set_ram_size(const uint64_t x) {
    m_ram_size = std::min(x, static_cast<uint64_t>(4294967296u));
  }

  bool trace_enabled() const {
    return m_trace_enabled;
  }

  void set_trace_enabled(const bool x) {
    m_trace_enabled = x;
  }

  const std::string& trace_file_name() const {
    return m_trace_file_name;
  }

  void set_trace_file_name(const std::string& x) {
    m_trace_file_name = x;
  }

  bool verbose() const {
    return m_verbose;
  }
  void set_verbose(const bool x) {
    m_verbose = x;
  }

  bool gfx_enabled() const {
    return m_gfx_enabled;
  }

  void set_gfx_enabled(const bool x) {
    m_gfx_enabled = x;
  }

  uint32_t gfx_addr() const {
    return m_gfx_addr;
  }

  void set_gfx_addr(const uint32_t x) {
    m_gfx_addr = x;
  }

  uint32_t gfx_pal_addr() const {
    return m_gfx_pal_addr;
  }

  void set_gfx_pal_addr(const uint32_t x) {
    m_gfx_pal_addr = x;
  }

  uint32_t gfx_width() const {
    return m_gfx_width;
  }

  void set_gfx_width(const uint32_t x) {
    m_gfx_width = x;
  }

  uint32_t gfx_height() const {
    return m_gfx_height;
  }

  void set_gfx_height(const uint32_t x) {
    m_gfx_height = x;
  }

  uint32_t gfx_depth() const {
    return m_gfx_depth;
  }

  void set_gfx_depth(const uint32_t x) {
    m_gfx_depth = x;
  }

  bool auto_close() const {
    return m_auto_close;
  }

  void set_auto_close(const bool x) {
    m_auto_close = x;
  }

private:
  config_t() {}

  // Default values.
  static const uint64_t DEFAULT_RAM_SIZE = 0x100000000u;  // 4 GiB
  static const bool DEFAULT_TRACE_ENABLED = false;
  static const bool DEFAULT_VERBOSE = false;
  static const bool DEFAULT_GFX_ENABLED = false;
  static const uint32_t DEFAULT_GFX_ADDR = 0x4003d480u;  // Start of MC1 VCON framebuffer.
  static const uint32_t DEFAULT_GFX_PAL_ADDR = 0x12345678u;
  static const uint32_t DEFAULT_GFX_WIDTH = 320u;
  static const uint32_t DEFAULT_GFX_HEIGHT = 180u;
  static const uint32_t DEFAULT_GFX_DEPTH = 1u;
  static const bool DEFAULT_AUTO_CLOSE = true;

  uint64_t m_ram_size = DEFAULT_RAM_SIZE;
  bool m_trace_enabled = DEFAULT_TRACE_ENABLED;
  std::string m_trace_file_name;
  bool m_verbose = DEFAULT_VERBOSE;
  bool m_gfx_enabled = DEFAULT_GFX_ENABLED;
  uint32_t m_gfx_addr = DEFAULT_GFX_ADDR;
  uint32_t m_gfx_pal_addr = DEFAULT_GFX_PAL_ADDR;
  uint32_t m_gfx_width = DEFAULT_GFX_WIDTH;
  uint32_t m_gfx_height = DEFAULT_GFX_HEIGHT;
  uint32_t m_gfx_depth = DEFAULT_GFX_DEPTH;
  bool m_auto_close = DEFAULT_AUTO_CLOSE;
};

#endif  // SIM_CONFIG_HPP_
