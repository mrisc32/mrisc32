#!/usr/bin/env python3
# -*- mode: python; tab-width: 4; indent-tabs-mode: nil; -*-
# -------------------------------------------------------------------------------------------------
# Copyright (c) 2019 Marcus Geelnard
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
import sys

def load_record(f):
    buf_str = f.read(5*4)
    if len(buf_str) < 5*4:
        return
    buf = struct.unpack('<LLLLL', buf_str)
    flags = buf[0]
    return {
        'valid': True if flags & 1 != 0 else False,
        'src_a_valid': True if flags & 2 != 0 else False,
        'src_b_valid': True if flags & 4 != 0 else False,
        'src_c_valid': True if flags & 8 != 0 else False,
        'pc': buf[1],
        'src_a': buf[2],
        'src_b': buf[3],
        'src_c': buf[4]
    }


def show(trace_file, show_operands, show_defunct):
    with open(trace_file, 'rb') as f:
        while True:
            trace = load_record(f)
            if not trace:
                break
            if trace['valid'] or show_defunct:
                s = f"{trace['pc']:08X}"
                if show_operands:
                    s += ":"
                    s += f" {trace['src_a']:08X}" if trace['src_a_valid'] else (" " + "-" * 8)
                    s += f" {trace['src_b']:08X}" if trace['src_b_valid'] else (" " + "-" * 8)
                    s += f" {trace['src_c']:08X}" if trace['src_c_valid'] else (" " + "-" * 8)
                    if not trace['valid']:
                        s += ' [defunct]'
                print(s)


def main():
    # Parse command line arguments.
    parser = argparse.ArgumentParser(
            description='Tool for inspecting MRISC32 debug trace files')
    parser.add_argument('file', metavar='TRACE_FILE', help='the debug trace file to show')
    parser.add_argument('-o', '--operands', action='store_true', help='show operand values')
    parser.add_argument('-d', '--defunct', action='store_true', help='show defunct operations (bubbles)')
    args = parser.parse_args()

    # Show the file.
    show(args.file, args.operands, args.defunct)


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, IOError):
        pass
    try:
        sys.stdout.close()
    except (BrokenPipeError, IOError):
        pass
