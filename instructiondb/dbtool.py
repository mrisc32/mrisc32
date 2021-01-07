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
    if fmt in ["A", "B"] and meta["tMode"] == "P":
        return ["", ".B", ".H"]
    return [""]


def get_scales(meta, fmt):
    if fmt == "A" and meta["tMode"] == "X":
        return ["", "*2", "*4", "*8"]
    return [""]


def get_sel_modes(meta, fmt):
    if fmt == "A" and meta["tMode"] == "S":
        return ["", "_1", "_2", "_3"]
    return [""]


def get_vecs(meta, fmt):
    if fmt == "A":
        vecs = ["SSS"]
        vecs.extend(meta["vModes"])
    elif fmt == "B":
        vecs = ["SS"]
        vecs.extend(meta["vModes"])
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
    suffixes = "abc"
    i = 0
    for c in vec:
        result += [f"{c}{suffixes[i]}"]
        i += 1
    if fmt == "C":
        result = result[:-1] + ["#ext14(H,IM)"]
    elif fmt == "D":
        result = result[:-1] + ["#ext21(IM)"]

    return result


def format_args(meta, args):
    result = meta["asmOperands"]
    for i in range(len(args)):
        result = result.replace(f"{{{i+1}}}", args[i])
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
                        for sel_mode in get_sel_modes(meta, fmt):
                            s = f"{name}{sel_mode}{pack}{fold} "
                            s += " " * max(0, (8 - len(s)))
                            s += format_args(meta, args) + scale
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
    result = "\\begin{bytefield}{32}\n"

    # Determine the minimum set of bit limits (for a pretty \bitheader).
    field_limits = set()
    for fmt in meta["fmts"]:
        if fmt == "A":
            field_limits.update({0,7,9,14,16,21,26,31})
        elif fmt == "B":
            field_limits.update({0,7,9,15,16,21,26,31})
        elif fmt == "C":
            field_limits.update({0,14,15,16,21,26,31})
        elif fmt == "D":
            field_limits.update({0,21,26,31})
    bitheader = ",".join([str(x) for x in field_limits])
    result += f" \\bitheader{{{bitheader}}} \\\\\n"

    for fmt in meta["fmts"]:
        result += f" \\begin{{rightwordgroup}}{{{fmt}}}\n"
        if fmt == "A":
            result += "  \\bitboxes*{1}{000000} &\n"
            result += "  \\bitbox{5}{Ra} &\n"
            result += "  \\bitbox{5}{Rb} &\n"
            result += "  \\bitbox{2}{V} &\n"
            result += "  \\bitbox{5}{Rc} &\n"
            result += "  \\bitbox{2}{T} &\n"
            result += f"  \\bitboxes*{{1}}{{{meta['op']:07b}}}\n"
        elif fmt == "B":
            result += "  \\bitboxes*{1}{000000} &\n"
            result += "  \\bitbox{5}{Ra} &\n"
            result += "  \\bitbox{5}{Rb} &\n"
            result += "  \\bitbox{1}{V} &\n"
            result += f"  \\bitboxes*{{1}}{{{meta['fn']:06b}}}\n"
            result += "  \\bitbox{2}{T} &\n"
            result += f"  \\bitboxes*{{1}}{{{meta['op']:07b}}}\n"
        elif fmt == "C":
            result += f"  \\bitboxes*{{1}}{{{meta['op']:06b}}} &\n"
            result += "  \\bitbox{5}{Ra} &\n"
            result += "  \\bitbox{5}{Rb} &\n"
            result += "  \\bitbox{1}{V} &\n"
            result += "  \\bitbox{1}{H} &\n"
            result += "  \\bitbox{14}{IM}\n"
        elif fmt == "D":
            result += f"  \\bitboxes*{{1}}{{{(48+meta['op']):06b}}}\n"
            result += "  \\bitbox{5}{Ra} &\n"
            result += "  \\bitbox{21}{IM}\n"
        result += f" \\end{{rightwordgroup}} \\\\\n"
    return result + "\\end{bytefield}\n\n"


def escape_tex(s):
    s = s.replace("\\", "\\textbackslash ")
    s = s.replace("~", "\\textasciitilde ")
    s = s.replace("^", "\\textasciicircum ")
    s = s.replace("...", "\\ldots ")
    for c in "&%$#_{}":
        s = s.replace(c, f"\\{c}")
    return s


def text_to_tex(s):
    paragraphs = s.split("\n")
    result = ""
    for par in paragraphs:
        par = escape_tex(par)
        if par:
            if result:
                result += "\n\n"
            result += par
    return result


def descr_to_tex(meta):
    if not "descr" in meta:
        return ""
    return text_to_tex(meta["descr"]) + "\n\n"


def note_to_tex(meta):
    if not "note" in meta:
        return ""
    return "\\begin{notebox}\n" + text_to_tex(meta["note"]) + "\n\\end{notebox}\n\n"


def todo_to_tex(meta):
    if not "todo" in meta:
        return ""
    return "\\begin{todobox}\n" + text_to_tex(meta["todo"]) + "\n\\end{todobox}\n\n"


def insns_to_tex(insns, sort_alphabetically):
    result = ""
    insn_list = sorted(insns) if sort_alphabetically else list(insns)
    for insn in insn_list:
        meta = insns[insn]
        result += f"\\subsection{{{insn}}}\n\n"
        result += descr_to_tex(meta)
        result += todo_to_tex(meta)
        result += encoding_to_tex(meta)
        result += f"\\begin{{lstlisting}}[style=assembler]\n{gen_asm(insn, meta)}\\end{{lstlisting}}\n\n"
        result += note_to_tex(meta)
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
        result += "\\clearpage\n\n"
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