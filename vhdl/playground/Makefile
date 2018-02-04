ANALYZE = ghdl -a
ELABORATE = ghdl -e
RUN = ghdl -r

.PHONY: all test clean

TESTS = \
    adder_tb \
    alu_tb

test: $(TESTS)
	$(RUN) adder_tb
	$(RUN) alu_tb

all: $(TESTS)

clean:
	rm -rf *.o *.cf *_tb

# Rule for linking test benches.
%_tb : %.o %_tb.o
	$(ELABORATE) $@

# Rule for analyzing VHDL files.
%.o : %.vhd
	$(ANALYZE) $<

