----------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 Marcus Geelnard
--
-- This software is provided 'as-is', without any express or implied warranty. In no event will the
-- authors be held liable for any damages arising from the use of this software.
--
-- Permission is granted to anyone to use this software for any purpose, including commercial
-- applications, and to alter it and redistribute it freely, subject to the following restrictions:
--
--  1. The origin of this software must not be misrepresented; you must not claim that you wrote
--     the original software. If you use this software in a product, an acknowledgment in the
--     product documentation would be appreciated but is not required.
--
--  2. Altered source versions must be plainly marked as such, and must not be misrepresented as
--     being the original software.
--
--  3. This notice may not be removed or altered from any source distribution.
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- This is the complete pipeline, with all pipeline stages connected together.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity pipeline is
  port(
      -- Control signals.
      i_clk : in std_logic;
      i_rst : in std_logic;

      -- Memory interface.
      o_mem_req : out std_logic;  -- 1 = request, 0 = nop
      o_mem_we : out std_logic;   -- 1 = write, 0 = read
      o_mem_byte_mask : out std_logic_vector(C_WORD_SIZE/8-1 downto 0);
      o_mem_addr : out std_logic_vector(C_WORD_SIZE-1 downto 2);
      o_mem_write_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_mem_read_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_mem_read_data_ready : in std_logic
    );
end pipeline;

