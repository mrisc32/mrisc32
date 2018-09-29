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

#include "config.hpp"
#include "cpu_simple.hpp"
#include "ram.hpp"

#include <exception>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <cstdint>
#include <cstdlib>
#include <cstring>

namespace {
void read_bin_file(const char* file_name, ram_t& ram) {
  std::ifstream f(file_name, std::fstream::in | std::fstream::binary);
  if (f.bad()) {
    throw std::runtime_error("Unable to open the binary file.");
  }

  // Read the start address.
  uint32_t start_addr;
  f.read(reinterpret_cast<char*>(&start_addr), 4);
  if (!f.good()) {
    throw std::runtime_error("Premature end of file.");
  }

  // Read blocks from the file into RAM.
  uint32_t current_addr = start_addr;
  uint32_t total_bytes_read = 0u;
  while (f.good()) {
    auto& byte = ram.at8(current_addr);
    f.read(reinterpret_cast<char*>(&byte), 1);
    const uint32_t bytes_read = f ? 1 : static_cast<uint32_t>(f.gcount());
    total_bytes_read += bytes_read;
    current_addr += bytes_read;
  }

  f.close();
  std::cout << "Read " << total_bytes_read << " bytes from " << file_name << " into RAM @ 0x"
            << std::hex << std::setw(8) << std::setfill('0') << start_addr << "\n";
  std::cout << std::resetiosflags(std::ios::hex);
}

void print_help(const char* prg_name) {
  std::cout << "mr32sim - An MRISC32 CPU simulator\n";
  std::cout << "Usage: " << prg_name << " [options] bin-file\n";
  std::cout << "Options:\n";
  std::cout << "  --help  Display this information.\n";
  return;
}
}  // namespace

int main(const int argc, const char** argv) {
  // Parse command line options.
  const char* bin_file = static_cast<const char*>(0);
  for (int k = 1; k < argc; ++k) {
    if (argv[k][0] == '-') {
      if ((std::strcmp(argv[k], "--help") == 0) || (std::strcmp(argv[k], "-h") == 0) ||
          (std::strcmp(argv[k], "-?") == 0)) {
        print_help(argv[0]);
        exit(0);
      } else {
        std::cerr << "Error: Unknown option: " << argv[k] << "\n";
        print_help(argv[0]);
        exit(1);
      }
    } else if (bin_file == static_cast<const char*>(0)) {
      bin_file = argv[k];
    } else {
      std::cerr << "Error: Only a single program file can be loaded.\n";
      print_help(argv[0]);
      exit(1);
    }
  }
  if (bin_file == static_cast<const char*>(0)) {
    std::cerr << "Error: No program file specified.\n";
    print_help(argv[0]);
    std::exit(1);
  }

  try {
    // Initialize the RAM.
    ram_t ram(config_t::instance().ram_size());

    // Load the program file into RAM.
    read_bin_file(bin_file, ram);

    // Initialize the CPU.
    cpu_simple_t cpu(ram);

    // Run until the program returns.
    std::cout << "--------------------------------------------------------------------------\n";
    const int exit_code = static_cast<int>(cpu.run());
    std::cout << "--------------------------------------------------------------------------\n";

    // Show some stats.
    cpu.dump_stats();

    // Dump some RAM (we use the same range as the VHDL testbench).
    cpu.dump_ram(0x00000000, 0x00020000, "/tmp/mrisc32_sim_ram.bin");

    std::exit(exit_code);
  } catch (std::exception& e) {
    std::cerr << "Error: " << e.what() << "\n";
    std::exit(1);
  }
}
