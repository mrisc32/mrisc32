# Vector (SIMD) Design

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
* Each register is split into different number of elements depending on the type (i.e. the data is packed in the registers).
* A completely separate instruction set and separate execution units are used for operating on the SIMD registers.

When used correctly, that model makes good use of the available CPU resources (e.g. with 128-bit registers, 16 byte-additions can be performed per clock cycle and execution unit). However it comes with relatively high costs for hardware and software:
* Specialized SIMD execution units must be included in the hardware, in addition to the regular scalar execution units.
* It is hard to write software that utilizes the SIMD hardware efficiently, partially because compilers have a hard time to map traditional software constructs to the SIMD ISA, so you often have to hand-write code at a very low level.
* Another problem is that it is hard to mix scalar and SIMD code, or mix different data types in SIMD code.

In comparison, the MRISC32 vector model is easier to implement in hardware and easier to use in software. For instance:
* The same execution units can be used for both vector operations and scalar operations, meaning less hardware.
* The software model maps better to traditional software patterns, and it should be easier for compilers to auto-vectorize code.

Furthermore the same ISA can be used for many different levels of hardware parallelism, as opposed to having to design a new ISA every time more hardware parallelism is to be added to a CPU architecture (e.g. MMX vs SSE vs AVX vs ...). In other words, the vector model scales well from very simple, scalar architectures, all the way up to highly parallel superscalar architectures.


## Implementations

It is possible to implement vector operations in various different ways, with different degrees of parallelism and different levels of operation throughput.

### Scalar CPU

In the simplest implementation each vector operation is implemented as a pipeline interlocking loop that executes a single vector element operation per clock cycle. This is essentially just a hardware assisted loop.

Even in this implementation, the vectorized operation will be faster than a corresponding repeated scalar operation for a number of reasons:
* Less overhead from loop branches, counters and memory index calculation.
* Improved cache performance:
  - Increased code density leads to better instruction cache utilization.
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


## Example

*TBD*

