# MRISC32-A1

This is a [VHDL](https://en.wikipedia.org/wiki/VHDL) implementation of a single issue, in-order CPU. The working name for the CPU is *MRISC32-A1*.

## Overview

![MRISC32-A1 pipleine](mrisc32-a1-pipeline.png)

## Progress

The CPU is still under development. So far, the following components have been implemented:

* An 8-stage pipeline.
  - PC and branching logic.
  - Instruction fetch.
  - Decode.
  - Register fetch.
  - Execute.
  - Data read/write logic (scalar and vector).
  - Register write-back.
  - Operand forwarding.
* The integer ALU.
  - All single-cycle unpacked integer operations are supported.
* A pipelined (two-cycle) multiply unit.
  - Supports all unpacked integer multiplication operations.
* An FPU.
  - Currently only a subset of all the FPU instructions is implemented.
* The scalar register file.
  - There are three read ports and one write port.
* The vector register file.
  - There are two read ports and one write port.
  - Each vector register has 16 elements.
* An address generation unit (AGU).
  - The AGU supports all [addressing modes](../doc/AddressingModes.md).
* Branch prediction and correction.
  - The branch misprediction penalty is 3 cycles.

**TODO**: Caches, divide, more FPU instrucions, packed operations, etc.

## Preformance

The MRISC32-A1 can issue **one operation per clock cycle**.

When synthesized against an [Intel Cyclone V FPGA](https://www.intel.com/content/www/us/en/products/programmable/fpga/cyclone-v.html), the maximum running frequency is around **100 MHz**.

