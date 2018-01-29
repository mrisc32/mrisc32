# Vector Design (SIMD)

## Description

The MRISC32 approach to Single Instruction Multiple Data (SIMD) operation is very similar to the early [vector processors](https://en.wikipedia.org/wiki/Vector_processor) (such as the [Cray-1](https://en.wikipedia.org/wiki/Cray-1)):
* There are 32 vector registers, V0-V31, with 32 entries in each register.
* All vector entries are the same size (32 bits), regardless if they represent bytes, half-words, words or floats.
* A Vector Length (VL) register controls the length of the vector operation (1-32 elements).
* There are vector,vector and vector,scalar versions of most integer and floating point operations.
* Vector loads and stores have a stride parameter.


## Motivation

The dominating SIMD solution today (SSE, AVX, NEON) is based on an ISA that is largely separate from the scalar ISA of the CPU.
* All SIMD instructions operate on fixed width registers (you have to use all elements or nothing).
* A completely separate instruction set and separate execution units are used for operating on the SIMD registers.
* Each register is split into different number of elements depending on the type (i.e. the data is packed in the registers).

That model, however, comes with relatively high costs for hardware and software:
* Specialized SIMD execution units must be included in the hardware, in addition to the regular scalar execution units.
* It is hard to write software that utilizes the SIMD hardware efficiently, partially because compilers have a hard time to map traditional software constructs to the SIMD ISA, so you often have to hand-write code at a very low level.
* Another problem is that it is hard to mix scalar and SIMD code, or mix different data types in SIMD code.
* In order to exploit more parallelism in new hardware generations, new instruction sets and registers have to be added (e.g. MMX vs SSE vs AVX vs ...), leading to a very complex software model.

In comparison, the MRISC32 vector model is easier to implement in hardware and easier to use in software. For instance:
* The same execution units can be used for both vector operations and scalar operations, meaning less hardware.
* The software model maps better to traditional software patterns, and it should be easier for compilers to auto-vectorize code.
* The same ISA can be used for many different levels of hardware parallelism. In other words, the vector model scales well from very simple, scalar architectures, all the way up to highly parallel superscalar architectures.


## Examples

Consider the following C code:

```C
void abs_diff(float* c, const float* a, const float* b, const int n) {
  for (int i = 0; i < n; ++i) {
    c[i] = fabs(a[i] - b[i]);
  }
}
```

Assuming that the arguments (c, a, b, n) are in registers S1, S2, S3 and S4 (according to the [calling convention](Registers.md)), this can be implemented using scalar operations as:

```
abs_diff:
  BEQ     S4, .done     ; n == 0, nothing to do

  LDHIO   S12, 0x7fffffff

  LDI     S11, 0
.loop:
  LDW     S9, S2, S11
  LDW     S10, S3, S11
  FSUB    S9, S10, S9   ; S9 = a - b
  AND     S9, S9, S12   ; S9 = abs(a - b) (i.e. clear the sign bit)
  STW     S9, S1, S11

  ADD     S4, S4, -1
  ADD     S11, S11, 4
  BNE     S4, .loop

.done:
  JMP     LR
```

...or using vector opertaions as:

```
abs_diff:
  ADD     SP, SP, -4
  STW     VL, SP, 0

  ADD     S4, S4, -1
  LDI     VL, 31
  BLT     S4, .done     ; n == 0, nothing to do

  LDHIO   S10, 0x7fffffff

.loop:
  ADD     S9, S4, -32
  MLT     VL, S9, S4    ; VL = min(32, number of elements left) - 1

  LDW     V9, S2, 4
  LDW     V10, S3, 4
  FSUB    V9, V10, V9   ; V9 = a - b
  AND     V9, V9, S10   ; V9 = abs(a - b) (i.e. clear the sign bit)
  STW     V9, S1, 4

  OR      S4, S9, 0
  ADD     S1, S1, 128
  ADD     S2, S2, 128
  ADD     S3, S3, 128
  BGE     S4, .loop

.done:
  LDW     VL, SP, 0
  ADD     SP, SP, 4
  JMP     LR
```

Notice that the same instructions are used in both cases, only with vector operands for the vector version. Also notice that it is easy to mix scalar and vector operands for vector operations.


## Implementations

It is possible to implement vector operations in various different ways, with different degrees of parallelism and different levels of operation throughput.

### Scalar CPU

In the simplest implementation each vector operation is implemented as a pipeline interlocking loop that executes a single vector element operation per clock cycle. This is essentially just a hardware assisted loop.

Even in this implementation, the vectorized operation will be faster than a corresponding repeated scalar operation for a number of reasons:
* Less overhead from loop branches, counters and memory index calculation.
* Improved cache performance:
  - With relatively little effort, accurate (non-speculative) data cache prefetching can be implemented in hardware for vector loads and stores.
* More data can be kept in registers, meaning less overhead for swapping data to memory.

### Scalar CPU with parallel loops

An extension to the simplest model is to keep two (or more) vector loops running in parallel, which would enable a scalar CPU (fetching only a single instruction per cycle) to execute multiple operations in parallel.

This requires slightly more hardware logic:
* More instruction decoding logic (multiple instructions need to be kept in the ID/loop stage).
* Duplicated vector loop logic.
* Logic for determning if two vector operations can run in parallel, and how.
* Possibly more execution units, in order to maximize parallelism.

The advantage of this implementation is that you can execute more than one operation per clock cycle without implementing a [superscalar architecture](https://en.wikipedia.org/wiki/Superscalar_processor).

### Multiple elements per cycle

Instead of processing one element at a time, each vector loop can process multiple elements at a time. For instance, if there are four identical floating point units, four elements can be read from a vector register and processed in parallel per clock cycle.

This is essentially the same principle as for SIMD ISAs such as SSE or NEON.

The only extra hardware requirements for issuing multiple elements per vector operation are:
* Sufficient number of execution units.
* Wider read/write ports for the vector registers and the data cache(s).

