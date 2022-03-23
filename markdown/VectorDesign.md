# Vector Design (SIMD)

## Description

The MRISC32 approach to Single Instruction Multiple Data (SIMD) operation is very similar to the early [vector processors](https://en.wikipedia.org/wiki/Vector_processor) (such as the [Cray-1](https://en.wikipedia.org/wiki/Cray-1)):
* There are 32 vector registers, V0-V31, with *at least* 16 elements in each register.
* All vector elements are the same size (32 bits), regardless if they represent bytes, half-words, words or floats.
* A Vector Length (VL) register controls the length of the vector operation.
* There are vector,vector and vector,scalar versions of most integer and floating-point operations.
* Vector loads and stores can either be stride-based or gather-scatter (see [addressing modes](AddressingModes.md) for more details).
* Folding operations are provided for doing horizontal vector operations (e.g. sum, min/max).

### Planned (not yet implemented)

Add a Register Length (RL) tag to each vector register.

* Writing to a vector register updates its Register Length to the operation Vector Length.
* In most instructions the Register Length of the first soruce vector operand defines the operation Vector Length.
* The VL register defines the operation Vector Length for certain "register initialization" instructions, e.g:
  - Stride based memory loads (LDW, LDUB etc) and load effective address (LDEA).
  - Operations using the VZ register as the first operand (e.g. `OR V2, VZ, R7`).
* Elements with an index >= RL are read as zero.
* Clearing a vector register to RL=0 marks the register as "unused", which can reduce context switch overhead.

## Motivation

The dominating SIMD solution today (SSE, AVX, NEON) is based on an ISA that is largely separate from the scalar ISA of the CPU. That model, however, comes with relatively high costs for hardware and software:
* All SIMD instructions operate on fixed width registers (you have to use all elements or nothing).
* A completely separate instruction set and separate execution units are used for operating on the SIMD registers.
* Each register is split into different number of elements depending on the type (i.e. the data is packed in the registers).
* It is hard to write software that utilizes the SIMD hardware efficiently, partially because compilers have a hard time to map traditional software constructs to the SIMD ISA, so you often have to hand-write code at a low level.
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

Assuming that the arguments (c, a, b, n) are in registers R1, R2, R3 and R4 (according to the calling convention), this can be implemented using scalar operations as:

```
abs_diff:
  bz      r4, #done            ; n == 0? (nothing to do)

  ldi     r5, #0
loop:
  add     r4, r4, #-1          ; Decrement the loop counter

  ldw     r6, [r2, r5*4]       ; r6 = a
  ldw     r7, [r3, r5*4]       ; r7 = b
  fsub    r6, r6, r7           ; r6 = a - b
  and     r6, r6, #0x7fffffff  ; r6 = fabs(a - b) (i.e. clear the sign bit)
  stw     r6, [r1, r5*4]       ; c  = fabs(a - b)

  add     r5, r5, #1           ; Increment the array offset
  bgt     r4, #loop

done:
  ret
```

...or using vector operations as:

```
abs_diff:
  bz      r4, #done            ; n == 0? (nothing to do)

  ; Prepare the vector operation
  mov     r5, vl               ; Preserve VL
  getsr   vl, #0x10            ; vl is the max number of vector elements

loop:
  min     vl, vl, r4           ; vl = min(vl, r4)
  sub     r4, r4, vl           ; Decrement the loop counter

  ldw     v1, [r2, #4]         ; v1 = a
  ldw     v2, [r3, #4]         ; v2 = b
  fsub    v1, v1, v2           ; v1 = a - b
  and     v1, v1, #0x7fffffff  ; v1 = fabs(a - b) (i.e. clear the sign bit)
  stw     v1, [r1, #4]         ; c  = fabs(a - b)

  ldea    r1, [r1, vl*4]       ; Increment the memory pointers
  ldea    r2, [r2, vl*4]
  ldea    r3, [r3, vl*4]
  bgt     r4, #loop

  mov     vl, r5               ; Restore VL

done:
  ret
```

Notice that:
* The same instructions are used in both cases, only with vector operands for the vector version.
* It is easy to mix scalar and vector operands for vector operations.
* The loop *overhead* is actually lower in the vector version, since fewer loop iterations are required:
  - Scalar version: 3 instructions / array element.
  - Vector version: 6/16 = 0.375 instructions / array element (for a machine with 16 elements per vector register).
* Any data dependency latencies in the scalar version (e.g. due to memory loads and the FPU pipeline) have vanished in the vector version.
  - Each vector instruction will iterate over several cycles, allowing the first vector elements to be produced before the next instruction starts executing.
  - Typically, an `M` elements wide, `N` stages long pipeline machine will have at least `M * N` elements per vector register.

## Implementations

It is possible to implement vector operations in various different ways, with different degrees of parallelism and different levels of operation throughput.

### Scalar CPU

In the simplest implementation each vector operation is implemented as a pipeline interlocking loop that executes a single vector element operation per clock cycle. This is essentially just a hardware assisted loop.

Even in this implementation, the vectorized operation will be faster than a corresponding repeated scalar operation for a number of reasons:
* Less overhead from loop branches, counters and memory index calculation.
* Improved throughput thanks to reduced number of data dependency stalls (vector operations effectively hide data dependencies).


### Scalar CPU with parallel loops

An extension to the simplest model is to keep two (or more) vector loops running in parallel, which would enable a single-issue CPU (fetching only a single instruction per cycle) to execute multiple operations in parallel.

This is similar to the concept of "chaining" in the Cray 1, which allowed it to do 160 MFLOPS at 80 MHz.

This requires slightly more hardware logic:
* Duplicated vector loop logic.
* Duplicated register fetch and instruction issue logic.
* More register read ports (with some restrictions it may be possible to rely entirely on operand forwarding though).
* Logic for determining if two vector operations can run in parallel, and how.
* Possibly more execution units, in order to maximize parallelism.

One advantage of this implementation is that the instruction fetch pipeline can be kept simple, and the logic for running multiple instructions in parallel is simpler than that of a traditional [superscalar architecture](https://en.wikipedia.org/wiki/Superscalar_processor).

Another advantage, compared to implementing a wider pipeline (see below), is that you can improve parallelism wihout adding more execution units.

### Multiple elements per cycle

Instead of processing one element at a time, each vector loop iteration can process multiple elements at a time. For instance, if there are four identical floating-point units, four elements can be read from a vector register and processed in parallel per clock cycle.

This is essentially the same principle as for SIMD ISAs such as SSE or NEON.

Some additional hardware logic is required to be able to issue multiple elements per vector operation. In particular the hardware needs:
* A sufficient number of execution units.
* Wider read/write ports for the vector registers and the data cache(s).
* More advanced data cache interface (e.g. for wide gather-scatter operations).

