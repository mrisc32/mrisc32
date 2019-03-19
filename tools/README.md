# Tools

## Assembler / Linker

The only way to program the MRISC32 is using [assembly language](https://en.wikipedia.org/wiki/Assembly_language) (high level languages such as C++ via LLVM and/or GCC are planned but not yet implemented).

The primary tool is [GNU binutils](https://www.gnu.org/software/binutils/), which includes an assembler (as) and a linker (ld). A special [MRISC32 port of binutils](https://github.com/mbitsnbites/binutils-mrisc32) is required to build software for MRISC32.


### Building/installing binutils

Clone the Git repository:

```bash
$ git clone https://github.com/mbitsnbites/binutils-mrisc32.git
```

Configure and build:

```bash
$ cd binutils-mrisc32
$ mkdir build
$ cd build
$ ../configure --target=mrisc32 --program-prefix=mrisc32- --with-system-zlib
$ make
```

Install:

```bash
$ sudo make install
```

> Warning 1: The MRISC32 port of binutils is maintained as a branch that is periodically rebased on top of the latest upstream master branch and force pushed to the fork repository. To update your local clone you need to `git fetch origin` and then `git reset --hard origin/users/mbitsnbites/mrisc32`.

> Warning 2: The binutils build system is not very robust. Using `make -j N` is tempting, but may result in failing builds. You may also need to `make clean` if some of the sources have changed, since the depency graph isn't 100% accurate.


## Building programs

To build assembly language programs that can be used by the simulator or the VHDL testbench (core_tb), do the following:

```bash
$ mrisc32-as -o my-program.o my-program.s
$ mrisc32-ld -o my-program.elf my-program.o
$ tools/elf2bin.py my-program.elf my-program.bin
```

The final `.bin` file can be loaded into the simulator, for instance.


## Simulator

The MRISC32 simulator is a C++ program that can run MRISC32 binaries. See [sim/README.md](sim/README.md).


## Syntax Highlighting

![MRISC32 Assembly Language](mrisc32-asm.png)

### gedit / GtkSourceView

Copy `tools/support/gtksourceview/mr32asm.lang` to `~/.local/share/gtksourceview-3.0/language-specs/`.