# Memory addressing modes

The MRISC32 is a [load/store architecture](https://en.wikipedia.org/wiki/Load/store_architecture), and has a limited but powerful set of addressing modes.

## Scalar load/store

There are five different addressing modes for loads and stores to/from scalar registers:

1. Base register plus immediate offset.
   - `Rd <= MEM[Ra + imm]`
   - `Rd => MEM[Ra + imm]`
   - `imm` is a signed 14-bit offset (±8 KiB).
2. PC plus immediate offset (word size only).
   - `Rd <= MEM[Ra + imm * 4]`
   - `Rd => MEM[Ra + imm * 4]`
   - `imm` is a signed 21-bit offset (±4 MiB).
3. Base register plus register offset.
   - `Rd <= MEM[Ra + Rb * scale]`
   - `Rd => MEM[Ra + Rb * scale]`
   - `scale` can be 1 (default), 2, 4 or 8.
4. Immediate (load only).
   - `Rd <= imm`
   - `imm` is a signed 21-bit value that can optionally be shifted left 11 bits with either zero- or one-filled lower 11 bits.
5. Load effective address (load only).
   - `Rd <= Ra + Rb * scale`
   - `scale` can be 1 (default), 2, 4 or 8.


## Vector load/store

There are five different addressing modes for loads and stores to/from vector registers:

1. Base register plus immediate stride.
   - `Vd[k] <= MEM[Ra + imm * k]`
   - `Vd[k] => MEM[Ra + imm * k]`
   - `imm` is a signed 14-bit stride value.
2. Base register plus register stride.
   - `Vd[k] <= MEM[Ra + Rb * scale * k]`
   - `Vd[k] => MEM[Ra + Rb * scale * k]`
   - `scale` can be 1 (default), 2, 4 or 8.
3. Base register plus vector offset (a.k.a. [gather-scatter](https://en.wikipedia.org/wiki/Gather-scatter_%28vector_addressing%29)).
   - `Vd[k] <= MEM[Ra + Vb[k] * scale]`
   - `Vd[k] => MEM[Ra + Vb[k] * scale]`
   - `scale` can be 1 (default), 2, 4 or 8.
4. Load effective address - immediate stride (load only).
   - `Vd[k] <= Ra + imm * k`
   - `imm` is a signed 14-bit stride value.
5. Load effective address - register stride (load only).
   - `Vd[k] <= Ra + Rb * scale * k`
   - `scale` can be 1 (default), 2, 4 or 8.


## Branch and jump instructions

All conditional branch instructions (`BZ`, `BNZ`, `BS`, `BNS`, `BLT`, `BGE`, `BLE`, `BGT`) use a PC-relative target address:

`PC <= PC + imm * 4`

...where `imm` is an 18-bit signed value.

The jump instructions (J, JL) use a scalar register as the base address (also note that PC can be used as the base address for J and JL):

`PC <= Ra + imm * 4`

...where `imm` is a 21-bit signed value.

### Branch ranges

The branch offset range for conditional branches is ±512 KiB.

Using a single instruction, the branch offset range for unconditional branches is ±4 MiB. It is possible to extend the range of unconditional branches to the full 32-bit address space with just one extra instruction.

For a jump to an absolute address, use `ldhi` followed by a `j`/`jl` instruction, e.g:

```
    ldhi    r10, #0x12345000
    j       r10, #0x00000678    ; Jump to 0x12345678
```

For a jump to a PC-relative address, use `addpchi` followed by a `j`/`jl` instruction, e.g:

```
    addpchi lr, #0x12345000     ; lr = pc + 0x12345000
    jl      lr, #0x00000678     ; Jump to pc + 0x12345678
```

Note: In the previous example we used the `lr` register as a temporary scratch register, which is both safe and recommended for linking jumps, since `jl` overwrites `lr` anyway.

You can also use the `z` register as the base address to jump to an absolute address in the range `0x00000000`..`0x003ffffc` or `0xffc00000`..`0xfffffffc`, in a single instruction, e.g:

```
    jl      z, #0x00345678    ; Jump (and link) to 0x00345678
```

| Jump type | Range (1 instr.) | Range (2 instr.) |
|---|---|---|
| Cond. branch | PC ±512 KiB | - |
| Uncond. branch | PC ±4 MiB | PC ±2 GiB |
| Absolute jump | Base ±4 MiB | 4 GiB |
