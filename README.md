# MRISC32
*Mostly harmless Reduced Instruction Set Computer, 32-bit edition*

This is an experimental, custom 32-bit RISC CPU with vector operations.

## Tools

Currently there is a simple assembler (written in python) and a CPU simulator (written in C++).

## Hardware/HDL

Not yet...


# Design

## Goals

* Experiment and learn the pros and cons of various design decisions.
* Keep things simple - both the ISA and the architecture.
* The ISA should map well to a [classic 5-stage RISC pipeline](https://en.wikipedia.org/wiki/Classic_RISC_pipeline).
* The ISA should scale from small embedded to larger superscalar implementations.
* The CPU should be easy to implement in an FPGA.


## Non-goals

* Don't support multiple word sizes or running modes. If a 64-bit CPU is required, create a new ISA and recompile your software.
* Don't be fast and optimal for everything.
* Don't be extensible at the cost of more complicated IF/ID stages.


## Features

* All instructions are 32 bits wide and easy to decode.
* There are two register files:
  - There are 32 scalar registers, S0-S31, each 32 bits wide.
    - Five registers are special (Z, PC, SP, LR, VL).
    - 27 registers are general purpose.
    - All registers can be used for all types (integers, pointers and floating point).
    - PC is user-visible (for arithmetic and addressing) but read-only (to simplify branching logic).
  - There are 32 vector registers, V0-V31, each with 32 32-bit elements.
    - All registers can be used for all types (integers, pointers and floating point).
* Branches are executed in the ID (instruction decode) step, which gives a low branch misprediction penalty.
* Conditional moves further reduce the cost of branch mispredictions.
* Conditionals (branches, moves) are based on register content.
* There are *no* condition code flags (carry, overflow, ...).
* Unlike early RISC architectures, there are *no* delay slots.
* Many traditional floating point operations are handled by integer operations, reducing the number of necessary instructions:
  - Load/store.
  - Compare/branch.
  - Conditional moves.
  - Sign and bit manipulation (e.g. neg, abs).
* Many instructions come in both scalar and vector variants.
* There is currently no HW support for 64-bit floating point operations (that is left for a 64-bit version of the ISA).


## Vector operarations (SIMD)

Vector operations use a Cray-like model, with 32 vector registers (V0-V31), each containing 32 32-bit elements.

Vector operations are variable length (1-32 elements), and most integer and floating point instructions can be executed as vector operations. This makes it very easy to convert traditional loop-based software constructs to vector operations.


# Documentation

* [Registers](doc/Registers.md).
* [Instruction encoding](doc/InstructionEncoding.md).
* [Instructions](doc/Instructions.md).
* [Vector design](doc/VectorDesign.md).
* [Common constructs](doc/CommonConstructs.md).

