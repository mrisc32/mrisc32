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
GHDLFLAGS = --std=93 --work=work

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
    regs_scalar.vhd \
    regs_scalar_tb.vhd \
    branch_target_cache.vhd \
    pipeline_if.vhd \
    pipeline_id.vhd \
    pipeline_ex.vhd \
    pipeline_mem.vhd

TESTS = \
    adder_tb \
    clz32_tb \
    comparator_tb \
    shift32_tb \
    alu_tb \
    reg_tb \
    icache_tb \
    regs_scalar_tb

all: $(TESTS)

$(TESTS): work-obj93.cf $(SRCS)
	$(GHDL) -m $(GHDLFLAGS) $@
	$(GHDL) -r $(GHDLFLAGS) $@

clean:
	$(GHDL) --clean
	rm -rf *.o *.cf *_tb *.vcd

work-obj93.cf: $(SRCS)
	$(GHDL) -i $(GHDLFLAGS) $(SRCS)

