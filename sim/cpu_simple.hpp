#ifndef SIM_CPU_SIMPLE_HPP_
#define SIM_CPU_SIMPLE_HPP_

#include "cpu.hpp"

class cpu_simple_t : public cpu_t {
public:
  cpu_simple_t(ram_t& ram) : cpu_t(ram) {
  }

  uint32_t run(const uint32_t addr) override;
};

#endif // SIM_CPU_SIMPLE_HPP_
