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

#ifndef SIM_GPU_HPP_
#define SIM_GPU_HPP_

#include "ram.hpp"

#include <glad/glad.h>

#include <cstdint>
#include <vector>

class gpu_t {
public:
  gpu_t(ram_t& ram);

  /// @brief Release OpenGL resources.
  ///
  /// Call this before destroying the OpenGL context.
  void cleanup();

  /// @brief Configure the GPU.
  ///
  /// The GPU is configured based on whatever configuration parameters are available. This method
  /// should be called each frame, before calling @c paint().
  ///
  /// When this method returns, the frame buffer dimensions have been updated.
  void configure();

  /// @brief Paint the CPU framebuffer RAM to the OpenGL context.
  /// @param actual_fb_width The OpenGL framebuffer width.
  /// @param actual_fb_height The OpenGL framebuffer height.
  void paint(const int actual_fb_width, const int actual_fb_height);

  uint32_t width() const {
    return m_width;
  }

  uint32_t height() const {
    return m_height;
  }

private:
  uint32_t mem32_or_default(const uint32_t addr, const uint32_t default_value);
  void check_gfx_config();
  void compile_shader();

  ram_t& m_ram;

  std::vector<uint8_t> m_conv_buffer;
  std::vector<uint8_t> m_default_palette;

  uint32_t m_gfx_ram_start = 0u;
  uint32_t m_gfx_pal_start = 0u;
  uint32_t m_width = 0u;
  uint32_t m_height = 0u;
  uint32_t m_depth = 0u;
  uint32_t m_frame_no = 0u;

  uint32_t m_bits_per_pixel;
  GLint m_tex_internalformat;
  GLenum m_tex_format;
  GLenum m_tex_type;

  GLuint m_program = 0u;
  GLuint m_fb_tex = 0u;
  GLuint m_pal_tex = 0u;
  GLuint m_vertex_array = 0u;
  GLuint m_vertex_buffer = 0u;
  GLint m_resolution_uniform = 0;
  GLint m_fb_sampler_uniform = 0;
  GLint m_pal_sampler_uniform = 0;
  GLint m_monochrome_uniform = 0;
};

#endif // SIM_GPU_HPP_
