# Register model and conventions

## Scalar registers

Each scalar register is 32 bits wide, and can be used for integers, floating point values and pointers.

Four scalar registers have a special meaning in hardware:
* Z (S0) - This register is always zero (read-only).
* VL (S29) - Vector length register (determines the length of vector operations).
* LR (S30) - Link register (return address for subroutine calls, must be 4-byte aligned).
* PC (S31) - Program counter (the address of the current instruction, read-only).

Furthermore, three scalar registers are reserved for special purposes:
* FP (S26) - Frame pointer.
* TP (S27) - Thread pointer (thread local storage).
* SP (S28) - Stack pointer (must be 4-byte aligned on subroutine entry).

The scalar registers are allocated as follows:

| Register | Alias | Purpose | Saved by callee |
|---|---|---|---|
| Z  | S0 | Always zero | (read-only) |
| S1-S8   | | Subroutine arguments / return values | no |
| S9-S15  | | Temporaries (scratch) | no |
| S16-S25 | | Saved registers | yes |
| FP | S26 | Frame pointer | yes |
| TP | S27 | Thread pointer | yes |
| SP | S28 | Stack pointer | yes |
| VL | S29 | Vector length register | yes |
| LR | S30 | Link register | yes |
| PC | S31 | Program counter | (read-only) |


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
