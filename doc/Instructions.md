# Instructions

**Note:** See [../asm/asm.py](../asm/asm.py) for a detailed list of instructions, their supported operands and instruction encodings.

## Legend

| Name | Description |
|---|---|
| dst | Destination register |
| src1 | Source operand 1 |
| src2 | Source operand 2 |
| src3 | Source operand 3 |
| i19 | 19-bit immediate value |
| V | Supports vector operation |

## Integer ALU instructions

| Mnemonic | V | Operands | Operation | Description |
|---|---|---|---|---|
|CPUID| x | dst, src1, src2 | dst <= cpuid(src1, src2) | Get CPU information based on src1, src2 |
|OR| x | dst, src1, src2 | dst <= src1 \| src2 | Bitwise or |
|NOR| x | dst, src1, src2 | dst <= ~(src1 \| src2)  | Bitwise nor |
|AND| x | dst, src1, src2 | dst <= src1 & src2 | Bitwise and |
|BIC| x | dst, src1, src2 | dst <= src1 & ~src2 | Bitwise clear |
|XOR| x | dst, src1, src2 | dst <= src1 ^ src2 | Bitwise exclusive or |
|ADD| x | dst, src1, src2 | dst <= src1 + src2 | Addition |
|SUB| x | dst, src1, src2 | dst <= src1 - src2 | Subtraction (note: src1 can be an immediate value) |
|SLT| x | dst, src1, src2 | dst <= (src1 < src2) ? 1 : 0 | Set if less than (signed) |
|SLTU| x | dst, src1, src2 | dst <= (src1 < src2) ? 1 : 0 | Set if less than (unsigned) |
|CEQ| x | dst, src1, src2 | dst <= (src1 == src2) ? 0xffffffff : 0 | Compare if equal (signed) |
|CLT| x | dst, src1, src2 | dst <= (src1 < src2) ? 0xffffffff : 0 | Compare if less than (signed) |
|CLTU| x | dst, src1, src2 | dst <= (src1 < src2) ? 0xffffffff : 0 | Compare if less than (unsigned) |
|CLE| x | dst, src1, src2 | dst <= (src1 <= src2) ? 0xffffffff : 0 | Compare less than or equal (signed) |
|CLEU| x | dst, src1, src2 | dst <= (src1 <= src2) ? 0xffffffff : 0 | Compare less than or equal (unsigned) |
|LSR| x | dst, src1, src2 | dst <= src1 >> src2 (unsigned) | Logic shift right |
|ASR| x | dst, src1, src2 | dst <= src1 >> src2 (signed) | Arithmetic shift right |
|LSL| x | dst, src1, src2 | dst <= src1 << src2 | Logic shift left |
|SHUF| x | dst, src1, src2 | dst <= shuffle(src1, src2) | Shuffle bytes according to indices in src2 (2) |
|SEL| x | dst, src1, src2 | dst <= (src1 & dst) \| (src2 & ~dst) | Bitwise select (use with C[cc]]) |
|CLZ| x | dst, src1 | dst <= clz(src1) | Count leading zeros |
|REV| x | dst, src1 | dst <= rev(src1) | Reverse bit order |
|EXTB| x | dst, src1 | dst <= signextend(src1[7:0]) | Sign-extend byte to word |
|EXTH| x | dst, src1 | dst <= signextend(src1[15:0]) | Sign-extend halfword to word |
|LDB| (1) | dst, src1, src2 | dst <= [src1 + src2] (byte) | Load signed byte |
|LDUB| (1) | dst, src1, src2 | dst <= [src1 + src2] (byte) | Load unsigned byte |
|LDH| (1) | dst, src1, src2 | dst <= [src1 + src2] (halfword) | Load signed halfword |
|LDUH| (1) | dst, src1, src2 | dst <= [src1 + src2] (halfword) | Load unsigned halfword |
|LDW| (1) | dst, src1, src2 | dst <= [src1 + src2] (word) | Load word |
|STB| (1) | src1, src2, src3 | [src2 + src3] <= src1 (byte) | Store byte |
|STH| (1) | src1, src2, src3 | [src2 + src3] <= src1 (halfword) | Store halfowrd |
|STW| (1) | src1, src2, src3 | [src2 + src3] <= src1 (word) | Store word |
|LDI| x | dst, i19 | dst <= signextend(i19) | Load immediate (low 19 bits) |
|LDHI| x | dst, i19 | dst <= i19 << 13 | Load immediate (high 19 bits) |
|LDHIO| x | dst, i19 | dst <= (i19 << 13) \| 0x1fff | Load immediate with low ones (high 19 bits) |

**(1)**: The third operand in vector loads/stores is used as a stride parameter rather than an offset.

**(2)**: SHUF uses the four indices given in src2 to rearrange bytes from src1 into dst. The indcies are given in the lowest 12 bits of src2 (three bits per index, where the upper bit in each index can be set to 1 for clearing the corresponding byte in dst).

