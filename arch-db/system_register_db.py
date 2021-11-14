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

import yaml
from tex_helpers import escape_tex, text_to_tex


class SystemRegisterDBError(Exception):
    pass


class SystemRegisterDB:
    def __init__(self, file_name):
        with open(file_name, "r", encoding="utf8") as f:
            self.__db = yaml.load(f, Loader=yaml.FullLoader)

    @staticmethod
    def __regprops_to_tex(meta):
        tick_yes = "\\checkmark"
        tick_no = " "

        result = ""
        result += "\\begin{tabular}{|l|l|l|p{150pt}|}\n"
        result += "\\hline\n"
        result += "\\textbf{Number} & \\textbf{R} & \\textbf{W} & \\textbf{Name} \\\\\n"
        result += "\\hline\n"
        result += f"${meta['num']:04x}_{{16}}$ & "
        result += f"{tick_yes if 'R' in meta['rw'] else tick_no} & "
        result += f"{tick_yes if 'W' in meta['rw'] else tick_no} & "
        result += f"{meta['name']} \\\\\n"
        result += "\\hline\n"
        result += "\\end{tabular}\n\n"
        return result

    @staticmethod
    def __fields_to_tex(meta):
        result = "\\begin{bytefield}{32}\n"

        # Define the bytefield header.
        field_limits = set([0, 31])
        for short_name in meta["fields"]:
            field = meta["fields"][short_name]
            offs = field["offs"]
            width = field["width"]
            field_limits.update({offs, min(offs + width, 31)})
        bitheader = ",".join([str(x) for x in field_limits])
        result += f"  \\bitheader{{{bitheader}}} \\\\\n"

        # Extract all fields, and sort them in decreasing order.
        sorted_fields = []
        for short_name in meta["fields"]:
            field = meta["fields"][short_name]
            sorted_fields.append({"name": short_name, "offs": field["offs"], "width": field["width"]})
        sorted_fields = sorted(sorted_fields, reverse=True, key=lambda x: x["offs"])

        # Emit the LaTeX bytefield fields.
        pos = 32
        for field in sorted_fields:
            name = field["name"]
            offs = field["offs"]
            width = field["width"]
            pad = pos - (offs + width)
            if pad < 0:
                raise SystemRegisterDBError("Invalid bit field specification")
            if pad > 0:
                result += f"  \\bitboxes*{{1}}{{{'0' * pad}}} &\n"
            bit_tex = "\\tiny " if width <= 2 else ""
            bit_tex += escape_tex(name)
            result += f"  \\bitbox{{{width}}}{{{bit_tex}}} &\n"
            pos = offs
        if pos > 0:
            result += f"  \\bitboxes*{{1}}{{{'0' * pos}}}\n"
        result += "\\end{bytefield}\n\n"

        # Describe each field.
        for short_name in meta["fields"]:
            field = meta["fields"][short_name]
            name = field['name'] if "name" in field else short_name
            first_bit = field["offs"]
            last_bit = first_bit + field["width"] - 1
            if first_bit == last_bit:
                bit_range = f"bit {first_bit}"
            else:
                bit_range = f"bits <{last_bit}:{first_bit}>"
            result += f"\\paragraph{{{escape_tex(name)} ({bit_range})}}\n\n"
            result += text_to_tex(field["descr"]) + "\n\n"

        return result

    @staticmethod
    def __descr_to_tex(meta):
        if not "descr" in meta:
            return ""
        return text_to_tex(meta["descr"]) + "\n\n"

    @staticmethod
    def __note_to_tex(meta):
        if not "note" in meta:
            return ""
        return "\\begin{notebox}\n" + text_to_tex(meta["note"]) + "\n\\end{notebox}\n\n"

    @staticmethod
    def __todo_to_tex(meta):
        if not "todo" in meta:
            return ""
        return "\\begin{todobox}\n" + text_to_tex(meta["todo"]) + "\n\\end{todobox}\n\n"

    @staticmethod
    def __reg_to_tex(reg, meta):
        reg_escaped = escape_tex(reg)

        result = ""
        result += f"\\subsection{{{reg_escaped}}}\n"
        result += f"\\label{{reg:{reg}}}\n\n"

        result += SystemRegisterDB.__regprops_to_tex(meta)

        result += "\\subsubsection{Description}\n\n"
        result += SystemRegisterDB.__descr_to_tex(meta)

        result += "\\subsubsection{Fields}\n\n"
        result += SystemRegisterDB.__fields_to_tex(meta)

        result += SystemRegisterDB.__todo_to_tex(meta)
        result += SystemRegisterDB.__note_to_tex(meta)

        return result

    @staticmethod
    def __regs_to_tex(regs, sort_alphabetically):
        result = ""
        reg_list = sorted(insns) if sort_alphabetically else list(regs)
        for reg in reg_list:
            meta = regs[reg]
            result += SystemRegisterDB.__reg_to_tex(reg, meta)
        return result

    def to_tex_manual(self, sort_alphabetically):
        result = ""
        for category, regs in self.__db.items():
            result += f"\\section{{{category}}}\n\n"
            result += SystemRegisterDB.__regs_to_tex(regs, sort_alphabetically)
            result += "\\clearpage\n\n"
        return result

    def to_tex_list(self, sort_alphabetically):
        # Merge all registers into a single dictionary.
        all_regs = {}
        for _, regs in self.__db.items():
            all_regs = {**all_regs, **regs}
        reg_list = sorted(all_regs) if sort_alphabetically else list(all_regs)

        # Generate the list.
        result = ""
        result += "\\begin{tabularx}{\\linewidth}{|l|l|c|c|p{200pt}|}\n"
        result += "\\toprule\n"
        result += "\\hline\n"
        result += "\\textbf{Register} & \\textbf{Number} & \\textbf{R} & \\textbf{W} & \\textbf{Name} \\\\\n"
        result += "\\hline\n"
        result += "\\midrule\n"
        result += "\\endfirsthead\n"
        result += "\\toprule\n"
        result += "\\hline\n"
        result += "\\textbf{Register} & \\textbf{Number} & \\textbf{R} & \\textbf{W} & \\textbf{Name} \\\\\n"
        result += "\\hline\n"
        result += "\\midrule\n"
        result += "\\endhead\n"
        result += "\\midrule\n"
        result += "\\multicolumn{5}{r}{\\footnotesize(continued)}\n"
        result += "\\endfoot\n"
        result += "\\bottomrule\n"
        result += "\\endlastfoot\n"
        result += "\\hline\n"
        tick_yes = "\\checkmark"
        tick_no = " "
        for reg in reg_list:
            meta = all_regs[reg]
            reg_escaped = escape_tex(reg)
            result += f"\\hyperref[reg:{reg}]{{{reg_escaped}}} & "
            result += f"${meta['num']:04x}_{{16}}$ & "
            result += f"{tick_yes if 'R' in meta['rw'] else tick_no} & "
            result += f"{tick_yes if 'W' in meta['rw'] else tick_no} & "
            result += f"{meta['name']} \\\\\n"
            result += "\\hline\n"
        result += "\\end{tabularx}\n\n"

        return result
