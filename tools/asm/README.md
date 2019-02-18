# MRISC32 Assmebler

**NOTE:** *This is the legacy MRISC32 assembler. A far more advanced implementation can be found in the [MRISC32 port of binutils](https://github.com/mbitsnbites/binutils-mrisc32) (i.e. the GNU assembler and linker).*

The assembler parses assembly code text files and converts them to binaries suitable to run in the simulator or in a VHDL test bench.

## Running

To run the assmebler, you need Python (3.x).

```bash
./mr32asm.py path/to/program.s
```

...will produce `path/to/program.bin`.

Or you can specify an output file with `-o`:

```bash
./mr32asm.py path/to/program.s -o other/path/to/output.bin
```