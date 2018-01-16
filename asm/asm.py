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
# A: |op8    |ra5 |rb5 |rc5 |op9     |
# B: |op8    |ra5 |rb5 |imm14        |
# C: |op8    |ra5 |imm19             |
# D: |op8    |imm24                  |

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
_PCREL24x4 = 13  # -33554432..33554428 (in steps of 4)

# Names of general purpose registers.
_REGS = {
        'z':  0,  # Read-only: Zero
        'vc': 28, # Vector count register
        'lr': 29, # Link register (branch return address)
        'sp': 30, # Stack pointer
        'pc': 31, # Read-only: Program counter

        'r0': 0,  # Alias for z
        'r1': 1,
        'r2': 2,
        'r3': 3,
        'r4': 4,
        'r5': 5,
        'r6': 6,
        'r7': 7,
        'r8': 8,
        'r9': 9,
        'r10': 10,
        'r11': 11,
        'r12': 12,
        'r13': 13,
        'r14': 14,
        'r15': 15,
        'r16': 16,
        'r17': 17,
        'r18': 18,
        'r19': 19,
        'r20': 20,
        'r21': 21,
        'r22': 22,
        'r23': 23,
        'r24': 24,
        'r25': 25,
        'r26': 26,
        'r27': 27,
        'r28': 28,  # Alias for vc
        'r29': 29,  # Alias for lr
        'r30': 30,  # Alias for sp
        'r31': 31,  # Alias for pc
    }

# Names of vector registers.
_VREGS = {
        'vz': 0,    # Read only: Zero

        'v0': 0,    # Alias for vz
        'v1': 1,
        'v2': 2,
        'v3': 3,
        'v4': 4,
        'v5': 5,
        'v6': 6,
        'v7': 7,
        'v8': 8,
        'v9': 9,
        'v10': 10,
        'v11': 11,
        'v12': 12,
        'v13': 13,
        'v14': 14,
        'v15': 15,
        'v16': 16,
        'v17': 17,
        'v18': 18,
        'v19': 19,
        'v20': 20,
        'v21': 21,
        'v22': 22,
        'v23': 23,
        'v24': 24,
        'v25': 25,
        'v26': 26,
        'v27': 27,
        'v28': 28,
        'v29': 29,
        'v30': 30,
        'v31': 31,
    }


# Names of constrol/status/auxiliary registers.
_XREGS = {
        'ccr':  0,  # Cache control register.
    }

