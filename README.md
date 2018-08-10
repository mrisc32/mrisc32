# MRISC32
*Mostly harmless Reduced Instruction Set Computer, 32-bit edition*

This is an experimental, custom 32-bit RISC/Vector CPU, primarily inspired by the [Cray-1](https://en.wikipedia.org/wiki/Cray-1) and [MIPS](https://en.wikipedia.org/wiki/MIPS_architecture) architectures. The focus is to create a clean, modern [ISA](https://en.wikipedia.org/wiki/Instruction_set_architecture) that is equally attractive to software, hardware and compiler developers.

# Features

* Unified scalar/vector/integer/floating point ISA.
* There are two register files:
  - There are 32 scalar registers, S0-S31, each 32 bits wide.
    - Four registers have special meaning in hardware: Z, PC, LR, VL.
    - 28 registers are general purpose (of which three are reserved: SP, TP, FP).
    - All registers can be used for all types (integers, addresses and floating point).
    - PC is user-visible (for arithmetic and addressing) but read-only (to simplify branching logic).
  - There are 32 vector registers, V0-V31, each with *at least* 16 32-bit elements.
    - All registers can be used for all types (integers, addresses and floating point).
* All instructions are 32 bits wide and easy to decode.
  - There are only three basic types of instruction encodings.
  - There is room for 512 register-based and 62 immediate-based instructions.
  - Space has been reserved for future double-word instruction encodings, for an additional 8192 register + 8192 immediate instructions (or more).
* Instructions are non-destructive 3-operand (two sources, one destination).
* All conditionals are based on register content.
  - There are no condition code flags (carry, overflow, ...).
  - Compare instructions generate bit masks.
  - Branch instructions can act on bit masks (all bits set, all bits zero, etc) as well as signed quantities (less than zero, etc).
  - Bit masks are suitable for masking in conditional operations (for scalars, vectors and packed data types).
* Unlike early RISC architectures, there are *no* delay slots.
* Many traditional floating point operations can be handled in whole or partially by integer operations, reducing the number of necessary instructions:
  - Load/store.
  - Branch.
  - Sign and bit manipulation (e.g. neg, abs).
* Vector operations use a Cray-like model:
  - Vector operations are variable length (1-*N* elements).
  - Most integer and floating point instructions come in both scalar and vector variants.
  - Vector instructions can use both vector and scalar operands (including immediate values), which removes the overhead for transfering scalar data into vector registers.
* In addition to vector operations, there are also packed operations that operate on small data types (byte and half-word).

Note: There is currently no HW support for 64-bit floating point operations (that is left for a 64-bit version of the ISA).


# Documentation

* [Registers](doc/Registers.md)
* [Instructions](doc/Instructions.md)
* [Addressing modes](doc/AddressingModes.md)
* [Vector design](doc/VectorDesign.md)
* [Packed operations](doc/PackedOperations.md)
* [Common constructs](doc/CommonConstructs.md)


# Tools

Currently there is a simple [assembler](asm/) (written in Python) and a [CPU simulator](sim/) (written in C++).

Use the assembler to compile programs, and use the simulator to run them.


# Hardware/HDL

A [VHDL implementation](vhdl/) of a single issue, in-order CPU is currently under development.


# Goals

* Keep things simple - both the ISA and the architecture.
* The ISA should map well to a [classic RISC pipeline](https://en.wikipedia.org/wiki/Classic_RISC_pipeline).
* The ISA should scale from small embedded to larger superscalar implementations.
* The CPU should be easy to implement in an FPGA.
* Create a simple baseline scalar CPU that actually works, and then experiment with optimizations.

## Non-goals

* Don't support multiple word sizes or running modes. If a 64-bit CPU is required, create a new ISA and recompile your software.
* Don't be extensible at the cost of more complicated IF/ID stages.
* Don't be fast and optimal for everything.

