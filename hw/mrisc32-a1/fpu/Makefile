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

FPU_PATH = fpu

SRCS += \
    $(FPU_PATH)/float_decompose.vhd \
    $(FPU_PATH)/float_decompose_tb.vhd \
    $(FPU_PATH)/float_compose.vhd \
    $(FPU_PATH)/float_compare.vhd \
    $(FPU_PATH)/float_compare_tb.vhd \
    $(FPU_PATH)/fadd.vhd \
    $(FPU_PATH)/fadd_tb.vhd \
    $(FPU_PATH)/fmul.vhd \
    $(FPU_PATH)/fmul_tb.vhd \
    $(FPU_PATH)/ftoi.vhd \
    $(FPU_PATH)/ftoi_tb.vhd \
    $(FPU_PATH)/itof_clz_and_left_shift.vhd \
    $(FPU_PATH)/itof_clz_and_left_shift_tb.vhd \
    $(FPU_PATH)/itof.vhd \
    $(FPU_PATH)/itof_tb.vhd \
    $(FPU_PATH)/fpu_impl.vhd \
    $(FPU_PATH)/fpu.vhd \
    $(FPU_PATH)/fpu_tb.vhd

TESTS += \
    float_decompose_tb \
    float_compare_tb \
    fadd_tb \
    fmul_tb \
    ftoi_tb \
    itof_clz_and_left_shift_tb \
    itof_tb \
    fpu_tb

EXTRA += \
    $(WORKDIR)/fpu_test_gen

# Data generator for FPU test data.
$(WORKDIR)/fpu_test_gen: $(FPU_PATH)/fpu_test_gen.cpp
	g++ $(FPU_PATH)/fpu_test_gen.cpp -o $(WORKDIR)/fpu_test_gen
