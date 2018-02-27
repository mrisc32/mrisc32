#!/usr/bin/env python
# -*- mode: python; tab-width: 4; indent-tabs-mode: nil; -*-
# -------------------------------------------------------------------------------------------------
# Copyright (c) 2018 Marcus Geelnard
#
# This software is provided 'as-is', without any express or implied warranty. In no event will the
# authors be held liable for any damages arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose, including commercial
# applications, and to alter it and redistribute it freely, subject to the following restrictions:
#
#  1. The origin of this software must not be misrepresented; you must not claim that you wrote
#     the original software. If you use this software in a product, an acknowledgment in the
#     product documentation would be appreciated but is not required.
#
#  2. Altered source versions must be plainly marked as such, and must not be misrepresented as
#     being the original software.
#
#  3. This notice may not be removed or altered from any source distribution.
# -------------------------------------------------------------------------------------------------

import argparse
import struct
import os
import sys


# Instruction formats:
#      3             2               1
#     |1| | | | | | |4| | | | | | | |6| | | | | | | |8| | | | | | | |0|
#     +---+-----------+---------+---------+---------+-----------------+
# A:  |VM |0 0 0 0 0 0|REG1     |REG2     |REG3     |OP (9b)          |
#     +---+-----------+---------+---------+---------+-----------------+
# B:  |VM |OP (6b)    |REG1     |REG2     |IMM (14b)                  |
#     +---+---+-------+---------+---------+---------------------------+
# C:  |VM |1 1|OP (4b)|REG1     |IMM (19b)                            |
#     +---+---+-------+---------+-------------------------------------+
#
# Reserved multi-word encodings for future extensions:
#
#      3             2               1
#     |1| | | | | | |4| | | | | | | |6| | | | | | | |8| | | | | | | |0|
#     +---+-----------+---------+---------+---------+-+---------------+
# A2: |VM |1 1 1 1 1 1|REG1     |REG2     |REG3     |0|OP (8b)        | [31:0]
#     +---+-----+-----+---------+---------+---------+-+---------------+
#     |OP (5b)  |                        (tbd)                        | [63:32]
#     +---+-----+-----+---------+---------+---------+-+---------------+
# B2: |VM |1 1 1 1 1 1|REG1     |REG2     |OP (5b)  |1|OP (8b)        | [31:0]
#     +---+-----------+---------+---------+---------+-+---------------+
#     |IMM (32b)                                                      | [63:32]
#     +---------------------------------------------------------------+
#
# VM:   Vector mode:
#         00 = scalar
#         10 = vector,scalar
#         11 = vector,vector
# OP:   Operation
# REGn: Register (5 bit identifier)
# IMM:  Immediate value

# Supported operand types.
_REG1 = 1
_REG2 = 2
_REG3 = 3
_VREG1 = 4
_VREG2 = 5
_VREG3 = 6
_XREG1 = 7
_XREG2 = 8
_IMM14 = 9       # -8192..8191
_IMM19 = 10      # -262144..262143
_IMM19HI = 11    # 0x00000000..0xffffe000 (in steps of 0x00002000)
_IMM19HIO = 12   # 0x0001ffff..0xffffffff (in steps of 0x00002000)
_PCREL14 = 13    # -8192..8191
_PCREL19x4 = 14  # -1048576..1048572 (in steps of 4)

# Names of general purpose registers.
_REGS = {
        'Z':  0,  # Read-only: Zero
        'FP': 26, # Frame pointer
        'TP': 27, # Thread pointer
        'SP': 28, # Stack pointer
        'VL': 29, # Vector length register
        'LR': 30, # Link register (branch return address)
        'PC': 31, # Read-only: Program counter

        'S0': 0,  # Alias for Z
        'S1': 1,
        'S2': 2,
        'S3': 3,
        'S4': 4,
        'S5': 5,
        'S6': 6,
        'S7': 7,
        'S8': 8,
        'S9': 9,
        'S10': 10,
        'S11': 11,
        'S12': 12,
        'S13': 13,
        'S14': 14,
        'S15': 15,
        'S16': 16,
        'S17': 17,
        'S18': 18,
        'S19': 19,
        'S20': 20,
        'S21': 21,
        'S22': 22,
        'S23': 23,
        'S24': 24,
        'S25': 25,
        'S26': 26,  # Alias for FP
        'S27': 27,  # Alias for TP
        'S28': 28,  # Alias for SP
        'S29': 29,  # Alias for VL
        'S30': 30,  # Alias for LR
        'S31': 31,  # Alias for PC
    }

