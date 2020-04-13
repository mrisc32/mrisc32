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

#include "cpu.hpp"

#include "config.hpp"

#include <algorithm>
#include <cstdio>
#include <iomanip>
#include <iostream>

cpu_t::cpu_t(ram_t& ram) : m_ram(ram), m_syscalls(ram) {
  if (config_t::instance().trace_enabled()) {
    m_trace_file.open(config_t::instance().trace_file_name(), std::ios::out | std::ios::binary);
  }
  reset();
}

cpu_t::~cpu_t() {
  if (m_trace_file.is_open()) {
    m_trace_file.close();
  }
}

void cpu_t::reset() {
  std::fill(m_regs.begin(), m_regs.end(), 0u);
  for (auto reg = m_vregs.begin(); reg != m_vregs.end(); ++reg) {
    std::fill(reg->begin(), reg->end(), 0.0f);
  }
  m_syscalls.clear();
  m_terminate_requested = false;
}

void cpu_t::terminate() {
  m_terminate_requested = true;
}

void cpu_t::dump_stats() {
  const double cpo = static_cast<double>(m_total_cycle_count) /
                     static_cast<double>(m_fetched_instr_count + m_vector_loop_count);
  std::cout << "CPU instructions:\n";
  std::cout << " Fetched instructions: " << m_fetched_instr_count << "\n";
  std::cout << " Vector loops:         " << m_vector_loop_count << "\n";
  std::cout << " Total CPU cycles:     " << m_total_cycle_count << "\n";
  std::cout << " Cycles/Operation:     " << cpo << "\n";
}

void cpu_t::dump_ram(const uint32_t begin, const uint32_t end, const std::string& file_name) {
  std::ofstream file;
  file.open(file_name, std::ios::out | std::ios::binary);
  for (uint32_t addr = begin; addr < end; ++addr) {
    const uint8_t byte = static_cast<uint8_t>(m_ram.load8(addr));
    file.write(reinterpret_cast<const char*>(&byte), 1);
  }
  file.close();
}

void cpu_t::append_debug_trace(const debug_trace_t& trace) {
  if (!(m_trace_file.is_open() && trace.valid)) {
    return;
  }

  uint8_t buf[5 * 4] = {};

  const uint32_t flags = (trace.valid ? 1 : 0) | (trace.src_a_valid ? 2 : 0) |
                         (trace.src_b_valid ? 4 : 0) | (trace.src_c_valid ? 8 : 0);
  buf[0] = static_cast<uint8_t>(flags);
  buf[1] = static_cast<uint8_t>(flags >> 8);
  buf[2] = static_cast<uint8_t>(flags >> 16);
  buf[3] = static_cast<uint8_t>(flags >> 24);

  buf[4] = static_cast<uint8_t>(trace.pc);
  buf[5] = static_cast<uint8_t>(trace.pc >> 8);
  buf[6] = static_cast<uint8_t>(trace.pc >> 16);
  buf[7] = static_cast<uint8_t>(trace.pc >> 24);

  if (trace.src_a_valid) {
    buf[8] = static_cast<uint8_t>(trace.src_a);
    buf[9] = static_cast<uint8_t>(trace.src_a >> 8);
    buf[10] = static_cast<uint8_t>(trace.src_a >> 16);
    buf[11] = static_cast<uint8_t>(trace.src_a >> 24);
  }
  if (trace.src_b_valid) {
    buf[12] = static_cast<uint8_t>(trace.src_b);
    buf[13] = static_cast<uint8_t>(trace.src_b >> 8);
    buf[14] = static_cast<uint8_t>(trace.src_b >> 16);
    buf[15] = static_cast<uint8_t>(trace.src_b >> 24);
  }
  if (trace.src_c_valid) {
    buf[16] = static_cast<uint8_t>(trace.src_c);
    buf[17] = static_cast<uint8_t>(trace.src_c >> 8);
    buf[18] = static_cast<uint8_t>(trace.src_c >> 16);
    buf[19] = static_cast<uint8_t>(trace.src_c >> 24);
  }

  m_trace_file.write(reinterpret_cast<const char*>(&buf[0]), sizeof(buf));
  m_trace_file.flush();
}

