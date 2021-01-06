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
import yaml


def read_db(file_name):
    with open(file_name, "r", encoding="utf8") as f:
        return yaml.load(f, Loader=yaml.FullLoader)["instructions"]


def get_packs(meta, fmt):
    if fmt == "A" and meta["tMode"] == "P":
        return ["", ".B", ".H"]
    return [""]


def get_scales(meta, fmt):
    if fmt == "A" and meta["tMode"] == "S":
        return ["", "*2", "*4", "*8"]
    return [""]


def get_vecs(meta, fmt):
    if fmt == "A":
        vecs = ["SSS"]
        vecs.extend(meta["vModes"])
    elif fmt == "B":
        vecs = ["SS"]
        vecs.extend(s[:2] for s in meta["vModes"])
    elif fmt == "C":
        vecs = ["SSS"]
        vecs.append(meta["vModes"][0])
    elif fmt == "D":
        vecs = ["SS"]
    return vecs


def get_folds(meta, vec):
    if len(vec) == 3 and vec[-1] == "V":
        return ["", "/F"]
    return [""]


def get_args(vec, fmt):
    result = []
    suffixes = "cab"
    i = 0
    for c in vec:
        result += [f"{c}{suffixes[i]}"]
        i += 1
    if fmt == "C":
        result = result[:-1] + ["#ext14(H,IM)"]
    elif fmt == "D":
        result = result[:-1] + ["#ext21(IM)"]

    return result


def gen_asm(name, meta):
    result = ""

    for fmt in meta["fmts"]:
        result += f"{fmt}:\n"
        for vec in get_vecs(meta, fmt):
            args = get_args(vec, fmt)
            for fold in get_folds(meta, vec):
                for pack in get_packs(meta, fmt):
                    for scale in get_scales(meta, fmt):
                        s = f"{name}{pack}{fold} "
                        s += " " * max(0, (8 - len(s)))
                        s += ", ".join(args) + scale
                        result += f"  {s}\n"

    return result


def insns_to_markdown(insns, sort_alphabetically):
    result = ""
    insn_list = sorted(insns) if sort_alphabetically else list(insns)
    for insn in insn_list:
        meta = insns[insn]
        result += f"### {insn}\n\n"
        result += meta["descr"].replace("\n", "\n\n")
        result += f"```\n{gen_asm(insn, meta)}```\n\n"
    return result


def db_to_markdown(db, sort_alphabetically):
    result = "# Instructions\n\n"
    for category, insns in db.items():
        result += f"## {category}\n\n"
        result += insns_to_markdown(insns, sort_alphabetically)
    return result


def encoding_to_tex(meta):
    result = "\\begin{bytefield}{32}\n  \\bitheader{0,7,9,14,15,16,21,26,31} \\\\\n"
    for fmt in meta["fmts"]:
        result += f" \\begin{{rightwordgroup}}{{{fmt}}}\n"
        if fmt == "A":
            result += "  \\bitboxes*{1}{000000} &\n"
            result += "  \\bitbox{5}{R1} &\n"
            result += "  \\bitbox{5}{R2} &\n"
            result += "  \\bitbox{2}{V} &\n"
            result += "  \\bitbox{5}{R3} &\n"
            result += "  \\bitbox{2}{T} &\n"
            result += f"  \\bitboxes*{{1}}{{{meta['op']:07b}}}\n"
        elif fmt == "B":
            pass  # TODO(m): Implement me - requires meta['fn'].
        elif fmt == "C":
            result += f"  \\bitboxes*{{1}}{{{meta['op']:06b}}} &\n"
            result += "  \\bitbox{5}{R1} &\n"
            result += "  \\bitbox{5}{R2} &\n"
            result += "  \\bitbox{1}{V} &\n"
            result += "  \\bitbox{1}{H} &\n"
            result += "  \\bitbox{14}{IM}\n"
        elif fmt == "D":
            pass  # TODO(m): Implement me.
        result += f" \\end{{rightwordgroup}} \\\\\n"
    return result + "\\end{bytefield}\n\n"


def descr_to_tex(meta):
    paragraphs = meta["descr"].split("\n")
    result = ""
    for par in paragraphs:
        if par.startswith("TODO: "):
            result += f"\\todo{{{par.replace('TODO: ', '')}}}\n\n"
        else:
            result += f"{par}\n\n"
    return result


def insns_to_tex(insns, sort_alphabetically):
    result = ""
    insn_list = sorted(insns) if sort_alphabetically else list(insns)
    for insn in insn_list:
        meta = insns[insn]
        result += f"\\subsection{{{insn}}}\n\n"
        result += descr_to_tex(meta)
        result += encoding_to_tex(meta)
        result += f"\\begin{{lstlisting}}[style=assembler]\n{gen_asm(insn, meta)}\\end{{lstlisting}}\n\n"
    return result


def db_to_tex(db, sort_alphabetically):
    result = """% -*- mode: latex; tab-width: 2; indent-tabs-mode: nil; -*-
%------------------------------------------------------------------------------
% MRISC32 ISA Manual - Instructions.
%
% This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
% International License. To view a copy of this license, visit
% http://creativecommons.org/licenses/by-sa/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
%------------------------------------------------------------------------------

\chapter{Instructions}

"""
    for category, insns in db.items():
        result += f"\\section{{{category}}}\n\n"
        result += insns_to_tex(insns, sort_alphabetically)
    return result


def main():
    # Parse command line arguments.
    parser = argparse.ArgumentParser(
        description="Extract information from the MRISC32 insturction database"
    )
    parser.add_argument(
        "-f", "--format", default="md", help="output format: md, tex (default: md)"
    )
    parser.add_argument("-o", "--output", help="output file")
    parser.add_argument(
        "--sort", action="store_true", help="sort instructions alphabetically"
    )
    parser.add_argument("db", help="the MRISC32 instruction database yaml file")
    args = parser.parse_args()

    # Read the database.
    db = read_db(args.db)

    # Parse the database and generate the output.
    if args.format == "md":
        generated = db_to_markdown(db, sort_alphabetically=args.sort)
    elif args.format == "tex":
        generated = db_to_tex(db, sort_alphabetically=args.sort)
    else:
        print(f"***Error: Unsupported output format: {args.format}")
        sys.exit(1)

    # Write or print the generated output.
    if args.output:
        with open(args.output, "w", encoding="utf8") as f:
            f.write(generated)
    else:
        print(generated)


if __name__ == "__main__":
    main()
