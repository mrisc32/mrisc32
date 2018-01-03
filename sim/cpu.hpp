#ifndef SIM_CPU_HPP_
#define SIM_CPU_HPP_

#include "cache.hpp"
#include "ram.hpp"

#include <array>
#include <cstdint>

class cpu_t {
public:
  cpu_t(ram_t& ram);

  void reset();

  void dump_stats();

  uint32_t run(const uint32_t addr);

private:
  void call_sim_routine(const uint32_t routine_no);

  // Memory interface.
  ram_t& m_ram;
  cache_t<32, 256> m_icache;
  cache_t<32, 256> m_dcache;

  // Registers.
  static const uint32_t NUM_REGS = 32u;
  std::array<uint32_t, NUM_REGS> m_regs;
  std::array<float, NUM_REGS> m_fregs;

  // Run state.
  bool m_terminate;
  uint32_t m_exit_code;
};

#endif  // SIM_CPU_HPP_
