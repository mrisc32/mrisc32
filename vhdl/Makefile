####################################################################################################
# Copyright (c) 2018 Marcus Geelnard
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
####################################################################################################

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
    shift32.vhd \
    shift32_tb.vhd \
    alu.vhd \
    alu_tb.vhd \
    reg.vhd \
    reg_tb.vhd \
    icache.vhd \
    icache_tb.vhd \
    reg32x32.vhd \
    reg32x32_tb.vhd

all: $(SRCS)
	$(GHDL) -i $(SRCS)
	$(GHDL) -m adder_tb
	$(GHDL) -r adder_tb
	$(GHDL) -m clz32_tb
	$(GHDL) -r clz32_tb
	$(GHDL) -m comparator_tb
	$(GHDL) -r comparator_tb
	$(GHDL) -m shift32_tb
	$(GHDL) -r shift32_tb
	$(GHDL) -m alu_tb
	$(GHDL) -r alu_tb
	$(GHDL) -m reg_tb
	$(GHDL) -r reg_tb
	$(GHDL) -m icache_tb
	$(GHDL) -r icache_tb
	$(GHDL) -m reg32x32_tb
	$(GHDL) -r reg32x32_tb

clean:
	$(GHDL) --clean
	rm -rf *.o *.cf *_tb *.vcd
