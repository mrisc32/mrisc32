# MRISC32

This is an experimental, custom 32-bit RISC CPU.

## Tools

Currently there is a simple assembler (written in python) and a CPU simulator (written in C++).

## General design

The MRISC32 ISA is designed to map well to a [classic 5-stage RISC pipeline](https://en.wikipedia.org/wiki/Classic_RISC_pipeline).

Some features are:

* All instructions are 32 bits wide and easy to decode.
* There is a single 32-entry, 32-bit register file.
  - Four registers are special (Z, PC, SP, LR).
  - 28 registers are general purpose.
  - All GPRs can be used for all types (integers, pointers and floating point).
  - PC is user-visible (for arithmetic and addressing) but read-only (to simplify branching logic).
* Branches are executed in the ID (instruction decode) step, which gives a branch misprediction penalty of only one cycle.
* Conditional moves further reduce the cost of branch mispredictions.
* Unlike early RISC architectures, there are *no* delay slots.
* Many traditional floating point operations are handled by integer operations, reducing the number of necessary instructions:
  - Load/store.
  - Compare/branch.
  - Conditional moves.
  - Sign and bit manipulation (e.g. neg, abs).

## Register model and conventions

The registers are allocated as follows:

| Register | Alias | Purpose | Saved by callee |
|---|---|---|---|
| r0  | z | Always zero (read-only) | - |
| r1  | pc | Program counter (read-only, always 4-byte aligned) | - |
| r2  | sp | Stack pointer (must be 4-byte aligned on subroutine entry) | yes |
| r3  | lr | Link register (return address, must be 4-byte aligned) | yes |
| r4-r11  | | Subroutine arguments / return values | no |
| r12-r19  | | Temporaries (scratch) | no |
| r20-r30  | | Saved registers | yes |
| r31  | | Frame pointer (optional) | yes |

## Instructions

### Legend

| Name | Description |
|---|---|
| rd | Destination register |
| ra | Source register 1 |
| rb | Source register 2 |
| rc | Source register 3 |
| i14 | 14-bit immediate value |
| i19 | 19-bit immediate value |
| i24 | 24-bit immediate value |
| c | Carry bit (ALU) |

### Supported instructions

*Still under construction*

| Mnemonic | Operands | Operation | Description |
|---|---|---|---|
|nop| - | - | No operation |
|or | rd, ra, rb | rd <= ra \| rb | Bitwise or |
|nor| rd, ra, rb | rd <= ~(ra \| rb)  | Bitwise nor |
|and| rd, ra, rb | rd <= ra & rb | Bitwise and |
|xor| rd, ra, rb | rd <= ra ^ rb | Bitwise exclusive or |
|add| rd, ra, rb | c:rd <= ra + rb | Addition |
|sub| rd, ra, rb | c:rd <= ra - rb | Subtraction |
|addc| rd, ra, rb | c:rd <= ra + rb + c | Addition with carry |
|subc| rd, ra, rb | c:rd <= ra - rb + c | Subtraction with carry |
|lsl| rd, ra, rb | rd <= ra << rb | Logic shift left |
|asr| rd, ra, rb | rd <= ra >> rb (signed) | Arithmetic shift right |
|lsr| rd, ra, rb | rd <= ra >> rb (unsigned) | Logic shift right |
|clz| rd, ra | rd <= clz(ra) | Count leading zeros |
|rev| rd, ra | rd <= rev(ra) | Reverse bit order |
|ext.b| rd, ra | rd <= signextend(ra[7:0]) | Sign-extend byte to word |
|ext.h| rd, ra | rd <= signextend(ra[15:0]) | Sign-extend halfword to word |
|ldx.b| rd, ra, rb | rd <= [ra + rb] (byte) | Load unsigned byte, indexed |
|ldx.h| rd, ra, rb | rd <= [ra + rb] (halfword) | Load unsigned halfword, indexed |
|ldx.w| rd, ra, rb | rd <= [ra + rb] (word) | Load word, indexed |
|stx.b| rc, ra, rb | [ra + rb] <= rc (byte) | Store byte, indexed |
|stx.h| rc, ra, rb | [ra + rb] <= rc (halfword) | Store halfowrd, indexed |
|stx.w| rc, ra, rb | [ra + rb] <= rc (word) | Store word, indexed |
|meq | rd, ra, rb | rd <= rb if ra == 0 | Conditionally move if equal to zero |
|mne | rd, ra, rb | rd <= rb if ra != 0 | Conditionally move if not equal to zero |
|mlt | rd, ra, rb | rd <= rb if ra < 0 | Conditionally move if less than zero |
|mle | rd, ra, rb | rd <= rb if ra <= 0 | Conditionally move if less than or equal to zero |
|mgt | rd, ra, rb | rd <= rb if ra > 0 | Conditionally move if greater than zero |
|mge | rd, ra, rb | rd <= rb if ra >= 0 | Conditionally move if greater than or equal to zero |
|jmp | ra | pc <= ra | Jump to register address |
|jsr | ra | lr <= pc+4, pc <= ra | Jump to register address and link |
|ori | rd, ra, i14 | rd <= ra \| signextend(i14) | Bitwise or |
|nori| rd, ra, i14 | rd <= ~(ra \| signextend(i14)) | Bitwise nor |
|andi| rd, ra, i14 | rd <= ra & signextend(i14) | Bitwise and |
|xori| rd, ra, i14 | rd <= ra ^ signextend(i14) | Bitwise exclusive or |
|addi| rd, ra, i14 | c:rd <= ra + signextend(i14) | Addition |
|subi| rd, ra, i14 | c:rd <= ra - signextend(i14) | Subtraction |
|addci| rd, ra, i14 | c:rd <= ra + signextend(i14) + c | Addition with carry |
|subci| rd, ra, i14 | c:rd <= ra - signextend(i14) + c | Subtraction with carry |
|lsli| rd, ra, i14 | rd <= ra << signextend(i14) | Logic shift left |
|asri| rd, ra, i14 | rd <= ra >> signextend(i14) (signed) | Arithmetic shift right |
|lsri| rd, ra, i14 | rd <= ra >> signextend(i14) (unsigned) | Logic shift right |
|ld.b| rd, ra, i14 | rd <= [ra + signextend(i14)] (byte) | Load unsigned byte |
|ld.h| rd, ra, i14 | rd <= [ra + signextend(i14)] (halfword) | Load unsigned halfword |
|ld.w| rd, ra, i14 | rd <= [ra + signextend(i14)] (word) | Load word |
|st.b| rc, ra, i14 | [ra + signextend(i14)] <= rc (byte) | Store byte |
|st.h| rc, ra, i14 | [ra + signextend(i14)] <= rc (halfword) | Store halfowrd |
|st.w| rc, ra, i14 | [ra + signextend(i14)] <= rc (word) | Store word |
|beq | ra, i19 | pc <= pc+signextend(i19)*4 if ra == 0 | Conditionally branch if equal to zero |
|bne | ra, i19 | pc <= pc+signextend(i19)*4 if ra != 0 | Conditionally branch if not equal to zero |
|bge | ra, i19 | pc <= pc+signextend(i19)*4 if ra >= 0 | Conditionally branch if greater than or equal to zero |
|bgt | ra, i19 | pc <= pc+signextend(i19)*4 if ra > 0 | Conditionally branch if greater than zero |
|ble | ra, i19 | pc <= pc+signextend(i19)*4 if ra <= 0 | Conditionally branch if less than or equal to zero |
|blt | ra, i19 | pc <= pc+signextend(i19)*4 if ra < 0 | Conditionally branch if less than zero |
|ldi | rd, i19 | rd <= signextend(i19) | Load immediate (low 19 bits) |
|ldhi| rd, i19 | rd <= i19 << 13 | Load immediate (high 19 bits) |
|bra | i24 | pc <= pc+signextend(i24)*4 | Branch unconditionally |
|bsr | i24 | lr <= pc+4, pc <= pc+signextend(i24)*4 | Branch unconditionally and link |

### Planned instructions

* Improved support for unsigned comparisons (sgtu, sltu, ...).
* Integer multiplication and division (32-bit operands and 64-bit results).
* Basic floating point operations (fadd, fsub, fmul, fdiv, ftoi, itof, etc).
* Control instructions/registers (cache control, interrupt masks, status flags, ...).
* Load Linked (ll) and Store Conditional (sc) for atomic operations.

### Common constructs

| Problem | Solution |
|---|---|
| Load 32-bit immediate | ldhi + ori |
| Move register | or rd,ra,z |
| Negate value | sub rd,z,ra |
| Compare and branch | sub + b[cc] |
| Return from subroutine | jmp lr |
| Push to stack | subi sp,sp,N + st.w ra,pc,0 + ... |
| Pop from stack | ld.w rd,pc,0 + ... + addi sp,sp,N |

