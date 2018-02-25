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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity pipeline_tb is
end pipeline_tb;

architecture behavioral of pipeline_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;

  -- From IF.
  signal s_if_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_if_instr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_if_bubble : std_logic;

  -- From ID.
  signal s_id_branch_reg_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_branch_offset_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_branch_is_branch : std_logic;
  signal s_id_branch_is_reg : std_logic;
  signal s_id_branch_is_taken : std_logic;

  signal s_id_alu_op : T_ALU_OP;
  signal s_id_src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_src_c : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_id_mem_op : T_MEM_OP;
  signal s_id_dst_reg : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);

  -- From EX.
  signal s_ex_mem_op : T_MEM_OP;
  signal s_ex_alu_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex_store_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex_dst_reg : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);

  -- From MEM.
  signal s_mem_we : std_logic;
  signal s_mem_data_w : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_mem_sel_w : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);

  -- ICache interface.
  signal s_icache_read : std_logic;
  signal s_icache_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_icache_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_icache_data_ready : std_logic;

  -- DCache interface.
  signal s_dcache_enable : std_logic;
  signal s_dcache_write : std_logic;
  signal s_dcache_size : std_logic_vector(1 downto 0);
  signal s_dcache_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_dcache_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_dcache_data_ready : std_logic;
begin
  fetch_0: entity work.fetch
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- TODO(m): Implement me!
      i_stall => '0',

      -- Branch results from the ID stage (async).
      i_id_branch_reg_addr => s_id_branch_reg_addr,
      i_id_branch_offset_addr => s_id_branch_offset_addr,
      i_id_branch_is_branch => s_id_branch_is_branch,
      i_id_branch_is_reg => s_id_branch_is_reg,
      i_id_branch_is_taken => s_id_branch_is_taken,

      -- ICache interface.
      o_icache_read => s_icache_read,
      o_icache_addr => s_icache_addr,
      i_icache_data => s_icache_data,
      i_icache_data_ready => s_icache_data_ready,

      -- To ID stage (sync).
      o_id_pc => s_if_pc,
      o_id_instr => s_if_instr,
      o_id_bubble => s_if_bubble
    );

  decode_0: entity work.decode
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- TODO(m): Implement me!
      i_stall => '0',

      -- From the IF stage (sync).
      i_if_pc => s_if_pc,
      i_if_instr => s_if_instr,
      i_if_bubble => s_if_bubble,

      -- WB data from the MEM stage (sync).
      i_wb_we => s_mem_we,
      i_wb_data_w => s_mem_data_w,
      i_wb_sel_w => s_mem_sel_w,

      -- Branch results to the IF stage (async).
      o_if_branch_reg_addr => s_id_branch_reg_addr,
      o_if_branch_offset_addr => s_id_branch_offset_addr,
      o_if_branch_is_branch => s_id_branch_is_branch,
      o_if_branch_is_reg => s_id_branch_is_reg,
      o_if_branch_is_taken => s_id_branch_is_taken,

      -- To the EX stage (sync).
      o_ex_alu_op => s_id_alu_op,
      o_ex_src_a => s_id_src_a,
      o_ex_src_b => s_id_src_b,
      o_ex_src_c => s_id_src_c,
      o_ex_mem_op => s_id_mem_op,
      o_ex_dst_reg => s_id_dst_reg
    );

  execute_0: entity work.execute
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- TODO(m): Implement me!
      i_stall => '0',

      -- From ID stage (sync).
      i_id_alu_op => s_id_alu_op,
      i_id_src_a => s_id_src_a,
      i_id_src_b => s_id_src_b,
      i_id_src_c => s_id_src_c,
      i_id_mem_op => s_id_mem_op,
      i_id_dst_reg => s_id_dst_reg,

      -- To MEM stage (sync).
      o_mem_op => s_ex_mem_op,
      o_mem_alu_result => s_ex_alu_result,
      o_mem_store_data => s_ex_store_data,
      o_mem_dst_reg => s_ex_dst_reg
    );

  memory_0: entity work.memory
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- TODO(m): Remove this (it's never used).
      i_stall => '0',

      -- From EX stage (sync).
      i_ex_op => s_ex_mem_op,
      i_ex_alu_result => s_ex_alu_result,
      i_ex_store_data => s_ex_store_data,
      i_ex_dst_reg => s_ex_dst_reg,

      -- DCache interface.
      o_dcache_enable => s_dcache_enable,
      o_dcache_write => s_dcache_write,
      o_dcache_size => s_dcache_size,
      o_dcache_addr => s_dcache_addr,
      i_dcache_data => s_dcache_data,
      i_dcache_data_ready => s_dcache_data_ready,

      -- To WB stage (sync).
      o_wb_we => s_mem_we,
      o_wb_data => s_mem_data_w,
      o_wb_dst_reg => s_mem_sel_w
    );

  process
  begin
    -- Start by resetting the pipeline (to have defined signals).
    s_rst <= '1';
    s_clk <= '0';

    wait for 1 ns;
    s_rst <= '0';

    -- Run a few cycles.
    for i in 0 to 10 loop
      wait for 1 ns;
      s_clk <= '1';
      wait for 1 ns;
      s_clk <= '0';
    end loop;

    --  Wait forever; this will finish the simulation.
    assert false report "End of test" severity note;
    wait;
  end process;
end behavioral;

