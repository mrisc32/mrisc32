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


class SystemRegisterDB:
    def __init__(self, file_name):
        with open(file_name, "r", encoding="utf8") as f:
            self.__db = yaml.load(f, Loader=yaml.FullLoader)["registers"]

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
        result += f"\\subsection{{{reg_escaped}}}\n\n"

        result += "\\begin{tabular}{|l|p{150pt}|}\n"
        result += "\\hline\n"
        result += "\\textbf{Number} & \\textbf{Name} \\\\\n"
        result += "\\hline\n"
        result += f"{meta['num']:#06x} & {meta['name']} \\\\\n"
        result += "\\hline\n"
        result += "\\end{tabular}\n\n"

        result += f"Read/write: {meta['rw']}\n\n"

        result += SystemRegisterDB.__descr_to_tex(meta)
        result += SystemRegisterDB.__todo_to_tex(meta)
        result += SystemRegisterDB.__note_to_tex(meta)

        return result

    def to_tex_manual(self, sort_alphabetically):
        reg_list = sorted(self.__db) if sort_alphabetically else list(self.__db)

        result = ""
        result += f"\\section{{Registers}}\n\n"
        for reg in reg_list:
            meta = self.__db[reg]
            result += SystemRegisterDB.__reg_to_tex(reg, meta)
            result += f"\\label{{reg:{reg}}}\n\n"

        return result

    def to_tex_list(self, sort_alphabetically):
        reg_list = sorted(self.__db) if sort_alphabetically else list(self.__db)

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
            meta = self.__db[reg]
            reg_escaped = escape_tex(reg)
            result += f"\\hyperref[reg:{reg}]{{{reg_escaped}}} & "
            result += f"{meta['num']:#06x} & "
            result += f"{tick_yes if 'R' in meta['rw'] else tick_no} & "
            result += f"{tick_yes if 'W' in meta['rw'] else tick_no} & "
            result += f"{meta['name']} \\\\\n"
            result += "\\hline\n"
        result += "\\end{tabularx}\n\n"

        return result
