# SHUF

### A Swiss Army knife of integer data type conversions

The `SHUF` instruction can be used for many different kinds of integer data type conversions, such as sign extension from smaller to larger data types, byte swizzling and unpacking of packed small data types.

The operation of `SHUF` is controlled by a 13-bit control word, which can either be given as an immediate value or as a register value.

```
    dest ← SHUF(src, ctrl)
```

For each sub-byte of the destination word, an individual sub-byte (0-3, where 0 is the least significant byte) can be selected freely from the source word. Furthermore each sub-byte in the destination register can either be copied from the given source sub-byte, or it can be filled with either zeros or the sign bit (bit 7) of the source sub-byte.

Whether a sub-byte should be filled or not is controlled by a single bit per sub-byte in the control word.

Whether a filled sub-byte should be zero- or sign-filled is selected by the sign mode bit (bit 12) in the control word.

As an example, the least significant signed byte of register `S1` can be sign extended to a 32-bit word (stored in `S2`) using the following instruction (details below):

```
    SHUF S2, S1, 0b1100100100000
```

More examples of different operations are given below.

## Control word legend
| Short | Description | Values |
|---|---|---|
| S | Sign mode | 0: zero fill, 1: sign extend |
| F<sub>*n*</sub> | Copy / fill mode *n* | 0: copy byte, 1: fill byte |
| I<sub>*n*</sub> | Source byte index *n* | 0-3, "--"=don't care |

## Sign extension

### Signed byte to word
|  S  | F<sub>3</sub> | I<sub>3</sub> | F<sub>2</sub> | I<sub>2</sub> | F<sub>1</sub> | I<sub>1</sub> | F<sub>0</sub> | I<sub>0</sub> |
|-----|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|
| `1` | `1`           | `00`          | `1`           | `00`          | `1`           | `00`          | `0`           | `00`          |

Examples:
- `0x12349ABC` → `0xFFFFFFBC`
- `0xDEF05678` → `0x00000078`

### Signed half-word to word
|  S  | F<sub>3</sub> | I<sub>3</sub> | F<sub>2</sub> | I<sub>2</sub> | F<sub>1</sub> | I<sub>1</sub> | F<sub>0</sub> | I<sub>0</sub> |
|-----|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|
| `1` | `1`           | `01`          | `1`           | `01`          | `0`           | `01`          | `0`           | `00`          |

Examples:
- `0x12349ABC` → `0xFFFF9ABC`
- `0xDEF05678` → `0x00005678`

## Extract packed data
### Extract the most significant, unsigned byte
|  S  | F<sub>3</sub> | I<sub>3</sub> | F<sub>2</sub> | I<sub>2</sub> | F<sub>1</sub> | I<sub>1</sub> | F<sub>0</sub> | I<sub>0</sub> |
|-----|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|
| `0` | `1`           | `--`          | `1`           | `--`          | `1`           | `--`          | `0`           | `11`          |

Examples:
- `0x12349ABC` → `0x00000012`
- `0xDEF05678` → `0x000000DE`

### Extract the most significant, signed half-word
|  S  | F<sub>3</sub> | I<sub>3</sub> | F<sub>2</sub> | I<sub>2</sub> | F<sub>1</sub> | I<sub>1</sub> | F<sub>0</sub> | I<sub>0</sub> |
|-----|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|
| `1` | `1`           | `11`          | `1`           | `11`          | `0`           | `11`          | `0`           | `10`          |

Examples:
- `0x12349ABC` → `0x00001234`
- `0xDEF05678` → `0xFFFFDEF0`

## Reverse endianity
### Reverse byte order
|  S  | F<sub>3</sub> | I<sub>3</sub> | F<sub>2</sub> | I<sub>2</sub> | F<sub>1</sub> | I<sub>1</sub> | F<sub>0</sub> | I<sub>0</sub> |
|-----|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|
| `0` | `0`           | `00`          | `0`           | `01`          | `0`           | `10`          | `0`           | `11`          |

Examples:
- `0x12349ABC` → `0xBC9A3412`
- `0xDEF05678` → `0x7856F0DE`

### Reverse half-word order
|  S  | F<sub>3</sub> | I<sub>3</sub> | F<sub>2</sub> | I<sub>2</sub> | F<sub>1</sub> | I<sub>1</sub> | F<sub>0</sub> | I<sub>0</sub> |
|-----|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|
| `0` | `0`           | `01`          | `0`           | `00`          | `0`           | `11`          | `0`           | `10`          |

Examples:
- `0x12349ABC` → `0x9ABC1234`
- `0xDEF05678` → `0x5678DEF0`


## Miscellaneous
### Duplicate the least significant byte
|  S  | F<sub>3</sub> | I<sub>3</sub> | F<sub>2</sub> | I<sub>2</sub> | F<sub>1</sub> | I<sub>1</sub> | F<sub>0</sub> | I<sub>0</sub> |
|-----|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|
| `0` | `0`           | `00`          | `0`           | `00`          | `0`           | `00`          | `0`           | `00`          |

Examples:
- `0x12349ABC` → `0xABABABAB`
- `0xDEF05678` → `0x78787878`

### Convert RGBA to ARGB (32-bit color)
|  S  | F<sub>3</sub> | I<sub>3</sub> | F<sub>2</sub> | I<sub>2</sub> | F<sub>1</sub> | I<sub>1</sub> | F<sub>0</sub> | I<sub>0</sub> |
|-----|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|
| `0` | `0`           | `00`          | `0`           | `11`          | `0`           | `10`          | `0`           | `01`          |

Examples:
- `0x12349ABC` → `0xBC12349A`
- `0xDEF05678` → `0x78DEF056`

