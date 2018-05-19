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

      -- ICache interface.
      o_icache_req : out std_logic;
      o_icache_addr : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_icache_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_icache_data_ready : in std_logic;

      -- DCache interface.
      o_dcache_req : out std_logic;  -- 1 = request, 0 = nop
      o_dcache_we : out std_logic;   -- 1 = write, 0 = read
      o_dcache_byte_mask : out std_logic_vector(C_WORD_SIZE/8-1 downto 0);
      o_dcache_addr : out std_logic_vector(C_WORD_SIZE-1 downto 2);
      o_dcache_write_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_dcache_read_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_dcache_read_data_ready : in std_logic
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

  signal s_id_branch_reg_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_branch_offset_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_branch_is_branch : std_logic;
  signal s_id_branch_is_reg : std_logic;
  signal s_id_branch_is_taken : std_logic;

  signal s_id_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_src_c : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_dst_reg : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_id_writes_to_reg : std_logic;
  signal s_id_alu_op : T_ALU_OP;
  signal s_id_muldiv_op : T_MULDIV_OP;
  signal s_id_mem_op : T_MEM_OP;
  signal s_id_alu_en : std_logic;
  signal s_id_muldiv_en : std_logic;
  signal s_id_mem_en : std_logic;

  -- From EX1.
  signal s_ex1_stall : std_logic;

  signal s_ex1_pccorr_target : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex1_pccorr_source : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex1_pccorr_is_branch : std_logic;
  signal s_ex1_pccorr_is_taken : std_logic;
  signal s_ex1_pccorr_adjust : std_logic;
  signal s_ex1_pccorr_adjusted_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);

  signal s_ex1_mem_op : T_MEM_OP;
  signal s_ex1_mem_enable : std_logic;
  signal s_ex1_mem_we : std_logic;
  signal s_ex1_mem_byte_mask : std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_ex1_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex1_store_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex1_dst_reg : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_ex1_writes_to_reg : std_logic;

  signal s_ex1_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);  -- Async.
  signal s_ex1_next_result_ready : std_logic;  -- Async.

  -- From EX2.
  signal s_ex2_stall : std_logic;

  signal s_ex2_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex2_dst_reg : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_ex2_writes_to_reg : std_logic;

  signal s_ex2_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);  -- Async.

  -- Operand forwarding signals.
  signal s_value_ready_from_ex : std_logic;

  signal s_branch_fwd_value : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_branch_fwd_use_value : std_logic;
  signal s_branch_fwd_value_ready : std_logic;

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
  signal s_stall_ex : std_logic;
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
      o_icache_req => o_icache_req,
      o_icache_addr => o_icache_addr,
      i_icache_data => i_icache_data,
      i_icache_data_ready => i_icache_data_ready,

      -- To ID stage (sync).
      o_pc => s_if_pc,
      o_instr => s_if_instr,
      o_bubble => s_if_bubble
    );


  -- ID: Instruction decode.

  decode_0: entity work.decode
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_stall => s_stall_id,
      o_stall => s_id_stall,
      i_cancel => s_cancel_speculative_instructions,

      -- From the IF stage (sync).
      i_pc => s_if_pc,
      i_instr => s_if_instr,
      i_bubble => s_if_bubble,

      -- Operand forwarding to the branch logic.
      i_branch_fwd_value => s_branch_fwd_value,
      i_branch_fwd_use_value => s_branch_fwd_use_value,
      i_branch_fwd_value_ready => s_branch_fwd_value_ready,

      -- Operand forwarding to the source registers.
      i_reg_a_fwd_value => s_reg_a_fwd_value,
      i_reg_a_fwd_use_value => s_reg_a_fwd_use_value,
      i_reg_a_fwd_value_ready => s_reg_a_fwd_value_ready,
      i_reg_b_fwd_value => s_reg_b_fwd_value,
      i_reg_b_fwd_use_value => s_reg_b_fwd_use_value,
      i_reg_b_fwd_value_ready => s_reg_b_fwd_value_ready,
      i_reg_c_fwd_value => s_reg_c_fwd_value,
      i_reg_c_fwd_use_value => s_reg_c_fwd_use_value,
      i_reg_c_fwd_value_ready => s_reg_c_fwd_value_ready,

      -- WB data from the EX stage (sync).
      i_wb_data_w => s_ex2_data,
      i_wb_sel_w => s_ex2_dst_reg,
      i_wb_we => s_ex2_writes_to_reg,

      -- Branch results to the EX stage (sync).
      o_branch_reg_addr => s_id_branch_reg_addr,
      o_branch_offset_addr => s_id_branch_offset_addr,
      o_branch_is_branch => s_id_branch_is_branch,
      o_branch_is_reg => s_id_branch_is_reg,
      o_branch_is_taken => s_id_branch_is_taken,

      -- To the EX stage (sync).
      o_pc => s_id_pc,
      o_src_a => s_id_src_a,
      o_src_b => s_id_src_b,
      o_src_c => s_id_src_c,
      o_dst_reg => s_id_dst_reg,
      o_writes_to_reg => s_id_writes_to_reg,
      o_alu_op => s_id_alu_op,
      o_muldiv_op => s_id_muldiv_op,
      o_mem_op => s_id_mem_op,
      o_alu_en => s_id_alu_en,
      o_muldiv_en => s_id_muldiv_en,
      o_mem_en => s_id_mem_en
    );


  -- EX1: Execute.

  execute_0: entity work.execute
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_stall => s_stall_ex,
      o_stall => s_ex1_stall,

      -- From ID stage (sync).
      i_pc => s_id_pc,
      i_src_a => s_id_src_a,
      i_src_b => s_id_src_b,
      i_src_c => s_id_src_c,
      i_dst_reg => s_id_dst_reg,
      i_writes_to_reg => s_id_writes_to_reg,
      i_alu_op => s_id_alu_op,
      i_muldiv_op => s_id_muldiv_op,
      i_mem_op => s_id_mem_op,
      i_alu_en => s_id_alu_en,
      i_muldiv_en => s_id_muldiv_en,
      i_mem_en => s_id_mem_en,

      -- PC signal from IF (sync).
      i_if_pc => s_if_pc,

      -- Branch results from the ID stage (sync).
      i_branch_reg_addr => s_id_branch_reg_addr,
      i_branch_offset_addr => s_id_branch_offset_addr,
      i_branch_is_branch => s_id_branch_is_branch,
      i_branch_is_reg => s_id_branch_is_reg,
      i_branch_is_taken => s_id_branch_is_taken,

      -- Branch PC correction to the PC stage (async).
      o_pccorr_target => s_ex1_pccorr_target,
      o_pccorr_source => s_ex1_pccorr_source,
      o_pccorr_is_branch => s_ex1_pccorr_is_branch,
      o_pccorr_is_taken => s_ex1_pccorr_is_taken,
      o_pccorr_adjust => s_ex1_pccorr_adjust,
      o_pccorr_adjusted_pc => s_ex1_pccorr_adjusted_pc,

      -- To MEM stage (sync).
      o_mem_op => s_ex1_mem_op,
      o_mem_enable => s_ex1_mem_enable,
      o_mem_we => s_ex1_mem_we,
      o_mem_byte_mask => s_ex1_mem_byte_mask,
      o_result => s_ex1_result,
      o_store_data => s_ex1_store_data,
      o_dst_reg => s_ex1_dst_reg,
      o_writes_to_reg => s_ex1_writes_to_reg,

      -- To operand forwarding (async).
      o_next_result => s_ex1_next_result,
      o_next_result_ready => s_ex1_next_result_ready
    );


  -- EX2: Memory.

  memory_0: entity work.memory
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      o_stall => s_ex2_stall,

      -- From EX stage (sync).
      i_mem_op => s_ex1_mem_op,
      i_mem_enable => s_ex1_mem_enable,
      i_mem_we => s_ex1_mem_we,
      i_mem_byte_mask => s_ex1_mem_byte_mask,
      i_ex_result => s_ex1_result,
      i_store_data => s_ex1_store_data,
      i_dst_reg => s_ex1_dst_reg,
      i_writes_to_reg => s_ex1_writes_to_reg,

      -- DCache interface.
      o_dcache_req => o_dcache_req,
      o_dcache_we => o_dcache_we,
      o_dcache_byte_mask => o_dcache_byte_mask,
      o_dcache_addr => o_dcache_addr,
      o_dcache_write_data => o_dcache_write_data,
      i_dcache_read_data => i_dcache_read_data,
      i_dcache_read_data_ready => i_dcache_read_data_ready,

      -- To WB stage (sync).
      o_data => s_ex2_data,
      o_dst_reg => s_ex2_dst_reg,
      o_writes_to_reg => s_ex2_writes_to_reg,

      -- To operand forwarding (async).
      o_next_data => s_ex2_next_result
    );


  --------------------------------------------------------------------------------------------------
  -- Operand forwarding.
  --------------------------------------------------------------------------------------------------

  -- Did the EX stage produce a value that is ready to use?
  s_value_ready_from_ex <= not s_ex1_mem_enable;

  -- Forwarding logic for the branching logic in the ID stage (async).
  forward_to_branch_logic_0: entity work.forward_to_branch_logic
    port map (
      i_src_reg => s_if_instr(23 downto 19),      -- From IF (sync).

      -- From ID (sync).
      i_id_writes_to_reg => s_id_writes_to_reg,
      i_dst_reg_from_id => s_id_dst_reg,

      -- From EX (sync).
      i_ex_writes_to_reg => s_ex1_writes_to_reg,
      i_dst_reg_from_ex => s_ex1_dst_reg,
      i_value_from_ex => s_ex1_result,
      i_ready_from_ex => s_value_ready_from_ex,

      -- From MEM (sync).
      i_mem_writes_to_reg => s_ex2_writes_to_reg,
      i_dst_reg_from_mem => s_ex2_dst_reg,
      i_value_from_mem => s_ex2_data,

      -- Operand forwarding to the ID stage.
      o_value => s_branch_fwd_value,
      o_use_value => s_branch_fwd_use_value,
      o_value_ready => s_branch_fwd_value_ready
    );

  -- Forwarding logic for the A operand input to the EX stage (sync).
  forward_to_ex_A: entity work.forward_to_ex
    port map (
      i_src_reg => s_if_instr(18 downto 14),  -- Reg A, from IF (sync).

      -- From EX input (async).
      i_ex_writes_to_reg => s_id_writes_to_reg,
      i_dst_reg_from_ex => s_id_dst_reg,
      i_value_from_ex => s_ex1_next_result,
      i_ready_from_ex => s_ex1_next_result_ready,

      -- From MEM input (async).
      i_mem_writes_to_reg => s_ex1_writes_to_reg,
      i_dst_reg_from_mem => s_ex1_dst_reg,
      i_value_from_mem => s_ex2_next_result,

      -- From WB input (async).
      i_wb_writes_to_reg => s_ex2_writes_to_reg,
      i_dst_reg_from_wb => s_ex2_dst_reg,
      i_value_from_wb => s_ex2_data,

      -- Operand forwarding to the EX inputs in the ID stage.
      o_value => s_reg_a_fwd_value,
      o_use_value => s_reg_a_fwd_use_value,
      o_value_ready => s_reg_a_fwd_value_ready
    );

  -- Forwarding logic for the B operand input to the EX stage (sync).
  forward_to_ex_B: entity work.forward_to_ex
    port map (
      i_src_reg => s_if_instr(13 downto 9),   -- Reg B, from IF (sync).

      -- From EX input (async).
      i_ex_writes_to_reg => s_id_writes_to_reg,
      i_dst_reg_from_ex => s_id_dst_reg,
      i_value_from_ex => s_ex1_next_result,
      i_ready_from_ex => s_ex1_next_result_ready,

      -- From MEM input (async).
      i_mem_writes_to_reg => s_ex1_writes_to_reg,
      i_dst_reg_from_mem => s_ex1_dst_reg,
      i_value_from_mem => s_ex2_next_result,

      -- From WB input (async).
      i_wb_writes_to_reg => s_ex2_writes_to_reg,
      i_dst_reg_from_wb => s_ex2_dst_reg,
      i_value_from_wb => s_ex2_data,

      -- Operand forwarding to the EX inputs in the ID stage.
      o_value => s_reg_b_fwd_value,
      o_use_value => s_reg_b_fwd_use_value,
      o_value_ready => s_reg_b_fwd_value_ready
    );

  -- Forwarding logic for the C operand input to the EX stage (sync).
  forward_to_ex_C: entity work.forward_to_ex
    port map (
      i_src_reg => s_if_instr(23 downto 19),  -- Reg C, from IF (sync).

      -- From EX input (async).
      i_ex_writes_to_reg => s_id_writes_to_reg,
      i_dst_reg_from_ex => s_id_dst_reg,
      i_value_from_ex => s_ex1_next_result,
      i_ready_from_ex => s_ex1_next_result_ready,

      -- From MEM input (async).
      i_mem_writes_to_reg => s_ex1_writes_to_reg,
      i_dst_reg_from_mem => s_ex1_dst_reg,
      i_value_from_mem => s_ex2_next_result,

      -- From WB input (async).
      i_wb_writes_to_reg => s_ex2_writes_to_reg,
      i_dst_reg_from_wb => s_ex2_dst_reg,
      i_value_from_wb => s_ex2_data,

      -- Operand forwarding to the EX inputs in the ID stage.
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
  s_stall_ex <= s_ex2_stall;
  s_stall_id <= s_ex1_stall or s_stall_ex;
  s_stall_if <= s_id_stall or s_stall_id;
  s_stall_pc <= s_if_stall or s_stall_if;
end rtl;
