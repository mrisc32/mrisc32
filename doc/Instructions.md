# Instructions

## Legend

| Name | Description |
|---|---|
| rd | Destination register |
| ra | Source register 1 |
| rb | Source register 2 |
| rc | Source register 3 |
| i14 | 14-bit immediate value |
| i19 | 19-bit immediate value |
| VV | Supports vector,vector operation |
| VS | Supports vector,scalar operation |

## Integer instructions

| Mnemonic | VV | VS | Operands | Operation | Description |
|---|---|---|---|---|---|
|NOP|   |   | - | - | No operation |
|OR| x | x | rd, ra, rb | rd <= ra \| rb | Bitwise or |
|NOR| x | x | rd, ra, rb | rd <= ~(ra \| rb)  | Bitwise nor |
|AND| x | x | rd, ra, rb | rd <= ra & rb | Bitwise and |
|XOR| x | x | rd, ra, rb | rd <= ra ^ rb | Bitwise exclusive or |
|ADD| x | x | rd, ra, rb | rd <= ra + rb | Addition |
|SUB| x | x | rd, ra, rb | rd <= rb - ra | Subtraction (note: argument order) |
|SLT| x | x | rd, ra, rb | rd <= (ra < rb) ? 1 : 0 | Set if less than (signed) |
|SLTU| x | x | rd, ra, rb | rd <= (ra < rb) ? 1 : 0 | Set if less than (unsigned) |
|LSL| x | x | rd, ra, rb | rd <= ra << rb | Logic shift left |
|ASR| x | x | rd, ra, rb | rd <= ra >> rb (signed) | Arithmetic shift right |
|LSR| x | x | rd, ra, rb | rd <= ra >> rb (unsigned) | Logic shift right |
|CLZ| x |   | rd, ra | rd <= clz(ra) | Count leading zeros |
|REV| x |   | rd, ra | rd <= rev(ra) | Reverse bit order |
|EXTB| x |   | rd, ra | rd <= signextend(ra[7:0]) | Sign-extend byte to word |
|EXTH| x |   | rd, ra | rd <= signextend(ra[15:0]) | Sign-extend halfword to word |
|LDXB|   |   | rd, ra, rb | rd <= [ra + rb] (byte) | Load signed byte, indexed |
|LDXUB|   |   | rd, ra, rb | rd <= [ra + rb] (byte) | Load unsigned byte, indexed |
|LDXH|   |   | rd, ra, rb | rd <= [ra + rb] (halfword) | Load signed halfword, indexed |
|LDXUH|   |   | rd, ra, rb | rd <= [ra + rb] (halfword) | Load unsigned halfword, indexed |
|LDXW|   |   | rd, ra, rb | rd <= [ra + rb] (word) | Load word, indexed |
|STXB|   |   | rc, ra, rb | [ra + rb] <= rc (byte) | Store byte, indexed |
|STXH|   |   | rc, ra, rb | [ra + rb] <= rc (halfword) | Store halfowrd, indexed |
|STXW|   |   | rc, ra, rb | [ra + rb] <= rc (word) | Store word, indexed |
|MEQ|   |   | rd, ra, rb | rd <= rb if ra == 0 | Conditionally move if equal to zero |
|MNE|   |   | rd, ra, rb | rd <= rb if ra != 0 | Conditionally move if not equal to zero |
|MLT|   |   | rd, ra, rb | rd <= rb if ra < 0 | Conditionally move if less than zero |
|MLE|   |   | rd, ra, rb | rd <= rb if ra <= 0 | Conditionally move if less than or equal to zero |
|MGT|   |   | rd, ra, rb | rd <= rb if ra > 0 | Conditionally move if greater than zero |
|MGE|   |   | rd, ra, rb | rd <= rb if ra >= 0 | Conditionally move if greater than or equal to zero |
|JMP|   |   | ra | pc <= ra | Jump to register address |
|JSR|   |   | ra | lr <= pc+4, pc <= ra | Jump to register address and link |
|ORI|   | x | rd, ra, i14 | rd <= ra \| signextend(i14) | Bitwise or |
|NORI|   | x | rd, ra, i14 | rd <= ~(ra \| signextend(i14)) | Bitwise nor |
|ADNI|   | x | rd, ra, i14 | rd <= ra & signextend(i14) | Bitwise and |
|XORI|   | x | rd, ra, i14 | rd <= ra ^ signextend(i14) | Bitwise exclusive or |
|ADDI|   | x | rd, ra, i14 | rd <= ra + signextend(i14) | Addition |
|SUBI|   | x | rd, ra, i14 | rd <= signextend(i14) - ra | Subtraction (note: argument order) |
|SLTI|   | x | rd, ra, i14 | rd <= (ra < signextend(i14)) ? 1 : 0 | Set if less than (signed) |
|SLTUI|   | x | rd, ra, i14 | rd <= (ra < signextend(i14)) ? 1 : 0 | Set if less than (unsigned) |
|LSLI|   | x | rd, ra, i14 | rd <= ra << signextend(i14) | Logic shift left |
|ASRI|   | x | rd, ra, i14 | rd <= ra >> signextend(i14) (signed) | Arithmetic shift right |
|LSRI|   | x | rd, ra, i14 | rd <= ra >> signextend(i14) (unsigned) | Logic shift right |
|LDB|   |   | rd, ra, i14 | rd <= [ra + signextend(i14)] (byte) | Load signed byte |
|LDUB|   |   | rd, ra, i14 | rd <= [ra + signextend(i14)] (byte) | Load unsigned byte |
|LDH|   |   | rd, ra, i14 | rd <= [ra + signextend(i14)] (halfword) | Load signed halfword |
|LDUH|   |   | rd, ra, i14 | rd <= [ra + signextend(i14)] (halfword) | Load unsigned halfword |
|LDW|   |   | rd, ra, i14 | rd <= [ra + signextend(i14)] (word) | Load word |
|STB|   |   | rc, ra, i14 | [ra + signextend(i14)] <= rc (byte) | Store byte |
|STH|   |   | rc, ra, i14 | [ra + signextend(i14)] <= rc (halfword) | Store halfowrd |
|STW|   |   | rc, ra, i14 | [ra + signextend(i14)] <= rc (word) | Store word |
|BEQ|   |   | ra, i19 | pc <= pc+signextend(i19)*4 if ra == 0 | Conditionally branch if equal to zero |
|BNE|   |   | ra, i19 | pc <= pc+signextend(i19)*4 if ra != 0 | Conditionally branch if not equal to zero |
|BGE|   |   | ra, i19 | pc <= pc+signextend(i19)*4 if ra >= 0 | Conditionally branch if greater than or equal to zero |
|BGT|   |   | ra, i19 | pc <= pc+signextend(i19)*4 if ra > 0 | Conditionally branch if greater than zero |
|BLE|   |   | ra, i19 | pc <= pc+signextend(i19)*4 if ra <= 0 | Conditionally branch if less than or equal to zero |
|BLT|   |   | ra, i19 | pc <= pc+signextend(i19)*4 if ra < 0 | Conditionally branch if less than zero |
|BLEQ|   |   | ra, i19 | lr <= pc+4, pc <= pc+signextend(i19)*4 if ra == 0 | Conditionally branch and link if equal to zero |
|BLNE|   |   | ra, i19 | lr <= pc+4, pc <= pc+signextend(i19)*4 if ra != 0 | Conditionally branch and link if not equal to zero |
|BLGE|   |   | ra, i19 | lr <= pc+4, pc <= pc+signextend(i19)*4 if ra >= 0 | Conditionally branch and link if greater than or equal to zero |
|BLGT|   |   | ra, i19 | lr <= pc+4, pc <= pc+signextend(i19)*4 if ra > 0 | Conditionally branch and link if greater than zero |
|BLLE|   |   | ra, i19 | lr <= pc+4, pc <= pc+signextend(i19)*4 if ra <= 0 | Conditionally branch and link if less than or equal to zero |
|BLLT|   |   | ra, i19 | lr <= pc+4, pc <= pc+signextend(i19)*4 if ra < 0 | Conditionally branch and link if less than zero |
|LDI|   |   | rd, i19 | rd <= signextend(i19) | Load immediate (low 19 bits) |
|LDHI|   |   | rd, i19 | rd <= i19 << 13 | Load immediate (high 19 bits) |

