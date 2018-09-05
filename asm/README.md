# MRISC32 Assmebler

The assembler parses assembly code text files and converts them to binaries suitable to run in the simulator or in a VHDL test bench.

## Running

To run the assmebler, you need Python (2.x).

```bash
./mr32asm.py path/to/program.s
```

...will produce `path/to/program.bin`.

## Syntax Highlighting

### gedit / GtkSourceView

Copy `support/gtksourceview/mr32asm.lang` to `~/.local/share/gtksourceview-3.0/language-specs/`.

