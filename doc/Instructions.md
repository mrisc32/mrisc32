# Instructions

**Note:** See [mr32asm.py](../asm/mr32asm.py) for a detailed list of instructions, their supported operands and instruction encodings.

## Legend

| Name | Description |
|---|---|
| dst | Destination register |
| src1 | Source operand 1 |
| src2 | Source operand 2 |
| src3 | Source operand 3 |
| i21 | 21-bit immediate value |
| I | Supports immediate operand |
| V | Supports vector operation |
| P | Supports packed operation |

## Load/store instructions

| Mnemonic | I | V | P | Operands | Operation | Description |
|---|---|---|---|---|---|---|
|LDB| x | (1) |   | dst, src1, src2 | dst <= [src1 + src2] (byte) | Load signed byte |
|LDUB| x | (1) |   | dst, src1, src2 | dst <= [src1 + src2] (byte) | Load unsigned byte |
|LDH| x | (1) |   | dst, src1, src2 | dst <= [src1 + src2] (halfword) | Load signed halfword |
|LDUH| x | (1) |   | dst, src1, src2 | dst <= [src1 + src2] (halfword) | Load unsigned halfword |
|LDW| x | (1) |   | dst, src1, src2 | dst <= [src1 + src2] (word) | Load word |
|STB| x | (1) |   | src1, src2, src3 | [src2 + src3] <= src1 (byte) | Store byte |
|STH| x | (1) |   | src1, src2, src3 | [src2 + src3] <= src1 (halfword) | Store halfowrd |
|STW| x | (1) |   | src1, src2, src3 | [src2 + src3] <= src1 (word) | Store word |
|LDI| x | x |   | dst, #i21 | dst <= signextend(i21) | Alt. 1: Load immediate (low 21 bits) |
|LDHI| x | x |   | dst, #i21 | dst <= i21 << 11 | Alt. 2: Load immediate (high 21 bits) |
|LDHIO| x | x |   | dst, #i21 | dst <= (i21 << 11) \| 0x7ff | Alt. 3: Load immediate with low ones (high 21 bits) |
|LDSTRD| x | x |   | dst, src1, src2 | dst[k] <= src1 + src2 * k | Load a linear stride (vector instruction) |

**(1)**: The third operand in vector loads/stores is used as a stride or offset parameter (see [addressing modes](AddressingModes.md) for more details).

## Branch and jump instructions

| Mnemonic | I | V | P | Operands | Operation | Description |
|---|---|---|---|---|---|---|
|J| x |   |   | src1, #i21 | pc <= src1+signextend(i21)*4 | Jump to register address<br>Note: src1 can be PC |
|JL| x |   |   | src1, #i21 | lr <= pc+4, pc <= src1+signextend(i21)*4 | Jump to register address and link<br>Note: src1 can be PC |
|BZ| x |   |   | src1, #i21 | pc <= pc+signextend(i21)*4 if src1 == 0 | Conditionally branch if equal to zero |
|BNZ| x |   |   | src1, #i21 | pc <= pc+signextend(i21)*4 if src1 != 0 | Conditionally branch if not equal to zero |
|BS| x |   |   | src1, #i21 | pc <= pc+signextend(i21)*4 if src1 == 0xffffffff | Conditionally branch if set (all bits = 1) |
|BNS| x |   |   | src1, #i21 | pc <= pc+signextend(i21)*4 if src1 != 0xffffffff | Conditionally branch if not set (at least one bit = 0) |
|BLT| x |   |   | src1, #i21 | pc <= pc+signextend(i21)*4 if src1 < 0 | Conditionally branch if less than zero |
|BGE| x |   |   | src1, #i21 | pc <= pc+signextend(i21)*4 if src1 >= 0 | Conditionally branch if greater than or equal to zero |
|BLE| x |   |   | src1, #i21 | pc <= pc+signextend(i21)*4 if src1 <= 0 | Conditionally branch if less than or equal to zero |
|BGT| x |   |   | src1, #i21 | pc <= pc+signextend(i21)*4 if src1 > 0 | Conditionally branch if greater than zero |

## Special PC-addition

| Mnemonic | I | V | P | Operands | Operation | Description |
|---|---|---|---|---|---|---|
|ADDPCHI| x |   |   | dst, #i21 | dst <= pc + (i21 << 11) | Add high immediate to PC |

Note: `ADDPCHI` can be used together with load/store instructions to perform 32-bit PC-relative addressing in just two instructions.

## Integer ALU instructions

