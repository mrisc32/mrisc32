# Memory addressing modes

The MRISC32 is a [load/store architecture](https://en.wikipedia.org/wiki/Load/store_architecture), and has a limited but powerful set of addressing modes.

Note that the program counter (PC) can be used as a source operand, so PC-relative addressing is possible for all scalar load and store operations. For extending the PC-relative range beyond ±16 KiB (using a regular 15-bit immediate offset), use an extra `addpchi` instruction to form a full 32-bit offset.

## Scalar load/store

There are three different addressing modes for loads and stores to/from scalar registers:

1. Base register plus immediate offset.
   - `Sd <= MEM[Sa + imm]`
   - `Sd => MEM[Sa + imm]`
   - `imm` is a signed 15-bit offset (±16 KiB).
2. Base register plus register offset.
   - `Sd <= MEM[Sa + Sb]`
   - `Sd => MEM[Sa + Sb]`
3. Immediate (load only).
   - `Sd <= imm`
   - `imm` is a signed 21-bit value that can optionally be shifted left 11 bits with either zero- or one-filled lower 11 bits.


## Vector load/store

There are five different addressing modes for loads and stores to/from vector registers:

1. Base register plus immediate stride.
   - `Vd[k] <= MEM[Sa + imm * k]`
   - `Vd[k] => MEM[Sa + imm * k]`
   - `imm` is a signed 15-bit stride value.
2. Base register plus register stride.
   - `Vd[k] <= MEM[Sa + Sb * k]`
   - `Vd[k] => MEM[Sa + Sb * k]`
3. Base register plus vector offset (a.k.a. [gather-scatter](https://en.wikipedia.org/wiki/Gather-scatter_%28vector_addressing%29)).
   - `Vd[k] <= MEM[Sa + Vb[k]]`
   - `Vd[k] => MEM[Sa + Vb[k]]`
4. Immediate stride (load only).
   - `Vd[k] <= Sa + imm * k`
   - `imm` is a signed 15-bit stride value.
5. Register stride (load only).
   - `Vd[k] <= Sa + Sb * k`


## Branch and jump instructions

All conditional branch instructions (BZ, BNZ, BS, BNS, BLT, BGE, BLE, BGT) use a PC-relative target address:

`PC <= PC + imm * 4`

...where `imm` is a 21-bit signed value.

The jump instructions (J, JL) use a scalar register as the base address (as usual, pc can be used as the base address):

`PC <= Sa + imm * 4`

### Branch ranges

Using a single instruction, the branch offset is ±4 MiB. For conditional branches this is the maximum range, but for unconditional branches it's possible to extend the range to the full 32-bit address space with just one extra instruction.

For a jump to an absolute address, use `ldhi` followed by a `j`/`jl` instruction, e.g:

```
    ldhi    s10, #0x12345000
    j       s10, #0x00000678    ; Jump to 0x12345678
```

For a jump to a PC-relative address, use `addpchi` followed by a `j`/`jl` instruction, e.g:

```
    addpchi s10, #0x12345000    ; s10 = pc + 0x12345000
    j       s10, #0x00000678    ; Jump to pc + 0x12345678
```

You can also use the `z` register as the base address to jump to an absolute address in the range `0x00000000`..`0x003ffffc` or `0xffc00000`..`0xfffffffc`, in a single instruction, e.g:

```
    jl      z, #0x00345678    ; Jump (and link) to 0x00345678
```

| Jump type | Range (1 instr.) | Rang (2 instr.) |
|---|---|---|
| Cond. branch | PC ±4 MiB | - |
| Uncond. branch | PC ±4 MiB | PC ±2 GiB |
| Absolute jump | Base ±4 MiB | 4 GiB |


