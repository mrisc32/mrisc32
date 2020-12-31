# Packed operations

## Unpacked operations
All regular operations act on single signed, unsigned or floating point 32-bit words. This is true for both scalar and vector operations (although in the latter case each instruction may spawn multiple operations). In other words, instructions such as `ADD` and `MUL` always operate on all 32 bits of the source operands and provide a 32-bit result.

Support for working with bytes (8-bit integers) and half-words (16-bit integers) is primarily provided via the load and store instructions, which do size expansion up to word size and truncation down to 8/16-bit size, respectively. Additionally bit and byte manipulating instructions such as `SHUF` can be used to expand or truncate signed and unsigned data in registers.

## Packed operations

In addition to the regular unpacked 32-bit operations, there are also packed 4x8-bit and 2x16-bit versions of many operations. Instructions that perform packed operations are suffixed with **.B** (packed bytes) and **.H** (packed half-words).

Packed operations perform the same operation as the unpacked operation, except on a smaller sized data type. Also, multiple operations are performed in parallel. For example:

| Instruction | Operand size | Parallel operations |
|---|---|---|
| ADD | 32 bits | 1 |
| ADD.H | 16 bits | 2 |
| ADD.B | 8 bits | 4 |

## Use cases
In general it is more convenient to work with 32-bit basic types (signed/unsigned integers or floating point values), and utilize vector instructions for improved parallelism. For instance, multiple bytes can be loaded into the 32-bit elements of a vector register using the `LDUB` instruction, processed using 32-bit arithmetic, and finally the result can be stored as bytes in memory using the `STB` instruction.

However, the packed operations have the following benefits:

* They provide additional processing and data throughput (typically 2x for half-words and 4x for bytes).
* They implement wrapping/limiting width arithmetic, which may be required for some data types.

## Packed operations and vector instructions
Packed operations are part of the scalar instruction set, and just as other instructions they can be used with both scalar registers and vector registers. In other words packed operations can be used with vector instructions without any problems.

For instance, the following code (which adds the number seven to 64 bytes in memory) is perfectly valid:

```
  ldi    s10, #7
  shuf   s10, s10, #0  ; s10 = 0x07070707

  ldi    vl, #16       ; Vector Length = 16 words, i.e. 64 bytes
  ldw    v10, s1, #4   ; Load source operands, X, into v10
  add.b  v10, v10, s10 ; Calculate the byte-wise addition of X and 0x07070707
  stw    v10, s1, #4   ; Store the result back into memory
```

## Floating point

Most floating point operations may also act on packed data. The natural size for floating point operations is 32 bits ([IEEE 754 binary32](https://en.wikipedia.org/wiki/Single-precision_floating-point_format)), but with packed operations the MRISC32 ISA also supports 16-bit floating point ([IEEE 754 binary16](https://en.wikipedia.org/wiki/Half-precision_floating-point_format)) and 8-bit floating point (non-standard).

For instance, `fadd.h` performs two 16-bit (half precision) floating point additions, and `fmul.b` performs four 8-bit floating point multiplications.

### Floating point formats

| Size | Sign | Exponent | Significand |
|---|---|---|---|
| 32 bits | 1 bit | 8 bits (bias: +127) | 23(24) bits |
| 16 bits | 1 bit | 5 bits (bias: +15) | 10(11) bits |
| 8 bits | 1 bit | 4 bits (bias: +7) | 3(4) bits |


## The 64-bit perspective
If the MRISC32 ISA is extended into an [MRISC64](https://github.com/mbitsnbites/mrisc64) ISA, packed operations would be the natural way to support 32-bit floating point and 32-bit integer arithmetic. In fact, there is room in the current ISA for Packed Word operations (though they make no sense with 32-bit registers), which could be used in a 64-bit ISA.

E.g. `fadd.w` would do two 32-bit floating point additions, whereas `fadd` would do a single 64-bit floating point addition. Similarly `add.w` would do two 32-bit integer additions, whereas `add` would do a single 64-bit integer addition.
