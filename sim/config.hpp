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

class config_t {
public:
  static config_t& instance();

  uint32_t ram_size() const {
    return m_ram_size;
  }

  bool gfx_enabled() const {
    return m_gfx_enabled;
  }

  uint32_t gfx_addr() const {
    return m_gfx_addr;
  }

  uint32_t gfx_width() const {
    return m_gfx_width;
  }

  uint32_t gfx_height() const {
    return m_gfx_height;
  }

  uint32_t gfx_depth() const {
    return m_gfx_depth;
  }

private:
  config_t() {}

  // Default values.
  static const uint32_t DEFAULT_RAM_SIZE = 0x1000000u;  // 16 MiB
  static const bool DEFAULT_GFX_ENABLED = true;
  static const uint32_t DEFAULT_GFX_ADDR = 0x0800000u;
  static const uint32_t DEFAULT_GFX_WIDTH = 1024u;
  static const uint32_t DEFAULT_GFX_HEIGHT = 576u;
  static const uint32_t DEFAULT_GFX_DEPTH = 32u;

  uint32_t m_ram_size = DEFAULT_RAM_SIZE;
  bool m_gfx_enabled = DEFAULT_GFX_ENABLED;
  uint32_t m_gfx_addr = DEFAULT_GFX_ADDR;
  uint32_t m_gfx_width = DEFAULT_GFX_WIDTH;
  uint32_t m_gfx_height = DEFAULT_GFX_HEIGHT;
  uint32_t m_gfx_depth = DEFAULT_GFX_DEPTH;
};

#endif  // SIM_CONFIG_HPP_
