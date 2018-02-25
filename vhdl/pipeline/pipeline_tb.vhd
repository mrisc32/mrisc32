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
begin
  fetch_0: entity work.fetch
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- TODO(m): Complete this...
      i_stall => '0',
      i_id_branch_reg_addr => (others => '0'),
      i_id_branch_offset_addr => (others => '0'),
      i_id_branch_is_branch => '0',
      i_id_branch_is_reg => '0',
      i_id_branch_is_taken => '0',
      i_icache_data => (others => '0'),
      i_icache_data_ready => '0'
    );

  decode_0: entity work.decode
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- TODO(m): Complete this...
      i_stall => '0',
      i_if_pc => (others => '0'),
      i_if_instr => (others => '0'),
      i_if_bubble => '0',
      i_wb_we => '0',
      i_wb_data_w => (others => '0'),
      i_wb_sel_w => (others => '0')
    );

  execute_0: entity work.execute
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- TODO(m): Complete this...
      i_stall => '0',
      i_id_alu_op => (others => '0'),
      i_id_src_a => (others => '0'),
      i_id_src_b => (others => '0'),
      i_id_src_c => (others => '0'),
      i_id_mem_op => (others => '0'),
      i_id_dst_reg => (others => '0')
    );

  memory_0: entity work.memory
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- TODO(m): Complete this...
      i_stall => '0',
      i_ex_op => (others => '0'),
      i_ex_alu_result => (others => '0'),
      i_ex_store_data => (others => '0'),
      i_ex_dst_reg => (others => '0'),
      i_dcache_data => (others => '0'),
      i_dcache_data_ready => '0'
    );

  process
  begin
    -- Start by resetting the pipeline (to have defined signals).
    s_rst <= '1';
    s_clk <= '0';

    wait for 1 ns;
    s_rst <= '0';

    --  Wait forever; this will finish the simulation.
    assert false report "End of test" severity note;
    wait;
  end process;
end behavioral;

