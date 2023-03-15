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
from tex_helpers import text_to_tex


class InstructionDB:
    def __init__(self, file_name):
        with open(file_name, "r", encoding="utf8") as f:
            self.__db = yaml.load(f, Loader=yaml.FullLoader)["instructions"]

    @staticmethod
    def __gen_asm(name, meta):
        def get_packs(meta, fmt):
            if fmt in ["A", "B"] and meta["tMode"] == "P":
                return ["", ".B", ".H"]
            if fmt in ["A", "B"] and meta["tMode"] == "PH":
                return ["", ".H"]
            return [""]

        def get_scales(meta, fmt):
            if fmt == "A" and meta["tMode"] == "X":
                return ["", "*2", "*4", "*8"]
            return [""]

        def get_bit_modes(meta, fmt):
            if fmt == "A" and meta["tMode"] == "B":
                return ["", ".PN", ".NP", ".NN"]
            return [""]

        def get_sel_modes(meta, fmt):
            if fmt == "A" and meta["tMode"] == "S":
                return ["", ".132", ".213", ".231"]
            return [""]

        def get_width_modes(meta, fmt):
            if fmt in ["A", "B"] and meta["tMode"] == "W":
                return [".8", ".16", ".32"]
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
                if meta["vModes"]:
                    vecs.append(meta["vModes"][0])
            elif fmt in ["D", "E"]:
                vecs = ["SS"]
            return vecs

        def get_folds(meta, vec):
            if meta["fold"] and len(vec) == 3 and vec[-1] == "V":
                return ["", "/F"]
            return [""]

        def get_reg_prefix(scalar_or_vec):
            return "R" if scalar_or_vec == "S" else "V"

        def get_args(vec, fmt, imm_syntax):
            result = []
            suffixes = "abc"
            i = 0
            for c in vec:
                result += [f"{get_reg_prefix(c)}{suffixes[i]}"]
                i += 1
            if fmt in ["C", "D", "E"]:
                result = result[:-1] + [f"#{imm_syntax}"]

            return result

        def format_args(meta, args, scale):
            result = meta["asmOperands"]
            for i in range(len(args)):
                arg = args[i]
                if i == 2:
                    arg += scale
                result = result.replace(f"{{{i+1}}}", arg)
            return result

        def get_v_bits(vec, fold):
            if vec in ["VVV", "VSV"]:
                return "$01_{2}$" if fold else "$11_{2}$"
            elif vec in ["VVS", "VV", "VSS"]:
                return "$10_{2}$"
            else:
                return "$00_{2}$"

        def get_t_bits(pack, scale, bit_mode, sel_mode, width_mode):
            if pack == ".B" or scale == "*2" or bit_mode == ".PN" or sel_mode == ".132" or width_mode == ".16":
                return "$01_{2}$"
            elif (
                pack == ".H" or scale == "*4" or bit_mode == ".NP" or sel_mode == ".213" or width_mode == ".32"
            ):
                return "$10_{2}$"
            elif scale == "*8" or bit_mode == ".NN" or sel_mode == ".231":
                return "$11_{2}$"
            else:
                return "$00_{2}$"

        def get_imm_syntax(meta):
            return meta.get("immSyntax", "imm")

        result = []
        for fmt in meta["fmts"]:
            for vec in get_vecs(meta, fmt):
                args = get_args(vec, fmt, get_imm_syntax(meta))
                for fold in get_folds(meta, vec):
                    v = get_v_bits(vec, fold)
                    for pack in get_packs(meta, fmt):
                        for scale in get_scales(meta, fmt):
                            for bit_mode in get_bit_modes(meta, fmt):
                                for sel_mode in get_sel_modes(meta, fmt):
                                    for width_mode in get_width_modes(meta, fmt):
                                        t = get_t_bits(pack, scale, bit_mode, sel_mode, width_mode)
                                        s = f"{name}{pack}{bit_mode}{sel_mode}{width_mode}{fold} "
                                        s += " " * max(0, (8 - len(s)))
                                        s += format_args(meta, args, scale)
                                        result.append(
                                            {"fmt": fmt, "v": v, "t": t, "asm": s}
                                        )
        return result

    @staticmethod
    def __encoding_to_tex(meta):
        result = "\\begin{bytefield}{32}\n"

        # Determine the immediate value encoding format.
        if "immEnc" in meta:
            imm_enc = f"\\hyperref[imm:{meta['immEnc']}]{{{meta['immEnc']}}}"
        else:
            imm_enc = ""

        # Determine the minimum set of bit limits (for a pretty \bitheader).
        field_limits = set()
        for fmt in meta["fmts"]:
            if fmt == "A":
                field_limits.update({0, 7, 9, 14, 16, 21, 26, 31})
            elif fmt == "B":
                field_limits.update({0, 7, 9, 15, 16, 21, 26, 31})
            elif fmt == "C":
                field_limits.update({0, 15, 16, 21, 26, 31})
            elif fmt == "D":
                field_limits.update({0, 21, 26, 31})
            elif fmt == "E":
                field_limits.update({0, 18, 21, 26, 31})
        bitheader = ",".join([str(x) for x in field_limits])
        result += f" \\bitheader{{{bitheader}}} \\\\\n"

        has_reserved_fields = False
        for fmt in meta["fmts"]:
            # Determine reserved fields.
            reserved_v = fmt in ["A", "B", "C"] and len(meta["vModes"]) == 0
            reserved_t = fmt in ["A", "B"] and meta["tMode"] == "N"
            reserved_regs = len(meta["asmOperands"]) == 0
            if reserved_v or reserved_t or reserved_regs:
                has_reserved_fields = True

            result += f" \\begin{{rightwordgroup}}{{{fmt}}}\n"
            if fmt == "A":
                result += "  \\bitboxes*{1}{000000} &\n"
                if reserved_regs:
                    result += "  \\bitboxes*{1}[bgcolor=reserved]{00000} &\n"
                    result += "  \\bitboxes*{1}[bgcolor=reserved]{00000} &\n"
                else:
                    result += "  \\bitbox{5}{REGa} &\n"
                    result += "  \\bitbox{5}{REGb} &\n"
                if reserved_v:
                    result += "  \\bitboxes*{1}[bgcolor=reserved]{00} &\n"
                else:
                    result += "  \\bitbox{2}{V} &\n"
                if reserved_regs:
                    result += "  \\bitboxes*{1}[bgcolor=reserved]{00000} &\n"
                else:
                    result += "  \\bitbox{5}{REGc} &\n"
                if reserved_t:
                    result += "  \\bitboxes*{1}[bgcolor=reserved]{00} &\n"
                else:
                    result += "  \\bitbox{2}{T} &\n"
                result += f"  \\bitboxes*{{1}}{{{meta['op']:07b}}}\n"
            elif fmt == "B":
                result += "  \\bitboxes*{1}{000000} &\n"
                if reserved_regs:
                    result += "  \\bitboxes*{1}[bgcolor=reserved]{00000} &\n"
                    result += "  \\bitboxes*{1}[bgcolor=reserved]{00000} &\n"
                else:
                    result += "  \\bitbox{5}{REGa} &\n"
                    result += "  \\bitbox{5}{REGb} &\n"
                if reserved_v:
                    result += "  \\bitbox{1}[bgcolor=reserved]{0} &\n"
                else:
                    result += "  \\bitbox{1}{V} &\n"
                result += f"  \\bitboxes*{{1}}{{{meta['fn']:06b}}}\n"
                if reserved_t:
                    result += "  \\bitboxes*{1}[bgcolor=reserved]{00} &\n"
                else:
                    result += "  \\bitbox{2}{T} &\n"
                result += f"  \\bitboxes*{{1}}{{{meta['op']:07b}}}\n"
            elif fmt == "C":
                result += f"  \\bitboxes*{{1}}{{{meta['op']:06b}}} &\n"
                if reserved_regs:
                    result += "  \\bitboxes*{1}[bgcolor=reserved]{00000} &\n"
                    result += "  \\bitboxes*{1}[bgcolor=reserved]{00000} &\n"
                else:
                    result += "  \\bitbox{5}{REGa} &\n"
                    result += "  \\bitbox{5}{REGb} &\n"
                if reserved_v:
                    result += "  \\bitbox{1}[bgcolor=reserved]{0} &\n"
                else:
                    result += "  \\bitbox{1}{V} &\n"
                result += f"  \\bitbox{{15}}{{IM [{imm_enc}]}}\n"
            elif fmt == "D":
                result += f"  \\bitboxes*{{1}}{{110{(meta['op']):03b}}}\n"
                result += "  \\bitbox{5}{REGa} &\n"
                result += f"  \\bitbox{{21}}{{IM [{imm_enc}]}}\n"
            elif fmt == "E":
                result += "  \\bitboxes*{1}{110111}\n"
                result += "  \\bitbox{5}{REGa} &\n"
                result += f"  \\bitboxes*{{1}}{{{(meta['op']):03b}}}\n"
                result += f"  \\bitbox{{18}}{{IM [{imm_enc}]}}\n"
            result += f" \\end{{rightwordgroup}} \\\\\n"
        result += "\\end{bytefield}\n"

        # Prepend a note about reserved fields if they are present in any of the encodings.
        if has_reserved_fields:
            result = "{\\smallskip \\hfill \\footnotesize \\fcolorbox{black}{reserved}{0} Reserved}\n\n" + result

        return result


    @staticmethod
    def __requires_to_tex(meta):
        if not "requires" in meta:
            return ""
        reqs = []
        for req in meta["requires"]:
            reqs.append(f"\\hyperref[module:{req}]{{{req}}}")
        return f"\\textbf{{Requires:}} {', '.join(reqs)}\n\n"

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
    def __asm_to_tex(insn, meta):
        def has_multiple_values(asm_forms, field):
            v = asm_forms[0][field]
            for form in asm_forms:
                if form[field] != v:
                    return True
            return False

        asm_forms = InstructionDB.__gen_asm(insn, meta)
        show_fmt = has_multiple_values(asm_forms, "fmt")
        show_v = has_multiple_values(asm_forms, "v")
        show_t = has_multiple_values(asm_forms, "t")
        num_extra_columns = (
            (1 if show_fmt else 0) + (1 if show_v else 0) + (1 if show_t else 0)
        )

        result = "\\begin{tabular}{" + ("l|" * num_extra_columns) + "l}\n"
        result += " "
        if show_fmt:
            result += "\\scriptsize \\textbf{Fmt} & "
        if show_v:
            result += "\\scriptsize \\textbf{V} & "
        if show_t:
            result += "\\scriptsize \\textbf{T} & "
        result += "\\scriptsize \\textbf{Assembler} \\\\\n"
        result += "\\hline\n"
        for form in asm_forms:
            if show_fmt:
                result += f"{{\\scriptsize {form['fmt']}}} & "
            if show_v:
                result += f"{{\\scriptsize {form['v']}}} & "
            if show_t:
                result += f"{{\\scriptsize {form['t']}}} & "
            result += "\\begin{lstlisting}[style=assembler]\n"
            result += f"{form['asm']}\n"
            result += "\\end{lstlisting}\\\\\n"
        return result + "\\end{tabular}\n\n"

    @staticmethod
    def __pseudo_to_tex(meta):
        if not "pseudo" in meta:
            return ""
        result = "\\begin{lstlisting}[style=pseudocode]\n"
        result += meta["pseudo"]
        return result + "\\end{lstlisting}\n\n"

    @staticmethod
    def __insns_to_tex(insns, sort_alphabetically):
        result = ""
        name_list = sorted(insns) if sort_alphabetically else list(insns)
        for name in name_list:
            meta = insns[name]
            title = f"{name} - {meta['name']}"
            result += f"\\subsection{{{title}}}\n"
            result += f"\\label{{insn:{name}}}\n\n"
            result += InstructionDB.__requires_to_tex(meta)
            result += InstructionDB.__descr_to_tex(meta)
            result += InstructionDB.__todo_to_tex(meta)

            if "pseudo" in meta:
                result += "\\subsubsection{Operation}\n\n"
                result += InstructionDB.__pseudo_to_tex(meta)

            result += "\\subsubsection{Encoding}\n\n"
            result += InstructionDB.__encoding_to_tex(meta)

            result += "\\subsubsection{Variants}\n\n"
            result += InstructionDB.__asm_to_tex(name, meta)
            result += InstructionDB.__note_to_tex(meta)
        return result

    def to_tex_manual(self, sort_alphabetically):
        result = ""
        for category, insns in self.__db.items():
            result += f"\\section{{{category}}}\n\n"
            result += InstructionDB.__insns_to_tex(insns, sort_alphabetically)
            result += "\\clearpage\n\n"
        return result

    def to_tex_list(self, sort_alphabetically):
        result = ""

        # Merge all instructions into a single dictionary.
        all_insns = {}
        for _, insns in self.__db.items():
            all_insns = {**all_insns, **insns}
        name_list = sorted(all_insns) if sort_alphabetically else list(all_insns)

        # Generate the list.
        result += "\\begin{tabularx}{\\linewidth}{|l|c|c|c|c|p{200pt}|}\n"
        result += "\\toprule\n"
        result += "\\hline\n"
        result += "\\textbf{Instruction} & \\textbf{Base} & \\textbf{PM} & \\textbf{FM} & \\textbf{SM} & \\textbf{Name} \\\\\n"
        result += "\\hline\n"
        result += "\\midrule\n"
        result += "\\endfirsthead\n"
        result += "\\toprule\n"
        result += "\\hline\n"
        result += "\\textbf{Instruction} & \\textbf{Base} & \\textbf{PM} & \\textbf{FM} & \\textbf{SM} & \\textbf{Name} \\\\\n"
        result += "\\hline\n"
        result += "\\midrule\n"
        result += "\\endhead\n"
        result += "\\midrule\n"
        result += "\\multicolumn{6}{r}{\\footnotesize(continued)}\n"
        result += "\\endfoot\n"
        result += "\\bottomrule\n"
        result += "\\endlastfoot\n"
        result += "\\hline\n"
        tick_yes = "\\checkmark"
        tick_no = " "
        for name in name_list:
            meta = all_insns[name]
            result += f"\\hyperref[insn:{name}]{{{name}}} & "
            result += f"{tick_no if 'requires' in meta and len(meta['requires']) > 0 else tick_yes} & "
            result += f"{tick_yes if 'requires' in meta and 'PM' in meta['requires'] else tick_no} & "
            result += f"{tick_yes if 'requires' in meta and 'FM' in meta['requires'] else tick_no} & "
            result += f"{tick_yes if 'requires' in meta and 'SM' in meta['requires'] else tick_no} & "
            result += f"{meta['name']} \\\\\n"
            result += "\\hline\n"
        result += "\\end{tabularx}\n\n"

        return result

    def to_tex_opcodes(self):
        def to_tex_opcodes_helper(insns, fmt, op_min, op_max, fn_min=0, fn_max=0):
            result = f"\n\section{{Format {fmt} opcodes}}\n\n"

            has_fn_field = fn_max > fn_min
            num_columns = 8 if has_fn_field else 7

            table_head = ""
            table_head += "\\textbf{OP} & "
            if has_fn_field:
                table_head += "\\textbf{FN} & "
            table_head += "\\textbf{Instruction} & "
            table_head += "\\textbf{Base} & "
            table_head += "\\textbf{PM} & "
            table_head += "\\textbf{FM} & "
            table_head += "\\textbf{SM} & "
            table_head += "\\textbf{Name} \\\\\n"

            if has_fn_field:
                result += "\\begin{tabularx}{\\linewidth}{|l|l|l|c|c|c|c|p{175pt}|}\n"
            else:
                result += "\\begin{tabularx}{\\linewidth}{|l|l|c|c|c|c|p{200pt}|}\n"
            result += "\\toprule\n"
            result += "\\hline\n"
            result += table_head
            result += "\\hline\n"
            result += "\\midrule\n"
            result += "\\endfirsthead\n"
            result += "\\toprule\n"
            result += "\\hline\n"
            result += table_head
            result += "\\hline\n"
            result += "\\midrule\n"
            result += "\\endhead\n"
            result += "\\midrule\n"
            result += (
                f"\\multicolumn{{{num_columns}}}{{r}}{{\\footnotesize(continued)}}\n"
            )
            result += "\\endfoot\n"
            result += "\\bottomrule\n"
            result += "\\endlastfoot\n"
            result += "\\hline\n"
            tick_yes = "\\checkmark"
            tick_no = " "

            # Extract all opcodes for this format.
            opcode_names = {}
            for name in insns:
                meta = insns[name]
                if fmt in meta["fmts"]:
                    key = (meta["op"], meta.get("fn", 0))
                    opcode_names[key] = name

            # Print all opcodes for this format (including vacant positions)
            for op in range(op_min, op_max + 1):
                for fn in range(fn_min, fn_max + 1):
                    result += f"{op} & "
                    if has_fn_field:
                        result += f"{fn} & "
                    key = (op, fn)
                    if key in opcode_names:
                        name = opcode_names[key]
                        meta = insns[name]
                        result += f"\\hyperref[insn:{name}]{{{name}}} & "
                        result += f"{tick_no if 'requires' in meta and len(meta['requires']) > 0 else tick_yes} & "
                        result += f"{tick_yes if 'requires' in meta and 'PM' in meta['requires'] else tick_no} & "
                        result += f"{tick_yes if 'requires' in meta and 'FM' in meta['requires'] else tick_no} & "
                        result += f"{tick_yes if 'requires' in meta and 'SM' in meta['requires'] else tick_no} & "
                        result += f"{meta['name']} \\\\\n"
                    else:
                        result += f"- & & & & & \\\\\n"
                    result += "\\hline\n"
            result += "\\end{tabularx}\n\n"
            return result

        # Merge all instructions into a single dictionary.
        all_insns = {}
        for _, insns in self.__db.items():
            all_insns = {**all_insns, **insns}

        result = ""
        result += to_tex_opcodes_helper(all_insns, "A", op_min=0, op_max=123)
        result += to_tex_opcodes_helper(
            all_insns, "B", op_min=124, op_max=127, fn_min=0, fn_max=63
        )
        result += to_tex_opcodes_helper(all_insns, "C", op_min=1, op_max=47)
        result += to_tex_opcodes_helper(all_insns, "D", op_min=0, op_max=6)
        result += to_tex_opcodes_helper(all_insns, "E", op_min=0, op_max=7)

        return result

    def to_tex_instr_counts(self):
        # Count number of instructions per format.
        max_counts = {"A": 124, "B": 256, "C": 47, "D": 7, "E": 8}
        counts = {"A": 0, "B": 0, "C": 0, "D": 0, "E": 0}
        for _, insns in self.__db.items():
            for name in insns:
                meta = insns[name]
                for fmt in meta["fmts"]:
                    counts[fmt] += 1

        # Generate a summary of the number of instructions per encoding format.
        result = ""
        result += "\\begin{tabular}{|l|r|r|r|}\n"
        result += "\\hline\n"
        result += (
            "\\textbf{Format} & \\textbf{Count} & \\textbf{Max} & \\textbf{Used} \\\\\n"
        )
        result += "\\hline\n"
        for fmt in counts:
            used = 100 * counts[fmt] / max_counts[fmt]
            result += (
                f"{fmt} & {counts[fmt]} & {max_counts[fmt]} & {used:.0f}\\% \\\\\n"
            )
            result += "\\hline\n"
        result += "\\end{tabular}\n\n"

        return result
