# Register model and conventions

## Scalar registers

Each scalar register is 32 bits wide, and can be used for integers, floating point values and addresses.

Three scalar registers have a special meaning in hardware:
* Z (R0) - This register is always zero (read-only).
* LR (R30) - Link register (return address for subroutine calls, must be 4-byte aligned).
* VL/PC (R31) - Vector Length register (determines the length of vector operations), or Program Counter for the J and JL instructions.

Furthermore, three scalar registers are reserved for special purposes:
* TP (R27) - Thread pointer (thread local storage).
* FP (R28) - Frame pointer.
* SP (R29) - Stack pointer (must be 4-byte aligned on subroutine entry).

The scalar registers are allocated as follows:

| Register | Alias | Purpose | Saved by callee |
|---|---|---|---|
| Z  | R0 | Always zero | (read-only) |
| R1-R8   | | Subroutine arguments / return values | no |
| R9-R15  | | Temporaries (scratch) | no |
| R16-R26 | | Saved registers | yes |
| TP | R27 | Thread pointer | yes |
| FP | R28 | Frame pointer | yes |
| SP | R29 | Stack pointer | yes |
| LR | R30 | Link register | yes |
| VL<sup>1</sup> | R31 | Vector length register | yes |

<sup>1</sup>: For most instructions R31 refers to the VL register, except for the J and JL instructions that substitute R31 for PC (the program counter).

## Vector registers

Each vector register contains *N* elements (at least 16 elements), and each element is 32 bits wide.

To find the number of elements per vector register, use `getsr rn,#0x10` (r*n* will hold the number of elements).

The vector registers are allocated as follows:

| Register | Alias | Purpose | Saved by callee |
|---|---|---|---|
| VZ | V0 | Always zero (read-only) | - |
| V1-V8 | | Subroutine arguments / return values | no |
| V9-V15 | | Temporaries (scratch) | no |
| V16-V31 | | Saved registers | yes |
