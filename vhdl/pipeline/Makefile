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

PIPELINE_PATH = pipeline

SRCS += \
    $(PIPELINE_PATH)/reg.vhd \
    $(PIPELINE_PATH)/reg_tb.vhd \
    $(PIPELINE_PATH)/regs_scalar.vhd \
    $(PIPELINE_PATH)/regs_scalar_tb.vhd \
    $(PIPELINE_PATH)/regs_vector.vhd \
    $(PIPELINE_PATH)/regs_vector_tb.vhd \
    $(PIPELINE_PATH)/vector_control.vhd \
    $(PIPELINE_PATH)/vector_control_tb.vhd \
    $(PIPELINE_PATH)/vector_stride_gen.vhd \
    $(PIPELINE_PATH)/vector_stride_gen_tb.vhd \
    $(PIPELINE_PATH)/pc_plus_4.vhd \
    $(PIPELINE_PATH)/pc_plus_offset.vhd \
    $(PIPELINE_PATH)/branch_target_buffer.vhd \
    $(PIPELINE_PATH)/program_counter.vhd \
    $(PIPELINE_PATH)/program_counter_tb.vhd \
    $(PIPELINE_PATH)/fetch.vhd \
    $(PIPELINE_PATH)/decode.vhd \
    $(PIPELINE_PATH)/execute.vhd \
    $(PIPELINE_PATH)/memory.vhd \
    $(PIPELINE_PATH)/forward_to_branch_logic.vhd \
    $(PIPELINE_PATH)/forward_to_ex.vhd \
    $(PIPELINE_PATH)/pipeline.vhd \
    $(PIPELINE_PATH)/pipeline_tb.vhd

TESTS += \
    reg_tb \
    regs_scalar_tb \
    regs_vector_tb \
    vector_control_tb \
    vector_stride_gen_tb \
    program_counter_tb \
    pipeline_tb

$(PIPELINE_PATH)/pipeline_tb_prg.bin: $(PIPELINE_PATH)/pipeline_tb_prg.s $(ASM)
	$(ASM) $<

pipeline_tb: $(PIPELINE_PATH)/pipeline_tb_prg.bin

