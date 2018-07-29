# Vector Design (SIMD)

## Description

The MRISC32 approach to Single Instruction Multiple Data (SIMD) operation is very similar to the early [vector processors](https://en.wikipedia.org/wiki/Vector_processor) (such as the [Cray-1](https://en.wikipedia.org/wiki/Cray-1)):
* There are 32 vector registers, V0-V31, with *at least* 16 elements in each register.
* All vector elements are the same size (32 bits), regardless if they represent bytes, half-words, words or floats.
* A Vector Length (VL) register controls the length of the vector operation.
* There are vector,vector and vector,scalar versions of most integer and floating point operations.
* Vector loads and stores can either be stride-based or gather-scatter (see [addressing modes](AddressingModes.md) for more details).
* Folding operations are provided for doing horizontal vector operations (e.g. sum, min/max).
* Each vector register has a Register Length (RL) state.
  - Writing to a register updates the Register Length to the operation Vector Length.
  - Elements with an index >= RL are zero.
  - Clearing all Register Lengths to zero reduces stack overhead.


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
  BZ      S4, .done    ; n == 0, nothing to do

  LDHIO   S12, 0x7fffffff

  LDI     S11, 0
.loop:
  ADD     S4, S4, -1   ; Decrement the loop counter

  LDW     S9, S2, S11  ; S9  = a
  LDW     S10, S3, S11 ; S10 = b
  FSUB    S9, S9, S10  ; S9  = a - b
  AND     S9, S9, S12  ; S9  = abs(a - b) (i.e. clear the sign bit)
  STW     S9, S1, S11  ; c   = abs(a - b)

  ADD     S11, S11, 4  ; Increment the array offset
  BGT     S4, .loop

.done:
  J       LR
```

...or using vector operations as:

```
abs_diff:
  ADD     SP, SP, -4
  STW     VL, SP, 0

  BZ      S4, .done    ; n == 0, nothing to do

  LDHIO   S10, 0x7fffffff

  ; Prepare the vector operation
  CPUID   S11, Z       ; S11 is the max number of vector elements
  LSL     S12, S11, 2  ; S12 is the memory increment per vector operation

.loop:
  MIN     VL, S4, S11  ; VL = min(S4, S11)

  SUB     S4, S4, S11  ; Decrement the loop counter

  LDW     V9, S2, 4    ; V9  = a
  LDW     V10, S3, 4   ; V10 = b
  FSUB    V9, V9, V10  ; V9  = a - b
  AND     V9, V9, S10  ; V9  = abs(a - b) (i.e. clear the sign bit)
  STW     V9, S1, 4    ; c   = abs(a - b)

  ADD     S1, S1, S12  ; Increment the memory pointers
  ADD     S2, S2, S12
  ADD     S3, S3, S12
  BGT     S4, .loop

.done:
  LDW     VL, SP, 0
  ADD     SP, SP, 4
  J       LR
```

Notice that the same instructions are used in both cases, only with vector operands for the vector version. Also notice that it is easy to mix scalar and vector operands for vector operations.


## Implementations

It is possible to implement vector operations in various different ways, with different degrees of parallelism and different levels of operation throughput.

### Scalar CPU

In the simplest implementation each vector operation is implemented as a pipeline interlocking loop that executes a single vector element operation per clock cycle. This is essentially just a hardware assisted loop.

Even in this implementation, the vectorized operation will be faster than a corresponding repeated scalar operation for a number of reasons:
* Less overhead from loop branches, counters and memory index calculation.
* Improved throughput thanks to reduced number of data dependency stalls (vector operations effectively hide data dependencies).
* Improved cache performance:
  - With relatively little effort, accurate (non-speculative) data cache prefetching can be implemented in hardware for vector loads and stores.
* More data can be kept in registers, meaning less overhead for swapping data to memory.

### Scalar CPU with parallel loops

An extension to the simplest model is to keep two (or more) vector loops running in parallel, which would enable a single-issue CPU (fetching only a single instruction per cycle) to execute multiple operations in parallel.

This is to the concept of "chaining" in the Cray 1, which allowed it to do 160 MFLOPS at 80 MHz.

This requires slightly more hardware logic:
* Duplicated vector loop logic.
* Duplicated register fetch and instruction issue logic.
* More register read ports (with some restrictions it may be possible to rely entirely on operand forwarding though).
* Logic for determning if two vector operations can run in parallel, and how.
* Possibly more execution units, in order to maximize parallelism.

One advantage of this implementation is that the instruction fetch pipeline can be kept simple, and the logic for running multiple instructions in parallel is simpler than that of a traditional [superscalar architecture](https://en.wikipedia.org/wiki/Superscalar_processor).

### Multiple elements per cycle

Instead of processing one element at a time, each vector loop can process multiple elements at a time. For instance, if there are four identical floating point units, four elements can be read from a vector register and processed in parallel per clock cycle.

This is essentially the same principle as for SIMD ISAs such as SSE or NEON.

It puts some more requirements on the hardware logic to be able to issue multiple elements per vector operation. In particular the hardware needs:
* A sufficient number of execution units.
* Wider read/write ports for the vector registers and the data cache(s).
* Masking logic for handling tail cases (e.g. if only three out of four parallel elements are to be processed).

