#!/usr/bin/env python3
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

# ELF format interpreted according to: https://en.wikipedia.org/wiki/Executable_and_Linkable_Format

import argparse
import struct
import subprocess
import tempfile


def convert(in_path, out_path):
    # Read the ELF file header (we don't need all this information, but we keep the code here for
    # informational purposes).
    with open(in_path, 'rb') as f:
        byte_ctype = 'B'

        hdr = {}
        hdr['EI_MAG'] = struct.unpack('>L', f.read(4))[0]
        if hdr['EI_MAG'] != 0x7f454c46:
            raise ValueError('Not an ELF file')
        hdr['EI_CLASS'] = struct.unpack(byte_ctype, f.read(1))[0]
        hdr['EI_DATA'] = struct.unpack(byte_ctype, f.read(1))[0]
        hdr['EI_VERSION'] = struct.unpack(byte_ctype, f.read(1))[0]
        hdr['EI_OSABI'] = struct.unpack(byte_ctype, f.read(1))[0]
        hdr['EI_ABIVERSION'] = struct.unpack(byte_ctype, f.read(1))[0]
        f.read(7)  # EI_PAD
        if hdr['EI_CLASS'] != 1:
            raise ValueError('Not a 32-bit ELF file')
        if hdr['EI_CLASS'] == 1:
            # Little endian.
            short_ctype = '<H'
            long_ctype = '<L'
        elif hdr['EI_CLASS'] == 2:
            # Big endian.
            short_ctype = '>H'
            long_ctype = '>L'
        else:
            raise ValueError('Invalid EI_CLASS: {}'.format(hdr['EI_CLASS']))
        hdr['e_type'] = struct.unpack(short_ctype, f.read(2))[0]
        hdr['e_machine'] = struct.unpack(short_ctype, f.read(2))[0]
        hdr['e_version'] = struct.unpack(long_ctype, f.read(4))[0]
        hdr['e_entry'] = struct.unpack(long_ctype, f.read(4))[0]
        hdr['e_phoff'] = struct.unpack(long_ctype, f.read(4))[0]
        hdr['e_shoff'] = struct.unpack(long_ctype, f.read(4))[0]
        hdr['e_flags'] = struct.unpack(long_ctype, f.read(4))[0]
        hdr['e_ehsize'] = struct.unpack(short_ctype, f.read(2))[0]
        hdr['e_phentsize'] = struct.unpack(short_ctype, f.read(2))[0]
        hdr['e_phnum'] = struct.unpack(short_ctype, f.read(2))[0]
        hdr['e_shentsize'] = struct.unpack(short_ctype, f.read(2))[0]
        hdr['e_shnum'] = struct.unpack(short_ctype, f.read(2))[0]
        hdr['e_shstrndx'] = struct.unpack(short_ctype, f.read(2))[0]
        if hdr['e_phoff'] != 0x34:
            raise ValueError('Expected e_phoff=0x00000034, got: 0x{0:08x}'.format(hdr['e_phoff']))
        if hdr['e_machine'] != 0xc001:
            raise ValueError('Not an MRISC32 ELF file')

    # Use objcopy to convert the file into raw binary.
    with tempfile.NamedTemporaryFile(mode='w+b') as tf:
        tmp_file = tf.name
        cmd = ['mrisc32-elf-objcopy', '-O', 'binary', in_path, tmp_file]
        subprocess.run(cmd, check=True)

        # Prepend the load address and copy the converted file to the
        # destination.
        # TODO(m): Currently we assume that the program entry is the first address of the binary
        # file, so we use e_entry as the load address. Instead, we should use the lowest address
        # that is represented in the file.
        load_address = hdr['e_entry']
        with open(out_path, 'wb') as out_f:
            out_f.write(struct.pack('<L', load_address))

            BUFFER_SIZE = 10000
            with open(tmp_file, 'rb') as tmp_f:
                while True:
                    data = tmp_f.read(BUFFER_SIZE)
                    if len(data) == 0:
                        break
                    out_f.write(data)


def main():
    # Parse command line arguments.
    parser = argparse.ArgumentParser(
            description='Convert elf32-mrisc32 to MRISC32 bin (requires mrisc32-elf-objcopy)')
    parser.add_argument('file', metavar='ELF_FILE', help='the ELF file to convert')
    parser.add_argument('output', metavar='BIN_FILE', help='the output bin file')
    args = parser.parse_args()

    # Convert the file.
    convert(args.file, args.output)


if __name__ == "__main__":
    main()
