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
#
#      3             2               1
#     |1| | | | | | |4| | | | | | | |6| | | | | | | |8| | | | | | | |0|
#     +-----------+---------+---------+---+---------+---+-------------+
# A:  |0 0 0 0 0 0|REG1     |REG2     |VM |REG3     |PM | OP (7b)     |
#     +-----------+---------+---------+-+-+---------+---+-------------+
# B:  |OP (6b)    |REG1     |REG2     |V|IMM (15b)                    |
#     +---+-------+---------+---------+-+-----------------------------+
# C:  |1 1|OP (4b)|REG1     |IMM (21b)                                |
#     +---+-------+---------+-----------------------------------------+
#
# The format of the instruction is determined by the 6 most significant bits:
#   000000:         Format A (128 instructions)
#   000001..101111: Format B (47 instructions)
#   110000..111110: Format C (15 instructions)
#   111111:         (Reserved for future multi-word encodings)
#
# OP:   Operation
# REGn: Register (5 bit identifier)
# IMM:  Immediate value
#
# VM: Vector mode (2-bit):
#   00: scalar <= op(scalar,scalar)
#   10: vector <= op(vector,scalar)
#   11: vector <= op(vector,vector)
#   01: vector <= op(vector,fold(vector))
#
# V: Vector mode (1-bit):
#    0: scalar <= op(scalar,scalar)
#    1: vector <= op(vector,scalar)
#
# PM: Packed mode:
#   00: None (1 x 32 bits)
#   01: Byte (4 x 8 bits)
#   10: Half-word (2 x 16 bits)
#   11: (reserved)
#
# Possible multi-word encoding:
#
#      3             2               1
#     |1| | | | | | |4| | | | | | | |6| | | | | | | |8| | | | | | | |0|
#     +-----------+---------+---------+---+---------+---+-------------+
# X:  |1 1 1 1 1 1|REG1     |REG2     |VM |REG3     |PM | OP (7b)     | [31:0]
#     +-----------+---------+---------+---+---------+---+-------------+
#     |                             (tbd)                             | [63:32]
#     +---------------------------------------------------------------+

# Supported operand types.
_REG1 = 1
_REG2 = 2
_REG3 = 3
_VREG1 = 4
_VREG2 = 5
_VREG3 = 6
_XREG1 = 7
_XREG2 = 8
_IMM15 = 9       # -16384..16383
_IMM21 = 10      # -1048576..1048575
_IMM21HI = 11    # 0x00000000..0xfffff800 (in steps of 0x00000800)
_IMM21HIO = 12   # 0x000007ff..0xffffffff (in steps of 0x00000800)
_PCREL15 = 13    # -16384..16383
_PCREL21x4 = 14  # -4194304..4194303 (in steps of 4)

