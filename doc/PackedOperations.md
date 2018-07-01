# Packed operations

## Unpacked operations
All regular integer operations act on single signed or unsigned 32-bit words. This is true for both scalar and vector operations (although in the latter case each instruction may spawn multiple operations). In other words, instructions such as `ADD` and `MUL` always operate on all 32 bits of the source operands and provide a 32-bit result.

Support for working with bytes (8-bit integers) and half-words (16-bit integers) is primarily provided via the load and store instructions, which do size expansion up to word size and truncation down to 8/16-bit size, respectively. Additionally bit and byte manipulating instructions such as `SHUF` can be used to expand or truncate signed and unsigned data in registers.

## Packed operations
*Note: This is still under construction.*

In addition to the regular unpacked 32-bit operations, there are also packed 4x8-bit and 2x16-bit versions of many integer operations. Instructions that perform packed operations are prefixed with **PB** ("packed bytes") and **BH** ("packed half-words").

Packed operations perform the same operation as the unpacked operation, except on a smaller sized data type. Also, multiple operations are performed in parallel. For example:

| Instruction | Operand size | Parallel operations |
|---|---|---|
| ADD | 32 bits | 1 |
| PHADD | 16 bits | 2 |
| PBADD | 8 bits | 4 |

## Use cases
In general it is more convenient to work with 32-bit basic types (signed/unsigned integers or floating point values), and utilize vector instructions for improved parallelism. For instance, multiple bytes can be loaded into the 32-bit elements of a vector register using the `LDUB` instruction, processed using 32-bit arithmetic, and finally the result can be stored as bytes in memory using the `STB` instruction.

However, the packed operations have the following benefits:

* They provide additional processing and data throughput (typically 2x for half-words and 4x for bytes).
* They implement wrapping/limiting width arithmetic, which may be required for some data types.

## Packed operations vs vector instructions
Packed operations are part of the scalar instruction set, and just as other instructions they can be used with both scalar registers and vector registers. In other words packed operations can be used with vector instructions without any problems.

For instance, the following code (which adds 7 to 16 bytes in memory) is perfectly valid:

```
  LDI   S10,7
  SHUF  S10,S10,0   ; S10 = 0x07070707

  LDI   VL,4        ; Vector Length = 4 words, i.e. 16 bytes
  LDW   V10,S1,4    ; Load source operands, X, into V10
  PBADD V10,V10,S10 ; Calculate the byte-wise addition of X and 0x07070707
  STW   V10,S1,4    ; Store the result back into memory
```
