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
uint32_t read_bin_file(const char* file_name, ram_t& ram) {
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
    ram_t::line_t& line = ram[current_addr];
    const uint32_t line_offset = current_addr % ram_t::LINE_WIDTH;
    const uint32_t bytes_to_read = ram_t::LINE_WIDTH - line_offset;
    f.read(reinterpret_cast<char*>(&line[line_offset]), bytes_to_read);
    const uint32_t bytes_read = f ? bytes_to_read : static_cast<uint32_t>(f.gcount());
    total_bytes_read += bytes_read;
    current_addr += bytes_read;
  }

  f.close();
  std::cout << "Read " << total_bytes_read << " bytes from " << file_name << " into RAM @ 0x"
            << std::hex << std::setw(8) << std::setfill('0') << start_addr << "\n";
  std::cout << std::resetiosflags(std::ios::hex);
  return start_addr;
}

void print_help(const char* prg_name) {
  std::cout << "sim - A misc16 CPU simulator\n";
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
    ram_t ram;

    // Load the program file into RAM.
    uint32_t start_addr;
    start_addr = read_bin_file(bin_file, ram);

    // Initialize the CPU.
    cpu_simple_t cpu(ram);

    // Run until the program returns.
    int exit_code = static_cast<int>(cpu.run(start_addr));

    // Show some stats.
    cpu.dump_stats();

    std::exit(exit_code);
  } catch (std::exception& e) {
    std::cerr << "Error: " << e.what() << "\n";
    std::exit(1);
  }
}
