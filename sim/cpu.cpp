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
#include <iomanip>
#include <iostream>
#include <cstdio>

namespace {
// Simulator routines.
const uint32_t SIM_ROUTINE_EXIT = 0u;
const uint32_t SIM_ROUTINE_PUTC = 1u;
}  // namespace

cpu_t::cpu_t(ram_t& ram) : m_ram(ram), m_icache(ram), m_dcache(ram) {
  reset();
}

cpu_t::~cpu_t() {
  // Nothing to do here...
}

void cpu_t::reset() {
  std::fill(m_regs.begin(), m_regs.end(), 0u);
  std::fill(m_fregs.begin(), m_fregs.end(), 0.0f);
  m_carry = 0u;
  m_terminate = false;
  m_exit_code = 0u;
}

void cpu_t::dump_stats() {
  std::cout << "Cache stats:\n";
  std::cout << " ICACHE: " << m_icache.accesses() << " accesses " << m_icache.hits() << " hits\n";
  std::cout << " DCACHE: " << m_dcache.accesses() << " accesses " << m_dcache.hits() << " hits\n";
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
