# Register model and conventions

## Scalar registers

Each scalar register is 32 bits wide, and can be used for integers, floating point values and pointers.

There are five special purpose scalar registers:
* Z (R0) - This register is always zero.
* VL (R28) - Vector length register (determines the length of vector opertaions).
* LR (R29) - Link register (return address for subroutines)
* SP (R30) - Stack pointer.
* PC (R31) - The program counter (read-only),

The scalar registers are allocated as follows:

| Register | Alias | Purpose | Saved by callee |
|---|---|---|---|
| R0  | Z | Always zero (read-only) | - |
| R1-R8   | | Subroutine arguments / return values | no |
| R9-R15  | | Temporaries (scratch) | no |
| R16-R26 | | Saved registers | yes |
| R27 | FP | Frame pointer (optional) | yes |
| R28 | VL | Vector length register (holds the last index for vector operations, 0-31) | yes |
| R29 | LR | Link register (return address, must be 4-byte aligned) | yes |
| R30 | SP | Stack pointer (must be 4-byte aligned on subroutine entry) | yes |
| R31 | PC | Program counter (read-only, always 4-byte aligned) | - |


## Vector registers

Each vector register contains 32 elements, and each element is 32 bits wide.

The vector registers are allocated as follows:

| Register | Alias | Purpose | Saved by callee |
|---|---|---|---|
| V0  | VZ | Always zero (read-only) | - |
| V1-V8   | | Subroutine arguments / return values | no |
| V9-V15  | | Temporaries (scratch) | no |
| V16-V31 | | Saved registers | yes |

