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
# A: |v|0    |ra5 |rb5 |rc5 |op9     |
# B: |v|op6  |ra5 |rb5 |imm14        |
# C: |v|op6  |ra5 |imm19             |

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
_PCREL14 = 11    # -8192..8191
_PCREL19x4 = 12  # -1048576..1048572 (in steps of 4)

# Names of general purpose registers.
_REGS = {
        'Z':  0,  # Read-only: Zero
        'VL': 28, # Vector length register
        'LR': 29, # Link register (branch return address)
        'SP': 30, # Stack pointer
        'PC': 31, # Read-only: Program counter

        'R0': 0,  # Alias for Z
        'R1': 1,
        'R2': 2,
        'R3': 3,
        'R4': 4,
        'R5': 5,
        'R6': 6,
        'R7': 7,
        'R8': 8,
        'R9': 9,
        'R10': 10,
        'R11': 11,
        'R12': 12,
        'R13': 13,
        'R14': 14,
        'R15': 15,
        'R16': 16,
        'R17': 17,
        'R18': 18,
        'R19': 19,
        'R20': 20,
        'R21': 21,
        'R22': 22,
        'R23': 23,
        'R24': 24,
        'R25': 25,
        'R26': 26,
        'R27': 27,
        'R28': 28,  # Alias for VL
        'R29': 29,  # Alias for LR
        'R30': 30,  # Alias for SP
        'R31': 31,  # Alias for PC
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

        # == A ==

        # Integer ALU ops.
        'NOP':    [0x00000000],                       # nop z, z, z
        'OR':     [0x00000001, _REG1, _REG2, _REG3],
        'NOR':    [0x00000002, _REG1, _REG2, _REG3],
        'AND':    [0x00000003, _REG1, _REG2, _REG3],
        'XOR':    [0x00000004, _REG1, _REG2, _REG3],
        'ADD':    [0x00000005, _REG1, _REG2, _REG3],
        'SUB':    [0x00000006, _REG1, _REG2, _REG3],
        'SLT':    [0x00000007, _REG1, _REG2, _REG3],
        'SLTU':   [0x00000008, _REG1, _REG2, _REG3],
        'LSL':    [0x00000009, _REG1, _REG2, _REG3],
        'ASR':    [0x0000000a, _REG1, _REG2, _REG3],
        'LSR':    [0x0000000b, _REG1, _REG2, _REG3],
        'CLZ':    [0x0000000c, _REG1, _REG2],         # 3rd reg is always z
        'REV':    [0x0000000d, _REG1, _REG2],         # 3rd reg is always z
        'EXTB':   [0x0000000e, _REG1, _REG2],         # 3rd reg is always z
        'EXTH':   [0x0000000f, _REG1, _REG2],         # 3rd reg is always z

        # Load/store reg + reg.
        'LDXB':   [0x00000010, _REG1, _REG2, _REG3],
        'LDXUB':  [0x00000011, _REG1, _REG2, _REG3],
        'LDXH':   [0x00000012, _REG1, _REG2, _REG3],
        'LDXUH':  [0x00000013, _REG1, _REG2, _REG3],
        'LDXW':   [0x00000014, _REG1, _REG2, _REG3],
        'STXB':   [0x00000018, _REG1, _REG2, _REG3],
        'STXH':   [0x00000019, _REG1, _REG2, _REG3],
        'STXW':   [0x0000001a, _REG1, _REG2, _REG3],

        # Conditional moves.
        'MEQ':    [0x00000020, _REG1, _REG2, _REG3],
        'MNE':    [0x00000021, _REG1, _REG2, _REG3],
        'MGE':    [0x00000022, _REG1, _REG2, _REG3],
        'MGT':    [0x00000023, _REG1, _REG2, _REG3],
        'MLE':    [0x00000024, _REG1, _REG2, _REG3],
        'MLT':    [0x00000025, _REG1, _REG2, _REG3],

        # Integer mul/div.
        'MUL':    [0x00000030, _REG1, _REG2, _REG3],
        'MULU':   [0x00000031, _REG1, _REG2, _REG3],
        'MULL':   [0x00000032, _REG1, _REG2, _REG3],  # dest = REG1:REG(1+1)
        'MULLU':  [0x00000033, _REG1, _REG2, _REG3],  # dest = REG1:REG(1+1)
        'DIV':    [0x00000034, _REG1, _REG2, _REG3],
        'DIVU':   [0x00000035, _REG1, _REG2, _REG3],
        'DIVL':   [0x00000036, _REG1, _REG2, _REG3],  # dest = REG1:REG(1+1)
        'DIVLU':  [0x00000037, _REG1, _REG2, _REG3],  # dest = REG1:REG(1+1)

        # FP arithmetic.
        'ITOF':   [0x00000040, _REG1, _REG2],    # Cast int->float (reg3 = z)
        'FTOI':   [0x00000041, _REG1, _REG2],    # Cast float->int (reg3 = z)
        'FADD':   [0x00000042, _REG1, _REG2, _REG3],
        'FSUB':   [0x00000043, _REG1, _REG2, _REG3],
        'FMUL':   [0x00000044, _REG1, _REG2, _REG3],
        'FDIV':   [0x00000045, _REG1, _REG2, _REG3],

        # Move to/from auxiliary registers.
        'MRX':    [0x00000070, _XREG1, _REG2],   # Move gpr->auxiliary (reg3 = z)
        'MXR':    [0x00000071, _REG1, _XREG2],   # Move auxiliary->gpr (reg3 = z)

        # Jump to register address.
        'JMP':    [0x00000080, _REG1],                # 1st & 3rd regs are always z
        'JSR':    [0x00000081, _REG1],                # 1st & 3rd regs are always z


        # == B ==

        # Immediate ALU ops.
        'ORI':    [0x01000000, _REG1, _REG2, _IMM14],
        'NORI':   [0x02000000, _REG1, _REG2, _IMM14],
        'ANDI':   [0x03000000, _REG1, _REG2, _IMM14],
        'XORI':   [0x04000000, _REG1, _REG2, _IMM14],
        'ADDI':   [0x05000000, _REG1, _REG2, _IMM14],
        'SUBI':   [0x06000000, _REG1, _REG2, _IMM14],
        'SLTI':   [0x07000000, _REG1, _REG2, _IMM14],
        'SLTUI':  [0x08000000, _REG1, _REG2, _IMM14],
        'LSLI':   [0x09000000, _REG1, _REG2, _IMM14],
        'ASRI':   [0x0a000000, _REG1, _REG2, _IMM14],
        'LSRI':   [0x0b000000, _REG1, _REG2, _IMM14],

        # Load/store reg + offset.
        'LDB':    [0x10000000, _REG1, _REG2, _IMM14],
        'LDUB':   [0x11000000, _REG1, _REG2, _IMM14],
        'LDH':    [0x12000000, _REG1, _REG2, _IMM14],
        'LDUH':   [0x13000000, _REG1, _REG2, _IMM14],
        'LDW':    [0x14000000, _REG1, _REG2, _IMM14],
        'STB':    [0x18000000, _REG1, _REG2, _IMM14],
        'STH':    [0x19000000, _REG1, _REG2, _IMM14],
        'STW':    [0x1a000000, _REG1, _REG2, _IMM14],

        # TODO(m): Load Linked (ll) and Store Conditional (sc) for atomic ops.
        # 'LL':    [(47 << 24), _REG2, _REG1],
        # 'SC':    [(47 << 24), _REG2, _REG1],


        # == C ==

        # Branch ops.
        'BEQ':    [0x20000000, _REG1, _PCREL19x4],
        'BNE':    [0x21000000, _REG1, _PCREL19x4],
        'BGE':    [0x22000000, _REG1, _PCREL19x4],
        'BGT':    [0x23000000, _REG1, _PCREL19x4],
        'BLE':    [0x24000000, _REG1, _PCREL19x4],
        'BLT':    [0x25000000, _REG1, _PCREL19x4],

        'BLEQ':   [0x28000000, _REG1, _PCREL19x4],
        'BLNE':   [0x29000000, _REG1, _PCREL19x4],
        'BLGE':   [0x2a000000, _REG1, _PCREL19x4],
        'BLGT':   [0x2b000000, _REG1, _PCREL19x4],
        'BLLE':   [0x2c000000, _REG1, _PCREL19x4],
        'BLLT':   [0x2d000000, _REG1, _PCREL19x4],

        # Load immediate.
        'LDI':    [0x30000000, _REG1, _IMM19],
        'LDHI':   [0x31000000, _REG1, _IMM19],


        # ---------------------------------------------------------------------
        # VECTOR OPERATIONS
        # ---------------------------------------------------------------------

        # == A: V <= V, V ==

        'VVOR':   [0xc0000001, _VREG1, _VREG2, _VREG3],
        'VVNOR':  [0xc0000002, _VREG1, _VREG2, _VREG3],
        'VVAND':  [0xc0000003, _VREG1, _VREG2, _VREG3],
        'VVXOR':  [0xc0000004, _VREG1, _VREG2, _VREG3],
        'VVADD':  [0xc0000005, _VREG1, _VREG2, _VREG3],
        'VVSUB':  [0xc0000006, _VREG1, _VREG2, _VREG3],
        'VVSLT':  [0xc0000007, _VREG1, _VREG2, _VREG3],
        'VVSLTU': [0xc0000008, _VREG1, _VREG2, _VREG3],
        'VVLSL':  [0xc0000009, _VREG1, _VREG2, _VREG3],
        'VVASR':  [0xc000000a, _VREG1, _VREG2, _VREG3],
        'VVLSR':  [0xc000000b, _VREG1, _VREG2, _VREG3],

        'VVMUL':  [0xc0000030, _VREG1, _VREG2, _VREG3],
        'VVMULU': [0xc0000031, _VREG1, _VREG2, _VREG3],
        'VVDIV':  [0xc0000034, _VREG1, _VREG2, _VREG3],
        'VVDIVU': [0xc0000035, _VREG1, _VREG2, _VREG3],

        'VVFADD': [0xc0000042, _VREG1, _VREG2, _VREG3],
        'VVFSUB': [0xc0000043, _VREG1, _VREG2, _VREG3],
        'VVFMUL': [0xc0000044, _VREG1, _VREG2, _VREG3],
        'VVFDIV': [0xc0000045, _VREG1, _VREG2, _VREG3],

        # == A: V <= V, S ==

        'VSOR':   [0x80000001, _VREG1, _VREG2, _REG3],
        'VSNOR':  [0x80000002, _VREG1, _VREG2, _REG3],
        'VSAND':  [0x80000003, _VREG1, _VREG2, _REG3],
        'VSXOR':  [0x80000004, _VREG1, _VREG2, _REG3],
        'VSADD':  [0x80000005, _VREG1, _VREG2, _REG3],
        'VSSUB':  [0x80000006, _VREG1, _VREG2, _REG3],
        'VSSLT':  [0x80000007, _VREG1, _VREG2, _REG3],
        'VSSLTU': [0x80000008, _VREG1, _VREG2, _REG3],
        'VSLSL':  [0x80000009, _VREG1, _VREG2, _REG3],
        'VSASR':  [0x8000000a, _VREG1, _VREG2, _REG3],
        'VSLSR':  [0x8000000b, _VREG1, _VREG2, _REG3],
        'VCLZ':   [0x8000000c, _VREG1, _VREG2],         # 3rd reg is always z
        'VREV':   [0x8000000d, _VREG1, _VREG2],         # 3rd reg is always z
        'VEXTB':  [0x8000000e, _VREG1, _VREG2],         # 3rd reg is always z
        'VEXTH':  [0x8000000f, _VREG1, _VREG2],         # 3rd reg is always z

        'VSMUL':  [0x80000030, _VREG1, _VREG2, _REG3],
        'VSMULU': [0x80000031, _VREG1, _VREG2, _REG3],
        'VSDIV':  [0x80000034, _VREG1, _VREG2, _REG3],
        'VSDIVU': [0x80000035, _VREG1, _VREG2, _REG3],

        'VITOF':  [0x80000040, _VREG1, _VREG2],    # Cast int->float (reg3 = z)
        'VFTOI':  [0x80000041, _VREG1, _VREG2],    # Cast float->int (reg3 = z)
        'VSFADD': [0x80000042, _VREG1, _VREG2, _REG3],
        'VSFSUB': [0x80000043, _VREG1, _VREG2, _REG3],
        'VSFMUL': [0x80000044, _VREG1, _VREG2, _REG3],
        'VSFDIV': [0x80000045, _VREG1, _VREG2, _REG3],

        # == B ==

        # V <= V, imm14
        'VSORI':   [0x81000000, _VREG1, _VREG2, _IMM14],
        'VSNORI':  [0x82000000, _VREG1, _VREG2, _IMM14],
        'VSANDI':  [0x83000000, _VREG1, _VREG2, _IMM14],
        'VSXORI':  [0x84000000, _VREG1, _VREG2, _IMM14],
        'VSADDI':  [0x85000000, _VREG1, _VREG2, _IMM14],
        'VSSUBI':  [0x86000000, _VREG1, _VREG2, _IMM14],
        'VSSLTI':  [0x87000000, _VREG1, _VREG2, _IMM14],
        'VSSLTUI': [0x88000000, _VREG1, _VREG2, _IMM14],
        'VSLSLI':  [0x89000000, _VREG1, _VREG2, _IMM14],
        'VSASRI':  [0x8a000000, _VREG1, _VREG2, _IMM14],
        'VSLSRI':  [0x8b000000, _VREG1, _VREG2, _IMM14],

        # Vector load/store from reg with stride.
        'VLDB':  [0x90000000, _VREG1, _REG2, _IMM14],
        'VLDUB': [0x91000000, _VREG1, _REG2, _IMM14],
        'VLDH':  [0x92000000, _VREG1, _REG2, _IMM14],
        'VLDUH': [0x93000000, _VREG1, _REG2, _IMM14],
        'VLDW':  [0x94000000, _VREG1, _REG2, _IMM14],
        'VSTB':  [0x98000000, _VREG1, _REG2, _IMM14],
        'VSTH':  [0x99000000, _VREG1, _REG2, _IMM14],
        'VSTW':  [0x9a000000, _VREG1, _REG2, _IMM14],


        # === ALIASES ===

        # Alias for: OR _REG1, Z, _REG3
        'MOV':    [0x00000001, _REG1, _REG3],

        # Alias for: VVOR _VREG1, VZ, _VREG3
        'VVMOV':  [0xc0000001, _VREG1, _VREG3],

        # Alias for: VSOR _VREG1, VZ, _REG3
        'VSMOV':  [0x80000001, _VREG1, _REG3],

        # Alias for: VSORI _VREG1, VZ, _IMM14
        'VSLDI':  [0x81000000, _VREG1, _IMM14],

        # Alias for: BEQ Z, _PCREL19x4
        'B':      [0x20000000, _PCREL19x4],

        # Alias for: BLEQ Z, _PCREL19x4
        'BL':     [0x28000000, _PCREL19x4],

        # Alias for: JMP LR
        'RTS':    [0x00e80080],

        # Alias for: ADDI _REG1, PC, offset
        'LEA':    [0x0507c000, _REG1, _PCREL14],

        # Load/store pc-relative (alias for: ld.?/st.? _REG1, pc, offset).
        'LDPCB':  [0x1007c000, _REG1, _PCREL14],
        'LDUPCB': [0x1107c000, _REG1, _PCREL14],
        'LDPCH':  [0x1207c000, _REG1, _PCREL14],
        'LDUPCH': [0x1307c000, _REG1, _PCREL14],
        'LDPCW':  [0x1407c000, _REG1, _PCREL14],
        'STPCB':  [0x1807c000, _REG1, _PCREL14],
        'STPCH':  [0x1907c000, _REG1, _PCREL14],
        'STPCW':  [0x1a07c000, _REG1, _PCREL14],
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

    value_max = {
            _IMM14:   1 << 13,
            _IMM19:   1 << 18,
        }[operand_type]
    if (value < -value_max or value >= (value_max * 2)):
        raise AsmError(line_no, 'Too large immediate value: {}'.format(operand))

    return value & (value_max * 2 - 1)


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
        elif operand_type in [_IMM14, _IMM19]:
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
            addr = 49152

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
                            print ' Label: "%s": %d' % (label, addr)

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
                        descr = _OPCODES[mnemonic]
                    except KeyError as e:
                        raise AsmError(line_no, 'Bad mnemonic: {}'.format(mnemonic))
                    if compilation_pass == 2:
                        instr = translate_operation(operation, mnemonic, descr, addr, line_no, labels, scope_label)
                        if verbosity_level >= 2:
                            print format(instr, '08x') + ' <= ' + '{}'.format(operation)
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
    parser = argparse.ArgumentParser(description='A simple assembler for misc16')
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

