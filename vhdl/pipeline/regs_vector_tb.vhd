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

entity regs_vector_tb is
end regs_vector_tb;

architecture behavioral of regs_vector_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_sel_a : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_element_a : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
  signal s_data_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_sel_b : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_element_b : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
  signal s_data_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_we : std_logic;
  signal s_data_w : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_sel_w : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_element_w : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);

  -- Clock period.
  constant C_HALF_PERIOD : time := 2 ns;
begin
  regs_vector_0: entity work.regs_vector
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_sel_a => s_sel_a,
      i_element_a => s_element_a,
      o_data_a => s_data_a,
      i_sel_b => s_sel_b,
      i_element_b => s_element_b,
      o_data_b => s_data_b,
      i_we => s_we,
      i_data_w => s_data_w,
      i_sel_w => s_sel_w,
      i_element_w => s_element_w
    );

  process
  begin
    -- Reset all inputs.
    s_sel_a <= "00000";
    s_element_a <= "00";
    s_sel_b <= "00000";
    s_element_b <= "00";
    s_we <= '0';
    s_data_w <= "00000000000000000000000000000000";
    s_sel_w <= "00000";
    s_element_w <= "00";
    s_clk <= '0';

    -- Start by resetting the register file.
    s_rst <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';
    s_rst <= '0';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';

    -- Write a value to V1[0].
    s_data_w <= "00000000000000000000000000010101";
    s_sel_w <= "00001";
    s_element_w <= "00";
    s_we <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';

    -- Write a value to V2[1].
    s_data_w <= "00000000000000000000000001010100";
    s_sel_w <= "00010";
    s_element_w <= "01";
    s_we <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';

    -- Write a value to V3[2].
    s_data_w <= "00000000000000000000000101010000";
    s_sel_w <= "00011";
    s_element_w <= "10";
    s_we <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';

    -- No more writing...
    s_we <= '0';

    -- Read V1[0] and check the result.
    s_sel_a <= "00001";
    s_element_a <= "00";
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';
    assert s_data_a = "00000000000000000000000000010101"
      report "Bad V1[0] value:" & lf &
             "  V1[0]=" & to_string(s_data_a) & " (expected 00000000000000000000000000010101)"
        severity error;

    -- Read V2[1] and check the result.
    s_sel_b <= "00010";
    s_element_b <= "01";
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';
    assert s_data_b = "00000000000000000000000001010100"
      report "Bad V2[1] value:" & lf &
             "  V2[1]=" & to_string(s_data_b) & " (expected 00000000000000000000000001010100)"
        severity error;

    -- Read V3[2] and check the result.
    s_sel_a <= "00011";
    s_element_a <= "10";
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';
    assert s_data_a = "00000000000000000000000101010000"
      report "Bad V3[2] value:" & lf &
             "  V3[2]=" & to_string(s_data_a) & " (expected 00000000000000000000000101010000)"
        severity error;

    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