| Mnemonic | I | V | P | Operands | Operation | Description |
|---|---|---|---|---|---|---|
|CPUID|   | x |   | dst, src1, src2 | dst <= cpuid(src1, src2) | Get CPU information based on src1, src2 (see [CPUID](CPUID.md)) |
|OR| x | x |   | dst, src1, src2 | dst <= src1 \| src2 | Bitwise or |
|NOR| x | x |   | dst, src1, src2 | dst <= ~(src1 \| src2)  | Bitwise nor |
|AND| x | x |   | dst, src1, src2 | dst <= src1 & src2 | Bitwise and |
|BIC| x | x |   | dst, src1, src2 | dst <= src1 & ~src2 | Bitwise clear |
|XOR| x | x |   | dst, src1, src2 | dst <= src1 ^ src2 | Bitwise exclusive or |
|ADD| x | x | x | dst, src1, src2 | dst <= src1 + src2 | Addition |
|SUB| x | x | x | dst, src1, src2 | dst <= src1 - src2 | Subtraction (note: src1 can be an immediate value) |
|SEQ| x | x | x | dst, src1, src2 | dst <= (src1 == src2) ? 0xffffffff : 0 | Set if equal |
|SNE| x | x | x | dst, src1, src2 | dst <= (src1 != src2) ? 0xffffffff : 0 | Set if not equal |
|SLT| x | x | x | dst, src1, src2 | dst <= (src1 < src2) ? 0xffffffff : 0 | Set if less than (signed) |
|SLTU| x | x | x | dst, src1, src2 | dst <= (src1 < src2) ? 0xffffffff : 0 | Set if less than (unsigned) |
|SLE| x | x | x | dst, src1, src2 | dst <= (src1 <= src2) ? 0xffffffff : 0 | Set if less than or equal (signed) |
|SLEU| x | x | x | dst, src1, src2 | dst <= (src1 <= src2) ? 0xffffffff : 0 | Set if less than or equal (unsigned) |
|MIN| x | x | x | dst, src1, src2 | dst <= min(src1, src2) (signed) | Minimum value |
|MAX| x | x | x | dst, src1, src2 | dst <= max(src1, src2) (signed) | Maximum value |
|MINU| x | x | x | dst, src1, src2 | dst <= min(src1, src2) (unsigned) | Minimum value |
|MAXU| x | x | x | dst, src1, src2 | dst <= max(src1, src2) (unsigned) | Maximum value |
|ASR| x | x | x | dst, src1, src2 | dst <= src1 >> src2 (signed) | Arithmetic shift right |
|LSL| x | x | x | dst, src1, src2 | dst <= src1 << src2 | Logic shift left |
|LSR| x | x | x | dst, src1, src2 | dst <= src1 >> src2 (unsigned) | Logic shift right |
|SHUF| x | x |   | dst, src1, src2 | dst <= shuffle(src1, src2) | Shuffle bytes according to the shuffle descriptor in src2 (see [SHUF](SHUF.md)) |
|CLZ|   | x | x | dst, src1 | dst <= clz(src1) | Count leading zeros |
|REV|   | x | x | dst, src1 | dst <= rev(src1) | Reverse bit order |
|PACKB|   | x |   | dst, src1, src2 | dst <=<br>((src1 & 0x00ff0000) << 8) \|<br>((src1 & 0x000000ff) << 16) \|<br>((src2 & 0x00ff0000) >> 8) \|<br>(src2 & 0x000000ff) | Pack four bytes into a word |
|PACKH|   | x |   | dst, src1, src2 | dst <=<br>((src1 & 0x0000ffff) << 16) \|<br>(src2 & 0x0000ffff) | Pack two half-words into a word |

## Saturating and halving arithmentic instructions

| Mnemonic | I | V | P | Operands | Operation | Description |
|---|---|---|---|---|---|---|
|ADDS|   | x | x | dst, src1, src2 | dst <= saturate(src1 + src2) | Saturating addition (signed) |
|ADDSU|   | x | x | dst, src1, src2 | dst <= saturate(src1 + src2) | Saturating addition (unsigned) |
|ADDH|   | x | x | dst, src1, src2 | dst <= (src1 + src2) / 2 | Halving addition (signed) |
|ADDHU|   | x | x | dst, src1, src2 | dst <= (src1 + src2) / 2 | Halving addition (unsigned) |
|SUBS|   | x | x | dst, src1, src2 | dst <= saturate(src1 - src2) | Saturating subtraction (signed) |
|SUBSU|   | x | x | dst, src1, src2 | dst <= saturate(src1 - src2) | Saturating subtraction (unsigned) |
|SUBH|   | x | x | dst, src1, src2 | dst <= (src1 - src2) / 2 | Halving subtraction (signed) |
|SUBHU|   | x | x | dst, src1, src2 | dst <= (src1 - src2) / 2 | Halving subtraction (unsigned) |

## Multiply and divide instructions

