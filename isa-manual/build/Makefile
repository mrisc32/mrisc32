# -*- mode: Makefile; tab-width: 8; indent-tabs-mode: t; -*-
#------------------------------------------------------------------------------
# MRISC32 ISA Manual - Makefile.
#
# This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/4.0/ or send a letter to
# Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
#------------------------------------------------------------------------------

srcdir = ..

docs = mrisc32-instruction-set-manual
pdfs = $(addsuffix .pdf, $(docs))

generated_tex = gen-version.tex \
                gen-instruction-counts.tex \
				gen-instructions.tex \
				gen-instruction-list.tex \
				gen-opcode-list.tex \
				gen-system-registers.tex \
				gen-system-register-list.tex

srcs = $(wildcard $(srcdir)/*.tex) $(generated_tex)
bibs = $(srcdir)/mrisc32-instruction-set-manual.bib
figs = mrisc32-logo.pdf

PDFLATEX := TEXINPUTS=$(srcdir): pdflatex -interaction=nonstopmode -halt-on-error
BIBTEX := BIBINPUTS=$(srcdir): bibtex
DBTOOL = $(srcdir)/../arch-db/dbtool.py \

insdb_files = $(DBTOOL) \
              $(srcdir)/../arch-db/instruction_db.py \
              $(srcdir)/../arch-db/mrisc32-instructions.yaml
regdb_files = $(DBTOOL) \
              $(srcdir)/../arch-db/system_register_db.py \
              $(srcdir)/../arch-db/mrisc32-system-registers.yaml

.PHONY: all clean

all: $(pdfs)

clean:
	rm -rf $(pdfs) *.aux *.log *.bbl *.blg *.toc *.out *.pdf *.tex *~ \#*

mrisc32-logo.pdf: $(srcdir)/../media/mrisc32-logo.svg
	cairosvg $< -o $@

# Generate a version file based on the latest Git tag.
.PHONY: .FORCE-VERSION.TEX
gen-version.tex: .FORCE-VERSION.TEX
	$(srcdir)/get_version.sh $@

gen-instruction-counts.tex: $(insdb_files)
	$(DBTOOL) --artifact instr-counts -o $@

gen-instructions.tex: $(insdb_files)
	$(DBTOOL) --artifact instr-full -o $@

gen-instruction-list.tex: $(insdb_files)
	$(DBTOOL) --artifact instr-list --sort -o $@

gen-opcode-list.tex: $(insdb_files)
	$(DBTOOL) --artifact instr-opcodes -o $@

gen-system-registers.tex: $(regdb_files)
	$(DBTOOL) --artifact reg-full -o $@

gen-system-register-list.tex: $(regdb_files)
	$(DBTOOL) --artifact reg-list -o $@

$(pdfs): %.pdf: $(srcdir)/%.tex $(srcs) $(figs) $(bibs)
	$(PDFLATEX) $*
	$(BIBTEX) $*
	$(PDFLATEX) $*
	$(PDFLATEX) $*
