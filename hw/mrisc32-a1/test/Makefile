####################################################################################################
# Copyright (c) 2019 Marcus Geelnard
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

TEST_PATH = test

CP = cp

SRCS += \
    $(TEST_PATH)/alu_tb.vhd \
    $(TEST_PATH)/clz32_tb.vhd \
    $(TEST_PATH)/comparator_tb.vhd \
    $(TEST_PATH)/core_tb.vhd \
    $(TEST_PATH)/div_impl_tb.vhd \
    $(TEST_PATH)/div_pipelined_tb.vhd \
    $(TEST_PATH)/fadd_tb.vhd \
    $(TEST_PATH)/fetch_tb.vhd \
    $(TEST_PATH)/float_compare_tb.vhd \
    $(TEST_PATH)/float_decompose_tb.vhd \
    $(TEST_PATH)/fmul_tb.vhd \
    $(TEST_PATH)/fpu_tb.vhd \
    $(TEST_PATH)/ftoi_tb.vhd \
    $(TEST_PATH)/itof_clz_and_left_shift_tb.vhd \
    $(TEST_PATH)/itof_tb.vhd \
    $(TEST_PATH)/mem_arbiter_tb.vhd \
    $(TEST_PATH)/memory_tb.vhd \
    $(TEST_PATH)/mul_tb.vhd \
    $(TEST_PATH)/regs_scalar_tb.vhd \
    $(TEST_PATH)/regs_vector_tb.vhd \
    $(TEST_PATH)/reg_tb.vhd \
    $(TEST_PATH)/sau_tb.vhd \
    $(TEST_PATH)/shift32_tb.vhd \
    $(TEST_PATH)/shuf32_tb.vhd \
    $(TEST_PATH)/vector_control_tb.vhd \
    $(TEST_PATH)/vector_stride_gen_tb.vhd

TESTS += \
    alu_tb \
    clz32_tb \
    comparator_tb \
    core_tb \
    div_impl_tb \
    div_pipelined_tb \
    fadd_tb \
    fetch_tb \
    float_compare_tb \
    float_decompose_tb \
    fmul_tb \
    fpu_tb \
    ftoi_tb \
    itof_clz_and_left_shift_tb \
    itof_tb \
    mem_arbiter_tb \
    memory_tb \
    mul_tb \
    regs_scalar_tb \
    regs_vector_tb \
    reg_tb \
    sau_tb \
    shift32_tb \
    shuf32_tb \
    vector_control_tb \
    vector_stride_gen_tb

EXTRA += \
    $(WORKDIR)/fpu_test_gen

# Data generator for FPU test data.
$(WORKDIR)/fpu_test_gen: $(FPU_PATH)/fpu_test_gen.cpp
	g++ $(FPU_PATH)/fpu_test_gen.cpp -o $(WORKDIR)/fpu_test_gen

out/core_tb_prg.bin: $(SW_SRC_DIR)/test/super_test.s
	ninja -C $(SW_SRC_DIR) out/super_test.bin
	$(CP) $(SW_SRC_DIR)/out/super_test.bin out/core_tb_prg.bin

core_tb: out/core_tb_prg.bin