## Branch and jump instructions

| Mnemonic | V | Operands | Operation | Description |
|---|---|---|---|---|
|J|   | src1 | pc <= src1 | Jump to register address |
|JL|   | src1 | lr <= pc+4, pc <= src1 | Jump to register address and link |
|BEQ|   | src1, i19 | pc <= pc+signextend(i19)*4 if src1 == 0 | Conditionally branch if equal to zero |
|BNE|   | src1, i19 | pc <= pc+signextend(i19)*4 if src1 != 0 | Conditionally branch if not equal to zero |
|BGE|   | src1, i19 | pc <= pc+signextend(i19)*4 if src1 >= 0 | Conditionally branch if greater than or equal to zero |
|BGT|   | src1, i19 | pc <= pc+signextend(i19)*4 if src1 > 0 | Conditionally branch if greater than zero |
|BLE|   | src1, i19 | pc <= pc+signextend(i19)*4 if src1 <= 0 | Conditionally branch if less than or equal to zero |
|BLT|   | src1, i19 | pc <= pc+signextend(i19)*4 if src1 < 0 | Conditionally branch if less than zero |
|BLEQ|   | src1, i19 | lr <= pc+4, pc <= pc+signextend(i19)*4 if src1 == 0 | Conditionally branch and link if equal to zero |
|BLNE|   | src1, i19 | lr <= pc+4, pc <= pc+signextend(i19)*4 if src1 != 0 | Conditionally branch and link if not equal to zero |
|BLGE|   | src1, i19 | lr <= pc+4, pc <= pc+signextend(i19)*4 if src1 >= 0 | Conditionally branch and link if greater than or equal to zero |
|BLGT|   | src1, i19 | lr <= pc+4, pc <= pc+signextend(i19)*4 if src1 > 0 | Conditionally branch and link if greater than zero |
|BLLE|   | src1, i19 | lr <= pc+4, pc <= pc+signextend(i19)*4 if src1 <= 0 | Conditionally branch and link if less than or equal to zero |
|BLLT|   | src1, i19 | lr <= pc+4, pc <= pc+signextend(i19)*4 if src1 < 0 | Conditionally branch and link if less than zero |

## Multiply and divide instructions

| Mnemonic | V | Operands | Operation | Description |
|---|---|---|---|---|
|MUL| x | dst, src1, src2 | dst <= src1 * src2 | Multiplication (signed or unsigned, low 32 bits) |
|MULHI| x | dst, src1, src2 | dst <= (src1 * src2) >> 32 | Multiplication (signed, high 32 bits) |
|MULHIU| x | dst, src1, src2 | dst <= (src1 * src2) >> 32 | Multiplication (unsigned, high 32 bits) |
|DIV| x | dst, src1, src2 | dst <= src1 / src2 | Division (signed, integer part) |
|DIVU| x | dst, src1, src2 | dst <= src1 / src2 | Division (unsigned, integer part) |
|REM| x | dst, src1, src2 | dst <= src1 % src2 | Remainder (signed) |
|REMU| x | dst, src1, src2 | dst <= src1 % src2 | Remainder (unsigned) |

## Floating point instructions

| Mnemonic | V | Operands | Operation | Description |
|---|---|---|---|---|
|ITOF| x | dst, src1 | dst <= (float)src1 | Cast integer to float |
|FTOI| x | dst, src1 | dst <= (int)src1 | Cast float to integer |
|FADD| x | dst, src1, src2 | dst <= src1 + src2 | Floating point addition |
|FSUB| x | dst, src1, src2 | dst <= src1 - src2 | Floating point subtraction |
|FMUL| x | dst, src1, src2 | dst <= src1 * src2 | Floating point multiplication |
|FDIV| x | dst, src1, src2 | dst <= src1 / src2 | Floating point division |

## Vector instructions

Most instructions (excluding branch instructions) can be executed in both scalar and vector mode.

For instance the integer instruction `ADD` has the following operation modes:
* `ADD Sd,Sa,Sb` - scalar <= scalar + scalar
* `ADD Sd,Sa,IMM` - scalar <= scalar + scalar
* `ADD Vd,Va,Vb` - vector <= vector + vector
* `ADD Vd,Va,Sb` - vector <= vector + scalar
* `ADD Vd,Va,IMM` - vector <= vector + scalar

## Planned instructions

* Move scalar registers to/from vector register elements.
* Control instructions/registers (cache control, interrupt masks, status flags, ...).
* Load Linked (ll) and Store Conditional (sc) for atomic operations.
* Single-instruction load of common constants (mostly floating point: PI, sqrt(2), ...).
* More floating point instructions (round, sqrt, ...?).
* More DSP-type operations (saturate, packed addition, ...).