# Names of vector registers.
_VREGS = {
        'VZ': 0,    # Read only: Zero

        'V0': 0,    # Alias for VZ
        'V1': 1,
        'V2': 2,
        'V3': 3,
        'V4': 4,
        'V5': 5,
        'V6': 6,
        'V7': 7,
        'V8': 8,
        'V9': 9,
        'V10': 10,
        'V11': 11,
        'V12': 12,
        'V13': 13,
        'V14': 14,
        'V15': 15,
        'V16': 16,
        'V17': 17,
        'V18': 18,
        'V19': 19,
        'V20': 20,
        'V21': 21,
        'V22': 22,
        'V23': 23,
        'V24': 24,
        'V25': 25,
        'V26': 26,
        'V27': 27,
        'V28': 28,
        'V29': 29,
        'V30': 30,
        'V31': 31,
    }


# Names of constrol/status/auxiliary registers.
_XREGS = {
        'CCR':  0,  # Cache control register.
    }

# Supported opcodes.
_OPCODES = {
        # ---------------------------------------------------------------------
        # SCALAR OPERATIONS
        # ---------------------------------------------------------------------

        # == A + B ==

        # Retrieve CPU information.
        # Note: Doubles in as NOP (0x00000000 = CPUID Z, Z, Z).
        'CPUID':  [[0x00000000, _REG1, _REG2],
                   [0x00000000, _REG1, _REG2, _REG3]],

        # Load/store.
        'LDB':    [[0x00000001, _REG1, _REG2, _REG3],
                   [0x01000000, _REG1, _REG2, _IMM14],
                   [0x81000000, _VREG1, _REG2, _IMM14]],
        'LDH':    [[0x00000002, _REG1, _REG2, _REG3],
                   [0x02000000, _REG1, _REG2, _IMM14],
                   [0x82000000, _VREG1, _REG2, _IMM14]],
        'LDW':    [[0x00000003, _REG1, _REG2, _REG3],
                   [0x03000000, _REG1, _REG2, _IMM14],
                   [0x83000000, _VREG1, _REG2, _IMM14]],
        'LDUB':   [[0x00000005, _REG1, _REG2, _REG3],
                   [0x05000000, _REG1, _REG2, _IMM14],
                   [0x85000000, _VREG1, _REG2, _IMM14]],
        'LDUH':   [[0x00000006, _REG1, _REG2, _REG3],
                   [0x06000000, _REG1, _REG2, _IMM14],
                   [0x86000000, _VREG1, _REG2, _IMM14]],
        'LDLW':   [[0x00000007, _REG1, _REG2, _REG3],      # Load linked
                   [0x07000000, _REG1, _REG2, _IMM14]],
        'STB':    [[0x00000009, _REG1, _REG2, _REG3],
                   [0x09000000, _REG1, _REG2, _IMM14],
                   [0x89000000, _VREG1, _REG2, _IMM14]],
        'STH':    [[0x0000000a, _REG1, _REG2, _REG3],
                   [0x0a000000, _REG1, _REG2, _IMM14],
                   [0x8a000000, _VREG1, _REG2, _IMM14]],
        'STW':    [[0x0000000b, _REG1, _REG2, _REG3],
                   [0x0b000000, _REG1, _REG2, _IMM14],
                   [0x8b000000, _VREG1, _REG2, _IMM14]],
        'STCW':   [[0x0000000f, _REG1, _REG2, _REG3],      # Store conditional
                   [0x0f000000, _REG1, _REG2, _IMM14]],

        # Integer ALU ops.
        'OR':     [[0x00000010, _REG1, _REG2, _REG3],
                   [0x80000010, _VREG1, _VREG2, _REG3],
                   [0xc0000010, _VREG1, _VREG2, _VREG3],
                   [0x10000000, _REG1, _REG2, _IMM14],
                   [0x90000000, _VREG1, _VREG2, _IMM14]],
        'NOR':    [[0x00000011, _REG1, _REG2, _REG3],
                   [0x80000011, _VREG1, _VREG2, _REG3],
                   [0xc0000011, _VREG1, _VREG2, _VREG3],
                   [0x11000000, _REG1, _REG2, _IMM14],
                   [0x91000000, _VREG1, _VREG2, _IMM14]],
        'AND':    [[0x00000012, _REG1, _REG2, _REG3],
                   [0x80000012, _VREG1, _VREG2, _REG3],
                   [0xc0000012, _VREG1, _VREG2, _VREG3],
                   [0x12000000, _REG1, _REG2, _IMM14],
                   [0x92000000, _VREG1, _VREG2, _IMM14]],
        'BIC':    [[0x00000013, _REG1, _REG2, _REG3],
                   [0x80000013, _VREG1, _VREG2, _REG3],
                   [0xc0000013, _VREG1, _VREG2, _VREG3],
                   [0x13000000, _REG1, _REG2, _IMM14],
                   [0x93000000, _VREG1, _VREG2, _IMM14]],
        'XOR':    [[0x00000014, _REG1, _REG2, _REG3],
                   [0x80000014, _VREG1, _VREG2, _REG3],
                   [0xc0000014, _VREG1, _VREG2, _VREG3],
                   [0x14000000, _REG1, _REG2, _IMM14],
                   [0x94000000, _VREG1, _VREG2, _IMM14]],
        'ADD':    [[0x00000015, _REG1, _REG2, _REG3],
                   [0x80000015, _VREG1, _VREG2, _REG3],
                   [0xc0000015, _VREG1, _VREG2, _VREG3],
                   [0x15000000, _REG1, _REG2, _IMM14],
                   [0x95000000, _VREG1, _VREG2, _IMM14]],
        'SUB':    [[0x00000016, _REG1, _REG3, _REG2],
                   [0x80000016, _VREG1, _REG3, _VREG2],
                   [0xc0000016, _VREG1, _VREG3, _VREG2],
                   [0x16000000, _REG1, _IMM14, _REG2],
                   [0x96000000, _VREG1, _IMM14, _VREG2]],
        'SLT':    [[0x00000017, _REG1, _REG3, _REG2],
                   [0x80000017, _VREG1, _REG3, _VREG2],
                   [0xc0000017, _VREG1, _VREG3, _VREG2],
                   [0x17000000, _REG1, _IMM14, _REG2],
                   [0x97000000, _VREG1, _IMM14, _VREG2]],
        'SLTU':   [[0x00000018, _REG1, _REG3, _REG2],
                   [0x80000018, _VREG1, _REG3, _VREG2],
                   [0xc0000018, _VREG1, _VREG3, _VREG2],
                   [0x18000000, _REG1, _IMM14, _REG2],
                   [0x98000000, _VREG1, _IMM14, _VREG2]],
        'CEQ':    [[0x00000019, _REG1, _REG2, _REG3],
                   [0x80000019, _VREG1, _VREG2, _REG3],
                   [0xc0000019, _VREG1, _VREG2, _VREG3],
                   [0x19000000, _REG1, _REG2, _IMM14],
                   [0x99000000, _VREG1, _VREG2, _IMM14]],
        'CLT':    [[0x0000001a, _REG1, _REG3, _REG2],
                   [0x8000001a, _VREG1, _REG3, _VREG2],
                   [0xc000001a, _VREG1, _VREG3, _VREG2],
                   [0x1a000000, _REG1, _IMM14, _REG2],
                   [0x9a000000, _VREG1, _IMM14, _VREG2]],
        'CLTU':   [[0x0000001b, _REG1, _REG3, _REG2],
                   [0x8000001b, _VREG1, _REG3, _VREG2],
                   [0xc000001b, _VREG1, _VREG3, _VREG2],
                   [0x1b000000, _REG1, _IMM14, _REG2],
                   [0x9b000000, _VREG1, _IMM14, _VREG2]],
        'CLE':    [[0x0000001c, _REG1, _REG3, _REG2],
                   [0x8000001c, _VREG1, _REG3, _VREG2],
                   [0xc000001c, _VREG1, _VREG3, _VREG2],
                   [0x1c000000, _REG1, _IMM14, _REG2],
                   [0x9c000000, _VREG1, _IMM14, _VREG2]],
        'CLEU':   [[0x0000001d, _REG1, _REG3, _REG2],
                   [0x8000001d, _VREG1, _REG3, _VREG2],
                   [0xc000001d, _VREG1, _VREG3, _VREG2],
                   [0x1d000000, _REG1, _IMM14, _REG2],
                   [0x9d000000, _VREG1, _IMM14, _VREG2]],
        'LSR':    [[0x0000001e, _REG1, _REG2, _REG3],
                   [0x8000001e, _VREG1, _VREG2, _REG3],
                   [0xc000001e, _VREG1, _VREG2, _VREG3],
                   [0x1e000000, _REG1, _REG2, _IMM14],
                   [0x9e000000, _VREG1, _VREG2, _IMM14]],
        'ASR':    [[0x0000001f, _REG1, _REG2, _REG3],
                   [0x8000001f, _VREG1, _VREG2, _REG3],
                   [0xc000001f, _VREG1, _VREG2, _VREG3],
                   [0x1f000000, _REG1, _REG2, _IMM14],
                   [0x9f000000, _VREG1, _VREG2, _IMM14]],
        'LSL':    [[0x00000020, _REG1, _REG2, _REG3],
                   [0x80000020, _VREG1, _VREG2, _REG3],
                   [0xc0000020, _VREG1, _VREG2, _VREG3],
                   [0x20000000, _REG1, _REG2, _IMM14],
                   [0xa0000000, _VREG1, _VREG2, _IMM14]],
        'SHUF':   [[0x00000021, _REG1, _REG2, _REG3],
                   [0x80000021, _VREG1, _VREG2, _REG3],
                   [0xc0000021, _VREG1, _VREG2, _VREG3],
                   [0x21000000, _REG1, _REG2, _IMM14],
                   [0xa1000000, _VREG1, _VREG2, _IMM14]],

        # Integer mul/div.
        'MUL':    [[0x00000030, _REG1, _REG2, _REG3],
                   [0x80000030, _VREG1, _VREG2, _REG3],
                   [0xc0000030, _VREG1, _VREG2, _VREG3]],
        # Note: MUL works for both signed and unsigned so no MULU is required.
        'MULHI':  [[0x00000032, _REG1, _REG2, _REG3],
                   [0x80000032, _VREG1, _VREG2, _REG3],
                   [0xc0000032, _VREG1, _VREG2, _VREG3]],
        'MULHIU': [[0x00000033, _REG1, _REG2, _REG3],
                   [0x80000033, _VREG1, _VREG2, _REG3],
                   [0xc0000033, _VREG1, _VREG2, _VREG3]],
        'DIV':    [[0x00000034, _REG1, _REG2, _REG3],
                   [0x80000034, _VREG1, _VREG2, _REG3],
                   [0xc0000034, _VREG1, _VREG2, _VREG3]],
        'DIVU':   [[0x00000035, _REG1, _REG2, _REG3],
                   [0x80000035, _VREG1, _VREG2, _REG3],
                   [0xc0000035, _VREG1, _VREG2, _VREG3]],
        'REM':    [[0x00000036, _REG1, _REG2, _REG3],
                   [0x80000036, _VREG1, _VREG2, _REG3],
                   [0xc0000036, _VREG1, _VREG2, _VREG3]],
        'REMU':   [[0x00000037, _REG1, _REG2, _REG3],
                   [0x80000037, _VREG1, _VREG2, _REG3],
                   [0xc0000037, _VREG1, _VREG2, _VREG3]],

        # FP arithmetic.
        'ITOF':   [[0x00000038, _REG1, _REG2],     # Cast int->float (reg3 = z)
                   [0x80000038, _VREG1, _VREG2]],
        'FTOI':   [[0x00000039, _REG1, _REG2],     # Cast float->int (reg3 = z)
                   [0x80000039, _VREG1, _VREG2]],
        'FADD':   [[0x0000003a, _REG1, _REG2, _REG3],
                   [0x8000003a, _VREG1, _VREG2, _REG3],
                   [0xc000003a, _VREG1, _VREG2, _VREG3]],
        'FSUB':   [[0x0000003b, _REG1, _REG2, _REG3],
                   [0x8000003b, _VREG1, _VREG2, _REG3],
                   [0xc000003b, _VREG1, _VREG2, _VREG3]],
        'FMUL':   [[0x0000003c, _REG1, _REG2, _REG3],
                   [0x8000003c, _VREG1, _VREG2, _REG3],
                   [0xc000003c, _VREG1, _VREG2, _VREG3]],
        'FDIV':   [[0x0000003d, _REG1, _REG2, _REG3],
                   [0x8000003d, _VREG1, _VREG2, _REG3],
                   [0xc000003d, _VREG1, _VREG2, _VREG3]],

        # Bit handling and byte/halfword/word shuffling.
        'SEL':    [[0x00000040, _REG1, _REG2, _REG3],
                   [0x80000040, _VREG1, _VREG2, _REG3],
                   [0xc0000040, _VREG1, _VREG2, _VREG3]],
        'CLZ':    [[0x00000041, _REG1, _REG2],          # 3rd reg is always z
                   [0x80000041, _VREG1, _VREG2]],
        'REV':    [[0x00000042, _REG1, _REG2],          # 3rd reg is always z
                   [0x80000042, _VREG1, _VREG2]],
        'EXTB':   [[0x00000043, _REG1, _REG2],          # 3rd reg is always z
                   [0x80000043, _VREG1, _VREG2]],
        'EXTH':   [[0x00000044, _REG1, _REG2],          # 3rd reg is always z
                   [0x80000044, _VREG1, _VREG2]],

        # Special move/load/store instructions.
        'MSX':    [[0x00000050, _XREG1, _REG2]],         # Move scalar->auxiliary (reg3 = z)
        'MXS':    [[0x00000051, _REG1, _XREG2]],         # Move auxiliary->scalar (reg3 = z)
        'MSV':    [[0x00000052, _VREG1, _REG2, _REG3]],  # Move scalar->vector element
        'MVS':    [[0x00000053, _REG1, _VREG2, _REG3]],  # Move vector element->scalar

        # Jump to register address.
        'J':      [[0x00000080, _REG1]],           # 2nd & 3rd regs are always z
        'JL':     [[0x00000081, _REG1]],           # 2nd & 3rd regs are always z


        # == C ==

        # Branch ops.
        'BEQ':    [[0x30000000, _REG1, _PCREL19x4]],
        'BNE':    [[0x31000000, _REG1, _PCREL19x4]],
        'BGE':    [[0x32000000, _REG1, _PCREL19x4]],
        'BGT':    [[0x33000000, _REG1, _PCREL19x4]],
        'BLE':    [[0x34000000, _REG1, _PCREL19x4]],
        'BLT':    [[0x35000000, _REG1, _PCREL19x4]],

        'BLEQ':   [[0x38000000, _REG1, _PCREL19x4]],
        'BLNE':   [[0x39000000, _REG1, _PCREL19x4]],
        'BLGE':   [[0x3a000000, _REG1, _PCREL19x4]],
        'BLGT':   [[0x3b000000, _REG1, _PCREL19x4]],
        'BLLE':   [[0x3c000000, _REG1, _PCREL19x4]],
        'BLLT':   [[0x3d000000, _REG1, _PCREL19x4]],

        # Load immediate.
        'LDHI':   [[0x36000000, _REG1, _IMM19HI],
                   [0xb6000000, _VREG1, _IMM19HI]],
        'LDHIO':  [[0x37000000, _REG1, _IMM19HIO],
                   [0xb7000000, _VREG1, _IMM19HIO]],
        'LDI':    [[0x3e000000, _REG1, _IMM19],
                   [0xbe000000, _VREG1, _IMM19]],


        # ---------------------------------------------------------------------
        # === ALIASES ===
        # ---------------------------------------------------------------------

        # CPUID Z, Z, Z
        'NOP':    [[0x00000000]],

        # Alias for: OR _REG1, _REG2, Z
        'MOV':    [[0x00000010, _REG1, _REG2],
                   [0x80000010, _VREG1, _REG2],
                   [0xc0000010, _VREG1, _VREG2]],

        # Alias for: BEQ Z, _PCREL19x4
        'B':      [[0x30000000, _PCREL19x4]],

        # Alias for: BLEQ Z, _PCREL19x4
        'BL':     [[0x38000000, _PCREL19x4]],

        # Alias for: ADD _REG1, PC, offset
        'LEA':    [[0x1507c000, _REG1, _PCREL14]],

        # Load/store pc-relative (alias for: LD?/ST? _REG1, pc, offset).
        'LDPCB':  [[0x0107c000, _REG1, _PCREL14]],
        'LDPCH':  [[0x0207c000, _REG1, _PCREL14]],
        'LDPCW':  [[0x0307c000, _REG1, _PCREL14]],
        'LDPCUB': [[0x0507c000, _REG1, _PCREL14]],
        'LDPCUH': [[0x0607c000, _REG1, _PCREL14]],
        'STPCB':  [[0x0907c000, _REG1, _PCREL14]],
        'STPCH':  [[0x0a07c000, _REG1, _PCREL14]],
        'STPCW':  [[0x0b07c000, _REG1, _PCREL14]],
    }