architecture rtl of pipeline is
  -- From PC.
  signal s_pc_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- From IF.
  signal s_if_stall : std_logic;

  signal s_if_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_if_instr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_if_bubble : std_logic;

  -- From ID.
  signal s_id_stall : std_logic;

  signal s_id_vl_requested : std_logic;

  signal s_id_next_sreg_a_reg : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_id_next_sreg_b_reg : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_id_next_sreg_c_reg : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_id_next_vreg_a_reg : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_id_next_vreg_a_element : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
  signal s_id_next_vreg_b_reg : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_id_next_vreg_b_element : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);

  signal s_id_branch_is_branch : std_logic;
  signal s_id_branch_is_unconditional : std_logic;
  signal s_id_branch_is_reg : std_logic;
  signal s_id_branch_condition : T_BRANCH_COND;

  signal s_id_reg_a_required : std_logic;
  signal s_id_reg_b_required : std_logic;
  signal s_id_reg_c_required : std_logic;
  signal s_id_src_a_mode : T_SRC_A_MODE;
  signal s_id_src_b_mode : T_SRC_B_MODE;
  signal s_id_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_imm : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_is_first_vector_op_cycle : std_logic;
  signal s_id_address_offset_is_stride : std_logic;
  signal s_id_src_reg_a : T_SRC_REG;
  signal s_id_src_reg_b : T_SRC_REG;
  signal s_id_src_reg_c : T_SRC_REG;
  signal s_id_dst_reg : T_DST_REG;
  signal s_id_packed_mode : T_PACKED_MODE;
  signal s_id_alu_op : T_ALU_OP;
  signal s_id_mem_op : T_MEM_OP;
  signal s_id_mul_op : T_MUL_OP;
  signal s_id_div_op : T_DIV_OP;
  signal s_id_fpu_op : T_FPU_OP;
  signal s_id_alu_en : std_logic;
  signal s_id_mem_en : std_logic;
  signal s_id_mul_en : std_logic;
  signal s_id_div_en : std_logic;
  signal s_id_fpu_en : std_logic;

  -- From REG.
  signal s_rf_stall : std_logic;

  signal s_rf_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_rf_pc_plus_4 : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_rf_branch_is_branch : std_logic;
  signal s_rf_branch_is_reg : std_logic;
  signal s_rf_branch_offset_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_rf_branch_reg_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_rf_branch_is_taken : std_logic;

  signal s_rf_src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_rf_src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_rf_src_c : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_rf_is_first_vector_op_cycle : std_logic;
  signal s_rf_address_offset_is_stride : std_logic;

  signal s_rf_src_reg_a : T_SRC_REG;
  signal s_rf_reg_a_required : std_logic;
  signal s_rf_src_reg_b : T_SRC_REG;
  signal s_rf_reg_b_required : std_logic;
  signal s_rf_src_reg_c : T_SRC_REG;
  signal s_rf_reg_c_required : std_logic;
  signal s_rf_dst_reg : T_DST_REG;
  signal s_rf_packed_mode : T_PACKED_MODE;
  signal s_rf_alu_op : T_ALU_OP;
  signal s_rf_mem_op : T_MEM_OP;
  signal s_rf_mul_op : T_MUL_OP;
  signal s_rf_div_op : T_DIV_OP;
  signal s_rf_fpu_op : T_FPU_OP;
  signal s_rf_alu_en : std_logic;
  signal s_rf_mem_en : std_logic;
  signal s_rf_mul_en : std_logic;
  signal s_rf_div_en : std_logic;
  signal s_rf_fpu_en : std_logic;

  -- From EX1/EX2.
  signal s_ex_stall : std_logic;

  -- From EX1.
  signal s_ex1_pccorr_target : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex1_pccorr_source : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex1_pccorr_is_branch : std_logic;
  signal s_ex1_pccorr_is_taken : std_logic;
  signal s_ex1_pccorr_adjust : std_logic;
  signal s_ex1_pccorr_adjusted_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Operand forwarding signals from EX1.
  signal s_ex1_next_dst_reg : T_DST_REG;
  signal s_ex1_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex1_next_result_ready : std_logic;
  signal s_ex1_dst_reg : T_DST_REG;
  signal s_ex1_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex1_result_ready : std_logic;

  -- From EX2.
  signal s_ex2_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex2_result_ready : std_logic;
  signal s_ex2_dst_reg : T_DST_REG;

  -- Operand forwarding signals from EX2.
  signal s_ex2_next_dst_reg : T_DST_REG;
  signal s_ex2_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex2_next_result_ready : std_logic;

  -- From EX3.
  signal s_ex3_dst_reg : T_DST_REG;
  signal s_ex3_result : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Operand forwarding signals from EX3.
  signal s_ex3_next_dst_reg : T_DST_REG;
  signal s_ex3_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Operand forwarding signals.
  signal s_branch_fwd_value : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_branch_fwd_use_value : std_logic;
  signal s_branch_fwd_value_ready : std_logic;

  signal s_vl_fwd_value : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_vl_fwd_use_value : std_logic;
  signal s_vl_fwd_value_ready : std_logic;

  signal s_reg_a_fwd_value : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_reg_a_fwd_use_value : std_logic;
  signal s_reg_a_fwd_value_ready : std_logic;

  signal s_reg_b_fwd_value : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_reg_b_fwd_use_value : std_logic;
  signal s_reg_b_fwd_value_ready : std_logic;

  signal s_reg_c_fwd_value : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_reg_c_fwd_use_value : std_logic;
  signal s_reg_c_fwd_value_ready : std_logic;

  -- Signal for cancelling speculative instructions in IF and ID.
  signal s_cancel_speculative_instructions : std_logic;

  -- Stall logic.
  signal s_stall_pc : std_logic;
  signal s_stall_if : std_logic;
  signal s_stall_id : std_logic;
  signal s_stall_rf : std_logic;

  -- ICache interface.
  signal s_icache_req : std_logic;
  signal s_icache_addr : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_icache_read_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_icache_read_data_ready : std_logic;

  signal s_icache_mem_req : std_logic;
  signal s_icache_mem_addr : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_icache_mem_read_data: std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_icache_mem_read_data_ready : std_logic;

  -- DCache interface.
  signal s_dcache_req : std_logic;  -- 1 = request, 0 = nop
  signal s_dcache_we : std_logic;   -- 1 = write, 0 = read
  signal s_dcache_byte_mask : std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_dcache_addr : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_dcache_write_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_dcache_read_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_dcache_read_data_ready : std_logic;

  signal s_dcache_mem_req : std_logic;
  signal s_dcache_mem_we : std_logic;
  signal s_dcache_mem_byte_mask: std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_dcache_mem_addr: std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_dcache_mem_write_data: std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_dcache_mem_read_data: std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_dcache_mem_read_data_ready : std_logic;