# Supported opcodes.
_OPCODES = {
        # ---------------------------------------------------------------------
        # SCALAR OPERATIONS
        # ---------------------------------------------------------------------

        # == A ==

        # Integer ALU ops.
        'nop':    [0x00000000],                       # nop z, z, z
        'or':     [0x00000001, _REG1, _REG2, _REG3],
        'nor':    [0x00000002, _REG1, _REG2, _REG3],
        'and':    [0x00000003, _REG1, _REG2, _REG3],
        'xor':    [0x00000004, _REG1, _REG2, _REG3],
        'add':    [0x00000005, _REG1, _REG2, _REG3],
        'sub':    [0x00000006, _REG1, _REG2, _REG3],
        'addc':   [0x00000007, _REG1, _REG2, _REG3],
        'subc':   [0x00000008, _REG1, _REG2, _REG3],
        'lsl':    [0x00000009, _REG1, _REG2, _REG3],
        'asr':    [0x0000000a, _REG1, _REG2, _REG3],
        'lsr':    [0x0000000b, _REG1, _REG2, _REG3],
        'clz':    [0x0000000c, _REG1, _REG2],         # 3rd reg is always z
        'rev':    [0x0000000d, _REG1, _REG2],         # 3rd reg is always z
        'ext.b':  [0x0000000e, _REG1, _REG2],         # 3rd reg is always z
        'ext.h':  [0x0000000f, _REG1, _REG2],         # 3rd reg is always z

        # Load/store reg + reg.
        'ldx.b':  [0x00000010, _REG1, _REG2, _REG3],
        'ldx.h':  [0x00000011, _REG1, _REG2, _REG3],
        'ldx.w':  [0x00000012, _REG1, _REG2, _REG3],
        'stx.b':  [0x00000014, _REG1, _REG2, _REG3],
        'stx.h':  [0x00000015, _REG1, _REG2, _REG3],
        'stx.w':  [0x00000016, _REG1, _REG2, _REG3],

        # Conditional moves.
        'meq':    [0x00000020, _REG1, _REG2, _REG3],
        'mne':    [0x00000021, _REG1, _REG2, _REG3],
        'mlt':    [0x00000022, _REG1, _REG2, _REG3],
        'mle':    [0x00000023, _REG1, _REG2, _REG3],
        'mgt':    [0x00000024, _REG1, _REG2, _REG3],
        'mge':    [0x00000025, _REG1, _REG2, _REG3],

        # Integer mul/div.
        'mul':    [0x00000030, _REG1, _REG2, _REG3],
        'mulu':   [0x00000031, _REG1, _REG2, _REG3],
        'mull':   [0x00000032, _REG1, _REG2, _REG3],  # dest = REG1:REG(1+1)
        'mullu':  [0x00000033, _REG1, _REG2, _REG3],  # dest = REG1:REG(1+1)
        'div':    [0x00000034, _REG1, _REG2, _REG3],
        'divu':   [0x00000035, _REG1, _REG2, _REG3],
        'divl':   [0x00000036, _REG1, _REG2, _REG3],  # dest = REG1:REG(1+1)
        'divlu':  [0x00000037, _REG1, _REG2, _REG3],  # dest = REG1:REG(1+1)

        # FP arithmetic.
        'itof':   [0x00000040, _REG1, _REG2],    # Cast int->float (reg3 = z)
        'ftoi':   [0x00000041, _REG1, _REG2],    # Cast float->int (reg3 = z)
        'fadd':   [0x00000042, _REG1, _REG2, _REG3],
        'fsub':   [0x00000043, _REG1, _REG2, _REG3],
        'fmul':   [0x00000044, _REG1, _REG2, _REG3],
        'fdiv':   [0x00000045, _REG1, _REG2, _REG3],

        # Move to/from auxiliary registers.
        'mrx':    [0x00000070, _XREG1, _REG2],   # Move gpr->auxiliary (reg3 = z)
        'mxr':    [0x00000071, _REG1, _XREG2],   # Move auxiliary->gpr (reg3 = z)

        # Jump to register address.
        'jmp':    [0x00000080, _REG1],                # 1st & 3rd regs are always z
        'jsr':    [0x00000081, _REG1],                # 1st & 3rd regs are always z


        # == B ==

        # Immediate ALU ops.
        'ori':    [0x01000000, _REG1, _REG2, _IMM14],
        'nori':   [0x02000000, _REG1, _REG2, _IMM14],
        'andi':   [0x03000000, _REG1, _REG2, _IMM14],
        'xori':   [0x04000000, _REG1, _REG2, _IMM14],
        'addi':   [0x05000000, _REG1, _REG2, _IMM14],
        'subi':   [0x06000000, _REG1, _REG2, _IMM14],
        'addci':  [0x07000000, _REG1, _REG2, _IMM14],
        'subci':  [0x08000000, _REG1, _REG2, _IMM14],
        'lsli':   [0x09000000, _REG1, _REG2, _IMM14],
        'asri':   [0x0a000000, _REG1, _REG2, _IMM14],
        'lsri':   [0x0b000000, _REG1, _REG2, _IMM14],

        # Load/store reg + offset.
        'ld.b':   [0x10000000, _REG1, _REG2, _IMM14],
        'ld.h':   [0x11000000, _REG1, _REG2, _IMM14],
        'ld.w':   [0x12000000, _REG1, _REG2, _IMM14],
        'st.b':   [0x14000000, _REG1, _REG2, _IMM14],
        'st.h':   [0x15000000, _REG1, _REG2, _IMM14],
        'st.w':   [0x16000000, _REG1, _REG2, _IMM14],

        # TODO(m): Load Linked (ll) and Store Conditional (sc) for atomic ops.
        # 'll':    [(47 << 24), _REG2, _REG1],
        # 'sc':    [(47 << 24), _REG2, _REG1],


        # == C ==

        # Branch ops.
        'beq':    [0x20000000, _REG1, _PCREL19x4],
        'bne':    [0x21000000, _REG1, _PCREL19x4],
        'bge':    [0x22000000, _REG1, _PCREL19x4],
        'bgt':    [0x23000000, _REG1, _PCREL19x4],
        'ble':    [0x24000000, _REG1, _PCREL19x4],
        'blt':    [0x25000000, _REG1, _PCREL19x4],

        # Load immediate.
        'ldi':    [0x28000000, _REG1, _IMM19],
        'ldhi':   [0x29000000, _REG1, _IMM19],


        # == D ==

        # Long range unconditional PC-relative branches.
        'bra':    [0x30000000, _PCREL24x4],
        'bsr':    [0x31000000, _PCREL24x4],


        # ---------------------------------------------------------------------
        # VECTOR OPERATIONS
        # ---------------------------------------------------------------------

        # == A: V <= V, V ==

        'vvor':   [0x80000001, _VREG1, _VREG2, _VREG3],
        'vvnor':  [0x80000002, _VREG1, _VREG2, _VREG3],
        'vvand':  [0x80000003, _VREG1, _VREG2, _VREG3],
        'vvxor':  [0x80000004, _VREG1, _VREG2, _VREG3],
        'vvadd':  [0x80000005, _VREG1, _VREG2, _VREG3],
        'vvsub':  [0x80000006, _VREG1, _VREG2, _VREG3],
        'vvlsl':  [0x80000009, _VREG1, _VREG2, _VREG3],
        'vvasr':  [0x8000000a, _VREG1, _VREG2, _VREG3],
        'vvlsr':  [0x8000000b, _VREG1, _VREG2, _VREG3],

        'vvmul':  [0x80000030, _VREG1, _VREG2, _VREG3],
        'vvmulu': [0x80000031, _VREG1, _VREG2, _VREG3],
        'vvdiv':  [0x80000034, _VREG1, _VREG2, _VREG3],
        'vvdivu': [0x80000035, _VREG1, _VREG2, _VREG3],

        'vvfadd': [0x80000042, _VREG1, _VREG2, _VREG3],
        'vvfsub': [0x80000043, _VREG1, _VREG2, _VREG3],
        'vvfmul': [0x80000044, _VREG1, _VREG2, _VREG3],
        'vvfdiv': [0x80000045, _VREG1, _VREG2, _VREG3],

        # == A: V <= V, S ==

        'vsor':   [0xc0000001, _VREG1, _VREG2, _REG3],
        'vsnor':  [0xc0000002, _VREG1, _VREG2, _REG3],
        'vsand':  [0xc0000003, _VREG1, _VREG2, _REG3],
        'vsxor':  [0xc0000004, _VREG1, _VREG2, _REG3],
        'vsadd':  [0xc0000005, _VREG1, _VREG2, _REG3],
        'vssub':  [0xc0000006, _VREG1, _VREG2, _REG3],
        'vslsl':  [0xc0000009, _VREG1, _VREG2, _REG3],
        'vsasr':  [0xc000000a, _VREG1, _VREG2, _REG3],
        'vslsr':  [0xc000000b, _VREG1, _VREG2, _REG3],
        'vclz':   [0xc000000c, _VREG1, _VREG2],         # 3rd reg is always z
        'vrev':   [0xc000000d, _VREG1, _VREG2],         # 3rd reg is always z
        'vext.b': [0xc000000e, _VREG1, _VREG2],         # 3rd reg is always z
        'vext.h': [0xc000000f, _VREG1, _VREG2],         # 3rd reg is always z

        'vsmul':  [0xc0000030, _VREG1, _VREG2, _REG3],
        'vsmulu': [0xc0000031, _VREG1, _VREG2, _REG3],
        'vsdiv':  [0xc0000034, _VREG1, _VREG2, _REG3],
        'vsdivu': [0xc0000035, _VREG1, _VREG2, _REG3],

        'vitof':  [0xc0000040, _VREG1, _VREG2],    # Cast int->float (reg3 = z)
        'vftoi':  [0xc0000041, _VREG1, _VREG2],    # Cast float->int (reg3 = z)
        'vsfadd': [0xc0000042, _VREG1, _VREG2, _REG3],
        'vsfsub': [0xc0000043, _VREG1, _VREG2, _REG3],
        'vsfmul': [0xc0000044, _VREG1, _VREG2, _REG3],
        'vsfdiv': [0xc0000045, _VREG1, _VREG2, _REG3],

        # == B ==

        # Load/store reg, stride.
        'vld.b':  [0x90000000, _REG1, _REG2, _IMM14],
        'vld.h':  [0x91000000, _REG1, _REG2, _IMM14],
        'vld.w':  [0x92000000, _REG1, _REG2, _IMM14],
        'vst.b':  [0x94000000, _REG1, _REG2, _IMM14],
        'vst.h':  [0x95000000, _REG1, _REG2, _IMM14],
        'vst.w':  [0x96000000, _REG1, _REG2, _IMM14],


        # === ALIASES ===

        # Alias for: or _REG1, _REG3, z
        'mov':    [0x00000001, _REG1, _REG2],

        # Alias for: jmp lr
        'rts':    [0x00e80080],

        # Alias for: addi _REG1, pc, offset
        'lea':    [0x0507c000, _REG1, _PCREL14],

        # Load/store pc-relative (alias for: ld.?/st.? _REG1, pc, offset).
        'ldpc.b': [0x1007c000, _REG1, _PCREL14],
        'ldpc.h': [0x1107c000, _REG1, _PCREL14],
        'ldpc.w': [0x1207c000, _REG1, _PCREL14],
        'stpc.b': [0x1407c000, _REG1, _PCREL14],
        'stpc.h': [0x1507c000, _REG1, _PCREL14],
        'stpc.w': [0x1607c000, _REG1, _PCREL14],
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
            reg_no = _REGS[operand.lower()]
        except KeyError as e:
            raise AsmError(line_no, 'Bad register: {}'.format(operand))
        shift = 19 if operand_type == _REG1 else (14 if operand_type == _REG2 else 9)
        return reg_no << shift
    elif operand_type in [_VREG1, _VREG2, _VREG3]:
        try:
            reg_no = _VREGS[operand.lower()]
        except KeyError as e:
            raise AsmError(line_no, 'Bad vector register: {}'.format(operand))
        shift = 19 if operand_type == _XFREG1 else 14
        return reg_no << shift
    elif operand_type in [_XREG1, _XREG2]:
        try:
            reg_no = _XREGS[operand.lower()]
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

    if operand_type in [_PCREL19x4, _PCREL24x4]:
        if (target_address & 3) != 0:
            raise AsmError(line_no, 'Targe address ({}) is not aligned to 4 bytes'.format(operand))
        offset = offset / 4

    offset_max = {
            _PCREL14:   1 << 13,
            _PCREL19x4: 1 << 18,
            _PCREL24x4: 1 << 23,
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
        elif operand_type in [_PCREL14, _PCREL19x4, _PCREL24x4]:
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
                    mnemonic = operation[0].lower()
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

