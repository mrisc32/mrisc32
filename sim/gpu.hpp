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

class gpu_t {
public:
  gpu_t(ram_t& ram);
  void cleanup();

  void paint(const int actual_fb_width, const int actual_fb_height);

private:
  void check_gfx_config();

  ram_t& m_ram;

  uint32_t m_gfx_ram_start;
  uint32_t m_width;
  uint32_t m_height;
  uint32_t m_bytes_per_pixel;

  GLint m_tex_internalformat;
  GLenum m_tex_format;
  GLenum m_tex_type;

  GLuint m_program = 0u;
  GLuint m_fb_tex = 0u;
  GLuint m_vertex_array = 0u;
  GLuint m_vertex_buffer = 0u;
  GLint m_resolution_uniform = 0;
  GLint m_sampler_uniform = 0;
  GLint m_monochrome_uniform = 0;
};

#endif // SIM_GPU_HPP_
