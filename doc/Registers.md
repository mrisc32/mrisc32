# Register model and conventions

## Scalar registers

Each scalar register is 32 bits wide, and can be used for integers, floating point values and addresses.

Three scalar registers have a special meaning in hardware:
* Z (S0) - This register is always zero (read-only).
* LR (S30) - Link register (return address for subroutine calls, must be 4-byte aligned).
* VL/PC (S31) - Vector Length register (determines the length of vector operations), or Program Counter for the J and JL instructions.

Furthermore, three scalar registers are reserved for special purposes:
* TP (S27) - Thread pointer (thread local storage).
* FP (S28) - Frame pointer.
* SP (S29) - Stack pointer (must be 4-byte aligned on subroutine entry).

The scalar registers are allocated as follows:

| Register | Alias | Purpose | Saved by callee |
|---|---|---|---|
| Z  | S0 | Always zero | (read-only) |
| S1-S8   | | Subroutine arguments / return values | no |
| S9-S15  | | Temporaries (scratch) | no |
| S16-S26 | | Saved registers | yes |
| TP | S27 | Thread pointer | yes |
| FP | S28 | Frame pointer | yes |
| SP | S29 | Stack pointer | yes |
| LR | S30 | Link register | yes |
| VL<sup>1</sup> | S31 | Vector length register | yes |

<sup>1</sup>: For most instructions S31 refers to the VL register, except for the J and JL instructions that substitute S31 for PC (the program counter).

## Vector registers

Each vector register contains *N* elements (at least 16 elements), and each element is 32 bits wide.

To find the number of elements per vector register, use `cpuid sn,z,z` (s*n* will hold the number of elements).

The vector registers are allocated as follows:

| Register | Alias | Purpose | Saved by callee |
|---|---|---|---|
| VZ | V0 | Always zero (read-only) | - |
| V1-V8 | | Subroutine arguments / return values | no |
| V9-V15 | | Temporaries (scratch) | no |
| V16-V31 | | Saved registers | yes |