class AsmError(Exception):
    def __init__(self, line_no, msg):
        self.line_no = line_no
        self.msg = msg


def parse_integer(s):
    # This supports decimal ('123'), hexadecimal ('0x123') and binary ('0b101').
    value = int(s, 0)
    return value


def extract_parts(line):
    parts = line.split()
    result = [parts[0]]
    for part in parts[1:]:
        result += [a for a in part.split(',') if a]
    return result


def translate_reg(operand, operand_type, line_no):
    if operand_type in [_REG1, _REG2, _REG3]:
        try:
            reg_no = _REGS[operand.upper()]
        except KeyError as e:
            raise AsmError(line_no, 'Bad register: {}'.format(operand))
        shift = 19 if operand_type == _REG1 else (14 if operand_type == _REG2 else 9)
        return reg_no << shift
    elif operand_type in [_VREG1, _VREG2, _VREG3]:
        try:
            reg_no = _VREGS[operand.upper()]
        except KeyError as e:
            raise AsmError(line_no, 'Bad vector register: {}'.format(operand))
        shift = 19 if operand_type == _VREG1 else (14 if operand_type == _VREG2 else 9)
        return reg_no << shift
    elif operand_type in [_XREG1, _XREG2]:
        try:
            reg_no = _XREGS[operand.upper()]
        except KeyError as e:
            raise AsmError(line_no, 'Bad control register: {}'.format(operand))
        shift = 19 if operand_type == _XREG1 else 14
        return reg_no << shift
    else:
        # Internal error.
        raise AsmError(line_no, 'Bad register type: {}'.format(operand_type))


