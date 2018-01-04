# MRISC32

This is an experimental, custom 32-bit RISC CPU.

## Tools
Currently there is a simple assembler (written in python) and a CPU simulator (written in C++).

## General design

The MRISC32 ISA is designed to map well to a classic 5-stage pipeline.

Some features are:

* All instructions are 32 bits wide and easy to decode.
* There are 28 32-bit general purpose registers plus four dedicated 32-bit registers (zero, PC, SP, LR).
* Branches are executed in the ID (instruction decode) step, which gives a branch misprediction penalty of only one cycle.
* Conditional moves further reduce the cost of branch mispredictions.
* Unlike early RISC architectures, there are *no* delay slots.

## Register model and conventions

The registers are allocated as follows:

| Register  | Alias | Purpose | Saved by callee |
|---|---|---|---|
| r0  | z | Always zero (read-only) | - |
| r1  | pc | Program counter (read-only, always 4-byte aligned) | - |
| r2  | sp | Stack pointer (must be 4-byte aligned on subroutine entry) | yes |
| r3  | lr | Link register (return address, must be 4-byte aligned) | yes |
| r4  | | 1:st subroutine argument / return value | - |
| r5-r11  | | 2:nd-8th subroutine arguments | no |
| r12-r19  | | Scratch registers | no |
| r20-r30  | | Saved registers | yes |
| r31  | | Frame pointer | yes |

## Instructions

**TBD**

