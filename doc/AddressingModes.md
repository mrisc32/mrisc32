# Memory addressing modes

The MRISC32 is a [load/store architecture](https://en.wikipedia.org/wiki/Load/store_architecture), and has a limited but powerful set of addressing modes.

Note that the program counter (PC) can be used as a source operand, so PC-relative addressing is possible for all scalar load and store operations. For extending the PC-relative range beyond ±16 KiB (using a regular 15-bit immediate offset), use one extra instruction to load a 21-bit offset into a register for a range of ±1 MiB, or two extra instructions for loading a full 32-bit offset into a register.

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

There are six different addressing modes for loads and stores to/from vector registers:

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

All branch instructions (BZ, BNZ, BS, BNS, BLT, BGE, BLE, BGT, B, BL) use a PC-relative target address:

`PC <= PC + imm * 4`

...where `imm` is a 21-bit signed value. Thus the range for a branch instruction is PC ±4 MiB.

The jump instructions (J, JL) use a scalar register as the target address:

`PC <= Sa`