def translate_imm(operand, operand_type, line_no):
    try:
        value = parse_integer(operand)
    except ValueError:
        raise AsmError(line_no, 'Invalid integer value: {}'.format(operand))

    value_bits = {
            _IMM14:    14,
            _IMM19:    19,
            _IMM19HI:  19,
            _IMM19HIO: 19,
        }[operand_type]
    value_shift = {
            _IMM14:    0,
            _IMM19:    0,
            _IMM19HI:  13,
            _IMM19HIO: 13,
        }[operand_type]
    value_min = {
            _IMM14:    -(1 << 13),
            _IMM19:    -(1 << 18),
            _IMM19HI:  0x00000000,
            _IMM19HIO: 0x00001fff,
        }[operand_type]
    value_max = {
            _IMM14:    (1 << 13) - 1,
            _IMM19:    (1 << 18) - 1,
            _IMM19HI:  0xffffe000,
            _IMM19HIO: 0xffffffff,
        }[operand_type]
    if value < value_min or value > value_max:
        raise AsmError(line_no, 'Immediate value out of range ({}..{}): {}'.format(value_min, value_max, operand))
    if operand_type == _IMM19HI and (value & 0x00001fff) != 0:
        raise AsmError(line_no, 'Immediate value must have the lower 13 bits cleared: {}'.format(operand))
    if operand_type == _IMM19HIO and (value & 0x00001fff) != 0x00001fff:
        raise AsmError(line_no, 'Immediate value must have the lower 13 bits set: {}'.format(operand))

    return (value >> value_shift) & ((1 << value_bits) - 1)


