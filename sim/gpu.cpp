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

#include "gpu.hpp"

#include "config.hpp"

#include <iostream>
#include <sstream>
#include <stdexcept>

namespace {
const GLchar* VERTEX_SRC =
    "#version 150\n"
    "in vec2 a_pos;"
    "out vec2 v_uv;"
    "uniform vec2 u_resolution;"
    "void main(void)"
    "{"
    "  v_uv = ((1.0 - a_pos) * 0.5) * u_resolution;"
    "  gl_Position = vec4(a_pos, 1.0, 1.0);"
    "}";

const GLchar* FRAGMENT_SRC =
    "#version 150\n"
    "uniform sampler2DRect u_sampler;"
    "uniform bool u_monochrome;"
    "in vec2 v_uv;"
    "out vec3 color;"
    "void main(void)"
    "{"
    "  if (u_monochrome) {"
    "    float r = texture(u_sampler, v_uv).r;"
    "    color = vec3(r, r, r);"
    "  } else {"
    "    color = texture(u_sampler, v_uv).rgb;"
    "  }"
    "}";

// clang-format off
const GLfloat VERTEX_BUFFER_DATA[] = {
    -1.0f, -1.0f,
     1.0f, -1.0f,
     1.0f,  1.0f,

    -1.0f, -1.0f,
     1.0f,  1.0f,
    -1.0f,  1.0f
};
// clang-format on

void check_gl_error_helper(const int line_no) {
  const auto err = glGetError();
  std::ostringstream ss;
  switch (err) {
    case GL_NO_ERROR:
    default:
      return;

    case GL_INVALID_ENUM:
      ss << "GL_INVALID_ENUM";
      break;

    case GL_INVALID_VALUE:
      ss << "GL_INVALID_VALUE";
      break;

    case GL_INVALID_OPERATION:
      ss << "GL_INVALID_OPERATION";
      break;

    case GL_INVALID_FRAMEBUFFER_OPERATION:
      ss << "GL_INVALID_FRAMEBUFFER_OPERATION";
      break;

    case GL_OUT_OF_MEMORY:
      ss << "GL_OUT_OF_MEMORY";
      break;
  }

  ss << " @ line " << line_no;
  throw std::runtime_error(ss.str());
}

#define check_gl_error() check_gl_error_helper(__LINE__)
}  // namespace

gpu_t::gpu_t(ram_t& ram)
    : m_ram(ram),
      m_gfx_ram_start(config_t::instance().gfx_addr()),
      m_width(config_t::instance().gfx_width()),
      m_height(config_t::instance().gfx_height()) {
  // Start by clearing the OpenGL error status.
  (void)glGetError();

  // Determine the pixel format.
  switch (config_t::instance().gfx_depth()) {
    case 32u:
      m_bytes_per_pixel = 4u;
      m_tex_internalformat = GL_RGBA;
      m_tex_format = GL_BGRA;
      m_tex_type = GL_UNSIGNED_BYTE;
      break;

    case 8u:
      m_bytes_per_pixel = 1u;
      m_tex_internalformat = GL_RED;
      m_tex_format = GL_RED;
      m_tex_type = GL_UNSIGNED_BYTE;
      break;

    default:
      throw std::runtime_error("Invalid pixel format.");
  }
  std::cout << "Gfx mode: " << m_width << " x " << m_height << " : " << (m_bytes_per_pixel * 8)
            << " bpp\n";

  // Make sure that we can use the current GFX configuration.
  check_gfx_config();

  // Compile the vertrex shader.
  auto vertex_shader = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vertex_shader, 1, reinterpret_cast<const GLchar**>(&VERTEX_SRC), nullptr);
  glCompileShader(vertex_shader);
  {
    GLint status;
    glGetShaderiv(vertex_shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
      throw std::runtime_error("Failed to compile the vertex shader.");
    }
  }
  check_gl_error();

  // Compile the fragment shader.
  auto fragment_shader = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fragment_shader, 1, reinterpret_cast<const GLchar**>(&FRAGMENT_SRC), nullptr);
  glCompileShader(fragment_shader);
  {
    GLint status;
    glGetShaderiv(fragment_shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
      throw std::runtime_error("Failed to compile the fragment shader.");
    }
  }
  check_gl_error();

  // Link the program.
  m_program = glCreateProgram();
  glAttachShader(m_program, vertex_shader);
  glAttachShader(m_program, fragment_shader);
  glLinkProgram(m_program);
  {
    GLint status;
    glGetProgramiv(m_program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
      throw std::runtime_error("Failed to link the shader program.");
    }
  }
  m_resolution_uniform = glGetUniformLocation(m_program, "u_resolution");
  m_sampler_uniform = glGetUniformLocation(m_program, "u_sampler");
  m_monochrome_uniform = glGetUniformLocation(m_program, "u_monochrome");
  check_gl_error();

  // Create the texture.
  glGenTextures(1, &m_fb_tex);
  glBindTexture(GL_TEXTURE_RECTANGLE, m_fb_tex);
  glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexImage2D(GL_TEXTURE_RECTANGLE,
               0,
               m_tex_internalformat,
               static_cast<GLsizei>(m_width),
               static_cast<GLsizei>(m_height),
               0,
               m_tex_format,
               m_tex_type,
               nullptr);
  check_gl_error();

  // Create the vertex buffer.
  glGenVertexArrays(1, &m_vertex_array);
  glBindVertexArray(m_vertex_array);
  glGenBuffers(1, &m_vertex_buffer);
  glBindBuffer(GL_ARRAY_BUFFER, m_vertex_buffer);
  glBufferData(GL_ARRAY_BUFFER, sizeof(VERTEX_BUFFER_DATA), VERTEX_BUFFER_DATA, GL_STATIC_DRAW);
  check_gl_error();
}

