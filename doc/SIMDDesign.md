# SIMD Design

## Motivation

The dominating SIMD solution today (SSE, AVX, NEON) is:
* Fixed width, relatively small SIMD registers (e.g. 128 bits wide).
* Split each register into different number of elements depending on the type (e.g. byte vs float).
* Use a completely separate instruction set and separate execution units for operating on the SIMD registers.

In comparison, the proposed SIMD model has the following advantages:
* Much more natural software model, and easier to apply to a wide range of problems.
* Much easier to mix different types (e.g. doing 32-bit integer arithmetic on bytes).
* Relatively easy for the compiler to auto-vectorize.
* Scales to large vector sizes (e.g. the Cray-1 had 4096-bit vector registers).
  - Independent on the number of underlying HW units (e.g. the Cray-1 only had a single 64-bit FPU).
  - No need to update the ISA when more HW parallelism is added.


## Main advantages

The proposed SIMD model scales well from very simple, non-parallel hardware, all the way up to massively parallel superscalar architectures.

Even in the simplest implementaion, e.g. a pipeline interlocking loop that executes a single vector element operation per clock cycle, the vectorized operation will be faster than a corresponding repeated scalar operation. At the same time it is possible to implement a massively parallel (e.g. 32x floating point operations per clock cycle) CPU that works with the exact same instruction set.

Furthermore, the software model is much simpler than "traditional" SIMD solutions, that:
1. Require you to write separate implementations for different generations of hardware.
2. Split your loop into a modulo-N loop (where N is the number of SIMD elements), and a tail-loop for the remaining elements.
3. Deal with the different vector lengths for different data types.

In contrast, the MRISC32 SIMD model allows you to:
* Use the same implementation regardless of the target hardware parallelism.
* Use the exact same instructions as for scalar operations.
* Use the same loop for the core and the tail.

