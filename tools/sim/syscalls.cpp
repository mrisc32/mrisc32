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

#include "syscalls.hpp"

#include <fcntl.h>
#include <stdio.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

syscalls_t::syscalls_t(ram_t& ram) : m_ram(ram) {
}

syscalls_t::~syscalls_t() {
  // TODO(m): Close open fd:s etc.
}

void syscalls_t::clear() {
  m_terminate = false;
  m_exit_code = 0u;
}

void syscalls_t::call(const uint32_t routine_no, std::array<uint32_t, 32>& regs) {
  if (routine_no >= static_cast<uint32_t>(routine_t::LAST_)) {
    // TODO(m): Warn!
    return;
  }
  const auto routine = static_cast<routine_t>(routine_no);
  switch (routine) {
    case routine_t::EXIT:
      sim_exit(static_cast<int>(regs[1]));
      break;

    case routine_t::PUTCHAR:
      regs[1] = static_cast<uint32_t>(sim_putchar(static_cast<int>(regs[1])));
      break;

    case routine_t::GETCHAR:
      regs[1] = static_cast<uint32_t>(sim_getchar());
      break;

    case routine_t::CLOSE:
      regs[1] = static_cast<uint32_t>(sim_close(fd_to_host(regs[1])));
      break;

    case routine_t::FSTAT:
      {
        struct stat buf;
        regs[1] = static_cast<uint32_t>(sim_fstat(fd_to_host(regs[1]), &buf));
        stat_to_ram(buf, regs[2]);
      }
      break;

    case routine_t::ISATTY:
      regs[1] = static_cast<uint32_t>(sim_isatty(fd_to_host(regs[1])));
      break;

    case routine_t::LINK:
      regs[1] = static_cast<uint32_t>(sim_link(path_to_host(regs[1]).c_str(), path_to_host(regs[2]).c_str()));
      break;

    case routine_t::LSEEK:
      regs[1] = static_cast<uint32_t>(sim_lseek(fd_to_host(regs[1]), static_cast<int>(regs[2]), static_cast<int>(regs[3])));
      break;

    case routine_t::MKDIR:
      regs[1] = static_cast<uint32_t>(sim_mkdir(path_to_host(regs[1]).c_str(), static_cast<mode_t>(regs[2])));
      break;

    case routine_t::OPEN:
      regs[1] = fd_to_guest(sim_open(path_to_host(regs[1]).c_str(), open_flags_to_host(regs[2]), static_cast<int>(regs[3])));
      break;

    case routine_t::READ:
      {
        if (!m_ram.valid_range(regs[2], regs[3])) {
          regs[1] = static_cast<uint32_t>(-1);
        }
        int fd = fd_to_host(regs[1]);
        char* buf = reinterpret_cast<char*>(&m_ram.at(regs[2]));
        int nbytes = static_cast<int>(regs[3]);
        regs[1] = static_cast<uint32_t>(sim_read(fd, buf, nbytes));
      }
      break;

    case routine_t::STAT:
      {
        struct stat buf;
        regs[1] = static_cast<uint32_t>(sim_stat(path_to_host(regs[1]).c_str(), &buf));
        stat_to_ram(buf, regs[2]);
      }
      break;

    case routine_t::UNLINK:
      regs[1] = static_cast<uint32_t>(sim_unlink(path_to_host(regs[1]).c_str()));
      break;

    case routine_t::WRITE:
      {
        if (!m_ram.valid_range(regs[2], regs[3])) {
          regs[1] = static_cast<uint32_t>(-1);
        }
        int fd = fd_to_host(regs[1]);
        const char* buf = reinterpret_cast<const char*>(&m_ram.at(regs[2]));
        int nbytes = static_cast<int>(regs[3]);
        regs[1] = static_cast<uint32_t>(sim_write(fd, buf, nbytes));
      }
      break;

    case routine_t::GETTIMEMICROS:
      {
        const auto result = sim_gettimemicros();
        regs[1] = static_cast<uint32_t>(result);
        regs[2] = static_cast<uint32_t>(result >> 32);
      }
      break;
  }
}

