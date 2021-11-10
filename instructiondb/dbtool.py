#!/usr/bin/env python3
# -*- mode: python; tab-width: 4; indent-tabs-mode: nil; -*-
# -------------------------------------------------------------------------------------------------
# Copyright (c) 2021 Marcus Geelnard
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
import sys
from pathlib import Path
from instruction_db import InstructionDB

__INSTRUCTIONS_YAML = Path(__file__).resolve().parent / "mrisc32-instructions.yaml"


def main():
    # Parse command line arguments.
    parser = argparse.ArgumentParser(
        description="Extract information from the MRISC32 insturction database",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "-a",
        "--artifact",
        required=True,
        help="select artifact: instr-full, instr-list, instr-opcodes, instr-counts",
    )
    parser.add_argument("-o", "--output", help="output file")
    parser.add_argument("--sort", action="store_true", help="sort alphabetically")
    args = parser.parse_args()

    # Read the instruction database.
    instruction_db = InstructionDB(__INSTRUCTIONS_YAML)

    # Parse the database and generate the output.
    if args.artifact == "instr-full":
        generated = instruction_db.to_tex_manual(sort_alphabetically=args.sort)
    elif args.artifact == "instr-list":
        generated = instruction_db.to_tex_list(sort_alphabetically=args.sort)
    elif args.artifact == "opcode-list":
        generated = instruction_db.to_tex_opcodes()
    elif args.artifact == "instr-counts":
        generated = instruction_db.to_tex_instr_counts()
    else:
        print(f"***Error: Unsupported artifact: {args.artifact}")
        sys.exit(1)

    # Write or print the generated output.
    if args.output:
        with open(args.output, "w", encoding="utf8") as f:
            f.write(generated)
    else:
        print(generated)


if __name__ == "__main__":
    main()