def mangle_local_label(label, scope_label):
    return '{}@{}'.format(scope_label, label[1:])


def translate_pcrel(operand, operand_type, pc, labels, scope_label, line_no):
    # TODO(m): Add support for numerical offsets and relative +/- deltas.
    try:
        if operand.startswith('.'):
            if not scope_label:
                raise AsmError(line_no, 'No scope for local label: {}'.format(operand))
            operand = mangle_local_label(operand, scope_label)
        target_address = labels[operand]
    except KeyError as e:
        raise AsmError(line_no, 'Bad label: {}'.format(operand))

    offset = target_address - pc

    if operand_type == _PCREL19x4:
        if (target_address & 3) != 0:
            raise AsmError(line_no, 'Targe address ({}) is not aligned to 4 bytes'.format(operand))
        offset = offset / 4

    offset_max = {
            _PCREL14:   1 << 13,
            _PCREL19x4: 1 << 18,
        }[operand_type]
    if (offset < -offset_max or offset >= offset_max):
        raise AsmError(line_no, 'Too large offset: {}'.format(offset))

    return offset & (offset_max * 2 - 1)


def translate_operation(operation, mnemonic, descr, addr, line_no, labels, scope_label):
    if len(operation) != len(descr):
        raise AsmError(line_no, 'Expected {} arguments for {}'.format(len(descr) - 1, mnemonic))
    instr = descr[0]
    for k in range(1, len(descr)):
        operand = operation[k]
        operand_type = descr[k]
        if operand_type in [_REG1, _REG2, _REG3, _VREG1, _VREG2, _VREG3, _XREG1, _XREG2]:
            instr = instr | translate_reg(operand, operand_type, line_no)
        elif operand_type in [_IMM14, _IMM19, _IMM19HI, _IMM19HIO]:
            instr = instr | translate_imm(operand, operand_type, line_no)
        elif operand_type in [_PCREL14, _PCREL19x4]:
            instr = instr | translate_pcrel(operand, operand_type, addr, labels, scope_label, line_no)

    return instr


