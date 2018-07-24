# Memory addressing modes

The MRISC32 is a [load/store architecture](https://en.wikipedia.org/wiki/Load/store_architecture), and has a limited but powerful set of addressing modes.

Note that the program counter (PC) can be used as a source operand, so PC-relative addressing is possible for all load and store operations. For extending the PC-relative range beyond ±8 KiB (using a regular 14-bit immediate offset), use one extra instruction to load a 19-bit offset into a register for a range of ±256 KiB, or two extra instructions for loading a full 32-bit offset into a register.

## Scalar load/store

There are three different addressing modes for loads and stores to/from scalar registers:

1. Base register plus immediate offset.
   - `Sd <= MEM[Sa + imm]`
   - `Sd => MEM[Sa + imm]`
   - `imm` is a signed 14-bit offset (±8 KiB).
2. Base register plus register offset.
   - `Sd <= MEM[Sa + Sb]`
   - `Sd => MEM[Sa + Sb]`
3. Immediate (load only).
   - `Sd <= imm`
   - `imm` is a signed 19-bit value that can optionally be shifted left 13 bits with either zero- or one-filled lower 13 bits.


## Vector load/store

There are four different addressing modes for loads and stores to/from vector registers:

1. Base register plus immediate stride.
   - `Vd[k] <= MEM[Sa + imm * k]`
   - `Vd[k] => MEM[Sa + imm * k]`
   - `imm` is a signed 14-bit stride value.
2. Base register plus register stride.
   - `Vd[k] <= MEM[Sa + Sb * k]`
   - `Vd[k] => MEM[Sa + Sb * k]`
3. Base register plus vector offset (a.k.a. [gather-scatter](https://en.wikipedia.org/wiki/Gather-scatter_%28vector_addressing%29)).
   - `Vd[k] <= MEM[Sa + Vb[k]]`
   - `Vd[k] => MEM[Sa + Vb[k]]`
4. Immediate (load only).
   - `Vd[k] <= imm`
   - `imm` is a signed 19-bit value that can optionally be shifted left 13 bits with either zero- or one-filled lower 13 bits.


## Branch and jump instructions

All branch instructions (BZ, BNZ, BS, BNS, BLT, BGE, BLE, BGT, B, BL) use a PC-relative target address:

`PC <= PC + imm * 4`

...where `imm` is a 19-bit signed value. Thus the range for a branch instruction is PC ±1 MiB.

The jump instructions (J, JL) use a scalar register as the target address:

`PC <= Sa`