void gpu_t::check_gfx_config() {
  const auto video_ram_end = m_gfx_ram_start + (m_width * m_height * m_bytes_per_pixel);
  const auto ram_end = config_t::instance().ram_size();
  if (video_ram_end > ram_end) {
    throw std::runtime_error("Invalid gfx RAM configuration (does not fit in CPU RAM).");
  }
}

void gpu_t::cleanup() {
  if (m_program != 0u) {
    glDeleteProgram(m_program);
    m_program = 0u;
  }
  if (m_fb_tex != 0u) {
    glDeleteTextures(1, &m_fb_tex);
    m_fb_tex = 0u;
  }
  if (m_vertex_array != 0u) {
    glDeleteVertexArrays(1, &m_vertex_array);
    m_vertex_array = 0u;
  }
  if (m_vertex_buffer != 0u) {
    glDeleteBuffers(1, &m_vertex_buffer);
    m_vertex_buffer = 0u;
  }
}

void gpu_t::paint(const int actual_fb_width, const int actual_fb_height) {
  // Set the viewport.
  glViewport(0, 0, static_cast<GLsizei>(actual_fb_width), static_cast<GLsizei>(actual_fb_height));

  // Upload the frame buffer from ram to the framebuffer texture.
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_RECTANGLE, m_fb_tex);
  glTexSubImage2D(GL_TEXTURE_RECTANGLE,
                  0,
                  0,
                  0,
                  static_cast<GLsizei>(m_width),
                  static_cast<GLsizei>(m_height),
                  m_tex_format,
                  m_tex_type,
                  &m_ram.at8(m_gfx_ram_start));
  check_gl_error();

  // Set up the shader.
  glUseProgram(m_program);
  glUniform2f(m_resolution_uniform, static_cast<GLfloat>(m_width), static_cast<GLfloat>(m_height));
  glUniform1i(m_sampler_uniform, 0);
  glUniform1i(m_monochrome_uniform, m_bytes_per_pixel == 1 ? 1 : 0);
  check_gl_error();

  // Draw the frame buffer texture to the screen.
  glBindVertexArray(m_vertex_array);
  glEnableVertexAttribArray(0);
  glBindBuffer(GL_ARRAY_BUFFER, m_vertex_buffer);
  glVertexAttribPointer(0,                          // Attribute 0
                        2,                          // Size
                        GL_FLOAT,                   // Type
                        GL_FALSE,                   // Normalized?
                        0,                          // Stride
                        reinterpret_cast<void*>(0)  // Array buffer offset = 0
  );
  glDrawArrays(GL_TRIANGLES, 0, 6);  // 6 vertices -> 2 triangles
  glDisableVertexAttribArray(0);
  check_gl_error();
}
