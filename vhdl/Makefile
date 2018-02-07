GHDL = ghdl

.PHONY: all clean

SRCS = \
    consts.vhd \
    adder.vhd \
    adder_tb.vhd \
    clz32.vhd \
    clz32_tb.vhd \
    comparator.vhd \
    comparator_tb.vhd \
    alu.vhd \
    alu_tb.vhd

all: $(SRCS)
	$(GHDL) -i $(SRCS)
	$(GHDL) -m adder_tb
	$(GHDL) -r adder_tb
	$(GHDL) -m clz32_tb
	$(GHDL) -r clz32_tb
	$(GHDL) -m comparator_tb
	$(GHDL) -r comparator_tb
	$(GHDL) -m alu_tb
	$(GHDL) -r alu_tb

clean:
	$(GHDL) --clean
	rm -rf *.o *.cf *_tb *.vcd
