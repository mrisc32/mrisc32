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
use work.types.all;
use work.config.all;

entity regs_scalar_tb is
end regs_scalar_tb;

architecture behavioral of regs_scalar_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_stall_read_ports : std_logic;
  signal s_sel_a : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_sel_b : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_sel_c : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_data_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_data_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_data_c : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_we : std_logic;
  signal s_data_w : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_sel_w : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Clock period.
  constant C_HALF_PERIOD : time := 2 ns;

  function reg(x: integer) return std_logic_vector is
  begin
    return to_vector(x, C_LOG2_NUM_REGS);
  end function;
begin
  regs_scalar_0: entity work.regs_scalar
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall_read_ports => s_stall_read_ports,
      i_sel_a => s_sel_a,
      i_sel_b => s_sel_b,
      i_sel_c => s_sel_c,
      o_data_a => s_data_a,
      o_data_b => s_data_b,
      o_data_c => s_data_c,
      i_we => s_we,
      i_data_w => s_data_w,
      i_sel_w => s_sel_w,
      i_pc => s_pc
    );

  process
  begin
    -- Reset all inputs.
    s_sel_a <= reg(0);
    s_sel_b <= reg(0);
    s_sel_c <= reg(0);
    s_we <= '0';
    s_data_w <= "00000000000000000000000000000000";
    s_sel_w <= reg(0);
    s_pc <= "00000000000000000000000000000000";
    s_clk <= '0';
    s_stall_read_ports <= '0';

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

    -- Write a value to register S1.
    s_data_w <= "00000000000000000000000000010101";
    s_sel_w <= reg(1);
    s_we <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';

    -- Write a value to register S2.
    s_data_w <= "00000000000000000000000001010100";
    s_sel_w <= reg(2);
    s_we <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';

    -- Write a value to register S3.
    s_data_w <= "00000000000000000000000101010000";
    s_sel_w <= reg(3);
    s_we <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';

    -- Read registers S1, S2, S3, and check the results.
    s_sel_a <= reg(1);
    s_sel_b <= reg(2);
    s_sel_c <= reg(3);
    s_we <= '0';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';

    assert s_data_a = "00000000000000000000000000010101"
      report "Bad S1 value:" & lf &
             "  S1=" & to_string(s_data_a) & " (expected 00000000000000000000000000010101)"
        severity error;
    assert s_data_b = "00000000000000000000000001010100"
      report "Bad S2 value:" & lf &
             "  S2=" & to_string(s_data_b) & " (expected 00000000000000000000000001010100)"
        severity error;
    assert s_data_c = "00000000000000000000000101010000"
      report "Bad S3 value:" & lf &
             "  S3=" & to_string(s_data_c) & " (expected 00000000000000000000000101010000)"
        severity error;

    -- Write a value to VL and...
    -- ...read registers Z, VL and PC, and check the results.
    s_sel_a <= reg(C_Z_REG);   -- Should return zero.
    s_sel_b <= reg(C_PC_REG);  -- Should return PC.
    s_sel_c <= reg(0);
    s_sel_w <= reg(0);
    s_pc <= "00000000000001010100000000000100";
    s_data_w <= "00000000000000000000000000000000";
    s_we <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';

    assert s_data_a = "00000000000000000000000000000000"
      report "Bad Z value:" & lf &
             "  Z=" & to_string(s_data_a) & " (expected 00000000000000000000000000000000)"
        severity error;
    assert s_data_b = s_pc
      report "Bad PC value:" & lf &
             "  PC=" & to_string(s_data_b) & " (expected " & to_string(s_pc) & ")"
        severity error;

    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

