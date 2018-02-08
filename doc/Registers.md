# Register model and conventions

## Scalar registers

Each scalar register is 32 bits wide, and can be used for integers, floating point values and pointers.

There are five special purpose scalar registers:
* Z (S0) - This register is always zero.
* VL (S28) - Vector length register (determines the length of vector operations).
* LR (S29) - Link register (return address for subroutines)
* SP (S30) - Stack pointer.
* PC (S31) - The program counter (read-only),

The scalar registers are allocated as follows:

| Register | Alias | Purpose | Saved by callee |
|---|---|---|---|
| Z  | S0 | Always zero (read-only) | - |
| S1-S8   | | Subroutine arguments / return values | no |
| S9-S15  | | Temporaries (scratch) | no |
| S16-S26 | | Saved registers | yes |
| FP | S27 |Frame pointer (optional) | yes |
| VL | S28 | Vector length register (holds the length for vector operations) | yes |
| LR | S29 | Link register (return address, must be 4-byte aligned) | yes |
| SP | S30 | Stack pointer (must be 4-byte aligned on subroutine entry) | yes |
| PC | S31 | Program counter (read-only, always 4-byte aligned) | - |


## Vector registers

Each vector register contains *N* elements (at least 4 elements), and each element is 32 bits wide.

To find the number of elements per vector register, use `CPUID Sn,Z` (S*n* will hold the number of elements).

The vector registers are allocated as follows:

| Register | Alias | Purpose | Saved by callee |
|---|---|---|---|
| VZ | V0 | Always zero (read-only) | - |
| V1-V8 | | Subroutine arguments / return values | no |
| V9-V15 | | Temporaries (scratch) | no |
| V16-V31 | | Saved registers | yes |
