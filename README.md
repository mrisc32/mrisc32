![MRISC32](doc/mrisc32-logo.png)

This is a open and free 32-bit RISC/Vector instruction set architecture ([ISA](https://en.wikipedia.org/wiki/Instruction_set_architecture)), primarily inspired by the [Cray-1](https://en.wikipedia.org/wiki/Cray-1) and [MIPS](https://en.wikipedia.org/wiki/MIPS_architecture) architectures. The focus is to create a clean, modern ISA that is equally attractive to software, hardware and compiler developers.

# Documentation

* The latest [MRISC32 Instruction Set Manual](https://github.com/mrisc32/mrisc32/releases/latest) (PDF)
* [Registers](doc/Registers.md)
* [Addressing modes](doc/AddressingModes.md)
* [Vector design](doc/VectorDesign.md)
* [Packed operations](doc/PackedOperations.md)
* [Common constructs](doc/CommonConstructs.md)

# Features

* Unified scalar/vector/integer/floating-point ISA.
* There are two register files:
  - **S0-S31**: 32 scalar registers, each 32 bits wide.
    - Four registers have special meaning in hardware: Z, PC, LR, VL.
    - 28 registers are general purpose (of which three are reserved by the ABI: SP, TP, FP).
    - All registers can be used for all types (integers, addresses and floating-point).
    - PC is user-visible (for addressing) but read-only (to simplify branching logic).
  - **V0-V31**: 32 vector registers, each with *at least* 16 32-bit elements.
    - All registers can be used for all types (integers, addresses and floating-point).
* All instructions are 32 bits wide and easy to decode.
* Most instructions are non-destructive 3-operand (two sources, one destination).
* All conditionals are based on register content.
  - There are no condition code flags (carry, overflow, ...).
  - Compare instructions generate bit masks.
  - Branch instructions can act on bit masks (all bits set, all bits zero, etc) as well as signed quantities (less than zero, etc).
  - Bit masks are suitable for masking in conditional operations (for scalars, vectors and packed data types).
* Powerful addressing modes:
  - Scaled indexed load/store (x1, x2, x4, x8).
  - Gather-scatter and stride-based vector load/store.
  - PC-releative and absolute load/store:
    - ±16 KiB range with one instruction.
    - Full 32-bit range with two instructions.
  - PC-relative and absolute branch:
    - ±4 MiB range with one instruction.
    - Full 32-bit range with two instructions.
* Many traditional floating-point operations can be handled in whole or partially by integer operations, reducing the number of necessary instructions:
  - Load/store.
  - Branch.
  - Sign and bit manipulation (e.g. neg, abs).
* Vector operations use a Cray-like model:
  - Vector operations are variable length (1-*N* elements).
  - Most integer and floating-point instructions come in both scalar and vector variants.
  - Vector instructions can use both vector and scalar operands (including immediate values), which removes the overhead for transfering scalar data into vector registers.
* In addition to vector operations, there are also packed operations that operate on small data types (byte and half-word).
* Fixed point operations are supported:
  - Single instruction multiplication of Q31, Q15 and Q7 fixed point numbers.
  - Single instruction conversion between floating-point and fixed point.
  - Saturating and halving addition and subtraction.

Note: There is no support for 64-bit floating-point operations (that is left for a [64-bit version of the ISA](https://github.com/mbitsnbites/mrisc64)).
