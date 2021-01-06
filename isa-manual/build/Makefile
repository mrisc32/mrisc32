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

srcs = $(wildcard $(srcdir)/*.tex) instructions.tex
bibs = $(srcdir)/mrisc32-instruction-set-manual.bib
figs = mrisc32-logo.pdf

PDFLATEX := TEXINPUTS=$(srcdir): pdflatex -interaction=nonstopmode -halt-on-error
BIBTEX := BIBINPUTS=$(srcdir): bibtex
DBTOOL = $(srcdir)/../instructiondb/dbtool.py

.PHONY: all clean

all: $(pdfs)

clean:
	rm -rf $(pdfs) *.aux *.log *.bbl *.blg *.toc *.out *.pdf *.tex *~ \#*

mrisc32-logo.pdf: $(srcdir)/../doc/mrisc32-logo.svg
	inkscape -D -z --file=$< --export-pdf=$@

instructions.tex: $(srcdir)/../instructiondb/mrisc32-instructions.yaml $(DBTOOL)
	$(DBTOOL) --format tex --sort -o $@ $<

$(pdfs): %.pdf: $(srcdir)/%.tex $(srcs) $(figs) $(bibs)
	$(PDFLATEX) $*
	$(BIBTEX) $*
	$(PDFLATEX) $*
	$(PDFLATEX) $*