void syscalls_t::stat_to_ram(struct stat& buf, uint32_t addr) {
  // MRISC32 type (from newlib):
  //    struct stat 
  //    {
  //      dev_t            st_dev;        // 0  (uint16_t)
  //      ino_t            st_ino;        // 2  (uint16_t)
  //      mode_t           st_mode;       // 4  (uint32_t)
  //      nlink_t          st_nlink;      // 8  (uint16_t)
  //      uid_t            st_uid;        // 10 (uint16_t)
  //      gid_t            st_gid;        // 12 (uint16_t)
  //      dev_t            st_rdev;       // 14 (uint16_t)
  //      off_t            st_size;       // 16 (uint32_t)
  //      struct timespec  st_atim;       // 20 (uint64_t + uint32_t)
  //      struct timespec  st_mtim;       // 32 (uint64_t + uint32_t)
  //      struct timespec  st_ctim;       // 44 (uint64_t + uint32_t)
  //      blksize_t        st_blksize;    // 56 (uint32_t)
  //      blkcnt_t         st_blocks;     // 60 (uint32_t)
  //      long             st_spare4[2];  // 64 (uint32_t * 2)
  //    };                                // Total size: 72
  m_ram.store16(addr + 0, buf.st_dev);
  m_ram.store16(addr + 2, buf.st_ino);
  m_ram.store32(addr + 4, buf.st_mode);
  m_ram.store16(addr + 8, buf.st_nlink);
  m_ram.store16(addr + 10, buf.st_uid);
  m_ram.store16(addr + 12, buf.st_gid);
  m_ram.store16(addr + 14, buf.st_rdev);
  m_ram.store32(addr + 16, buf.st_size);
#ifdef __APPLE__
  m_ram.store32(addr + 20, static_cast<uint32_t>(buf.st_atimespec.tv_sec));
  m_ram.store32(addr + 24, static_cast<uint32_t>(buf.st_atimespec.tv_sec >> 32));
  m_ram.store32(addr + 28, static_cast<uint32_t>(buf.st_atimespec.tv_nsec));
  m_ram.store32(addr + 32, static_cast<uint32_t>(buf.st_mtimespec.tv_sec));
  m_ram.store32(addr + 36, static_cast<uint32_t>(buf.st_mtimespec.tv_sec >> 32));
  m_ram.store32(addr + 40, static_cast<uint32_t>(buf.st_mtimespec.tv_nsec));
  m_ram.store32(addr + 44, static_cast<uint32_t>(buf.st_ctimespec.tv_sec));
  m_ram.store32(addr + 48, static_cast<uint32_t>(buf.st_ctimespec.tv_sec >> 32));
  m_ram.store32(addr + 52, static_cast<uint32_t>(buf.st_ctimespec.tv_nsec));
#else
  m_ram.store32(addr + 20, static_cast<uint32_t>(buf.st_atim.tv_sec));
  m_ram.store32(addr + 24, static_cast<uint32_t>(buf.st_atim.tv_sec >> 32));
  m_ram.store32(addr + 28, buf.st_atim.tv_nsec);
  m_ram.store32(addr + 32, static_cast<uint32_t>(buf.st_mtim.tv_sec));
  m_ram.store32(addr + 36, static_cast<uint32_t>(buf.st_mtim.tv_sec >> 32));
  m_ram.store32(addr + 40, buf.st_mtim.tv_nsec);
  m_ram.store32(addr + 44, static_cast<uint32_t>(buf.st_ctim.tv_sec));
  m_ram.store32(addr + 48, static_cast<uint32_t>(buf.st_ctim.tv_sec >> 32));
  m_ram.store32(addr + 52, buf.st_ctim.tv_nsec);
#endif
  m_ram.store32(addr + 56, buf.st_blksize);
  m_ram.store32(addr + 60, buf.st_blocks);
}

std::string syscalls_t::path_to_host(uint32_t addr) {
  std::string result;
  while (true) {
    const auto c = m_ram.load8(addr++);
    if (c == 0u) {
      break;
    }
    result += static_cast<char>(c);
  }
  // TODO(m): Map the path to a suitable host file system path.
  return result;
}

int syscalls_t::fd_to_host(uint32_t fd) {
  // TODO(m): Use a translation map.
  return static_cast<int>(fd);
}

uint32_t syscalls_t::fd_to_guest(int fd) {
  // TODO(m): Use a translation map.
  return static_cast<uint32_t>(fd);
}

int syscalls_t::open_flags_to_host(uint32_t flags) {
  int result;
  if ((flags & 0x0003u) == 1)
    result = O_WRONLY;
  else if ((flags & 0x0003u) == 2)
    result = O_RDWR;
  else
    result = O_RDONLY;

  if ((flags & 0x0008u) != 0u)
    result |= O_APPEND;
  if ((flags & 0x0200u) != 0u)
    result |= O_CREAT;
  if ((flags & 0x0400u) != 0u)
    result |= O_TRUNC;

  return result;
}

void syscalls_t::sim_exit(int status) {
  m_terminate = true;
  m_exit_code = static_cast<uint32_t>(status);
}

int syscalls_t::sim_putchar(int c) {
  return ::putchar(c);
}

int syscalls_t::sim_getchar(void) {
  return ::getchar();
}

int syscalls_t::sim_close(int fd) {
  if (fd >= 0 && fd <= 2) {
    // We don't want to close stdin (0), stdout (1) or stderr (2), since they are used by the
    // simulator.
    return 0;
  }
  return ::close(fd);
}

int syscalls_t::sim_fstat(int fd, struct stat *buf) {
  return ::fstat(fd, buf);
}

int syscalls_t::sim_isatty(int fd) {
  return ::isatty(fd);
}

int syscalls_t::sim_link(const char *oldpath, const char *newpath) {
  return ::link(oldpath, newpath);
}

int syscalls_t::sim_lseek(int fd, int offset, int whence) {
  return ::lseek(fd, offset, whence);
}

int syscalls_t::sim_mkdir(const char *pathname, mode_t mode) {
  return ::mkdir(pathname, mode);
}

int syscalls_t::sim_open(const char *pathname, int flags, int mode) {
  return ::open(pathname, flags, mode);
}

int syscalls_t::sim_read(int fd, char *buf, int nbytes) {
  return ::read(fd, buf, nbytes);
}

int syscalls_t::sim_stat(const char *path, struct stat *buf) {
  return ::stat(path, buf);
}

int syscalls_t::sim_unlink(const char *pathname) {
  return ::unlink(pathname);
}

int syscalls_t::sim_write(int fd, const char *buf, int nbytes) {
  return ::write(fd, buf, nbytes);
}

unsigned long long syscalls_t::sim_gettimemicros(void) {
  struct timeval tv;
  if (::gettimeofday(&tv, nullptr) == 0) {
    return static_cast<unsigned long long>(tv.tv_sec) * 1000000ULL + static_cast<unsigned long long>(tv.tv_usec);
  } else {
    return 0;
  }
}

