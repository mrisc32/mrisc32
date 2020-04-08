//--------------------------------------------------------------------------------------------------
// Copyright (c) 2020 Marcus Geelnard
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

#ifndef SIM_SYSCALLS_HPP_
#define SIM_SYSCALLS_HPP_

#include "ram.hpp"

#include <array>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

class syscalls_t {
public:
  // Simulator routines.
  enum class routine_t {
    EXIT = 0,
    PUTCHAR = 1,
    GETCHAR = 2,
    CLOSE = 3,
    FSTAT = 4,
    ISATTY = 5,
    LINK = 6,
    LSEEK = 7,
    MKDIR = 8,
    OPEN = 9,
    READ = 10,
    STAT = 11,
    UNLINK = 12,
    WRITE = 13,
    GETTIMEMICROS = 14,
    LAST_
  };

  syscalls_t(ram_t& ram);
  ~syscalls_t();

  /// @brief Clear the run state.
  void clear();

  /// @brief Call a system routine.
  /// @param routine_no Syscall routine ID.
  /// @param regs A mutable array of the current register state.
  void call(const uint32_t routine_no, std::array<uint32_t, 32>& regs);

  /// @returns true if a call requested the process to terminate.
  bool terminate() const {
    return m_terminate;
  }

  /// @returns the exit code for the process.
  uint32_t exit_code() const {
    return m_exit_code;
  }

private:
  void stat_to_ram(struct stat& buf, uint32_t addr);
  std::string path_to_host(uint32_t addr);
  int fd_to_host(uint32_t fd);
  uint32_t fd_to_guest(int fd);
  int open_flags_to_host(uint32_t flags);

  void sim_exit(int status);
  int sim_putchar(int c);
  int sim_getchar(void);
  int sim_close(int fd);
  int sim_fstat(int fd, struct stat *buf);
  int sim_isatty(int fd);
  int sim_link(const char *oldpath, const char *newpath);
  int sim_lseek(int fd, int offset, int whence);
  int sim_mkdir(const char *pathname, mode_t mode);
  int sim_open(const char *pathname, int flags, int mode);
  int sim_read(int fd, char *buf, int nbytes);
  int sim_stat(const char *path, struct stat *buf);
  int sim_unlink(const char *pathname);
  int sim_write(int fd, const char *buf, int nbytes);
  unsigned long long sim_gettimemicros(void);

  ram_t& m_ram;

  bool m_terminate = false;
  uint32_t m_exit_code = 0u;
};

#endif  // SIM_SYSCALLS_HPP_