# Supported packed operation types.
_PACKED_NONE = 0
_PACKED_BYTE = 1
_PACKED_HALF_WORD = 2

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
        # == A + B ==

        # Retrieve CPU information.
        # Note: Doubles in as NOP (0x00000000 = CPUID Z, Z, Z).
        'CPUID':  {'descrs':
                    [[0x00000000, _REG1, _REG2],
                     [0x00000000, _REG1, _REG2, _REG3]],
                   'packed_op': False
                  },

        # Load/store.
        'LDB':    {'descrs':
                    [[0x00000001, _REG1, _REG2, _REG3],
                     [0x00008001, _VREG1, _REG2, _REG3],
                     [0x0000c001, _VREG1, _REG2, _VREG3],
                     [0x04000000, _REG1, _REG2, _IMM15],
                     [0x041f0000, _REG1, _PCREL15],        # Alias for _REG1, PC, offset
                     [0x04008000, _VREG1, _REG2, _IMM15]],
                   'packed_op': False
                  },
        'LDH':    {'descrs':
                    [[0x00000002, _REG1, _REG2, _REG3],
                     [0x00008002, _VREG1, _REG2, _REG3],
                     [0x0000c002, _VREG1, _REG2, _VREG3],
                     [0x08000000, _REG1, _REG2, _IMM15],
                     [0x081f0000, _REG1, _PCREL15],        # Alias for _REG1, PC, offset
                     [0x08008000, _VREG1, _REG2, _IMM15]],
                   'packed_op': False
                  },
        'LDW':    {'descrs':
                    [[0x00000003, _REG1, _REG2, _REG3],
                     [0x00008003, _VREG1, _REG2, _REG3],
                     [0x0000c003, _VREG1, _REG2, _VREG3],
                     [0x0c000000, _REG1, _REG2, _IMM15],
                     [0x0c1f0000, _REG1, _PCREL15],        # Alias for _REG1, PC, offset
                     [0x0c008000, _VREG1, _REG2, _IMM15]],
                   'packed_op': False
                  },
        'LDUB':   {'descrs':
                    [[0x00000005, _REG1, _REG2, _REG3],
                     [0x00008005, _VREG1, _REG2, _REG3],
                     [0x0000c005, _VREG1, _REG2, _VREG3],
                     [0x14000000, _REG1, _REG2, _IMM15],
                     [0x141f0000, _REG1, _PCREL15],        # Alias for _REG1, PC, offset
                     [0x14008000, _VREG1, _REG2, _IMM15]],
                   'packed_op': False
                  },
        'LDUH':   {'descrs':
                    [[0x00000006, _REG1, _REG2, _REG3],
                     [0x00008006, _VREG1, _REG2, _REG3],
                     [0x0000c006, _VREG1, _REG2, _VREG3],
                     [0x18000000, _REG1, _REG2, _IMM15],
                     [0x181f0000, _REG1, _PCREL15],        # Alias for _REG1, PC, offset
                     [0x18008000, _VREG1, _REG2, _IMM15]],
                   'packed_op': False
                  },
        'LDSTRD': {'descrs':
                    [[0x00008007, _VREG1, _REG2, _REG3],
                     [0x1c008000, _VREG1, _REG2, _IMM15]],
                   'packed_op': False
                  },
        'STB':    {'descrs':
                    [[0x00000009, _REG1, _REG2, _REG3],
                     [0x00008009, _VREG1, _REG2, _REG3],
                     [0x0000c009, _VREG1, _REG2, _VREG3],
                     [0x24000000, _REG1, _REG2, _IMM15],
                     [0x241f0000, _REG1, _PCREL15],        # Alias for _REG1, PC, offset
                     [0x24008000, _VREG1, _REG2, _IMM15]],
                   'packed_op': False
                  },
        'STH':    {'descrs':
                    [[0x0000000a, _REG1, _REG2, _REG3],
                     [0x0000800a, _VREG1, _REG2, _REG3],
                     [0x0000c00a, _VREG1, _REG2, _VREG3],
                     [0x28000000, _REG1, _REG2, _IMM15],
                     [0x281f0000, _REG1, _PCREL15],        # Alias for _REG1, PC, offset
                     [0x28008000, _VREG1, _REG2, _IMM15]],
                   'packed_op': False
                  },
        'STW':    {'descrs':
                    [[0x0000000b, _REG1, _REG2, _REG3],
                     [0x0000800b, _VREG1, _REG2, _REG3],
                     [0x0000c00b, _VREG1, _REG2, _VREG3],
                     [0x2c000000, _REG1, _REG2, _IMM15],
                     [0x2c1f0000, _REG1, _PCREL15],        # Alias for _REG1, PC, offset
                     [0x2c008000, _VREG1, _REG2, _IMM15]],
                   'packed_op': False
                  },

        # Integer ALU ops.
        'OR':     {'descrs':
                    [[0x00000010, _REG1, _REG2, _REG3],
                     [0x00008010, _VREG1, _VREG2, _REG3],
                     [0x0000c010, _VREG1, _VREG2, _VREG3],
                     [0x40000000, _REG1, _REG2, _IMM15],
                     [0x40008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': False
                  },
        'NOR':    {'descrs':
                    [[0x00000011, _REG1, _REG2, _REG3],
                     [0x00008011, _VREG1, _VREG2, _REG3],
                     [0x0000c011, _VREG1, _VREG2, _VREG3],
                     [0x44000000, _REG1, _REG2, _IMM15],
                     [0x44008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': False
                  },
        'AND':    {'descrs':
                    [[0x00000012, _REG1, _REG2, _REG3],
                     [0x00008012, _VREG1, _VREG2, _REG3],
                     [0x0000c012, _VREG1, _VREG2, _VREG3],
                     [0x48000000, _REG1, _REG2, _IMM15],
                     [0x48008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': False
                  },
        'BIC':    {'descrs':
                    [[0x00000013, _REG1, _REG2, _REG3],
                     [0x00008013, _VREG1, _VREG2, _REG3],
                     [0x0000c013, _VREG1, _VREG2, _VREG3],
                     [0x4c000000, _REG1, _REG2, _IMM15],
                     [0x4c008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': False
                  },
        'XOR':    {'descrs':
                    [[0x00000014, _REG1, _REG2, _REG3],
                     [0x00008014, _VREG1, _VREG2, _REG3],
                     [0x0000c014, _VREG1, _VREG2, _VREG3],
                     [0x50000000, _REG1, _REG2, _IMM15],
                     [0x50008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': False
                  },
        'ADD':    {'descrs':
                    [[0x00000015, _REG1, _REG2, _REG3],
                     [0x00008015, _VREG1, _VREG2, _REG3],
                     [0x0000c015, _VREG1, _VREG2, _VREG3],
                     [0x54000000, _REG1, _REG2, _IMM15],
                     [0x54008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'SUB':    {'descrs':
                    [[0x00000016, _REG1, _REG3, _REG2],
                     [0x00008016, _VREG1, _REG3, _VREG2],
                     [0x0000c016, _VREG1, _VREG3, _VREG2],
                     [0x58000000, _REG1, _IMM15, _REG2],
                     [0x58008000, _VREG1, _IMM15, _VREG2]],
                   'packed_op': True
                  },

        'SEQ':    {'descrs':
                    [[0x00000017, _REG1, _REG2, _REG3],
                     [0x00008017, _VREG1, _VREG2, _REG3],
                     [0x0000c017, _VREG1, _VREG2, _VREG3],
                     [0x5c000000, _REG1, _REG2, _IMM15],
                     [0x5c008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'SNE':    {'descrs':
                    [[0x00000018, _REG1, _REG2, _REG3],
                     [0x00008018, _VREG1, _VREG2, _REG3],
                     [0x0000c018, _VREG1, _VREG2, _VREG3],
                     [0x60000000, _REG1, _REG2, _IMM15],
                     [0x60008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'SLT':    {'descrs':
                    [[0x00000019, _REG1, _REG3, _REG2],
                     [0x00008019, _VREG1, _REG3, _VREG2],
                     [0x0000c019, _VREG1, _VREG3, _VREG2],
                     [0x64000000, _REG1, _REG2, _IMM15],
                     [0x64008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'SLTU':   {'descrs':
                    [[0x0000001a, _REG1, _REG3, _REG2],
                     [0x0000801a, _VREG1, _REG3, _VREG2],
                     [0x0000c01a, _VREG1, _VREG3, _VREG2],
                     [0x68000000, _REG1, _REG2, _IMM15],
                     [0x68008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'SLE':    {'descrs':
                    [[0x0000001b, _REG1, _REG3, _REG2],
                     [0x0000801b, _VREG1, _REG3, _VREG2],
                     [0x0000c01b, _VREG1, _VREG3, _VREG2],
                     [0x6c000000, _REG1, _REG2, _IMM15],
                     [0x6c008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'SLEU':   {'descrs':
                    [[0x0000001c, _REG1, _REG3, _REG2],
                     [0x0000801c, _VREG1, _REG3, _VREG2],
                     [0x0000c01c, _VREG1, _VREG3, _VREG2],
                     [0x70000000, _REG1, _REG2, _IMM15],
                     [0x70008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'MIN':    {'descrs':
                    [[0x0000001d, _REG1, _REG2, _REG3],
                     [0x0000801d, _VREG1, _VREG2, _REG3],
                     [0x0000c01d, _VREG1, _VREG2, _VREG3],
                     [0x74000000, _REG1, _REG2, _IMM15],
                     [0x74008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'MAX':    {'descrs':
                    [[0x0000001e, _REG1, _REG2, _REG3],
                     [0x0000801e, _VREG1, _VREG2, _REG3],
                     [0x0000c01e, _VREG1, _VREG2, _VREG3],
                     [0x78000000, _REG1, _REG2, _IMM15],
                     [0x78008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'MINU':   {'descrs':
                    [[0x0000001f, _REG1, _REG2, _REG3],
                     [0x0000801f, _VREG1, _VREG2, _REG3],
                     [0x0000c01f, _VREG1, _VREG2, _VREG3],
                     [0x7c000000, _REG1, _REG2, _IMM15],
                     [0x7c008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'MAXU':   {'descrs':
                    [[0x00000020, _REG1, _REG2, _REG3],
                     [0x00008020, _VREG1, _VREG2, _REG3],
                     [0x0000c020, _VREG1, _VREG2, _VREG3],
                     [0x80000000, _REG1, _REG2, _IMM15],
                     [0x80008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },

        'ASR':    {'descrs':
                    [[0x00000021, _REG1, _REG2, _REG3],
                     [0x00008021, _VREG1, _VREG2, _REG3],
                     [0x0000c021, _VREG1, _VREG2, _VREG3],
                     [0x84000000, _REG1, _REG2, _IMM15],
                     [0x84008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'LSL':    {'descrs':
                    [[0x00000022, _REG1, _REG2, _REG3],
                     [0x00008022, _VREG1, _VREG2, _REG3],
                     [0x0000c022, _VREG1, _VREG2, _VREG3],
                     [0x88000000, _REG1, _REG2, _IMM15],
                     [0x88008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'LSR':    {'descrs':
                    [[0x00000023, _REG1, _REG2, _REG3],
                     [0x00008023, _VREG1, _VREG2, _REG3],
                     [0x0000c023, _VREG1, _VREG2, _VREG3],
                     [0x8c000000, _REG1, _REG2, _IMM15],
                     [0x8c008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': True
                  },
        'SHUF':   {'descrs':
                    [[0x00000024, _REG1, _REG2, _REG3],
                     [0x00008024, _VREG1, _VREG2, _REG3],
                     [0x0000c024, _VREG1, _VREG2, _VREG3],
                     [0x90000000, _REG1, _REG2, _IMM15],
                     [0x90008000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': False
                  },

        # Get a vector register element.
        # NOTE: The interpretation of the vector mode bits is non standard!
        'GETE':  {'descrs':
                    [[0x28000000, _REG1, _VREG2, _IMM15],
                     [0xa8000000, _VREG1, _VREG2, _IMM15]],
                   'packed_op': False
                  },


        # Bit/byte/half-word handling.
        # Note: These op-codes are put in the 0x31+ range since they are not
        # very useful with immediate operands (to leave space for new immediate
        # type instructions).
        'CLZ':    {'descrs':
                    [[0x00000031, _REG1, _REG2],          # 3rd reg is always z
                     [0x00008031, _VREG1, _VREG2]],
                   'packed_op': False
                  },
        'REV':    {'descrs':
                    [[0x00000032, _REG1, _REG2],          # 3rd reg is always z
                     [0x00008032, _VREG1, _VREG2]],
                   'packed_op': False
                  },
        'PACKB':  {'descrs':
                    [[0x00000033, _REG1, _REG2, _REG3],
                     [0x00008033, _VREG1, _VREG2, _REG3],
                     [0x0000c033, _VREG1, _VREG2, _VREG3]],
                   'packed_op': False
                  },
        'PACKH':  {'descrs':
                    [[0x00000034, _REG1, _REG2, _REG3],
                     [0x00008034, _VREG1, _VREG2, _REG3],
                     [0x0000c034, _VREG1, _VREG2, _VREG3]],
                   'packed_op': False
                  },

        # Query the vector register mask.
        # NOTE: The interpretation of the vector mode bits is non standard!
        'GETM':   {'descrs':
                    [[0x0000c035, _REG1, _VREG2, _VREG3]],
                   'packed_op': False
                  },

        # DSP style saturating and halving arithmetic.
        'ADDS':   {'descrs':
                    [[0x00000038, _REG1, _REG2, _REG3],
                     [0x00008038, _VREG1, _VREG2, _REG3],
                     [0x0000c038, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'ADDSU':  {'descrs':
                    [[0x00000039, _REG1, _REG2, _REG3],
                     [0x00008039, _VREG1, _VREG2, _REG3],
                     [0x0000c039, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'ADDH':   {'descrs':
                    [[0x0000003a, _REG1, _REG2, _REG3],
                     [0x0000803a, _VREG1, _VREG2, _REG3],
                     [0x0000c03a, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'ADDHU':  {'descrs':
                    [[0x0000003b, _REG1, _REG2, _REG3],
                     [0x0000803b, _VREG1, _VREG2, _REG3],
                     [0x0000c03b, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'SUBS':   {'descrs':
                    [[0x0000003c, _REG1, _REG2, _REG3],
                     [0x0000803c, _VREG1, _VREG2, _REG3],
                     [0x0000c03c, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'SUBSU':  {'descrs':
                    [[0x0000003d, _REG1, _REG2, _REG3],
                     [0x0000803d, _VREG1, _VREG2, _REG3],
                     [0x0000c03d, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'SUBH':   {'descrs':
                    [[0x0000003e, _REG1, _REG2, _REG3],
                     [0x0000803e, _VREG1, _VREG2, _REG3],
                     [0x0000c03e, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'SUBHU':  {'descrs':
                    [[0x0000003f, _REG1, _REG2, _REG3],
                     [0x0000803f, _VREG1, _VREG2, _REG3],
                     [0x0000c03f, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },

        # Multiplication operations.
        'MULQ':   {'descrs':
                    [[0x00000040, _REG1, _REG2, _REG3],
                     [0x00008040, _VREG1, _VREG2, _REG3],
                     [0x0000c040, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'MUL':    {'descrs':
                    [[0x00000041, _REG1, _REG2, _REG3],
                     [0x00008041, _VREG1, _VREG2, _REG3],
                     [0x0000c041, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'MULHI':  {'descrs':
                    [[0x00000042, _REG1, _REG2, _REG3],
                     [0x00008042, _VREG1, _VREG2, _REG3],
                     [0x0000c042, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'MULHIU': {'descrs':
                    [[0x00000043, _REG1, _REG2, _REG3],
                     [0x00008043, _VREG1, _VREG2, _REG3],
                     [0x0000c043, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },

        # Division operations.
        'DIV':    {'descrs':
                    [[0x00000044, _REG1, _REG2, _REG3],
                     [0x00008044, _VREG1, _VREG2, _REG3],
                     [0x0000c044, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'DIVU':   {'descrs':
                    [[0x00000045, _REG1, _REG2, _REG3],
                     [0x00008045, _VREG1, _VREG2, _REG3],
                     [0x0000c045, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'REM':    {'descrs':
                    [[0x00000046, _REG1, _REG2, _REG3],
                     [0x00008046, _VREG1, _VREG2, _REG3],
                     [0x0000c046, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'REMU':   {'descrs':
                    [[0x00000047, _REG1, _REG2, _REG3],
                     [0x00008047, _VREG1, _VREG2, _REG3],
                     [0x0000c047, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },

        # FP arithmetic.
        'ITOF':   {'descrs':
                    [[0x00000050, _REG1, _REG2],            # REG3 = Z (no exponent offset)
                     [0x00000050, _REG1, _REG2, _REG3],
                     [0x00008050, _VREG1, _VREG2],          # REG3 = Z (no exponent offset)
                     [0x00008050, _VREG1, _VREG2, _REG3],
                     [0x0000c050, _VREG1, _VREG2, _VREG3]],
                   'packed_op': False
                  },
        'FTOI':   {'descrs':
                    [[0x00000051, _REG1, _REG2],            # REG3 = Z (no exponent offset)
                     [0x00000051, _REG1, _REG2, _REG3],
                     [0x00008051, _VREG1, _VREG2],          # REG3 = Z (no exponent offset)
                     [0x00008051, _VREG1, _VREG2, _REG3],
                     [0x0000c051, _VREG1, _VREG2, _VREG3]],
                   'packed_op': False
                  },
        'FADD':   {'descrs':
                    [[0x00000052, _REG1, _REG2, _REG3],
                     [0x00008052, _VREG1, _VREG2, _REG3],
                     [0x0000c052, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'FSUB':   {'descrs':
                    [[0x00000053, _REG1, _REG2, _REG3],
                     [0x00008053, _VREG1, _VREG2, _REG3],
                     [0x0000c053, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'FMUL':   {'descrs':
                    [[0x00000054, _REG1, _REG2, _REG3],
                     [0x00008054, _VREG1, _VREG2, _REG3],
                     [0x0000c054, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'FDIV':   {'descrs':
                    [[0x00000055, _REG1, _REG2, _REG3],
                     [0x00008055, _VREG1, _VREG2, _REG3],
                     [0x0000c055, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'FSQRT': {'descrs':
                    [[0x00000056, _REG1, _REG2],      # REG3 = Z (operand is unused)
                     [0x0000c056, _VREG1, _VREG2]],   # VREG3 = VZ (operand is unused)
                   'packed_op': True
                  },
        'FSEQ':   {'descrs':
                    [[0x00000058, _REG1, _REG2, _REG3],
                     [0x00008058, _VREG1, _VREG2, _REG3],
                     [0x0000c058, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'FSNE':   {'descrs':
                    [[0x00000059, _REG1, _REG2, _REG3],
                     [0x00008059, _VREG1, _VREG2, _REG3],
                     [0x0000c059, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'FSLT':   {'descrs':
                    [[0x0000005a, _REG1, _REG2, _REG3],
                     [0x0000805a, _VREG1, _VREG2, _REG3],
                     [0x0000c05a, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'FSLE':   {'descrs':
                    [[0x0000005b, _REG1, _REG2, _REG3],
                     [0x0000805b, _VREG1, _VREG2, _REG3],
                     [0x0000c05b, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'FSNAN':  {'descrs':
                    [[0x0000005c, _REG1, _REG2, _REG3],
                     [0x0000805c, _VREG1, _VREG2, _REG3],
                     [0x0000c05c, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'FMIN':   {'descrs':
                    [[0x0000005d, _REG1, _REG2, _REG3],
                     [0x0000805d, _VREG1, _VREG2, _REG3],
                     [0x0000c05d, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },
        'FMAX':   {'descrs':
                    [[0x0000005e, _REG1, _REG2, _REG3],
                     [0x0000805e, _VREG1, _VREG2, _REG3],
                     [0x0000c05e, _VREG1, _VREG2, _VREG3]],
                   'packed_op': True
                  },

        # == C ==

        # Conditional branches.
        'BZ':     {'descrs':
                    [[0xc0000000, _REG1, _PCREL21x4]],
                   'packed_op': False
                  },
        'BNZ':    {'descrs':
                    [[0xc4000000, _REG1, _PCREL21x4]],
                   'packed_op': False
                  },
        'BS':     {'descrs':
                    [[0xc8000000, _REG1, _PCREL21x4]],
                   'packed_op': False
                  },
        'BNS':    {'descrs':
                    [[0xcc000000, _REG1, _PCREL21x4]],
                   'packed_op': False
                  },
        'BLT':    {'descrs':
                    [[0xd0000000, _REG1, _PCREL21x4]],
                   'packed_op': False
                  },
        'BGE':    {'descrs':
                    [[0xd4000000, _REG1, _PCREL21x4]],
                   'packed_op': False
                  },
        'BLE':    {'descrs':
                    [[0xd8000000, _REG1, _PCREL21x4]],
                   'packed_op': False
                  },
        'BGT':    {'descrs':
                    [[0xdc000000, _REG1, _PCREL21x4]],
                   'packed_op': False
                  },

        # Unconditional branches and jumps.
        # Note: With this encoding we could support J/JL REG+OFFSET19x4 for any
        # register, but right now we only support offsets when REG is PC (and
        # call the instruction B/BL instead). For all other registers, the offset
        # is forcibly zero.
        'J':      {'descrs':
                    [[0xe0000000, _REG1]],
                   'packed_op': False
                  },
        'B':      {'descrs':
                    [[0xe3e00000, _PCREL21x4]],
                   'packed_op': False
                  },
        'JL':     {'descrs':
                    [[0xe4000000, _REG1]],
                   'packed_op': False
                  },
        'BL':     {'descrs':
                    [[0xe7e00000, _PCREL21x4]],
                   'packed_op': False
                  },

        # Load immediate.
        'LDI':    {'descrs':
                    [[0xe8000000, _REG1, _IMM21],
                     [0xec000000, _REG1, _IMM21HI],     # LDHI
                     [0xf0000000, _REG1, _IMM21HIO]],   # LDHIO
                   'packed_op': False
                  },


        # ---------------------------------------------------------------------
        # === ALIASES ===
        # ---------------------------------------------------------------------

        # CPUID Z, Z, Z
        'NOP':    {'descrs':
                    [[0x00000000]],
                   'packed_op': False
                  },

        # Alias for: OR _REG1, _REG2, Z
        'MOV':    {'descrs':
                    [[0x00000010, _REG1, _REG2],
                     [0x00008010, _VREG1, _REG2],
                     [0x0000c010, _VREG1, _VREG2]],
                   'packed_op': False
                  },

        # Alias for: ADD _REG1, PC, offset
        'LEA':    {'descrs':
                    [[0x541f0000, _REG1, _PCREL15]],
                   'packed_op': False
                  },
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
        shift = 21 if operand_type == _REG1 else (16 if operand_type == _REG2 else 9)
        return reg_no << shift
    elif operand_type in [_VREG1, _VREG2, _VREG3]:
        try:
            reg_no = _VREGS[operand.upper()]
        except KeyError as e:
            raise AsmError(line_no, 'Bad vector register: {}'.format(operand))
        shift = 21 if operand_type == _VREG1 else (16 if operand_type == _VREG2 else 9)
        return reg_no << shift
    elif operand_type in [_XREG1, _XREG2]:
        try:
            reg_no = _XREGS[operand.upper()]
        except KeyError as e:
            raise AsmError(line_no, 'Bad control register: {}'.format(operand))
        shift = 21 if operand_type == _XREG1 else 16
        return reg_no << shift
    else:
        # Internal error.
        raise AsmError(line_no, 'Bad register type: {}'.format(operand_type))


def mangle_local_label(label, scope_label):
    return '{}@{}'.format(scope_label, label[1:])


def translate_addr_or_number(string, labels, scope_label, line_no):
    # Numeric literal?
    try:
        return parse_integer(string)
    except ValueError:
        pass

    # Label?
    # TODO(m): Add support for numerical offsets and relative +/- deltas.
    try:
        if string.startswith('.'):
            if not scope_label:
                raise AsmError(line_no, 'No scope for local label: {}'.format(string))
            string = mangle_local_label(string, scope_label)
        return labels[string]
    except KeyError as e:
        raise AsmError(line_no, 'Bad label: {}'.format(string))


def translate_imm(operand, operand_type, labels, scope_label, line_no):
    value = translate_addr_or_number(operand, labels, scope_label, line_no)

    value_bits = {
            _IMM15:    15,
            _IMM21:    21,
            _IMM21HI:  21,
            _IMM21HIO: 21,
        }[operand_type]
    value_shift = {
            _IMM15:    0,
            _IMM21:    0,
            _IMM21HI:  11,
            _IMM21HIO: 11,
        }[operand_type]
    value_min = {
            _IMM15:    -(1 << 14),
            _IMM21:    -(1 << 20),
            _IMM21HI:  0x00000000,
            _IMM21HIO: 0x000007ff,
        }[operand_type]
    value_max = {
            _IMM15:    (1 << 14) - 1,
            _IMM21:    (1 << 20) - 1,
            _IMM21HI:  0xfffff800,
            _IMM21HIO: 0xffffffff,
        }[operand_type]

    # Convert value to signed or unsigned.
    if operand_type in [_IMM15, _IMM21] and value >= 2147483648:
        value = -((~(value - 1)) & 0xffffffff)

    if value < value_min or value > value_max:
        raise AsmError(line_no, 'Immediate value out of range ({}..{}): {}'.format(value_min, value_max, operand))
    if operand_type == _IMM21HI and (value & 0x000007ff) != 0:
        raise AsmError(line_no, 'Immediate value must have the lower 11 bits cleared: {}'.format(operand))
    if operand_type == _IMM21HIO and (value & 0x000007ff) != 0x000007ff:
        raise AsmError(line_no, 'Immediate value must have the lower 11 bits set: {}'.format(operand))

    return (value >> value_shift) & ((1 << value_bits) - 1)


def translate_pcrel(operand, operand_type, pc, labels, scope_label, line_no):
    target_address = translate_addr_or_number(operand, labels, scope_label, line_no)
    offset = target_address - pc

    if operand_type == _PCREL21x4:
        if (target_address & 3) != 0:
            raise AsmError(line_no, 'Targe address ({}) is not aligned to 4 bytes'.format(operand))
        offset = offset / 4

    offset_max = {
            _PCREL15:   1 << 14,
            _PCREL21x4: 1 << 20,
        }[operand_type]
    if (offset < -offset_max or offset >= offset_max):
        raise AsmError(line_no, 'Too large offset: {}'.format(offset))

    return offset & (offset_max * 2 - 1)


def translate_operation(operation, mnemonic, descr, packed_type, folding, addr, line_no, labels, scope_label):
    if len(operation) != len(descr):
        raise AsmError(line_no, 'Expected {} arguments for {}'.format(len(descr) - 1, mnemonic))
    instr = descr[0]
    is_immediate_op = False
    for k in range(1, len(descr)):
        operand = operation[k]
        operand_type = descr[k]
        if operand_type in [_REG1, _REG2, _REG3, _VREG1, _VREG2, _VREG3, _XREG1, _XREG2]:
            instr = instr | translate_reg(operand, operand_type, line_no)
        elif operand_type in [_IMM15, _IMM21, _IMM21HI, _IMM21HIO]:
            instr = instr | translate_imm(operand, operand_type, labels, scope_label, line_no)
            is_immediate_op = True
        elif operand_type in [_PCREL15, _PCREL21x4]:
            instr = instr | translate_pcrel(operand, operand_type, addr, labels, scope_label, line_no)
            is_immediate_op = True

    # Folding.
    if folding:
        if is_immediate_op:
            raise AsmError(line_no, 'Folding not supported for these operands')
        instr = (instr & 0xffff3fff) | 0x00004000

    # TODO(m): This check is kind of coarse. More specifically packed operations are only supported
    # for A-type encodings, but we don't have that information here.
    if is_immediate_op and packed_type != _PACKED_NONE:
        raise AsmError(line_no, 'Packed operation not supported for immediate operands')

    return instr | (packed_type << 7)


def imm_can_be_handled_by_single_ldi(imm):
    upper_12 = imm & 0xfff00000
    lower_11 = imm & 0x000007ff
    if (upper_12 == 0x00000000) or (upper_12 == 0xfff00000):
        # Covered by LDI.
        return True
    if (lower_11 == 0x0000) or (lower_11 == 0x07ff):
        # Handled by LDHI or LDHIO.
        return True
    # Not handled.
    return False


def make_or_for_ldi(ldi_instr, imm):
    # Create an OR instruction that complements the given LDI instruction.
    op = 0x40000000  # OR
    reg = ldi_instr & 0x03e00000
    imm_low_bits = imm & 0x000007ff
    return op | reg | (reg >> 5) | imm_low_bits


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


def decompose_mnemonic(full_mnemonic):
    mnemonic = full_mnemonic

    # Is this a folding operation?
    folding = False
    if mnemonic[-2:] == ':F':
        folding = True
        mnemonic = mnemonic[:-2]

    # Is this a packed operation?
    packed_type = _PACKED_NONE
    if mnemonic[-2:] == '.B':
        packed_type = _PACKED_BYTE
        mnemonic = mnemonic[:-2]
    elif mnemonic[-2:] == '.H':
        packed_type = _PACKED_HALF_WORD
        mnemonic = mnemonic[:-2]

    return mnemonic, packed_type, folding


def parse_assigned_label(line, line_no):
    parts_unfiltered = line.split('=')
    parts = []
    for part in parts_unfiltered:
        part = part.strip()
        if len(part) > 0:
            parts.append(part)
    if len(parts) != 2:
        raise AsmError(line_no, 'Invalid label assignment: {}'.format(line))
    label = parts[0]
    try:
        label_value = parse_integer(parts[1])
    except ValueError:
        raise AsmError(line_no, 'Invalid integer value: {}'.format(parts[1]))

    return label, label_value


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

                elif line.endswith(':') or '=' in line:
                    # This is a label.
                    if line.endswith(':'):
                        label = line[:-1]
                        label_value = addr
                    else:
                        label, label_value = parse_assigned_label(line, line_no)
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
                        labels[label] = label_value
                        if verbosity_level >= 2:
                            print ' Label: {} = '.format(label) + format(label_value, '08x')

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
                        if not addr & (val_size - 1) == 0:
                            raise AsmError(line_no, 'Data not aligned to a {} byte boundary'.format(val_size))
                        val_type = {
                          '.i8': 'b',
                          '.u8': 'B',
                          '.i16': '<h',
                          '.u16': '<H',
                          '.i32': '<l',
                          '.u32': '<L'
                        }[directive[0]];
                        for k in range(1, len(directive)):
                            addr += val_size
                            if compilation_pass == 2:
                                try:
                                    # value = parse_integer(directive[k])
                                    value = translate_addr_or_number(directive[k], labels, scope_label, line_no)
                                except ValueError:
                                    raise AsmError(line_no, 'Invalid integer: {}'.format(directive[k]))
                                if value < val_min or value > val_max:
                                    raise AsmError(line_no, 'Value out of range: {}'.format(value))
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
                    full_mnemonic = operation[0].upper()
                    mnemonic, packed_type, folding = decompose_mnemonic(full_mnemonic)
                    packed_op = (packed_type != _PACKED_NONE)

                    try:
                        op_descr = _OPCODES[mnemonic]
                    except KeyError as e:
                        raise AsmError(line_no, 'Bad mnemonic: {}'.format(full_mnemonic))

                    # Special case: Expand LDI into LDI + OR?
                    original_operation = list(operation)
                    need_to_expand_ldi = False
                    if full_mnemonic == 'LDI':
                        try:
                            ldi_imm = parse_integer(operation[2]) & 0xffffffff
                            if not imm_can_be_handled_by_single_ldi(ldi_imm):
                                operation[2] = '0x' + format(ldi_imm & 0xfffff800, '08x')
                                need_to_expand_ldi = True
                        except:
                            pass

                    if compilation_pass == 2:
                        errors = []
                        translation_successful = False
                        if packed_op and not op_descr['packed_op']:
                            raise AsmError(line_no, '{} does not support packed operation'.format(mnemonic))
                        descrs = op_descr['descrs']
                        for descr in descrs:
                            try:
                                instr = translate_operation(operation, full_mnemonic, descr, packed_type, folding, addr, line_no, labels, scope_label)
                                translation_successful = True
                                break
                            except AsmError as e:
                                errors.append(e.msg)
                        if not translation_successful:
                            msg = 'Invalid operands for {}: {}'.format(full_mnemonic, ','.join(operation[1:]))
                            for e in errors:
                                msg += '\n  Candidate: {}'.format(e)
                            raise AsmError(line_no, msg)
                        if verbosity_level >= 2:
                            extra_chars = ' \\ ' if need_to_expand_ldi else ' <='
                            print format(addr, '08x') + ': ' + format(instr, '08x') + extra_chars + ' {}'.format(original_operation)
                        code += struct.pack('<L', instr)

                        if need_to_expand_ldi:
                            or_instr = make_or_for_ldi(instr, ldi_imm)
                            if verbosity_level >= 2:
                                print format(addr + 4, '08x') + ': ' + format(or_instr, '08x') + ' /  (expanded to LDHI + OR)'
                            code += struct.pack('<L', or_instr)

                    addr += 8 if need_to_expand_ldi else 4

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
    parser.add_argument('-o', '--output',
                        help='output file')
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

    # Collect source -> output jobs.
    jobs = []
    if args.output is not None:
        if len(args.files) != 1:
            print 'Error: Only a single source file must be specified together with -o.'
            sys.exit(1)
        jobs.append({'src': args.files[0], 'out': args.output})
    else:
        for file_name in args.files:
            out_name = os.path.splitext(file_name)[0] + '.bin'
            jobs.append({'src': file_name, 'out': out_name})

    # Perform compilations.
    for job in jobs:
        if not compile_file(job['src'], job['out'], verbosity_level):
            sys.exit(1)


if __name__ == "__main__":
    main()

