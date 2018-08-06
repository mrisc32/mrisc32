# CPUID

The `CPUID` instruction provides information about the CPU. The instruction takes two arguments (command and sub-command) and returns the corresponding information in the destination operand.

`CPUID Sd, cmd, subcmd`


## 0: Maximum vector length

### 0:0: GetMaxVectorLength

Return the maximum vector length (number of elements).

*Note:* This command is conveniently issued with the `Z` register: `CPUID Sd, Z, Z`.


### 0:1: GetLog2MaxVectorLength

Return log2 of the maximum vector length (number of elements). For instance, if the maximum vector length is 16, then GetLog2MaxVectorLength returns 4.


## 1: CPU features

### 1:0: GetBaseFeatures

Return a bit-field that specifies what features are supported by the CPU.

| Bit | Name | Meaning |
|---|---|---|
| 0 | VEC | Vector operations |
| 1 | PO | Packed operations |
| 2 | MUL | Integer multiplication |
| 3 | DIV | Integer division |
| 4 | FP | Floating point |