| Mnemonic | I | V | P | Operands | Operation | Description |
|---|---|---|---|---|---|---|
|MULQ|   | x | x | dst, src1, src2 | dst <= (src1 * src2) >> 31 | Fixed point multiplication (signed Q31 format, or Q15/Q7 for packed operations) |
|MUL|   | x | x | dst, src1, src2 | dst <= src1 * src2 | Multiplication (signed or unsigned, low 32 bits) |
|MULHI|   | x | x | dst, src1, src2 | dst <= (src1 * src2) >> 32 | Multiplication (signed, high 32 bits) |
|MULHIU|   | x | x | dst, src1, src2 | dst <= (src1 * src2) >> 32 | Multiplication (unsigned, high 32 bits) |
|DIV|   | x | x | dst, src1, src2 | dst <= src1 / src2 | Division (signed, integer part) |
|DIVU|   | x | x | dst, src1, src2 | dst <= src1 / src2 | Division (unsigned, integer part) |
|REM|   | x | x | dst, src1, src2 | dst <= src1 % src2 | Remainder (signed) |
|REMU|   | x | x | dst, src1, src2 | dst <= src1 % src2 | Remainder (unsigned) |

## Floating point instructions

| Mnemonic | I | V | P | Operands | Operation | Description |
|---|---|---|---|---|---|---|
|ITOF|   | x |   | dst, src1, src2 | dst <= ((float)src1) * 2^src2 | Cast integer to float with exponent offset |
|FTOI|   | x |   | dst, src1, src2 | dst <= (int)(src1 * 2^src2) | Cast float to integer with exponent offset |
|FADD|   | x | x | dst, src1, src2 | dst <= src1 + src2 | Floating point addition |
|FSUB|   | x | x | dst, src1, src2 | dst <= src1 - src2 | Floating point subtraction |
|FMUL|   | x | x | dst, src1, src2 | dst <= src1 * src2 | Floating point multiplication |
|FDIV|   | x | x | dst, src1, src2 | dst <= src1 / src2 | Floating point division |
|FSQRT|   | x | x | dst, src1 | dst <= sqrt(src1) | Floating point square root |
|FSEQ|   | x | x | dst, src1, src2 | dst <= (src1 == src2) ? 0xffffffff : 0 | Set if equal (floating point) |
|FSNE|   | x | x | dst, src1, src2 | dst <= (src1 != src2) ? 0xffffffff : 0 | Set if not equal (floating point) |
|FSLT|   | x | x | dst, src1, src2 | dst <= (src1 < src2) ? 0xffffffff : 0 | Set if less than (floating point) |
|FSLE|   | x | x | dst, src1, src2 | dst <= (src1 <= src2) ? 0xffffffff : 0 | Set if less than or equal (floating point) |
|FSNAN|   | x | x | dst, src1, src2 | dst <= (isNaN(src1) \|\| isNaN(src2)) ? 0xffffffff : 0 | Set if Not-a-Number |
|FMIN|   | x | x | dst, src1, src2 | dst <= min(src1, src2) | Floating point minimum value |
|FMAX|   | x | x | dst, src1, src2 | dst <= max(src1, src2) | Floating point maximum value |

## Vector instructions

Most instructions (excluding branch instructions) can be executed in both scalar and vector mode.

For instance the integer instruction `ADD` has the following operation modes:
* `ADD Sd,Sa,Sb` - scalar <= scalar + scalar
* `ADD Sd,Sa,#IMM` - scalar <= scalar + scalar
* `ADD Vd,Va,Sb` - vector <= vector + scalar
* `ADD Vd,Va,#IMM` - vector <= vector + scalar
* `ADD Vd,Va,Vb` - vector <= vector + vector

*See [Vector Design](VectorDesign.md) for more information.*

## Packed operation

Many instructions support packed operation. Suffix the instruction with `.B` for packed byte operation (each word is treated as four bytes, and four operations are performed in parallel), or `.H` for packed half-word operation (each word is treated as two half-words, and two operations are performed in parallel).

For instance, the following packed operations are possible for the `MAX` instruction:
* `MAX.B Sd,Sa,Sb` - 4x packed byte MAX, scalar <= max(scalar, scalar)
* `MAX.B Vd,Va,Sb` - 4x packed byte MAX, vector <= max(vector, scalar)
* `MAX.B Vd,Va,Vb` - 4x packed byte MAX, vector <= max(vector, vector)
* `MAX.H Sd,Sa,Sb` - 2x packed half-word MAX, scalar <= max(scalar, scalar)
* `MAX.H Vd,Va,Sb` - 2x packed half-word MAX, vector <= max(vector, scalar)
* `MAX.H Vd,Va,Vb` - 2x packed half-word MAX, vector <= max(vector, vector)

Note that immediate operands are not supported for packed operations.

*See [Packed Operations](PackedOperations.md) for more information.*

## Planned instructions

* Move scalar registers to/from vector register elements.
* Conversion and packing/unpacking of different floating point representations (32-bit, 2x16-bit, 4x8-bit).
* More floating point instructions (round, ...?).
* Control instructions/registers (cache control, interrupt masks, status flags, ...).
* Load Linked (ll) and Store Conditional (sc) for atomic operations.