def read_file(file_name):
    with open(file_name, "r") as f:
        lines = f.readlines()
    return lines


def preprocess(lines, file_dir):
    result = []
    for line in lines:
        l = line.strip()
        if l.startswith('.include'):
            include_file_name = os.path.join(file_dir, l[8:].strip().replace('"', ''))
            include_lines = read_file(include_file_name)
            include_dir = os.path.dirname(include_file_name)
            result.extend(preprocess(include_lines, include_dir))
        else:
            result.append(l)

    return result


def compile_file(file_name, out_name, verbosity_level):
    if verbosity_level >= 1:
        print "Compiling %s..." % (file_name)
    success = True
    labels = {}
    code = ''
    try:
        # Read the file, and preprocess-it.
        file_dir = os.path.dirname(file_name)
        lines = read_file(file_name)
        lines = preprocess(lines, file_dir)

        for compilation_pass in [1, 2]:
            if verbosity_level >= 1:
                print 'Pass %d' % (compilation_pass)

            # Set the default start address.
            addr = 0x200  # The reset PC address = 0x200.

            # Clear the scope for local labels.
            scope_label = ''

            # Emit start address.
            # TODO(m): Allow for dynamic address definitions (e.g. .addr).
            if compilation_pass == 2:
                code += struct.pack('<L', addr)

            for line_no, raw_line in enumerate(lines, 1):
                line = raw_line

                # Remove comment.
                comment_pos = line.find(';')
                comment_pos2 = line.find('#')
                if comment_pos2 >= 0 and (comment_pos2 < comment_pos or comment_pos < 0):
                    comment_pos = comment_pos2
                comment_pos2 = line.find('//')
                if comment_pos2 >= 0 and (comment_pos2 < comment_pos or comment_pos < 0):
                    comment_pos = comment_pos2
                if comment_pos >= 0:
                    line = line[:comment_pos]

                # Strip head and tail whitespaces.
                line = line.strip()

                if len(line) == 0:
                    # This is an empty line.
                    pass

                elif line.endswith(':'):
                    # This is a label.
                    label = line[:-1]
                    if ' ' in label or '@' in label:
                        raise AsmError(line_no, 'Bad label "%s"' % label)
                    if label.startswith('.'):
                        # This is a local label - make it global.
                        if not scope_label:
                            raise AsmError(line_no, 'No scope for local label: {}'.format(label))
                        label = mangle_local_label(label, scope_label)
                    else:
                        # This is a global label - use it as the scope label.
                        scope_label = label
                    if compilation_pass == 1:
                        if label in labels:
                            raise AsmError(line_no, 'Re-definition of label: {}'.format(label))
                        labels[label] = addr
                        if verbosity_level >= 2:
                            print ' Label: ' + format(addr, '08x') + ' = {}'.format(label)

                elif line.startswith('.'):
                    # This is a data directive.
                    directive = extract_parts(line)

                    if directive[0] == '.align':
                        try:
                            value = parse_integer(directive[1])
                        except ValueError:
                            raise AsmError(line_no, 'Invalid alignment: {}'.format(directive[1]))
                        if not value in [1, 2, 4, 8, 16]:
                            raise AsmError(line_no, 'Invalid alignment: {} (must be 1, 2, 4, 8 or 16)'.format(value))
                        addr_adjust = addr % value
                        if addr_adjust > 0:
                            num_pad_bytes = value - addr_adjust
                            if compilation_pass == 2:
                                for k in range(num_pad_bytes):
                                    code += struct.pack('B', 0)
                            addr += num_pad_bytes
                            if verbosity_level >= 2:
                                print 'Aligned pc to: {} (padded by {} bytes)'.format(addr, num_pad_bytes)

                    elif directive[0] in ['.i8', '.u8', '.i16', '.u16', '.i32', '.u32']:
                        num_bits = parse_integer(directive[0][2:])
                        is_unsigned = (directive[0][1] == 'u')
                        val_min = 0 if is_unsigned else -(1 << (num_bits - 1))
                        val_max = ((1 << num_bits) - 1) if is_unsigned else ((1 << (num_bits - 1)) - 1)
                        val_size = num_bits >> 3
                        val_type = {
                          '.i8': 'b',
                          '.u8': 'B',
                          '.i16': '<h',
                          '.u16': '<H',
                          '.i32': '<l',
                          '.u32': '<L'
                        }[directive[0]];
                        for k in range(1, len(directive)):
                            try:
                                value = parse_integer(directive[k])
                            except ValueError:
                                raise AsmError(line_no, 'Invalid integer: {}'.format(directive[k]))
                            if not addr & (val_size - 1) == 0:
                                raise AsmError(line_no, 'Data not aligned to a {} byte boundary'.format(val_size))
                            if value < val_min or value > val_max:
                                raise AsmError(line_no, 'Value out of range: {}'.format(value))
                            addr += val_size
                            if compilation_pass == 2:
                                code += struct.pack(val_type, value)

                    elif directive[0] in ['.space', '.zero']:
                        if len(directive) != 2:
                            raise AsmError(line_no, 'Invalid usage of {}'.format(directive[0]))
                        try:
                            size = parse_integer(directive[1])
                        except ValueError:
                            raise AsmError(line_no, 'Invalid size: {}'.format(directive[1]))
                        addr += size
                        if compilation_pass == 2:
                            for k in range(0, size):
                                code += struct.pack('b', 0)

                    elif directive[0] in ['.ascii', '.asciz']:
                        raw_text = line[6:].strip()
                        first_quote = raw_text.find('"')
                        last_quote = raw_text.rfind('"')
                        if (first_quote < 0) or (last_quote != (len(raw_text) - 1)) or (last_quote == first_quote):
                            raise AsmError(line_no, 'Invalid string: {}'.format(raw_text))
                        text = raw_text[(first_quote + 1):last_quote]
                        k = 0
                        while k < len(text):
                            char = text[k]
                            k += 1
                            if char == '\\':
                                if k == len(text):
                                    raise AsmError(line_no, 'Premature end of string: {}'.format(raw_text))
                                control_char = text[k]
                                k += 1
                                if control_char.isdigit():
                                    char_code = parse_integer(control_char)
                                else:
                                    try:
                                        char_code = {
                                            't': 9,
                                            'n': 10,
                                            'r': 13,
                                            '\\': 92,
                                            '"': 34
                                        }[control_char]
                                    except KeyError as e:
                                        raise AsmError(line_no, 'Bad control character: \\{}'.format(control_char))
                            else:
                                char_code = ord(char)
                            addr += 1
                            if compilation_pass == 2:
                                code += struct.pack('B', char_code)

                        if directive[0] == '.asciz':
                            # .asciz => zero terminated string.
                            addr += 1
                            if compilation_pass == 2:
                                code += struct.pack('B', 0)

                    else:
                        raise AsmError(line_no, 'Unknown directive: {}'.format(directive[0]))

                else:
                    # This is a machine code instruction.
                    operation = extract_parts(line)
                    mnemonic = operation[0].upper()
                    try:
                        descrs = _OPCODES[mnemonic]
                    except KeyError as e:
                        raise AsmError(line_no, 'Bad mnemonic: {}'.format(mnemonic))
                    if compilation_pass == 2:
                        errors = []
                        translation_successful = False
                        for descr in descrs:
                            try:
                                instr = translate_operation(operation, mnemonic, descr, addr, line_no, labels, scope_label)
                                translation_successful = True
                                break
                            except AsmError as e:
                                errors.append(e.msg)
                        if not translation_successful:
                            # TODO(m): Show the individual errors (overload candidates).
                            msg = 'Invalid operands for {}: {}'.format(mnemonic, ','.join(operation[1:]))
                            for e in errors:
                                msg += '\n  Candidate: {}'.format(e)
                            raise AsmError(line_no, msg)
                        if verbosity_level >= 2:
                            print format(addr, '08x') + ': ' + format(instr, '08x') + ' <= ' + '{}'.format(operation)
                        code += struct.pack('<L', instr)
                    addr += 4

        with open(out_name, 'w') as f:
            f.write(code)

    except AsmError as e:
        print '%s:%d: ERROR: %s' % (file_name, e.line_no, e.msg)
        success = False

    return success


def main():
    # Parse command line arguments.
    parser = argparse.ArgumentParser(description='A simple assembler for MRISC32')
    parser.add_argument('files', metavar='FILE', nargs='+',
                        help='the file(s) to process')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='be verbose')
    parser.add_argument('-vv', '--extra-verbose', action='store_true',
                        help='be extra verbose')
    args = parser.parse_args()

    # Select verbosity level.
    verbosity_level = 0
    if args.verbose:
        verbosity_level = 1
    elif args.extra_verbose:
        verbosity_level = 2

    for file_name in args.files:
        out_name = base = os.path.splitext(file_name)[0] + '.bin'
        if not compile_file(file_name, out_name, verbosity_level):
            sys.exit(1)


if __name__ == "__main__":
    main()