begin
  --------------------------------------------------------------------------------------------------
  -- Pipeline stages.
  --------------------------------------------------------------------------------------------------

  -- PC: Program counter.

  program_counter_0: entity work.program_counter
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_stall => s_stall_pc,

      -- Results from the branch/PC correction unit in the EX stage (async).
      i_pccorr_source => s_ex1_pccorr_source,
      i_pccorr_target => s_ex1_pccorr_target,
      i_pccorr_is_branch => s_ex1_pccorr_is_branch,
      i_pccorr_is_taken => s_ex1_pccorr_is_taken,
      i_pccorr_adjust => s_ex1_pccorr_adjust,
      i_pccorr_adjusted_pc => s_ex1_pccorr_adjusted_pc,

      -- To IF stage (sync).
      o_pc => s_pc_pc
    );


  -- IF: Instruction fetch.

  fetch_0: entity work.fetch
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_stall => s_stall_if,
      o_stall => s_if_stall,
      i_cancel => s_cancel_speculative_instructions,

      -- Signals from the PC stage.
      i_pc => s_pc_pc,

      -- ICache interface.
      o_icache_req => s_icache_req,
      o_icache_addr => s_icache_addr,
      i_icache_data => s_icache_read_data,
      i_icache_data_ready => s_icache_read_data_ready,

      -- To ID stage (sync).
      o_pc => s_if_pc,
      o_instr => s_if_instr,
      o_bubble => s_if_bubble
    );


  -- ID: Instruction decode.

  decode_0: entity work.decode
    port map (
      -- Control signals.
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => s_stall_id,
      o_stall => s_id_stall,
      i_cancel => s_cancel_speculative_instructions,

      -- From the IF stage (sync).
      i_pc => s_if_pc,
      i_instr => s_if_instr,
      i_bubble => s_if_bubble,

      -- Information to the operand forwarding logic (async).
      o_vl_requested => s_id_vl_requested,

      -- Operand forwarding to the vector control unit (async).
      i_vl_fwd_value => s_vl_fwd_value,
      i_vl_fwd_use_value => s_vl_fwd_use_value,
      i_vl_fwd_value_ready => s_vl_fwd_value_ready,

      -- WB data from the EX2 stage (sync).
      i_wb_data_w => s_ex2_result,
      i_wb_we => s_ex2_dst_reg.is_target,
      i_wb_sel_w => s_ex2_dst_reg.reg,
      i_wb_is_vector => s_ex2_dst_reg.is_vector,

      -- To the RF stage (async).
      o_next_sreg_a_reg => s_id_next_sreg_a_reg,
      o_next_sreg_b_reg => s_id_next_sreg_b_reg,
      o_next_sreg_c_reg => s_id_next_sreg_c_reg,
      o_next_vreg_a_reg => s_id_next_vreg_a_reg,
      o_next_vreg_a_element => s_id_next_vreg_a_element,
      o_next_vreg_b_reg => s_id_next_vreg_b_reg,
      o_next_vreg_b_element => s_id_next_vreg_b_element,

      -- To the RF stage (sync).
      o_branch_is_branch => s_id_branch_is_branch,
      o_branch_is_unconditional => s_id_branch_is_unconditional,
      o_branch_is_reg => s_id_branch_is_reg,
      o_branch_condition => s_id_branch_condition,

      o_reg_a_required => s_id_reg_a_required,
      o_reg_b_required => s_id_reg_b_required,
      o_reg_c_required => s_id_reg_c_required,
      o_src_a_mode => s_id_src_a_mode,
      o_src_b_mode => s_id_src_b_mode,
      o_pc => s_id_pc,
      o_imm => s_id_imm,
      o_is_first_vector_op_cycle => s_id_is_first_vector_op_cycle,
      o_address_offset_is_stride => s_id_address_offset_is_stride,
      o_src_reg_a => s_id_src_reg_a,
      o_src_reg_b => s_id_src_reg_b,
      o_src_reg_c => s_id_src_reg_c,
      o_dst_reg => s_id_dst_reg,
      o_packed_mode => s_id_packed_mode,
      o_alu_op => s_id_alu_op,
      o_mem_op => s_id_mem_op,
      o_mul_op => s_id_mul_op,
      o_div_op => s_id_div_op,
      o_fpu_op => s_id_fpu_op,
      o_alu_en => s_id_alu_en,
      o_mem_en => s_id_mem_en,
      o_mul_en => s_id_mul_en,
      o_div_en => s_id_div_en,
      o_fpu_en => s_id_fpu_en
    );


  -- RF: Register fetch.

  register_fetch_0: entity work.register_fetch
    port map (
      -- Control signals.
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => s_stall_rf,
      o_stall => s_rf_stall,
      i_cancel => s_cancel_speculative_instructions,

      -- From the ID stage (async).
      i_next_sreg_a_reg => s_id_next_sreg_a_reg,
      i_next_sreg_b_reg => s_id_next_sreg_b_reg,
      i_next_sreg_c_reg => s_id_next_sreg_c_reg,
      i_next_vreg_a_reg => s_id_next_vreg_a_reg,
      i_next_vreg_a_element => s_id_next_vreg_a_element,
      i_next_vreg_b_reg => s_id_next_vreg_b_reg,
      i_next_vreg_b_element => s_id_next_vreg_b_element,

      -- From the ID stage (sync).
      i_branch_is_branch => s_id_branch_is_branch,
      i_branch_is_unconditional => s_id_branch_is_unconditional,
      i_branch_is_reg => s_id_branch_is_reg,
      i_branch_condition => s_id_branch_condition,

      i_reg_a_required => s_id_reg_a_required,
      i_reg_b_required => s_id_reg_b_required,
      i_reg_c_required => s_id_reg_c_required,
      i_src_a_mode => s_id_src_a_mode,
      i_src_b_mode => s_id_src_b_mode,
      i_pc => s_id_pc,
      i_imm => s_id_imm,
      i_is_first_vector_op_cycle => s_id_is_first_vector_op_cycle,
      i_address_offset_is_stride => s_id_address_offset_is_stride,
      i_src_reg_a => s_id_src_reg_a,
      i_src_reg_b => s_id_src_reg_b,
      i_src_reg_c => s_id_src_reg_c,
      i_dst_reg => s_id_dst_reg,
      i_packed_mode => s_id_packed_mode,
      i_alu_op => s_id_alu_op,
      i_mem_op => s_id_mem_op,
      i_mul_op => s_id_mul_op,
      i_div_op => s_id_div_op,
      i_fpu_op => s_id_fpu_op,
      i_alu_en => s_id_alu_en,
      i_mem_en => s_id_mem_en,
      i_mul_en => s_id_mul_en,
      i_div_en => s_id_div_en,
      i_fpu_en => s_id_fpu_en,

      -- Information to the operand forwarding logic (async).
      o_src_reg_a => s_rf_src_reg_a,
      o_reg_a_required => s_rf_reg_a_required,
      o_src_reg_b => s_rf_src_reg_b,
      o_reg_b_required => s_rf_reg_b_required,
      o_src_reg_c => s_rf_src_reg_c,
      o_reg_c_required => s_rf_reg_c_required,

      -- Operand forwarding to the branch logic (async).
      i_branch_fwd_value => s_branch_fwd_value,
      i_branch_fwd_use_value => s_branch_fwd_use_value,
      i_branch_fwd_value_ready => s_branch_fwd_value_ready,

      -- Operand forwarding to EX1 input (async).
      i_reg_a_fwd_value => s_reg_a_fwd_value,
      i_reg_a_fwd_use_value => s_reg_a_fwd_use_value,
      i_reg_a_fwd_value_ready => s_reg_a_fwd_value_ready,
      i_reg_b_fwd_value => s_reg_b_fwd_value,
      i_reg_b_fwd_use_value => s_reg_b_fwd_use_value,
      i_reg_b_fwd_value_ready => s_reg_b_fwd_value_ready,
      i_reg_c_fwd_value => s_reg_c_fwd_value,
      i_reg_c_fwd_use_value => s_reg_c_fwd_use_value,
      i_reg_c_fwd_value_ready => s_reg_c_fwd_value_ready,

      -- WB data from the EX2 stage (sync).
      i_wb_data_w => s_ex2_result,
      i_wb_we => s_ex2_dst_reg.is_target,
      i_wb_sel_w => s_ex2_dst_reg.reg,
      i_wb_element_w => s_ex2_dst_reg.element,
      i_wb_is_vector => s_ex2_dst_reg.is_vector,

      -- Branch results to the EX1 stage (sync).
      o_branch_is_branch => s_rf_branch_is_branch,
      o_branch_is_reg => s_rf_branch_is_reg,
      o_branch_offset_addr => s_rf_branch_offset_addr,
      o_branch_reg_addr => s_rf_branch_reg_addr,
      o_branch_is_taken => s_rf_branch_is_taken,

      -- To the EX1 stage (sync).
      o_pc => s_rf_pc,
      o_pc_plus_4 => s_rf_pc_plus_4,
      o_src_a => s_rf_src_a,
      o_src_b => s_rf_src_b,
      o_src_c => s_rf_src_c,
      o_is_first_vector_op_cycle => s_rf_is_first_vector_op_cycle,
      o_address_offset_is_stride => s_rf_address_offset_is_stride,
      o_dst_reg => s_rf_dst_reg,
      o_packed_mode => s_rf_packed_mode,
      o_alu_op => s_rf_alu_op,
      o_mem_op => s_rf_mem_op,
      o_mul_op => s_rf_mul_op,
      o_div_op => s_rf_div_op,
      o_fpu_op => s_rf_fpu_op,
      o_alu_en => s_rf_alu_en,
      o_mem_en => s_rf_mem_en,
      o_mul_en => s_rf_mul_en,
      o_div_en => s_rf_div_en,
      o_fpu_en => s_rf_fpu_en
    );


  -- EX1/EX2: Execute.

  execute_0: entity work.execute
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      o_stall => s_ex_stall,

      -- From ID stage (sync).
      i_pc => s_rf_pc,
      i_pc_plus_4 => s_rf_pc_plus_4,
      i_src_a => s_rf_src_a,
      i_src_b => s_rf_src_b,
      i_src_c => s_rf_src_c,
      i_is_first_vector_op_cycle => s_rf_is_first_vector_op_cycle,
      i_address_offset_is_stride => s_rf_address_offset_is_stride,
      i_dst_reg => s_rf_dst_reg,
      i_packed_mode => s_rf_packed_mode,
      i_alu_op => s_rf_alu_op,
      i_mem_op => s_rf_mem_op,
      i_mul_op => s_rf_mul_op,
      i_div_op => s_rf_div_op,
      i_fpu_op => s_rf_fpu_op,
      i_alu_en => s_rf_alu_en,
      i_mem_en => s_rf_mem_en,
      i_mul_en => s_rf_mul_en,
      i_div_en => s_rf_div_en,
      i_fpu_en => s_rf_fpu_en,

      -- PC signal from ID (sync).
      i_id_pc => s_id_pc,

      -- Branch results from the ID stage (sync).
      i_branch_reg_addr => s_rf_branch_reg_addr,
      i_branch_offset_addr => s_rf_branch_offset_addr,
      i_branch_is_branch => s_rf_branch_is_branch,
      i_branch_is_reg => s_rf_branch_is_reg,
      i_branch_is_taken => s_rf_branch_is_taken,

      -- Branch PC correction to the PC stage (async).
      o_pccorr_target => s_ex1_pccorr_target,
      o_pccorr_source => s_ex1_pccorr_source,
      o_pccorr_is_branch => s_ex1_pccorr_is_branch,
      o_pccorr_is_taken => s_ex1_pccorr_is_taken,
      o_pccorr_adjust => s_ex1_pccorr_adjust,
      o_pccorr_adjusted_pc => s_ex1_pccorr_adjusted_pc,

      -- DCache interface.
      o_dcache_req => s_dcache_req,
      o_dcache_we => s_dcache_we,
      o_dcache_byte_mask => s_dcache_byte_mask,
      o_dcache_addr => s_dcache_addr,
      o_dcache_write_data => s_dcache_write_data,
      i_dcache_read_data => s_dcache_read_data,
      i_dcache_read_data_ready => s_dcache_read_data_ready,

      -- To WB stage (sync).
      o_result => s_ex3_result,
      o_dst_reg => s_ex3_dst_reg,

      -- To operand forwarding (async).
      o_ex1_next_dst_reg => s_ex1_next_dst_reg,
      o_ex1_next_result => s_ex1_next_result,
      o_ex1_next_result_ready => s_ex1_next_result_ready,
      o_ex2_next_dst_reg => s_ex2_next_dst_reg,
      o_ex2_next_result => s_ex2_next_result,
      o_ex2_next_result_ready => s_ex2_next_result_ready,
      o_ex3_next_dst_reg => s_ex3_next_dst_reg,
      o_ex3_next_result => s_ex3_next_result,

      -- To operand forwarding (sync).
      o_ex1_dst_reg => s_ex1_dst_reg,
      o_ex1_result => s_ex1_result,
      o_ex1_result_ready => s_ex1_result_ready,
      o_ex2_dst_reg => s_ex2_dst_reg,
      o_ex2_result => s_ex2_result,
      o_ex2_result_ready => s_ex2_result_ready
    );


  --------------------------------------------------------------------------------------------------
  -- Operand forwarding.
  --------------------------------------------------------------------------------------------------

  -- Forwarding logic for the branching logic in the RF stage (async).
  forward_to_branch_logic_0: entity work.forward_to_branch_logic
    port map (
      -- From ID (async).
      i_src_reg => s_rf_src_reg_c,

      -- From RF (sync).
      i_dst_reg_from_rf => s_rf_dst_reg,

      -- From EX1 (sync).
      i_dst_reg_from_ex1 => s_ex1_dst_reg,
      i_value_from_ex1 => s_ex1_result,
      i_ready_from_ex1 => s_ex1_result_ready,

      -- From EX2 (sync).
      i_dst_reg_from_ex2 => s_ex2_dst_reg,
      i_value_from_ex2 => s_ex2_result,
      i_ready_from_ex2 => s_ex2_result_ready,

      -- From EX3 (sync).
      i_dst_reg_from_ex3 => s_ex3_dst_reg,
      i_value_from_ex3 => s_ex3_result,

      -- Operand forwarding to the ID stage.
      o_value => s_branch_fwd_value,
      o_use_value => s_branch_fwd_use_value,
      o_value_ready => s_branch_fwd_value_ready
    );

  -- Forwarding logic for the vector control (VL data) in the ID stage (async).
  forward_to_vector_control_0: entity work.forward_to_vector_control
    port map (
      -- From ID (async).
      i_vl_requested => s_id_vl_requested,

      -- From ID (sync).
      i_dst_reg_from_id => s_id_dst_reg,

      -- From RF (sync).
      i_dst_reg_from_rf => s_rf_dst_reg,

      -- From EX1 (sync).
      i_dst_reg_from_ex1 => s_ex1_dst_reg,
      i_value_from_ex1 => s_ex1_result,
      i_ready_from_ex1 => s_ex1_result_ready,

      -- From EX2 (sync).
      i_dst_reg_from_ex2 => s_ex2_dst_reg,
      i_value_from_ex2 => s_ex2_result,
      i_ready_from_ex2 => s_ex2_result_ready,

      -- From EX3 (sync).
      i_dst_reg_from_ex3 => s_ex3_dst_reg,
      i_value_from_ex3 => s_ex3_result,

      -- Operand forwarding to the ID stage.
      o_value => s_vl_fwd_value,
      o_use_value => s_vl_fwd_use_value,
      o_value_ready => s_vl_fwd_value_ready
    );


  -- Forwarding logic for the A operand input to the EX stage (sync).
  forward_to_ex_A: entity work.forward_to_ex
    port map (
      -- From RF (async).
      i_src_reg => s_rf_src_reg_a,
      i_reg_required => s_rf_reg_a_required,

      -- From EX1 input (async).
      i_dst_reg_from_ex1 => s_ex1_next_dst_reg,
      i_value_from_ex1 => s_ex1_next_result,
      i_ready_from_ex1 => s_ex1_next_result_ready,

      -- From EX2 input (async).
      i_dst_reg_from_ex2 => s_ex2_next_dst_reg,
      i_value_from_ex2 => s_ex2_next_result,
      i_ready_from_ex2 => s_ex2_next_result_ready,

      -- From EX3 input (async).
      i_dst_reg_from_ex3 => s_ex3_next_dst_reg,
      i_value_from_ex3 => s_ex3_next_result,

      -- From WB input (async).
      i_dst_reg_from_wb => s_ex3_dst_reg,
      i_value_from_wb => s_ex3_result,

      -- Operand forwarding to the EX inputs in the RF stage.
      o_value => s_reg_a_fwd_value,
      o_use_value => s_reg_a_fwd_use_value,
      o_value_ready => s_reg_a_fwd_value_ready
    );

  -- Forwarding logic for the B operand input to the EX stage (sync).
  forward_to_ex_B: entity work.forward_to_ex
    port map (
      -- From RF (async).
      i_src_reg => s_rf_src_reg_b,
      i_reg_required => s_rf_reg_b_required,

      -- From EX1 input (async).
      i_dst_reg_from_ex1 => s_ex1_next_dst_reg,
      i_value_from_ex1 => s_ex1_next_result,
      i_ready_from_ex1 => s_ex1_next_result_ready,

      -- From EX2 input (async).
      i_dst_reg_from_ex2 => s_ex2_next_dst_reg,
      i_value_from_ex2 => s_ex2_next_result,
      i_ready_from_ex2 => s_ex2_next_result_ready,

      -- From EX3 input (async).
      i_dst_reg_from_ex3 => s_ex3_next_dst_reg,
      i_value_from_ex3 => s_ex3_next_result,

      -- From WB input (async).
      i_dst_reg_from_wb => s_ex3_dst_reg,
      i_value_from_wb => s_ex3_result,

      -- Operand forwarding to the EX inputs in the RF stage.
      o_value => s_reg_b_fwd_value,
      o_use_value => s_reg_b_fwd_use_value,
      o_value_ready => s_reg_b_fwd_value_ready
    );

  -- Forwarding logic for the C operand input to the EX stage (sync).
  forward_to_ex_C: entity work.forward_to_ex
    port map (
      -- From RF (async).
      i_src_reg => s_rf_src_reg_c,
      i_reg_required => s_rf_reg_c_required,

      -- From EX1 input (async).
      i_dst_reg_from_ex1 => s_ex1_next_dst_reg,
      i_value_from_ex1 => s_ex1_next_result,
      i_ready_from_ex1 => s_ex1_next_result_ready,

      -- From EX2 input (async).
      i_dst_reg_from_ex2 => s_ex2_next_dst_reg,
      i_value_from_ex2 => s_ex2_next_result,
      i_ready_from_ex2 => s_ex2_next_result_ready,

      -- From EX3 input (async).
      i_dst_reg_from_ex3 => s_ex3_next_dst_reg,
      i_value_from_ex3 => s_ex3_next_result,

      -- From WB input (async).
      i_dst_reg_from_wb => s_ex3_dst_reg,
      i_value_from_wb => s_ex3_result,

      -- Operand forwarding to the EX inputs in the RF stage.
      o_value => s_reg_c_fwd_value,
      o_use_value => s_reg_c_fwd_use_value,
      o_value_ready => s_reg_c_fwd_value_ready
    );


  --------------------------------------------------------------------------------------------------
  -- Pipeline control logic.
  --------------------------------------------------------------------------------------------------

  -- Determine if we need to cancel speculative instructions.
  s_cancel_speculative_instructions <= s_ex1_pccorr_adjust;

  -- Determine which pipeline stages need to be stalled during the next cycle.
  s_stall_rf <= s_ex_stall;
  s_stall_id <= s_rf_stall or s_stall_rf;
  s_stall_if <= s_id_stall or s_stall_id;
  s_stall_pc <= s_if_stall or s_stall_if;


  --------------------------------------------------------------------------------------------------
  -- Caches and memory interface.
  --------------------------------------------------------------------------------------------------

  icache_0: entity work.dummy_icache
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_cpu_req => s_icache_req,
      i_cpu_addr => s_icache_addr,
      o_cpu_read_data => s_icache_read_data,
      o_cpu_read_data_ready => s_icache_read_data_ready,

      o_mem_req => s_icache_mem_req,
      o_mem_addr => s_icache_mem_addr,
      i_mem_read_data => s_icache_mem_read_data,
      i_mem_read_data_ready => s_icache_mem_read_data_ready
    );

  dcache_0: entity work.dummy_dcache
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_cpu_req => s_dcache_req,
      i_cpu_we => s_dcache_we,
      i_cpu_byte_mask => s_dcache_byte_mask,
      i_cpu_addr => s_dcache_addr,
      i_cpu_write_data => s_dcache_write_data,
      o_cpu_read_data => s_dcache_read_data,
      o_cpu_read_data_ready => s_dcache_read_data_ready,

      o_mem_req => s_dcache_mem_req,
      o_mem_we => s_dcache_mem_we,
      o_mem_byte_mask => s_dcache_mem_byte_mask,
      o_mem_addr => s_dcache_mem_addr,
      o_mem_write_data => s_dcache_mem_write_data,
      i_mem_read_data => s_dcache_mem_read_data,
      i_mem_read_data_ready => s_dcache_mem_read_data_ready
    );

  cache_access_arbitrator_0: entity work.cache_access_arbitrator
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_icache_req => s_icache_mem_req,
      i_icache_addr => s_icache_mem_addr,
      o_icache_read_data => s_icache_mem_read_data,
      o_icache_read_data_ready => s_icache_mem_read_data_ready,

      i_dcache_req => s_dcache_mem_req,
      i_dcache_we => s_dcache_mem_we,
      i_dcache_byte_mask => s_dcache_mem_byte_mask,
      i_dcache_addr => s_dcache_mem_addr,
      i_dcache_write_data => s_dcache_mem_write_data,
      o_dcache_read_data => s_dcache_mem_read_data,
      o_dcache_read_data_ready => s_dcache_mem_read_data_ready,

      o_mem_req => o_mem_req,
      o_mem_we => o_mem_we,
      o_mem_byte_mask => o_mem_byte_mask,
      o_mem_addr => o_mem_addr,
      o_mem_write_data => o_mem_write_data,
      i_mem_read_data => i_mem_read_data,
      i_mem_read_data_ready => i_mem_read_data_ready
    );

end rtl;