## Floating point instructions

| Mnemonic | VV | VS | Operands | Operation | Description |
|---|---|---|---|---|---|
|ITOF| x |   | rd, ra | rd <= (float)ra | Cast integer to float |
|FTOI| x |   | rd, ra | rd <= (int)ra | Cast float to integer |
|FADD| x | x | rd, ra, rb | rd <= ra + rb | Floating point addition |
|FSUB| x | x | rd, ra, rb | rd <= rb - ra | Floating point subtraction (note: argument order) |
|FMUL| x | x | rd, ra, rb | rd <= ra * rb | Floating point multiplication |
|FDIV| x | x | rd, ra, rb | rd <= ra / rb | Floating point division |

## Vector instructions

Many instructions can be executed in one or two of two existing vector modes: vector,vector (`VV`) or vector,scalar (`VS`).

For instance the integer instruction `ADD` has two corresponding vector modes:
* `VVADD` - Add two source vector registers, and store the result in destination vector register.
* `VSADD` - Add a source scalar register to a source vector register, and store the result in destination vector register.

Additionally, there are eight special vector load and store operations:

| Mnemonic | Operands | Operation | Description |
|---|---|---|---|
|VLDB| rd, ra, i14 | rd[k] <= [ra + k * signextend(i14)] (byte) | Load signed bytes with stride |
|VLDUB| rd, ra, i14 | rd[k] <= [ra + k * signextend(i14)] (byte) | Load unsigned bytes with stride |
|VLDH| rd, ra, i14 | rd[k] <= [ra + k * signextend(i14)] (halfword) | Load signed halfwords with stride |
|VLDUH| rd, ra, i14 | rd[k] <= [ra + k * signextend(i14)] (halfword) | Load unsigned halfwords with stride |
|VLDW| rd, ra, i14 | rd[k] <= [ra + k * signextend(i14)] (word) | Load words with stride |
|VSTB| rc, ra, i14 | [ra + k * signextend(i14)] <= rc[k] (byte) | Store bytes with stride |
|VSTH| rc, ra, i14 | [ra + k * signextend(i14)] <= rc[k] (halfword) | Store halfowrds with stride |
|VSTW| rc, ra, i14 | [ra + k * signextend(i14)] <= rc[k] (word) | Store words with stride |

## Planned instructions

* Integer multiplication and division.
* Control instructions/registers (cache control, interrupt masks, status flags, ...).
* Load Linked (ll) and Store Conditional (sc) for atomic operations.
* Single-instruction load of common constants (mostly floating point: PI, sqrt(2), ...).
* More DSP-type manipulation (saturate, swizzle, ...).

