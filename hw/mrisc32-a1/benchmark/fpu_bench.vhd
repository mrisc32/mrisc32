----------------------------------------------------------------------------------------------------
-- Copyright (c) 2019 Marcus Geelnard
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
use work.types.all;

entity fpu_bench is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;

    -- Inputs (sync).
    i_enable : in std_logic;
    i_op : in T_FPU_OP;
    i_packed_mode : in T_PACKED_MODE;
    i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- Outputs (sync).
    o_f1_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_f1_result_ready : out std_logic;
    o_f3_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_f3_result_ready : out std_logic;
    o_f4_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_f4_result_ready : out std_logic
  );
end fpu_bench;

architecture rtl of fpu_bench is
  signal s_enable : std_logic;
  signal s_op : T_FPU_OP;
  signal s_packed_mode : T_PACKED_MODE;
  signal s_src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);

  signal s_f1_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f1_next_result_ready : std_logic;
  signal s_f3_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f3_next_result_ready : std_logic;
  signal s_f4_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f4_next_result_ready : std_logic;
begin
  dut_0: entity work.fpu
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => i_stall,

      i_enable => s_enable,
      i_op => s_op,
      i_packed_mode => s_packed_mode,
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      o_f1_next_result => s_f1_next_result,
      o_f1_next_result_ready => s_f1_next_result_ready,
      o_f3_next_result => s_f3_next_result,
      o_f3_next_result_ready => s_f3_next_result_ready,
      o_f4_next_result => s_f4_next_result,
      o_f4_next_result_ready => s_f4_next_result_ready
    );

  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_enable <= '0';
      s_op <= (others => '0');
      s_packed_mode <= (others => '0');
      s_src_a <= (others => '0');
      s_src_b <= (others => '0');
      o_f1_result <= (others => '0');
      o_f1_result_ready <= '0';
      o_f3_result <= (others => '0');
      o_f3_result_ready <= '0';
      o_f4_result <= (others => '0');
      o_f4_result_ready <= '0';
    elsif rising_edge(i_clk) then
      s_enable <= i_enable;
      s_op <= i_op;
      s_packed_mode <= i_packed_mode;
      s_src_a <= i_src_a;
      s_src_b <= i_src_b;
      o_f1_result <= s_f1_next_result;
      o_f1_result_ready <= s_f1_next_result_ready;
      o_f3_result <= s_f3_next_result;
      o_f3_result_ready <= s_f3_next_result_ready;
      o_f4_result <= s_f4_next_result;
      o_f4_result_ready <= s_f4_next_result_ready;
    end if;
  end process;
end rtl;
