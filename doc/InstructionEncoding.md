# Instruction encoding

There are only three different encoding formats for instructions (called A, B and C).

## Legend

|  | Description |
|---|---|
| VM | Vector mode (00=scalar 10=vector,scalar 11=vector,vector) |
| OP | Operation |
| REG*n* | Register |
| IMM | Immediate value |

## Format A

| VM | 0 (zero) | REG1 | REG2 | REG3 | OP |
|---|---|---|---|---|---|
| 2 bits | 6 bits | 5 bits | 5 bits | 5 bits | 9 bits |

## Format B

| VM | OP | REG1 | REG2 | IMM |
|---|---|---|---|---|
| 2 bits | 6 bits | 5 bits | 5 bits | 14 bits |

## Format C

| VM | OP | REG1 | IMM |
|---|---|---|---|
| 2 bits | 6 bits | 5 bits | 19 bits |

