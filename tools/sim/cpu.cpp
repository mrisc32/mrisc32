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

#include <algorithm>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <cstdio>

namespace {
// Simulator routines.
const uint32_t SIM_ROUTINE_EXIT = 0u;
const uint32_t SIM_ROUTINE_PUTC = 1u;
}  // namespace

cpu_t::cpu_t(ram_t& ram) : m_ram(ram) {
  reset();
}

cpu_t::~cpu_t() {
  // Nothing to do here...
}

void cpu_t::reset() {
  std::fill(m_regs.begin(), m_regs.end(), 0u);
  for (auto reg = m_vregs.begin(); reg != m_vregs.end(); ++reg) {
    std::fill(reg->begin(), reg->end(), 0.0f);
  }
  m_terminate = false;
  m_exit_code = 0u;
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
    const uint8_t& byte = m_ram.at8(addr);
    file.write(reinterpret_cast<const char*>(&byte), 1);
  }
  file.close();
}

void cpu_t::call_sim_routine(const uint32_t routine_no) {
  switch (routine_no) {
    case SIM_ROUTINE_EXIT:
      m_terminate = true;
      m_exit_code = m_regs[1];
      break;
    case SIM_ROUTINE_PUTC:
      const int c = static_cast<int>(m_regs[1]);
      std::putc(c, stdout);
      break;
  }
}
