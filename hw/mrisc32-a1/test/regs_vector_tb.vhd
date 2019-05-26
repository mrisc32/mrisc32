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

entity regs_vector_tb is
end regs_vector_tb;

architecture behavioral of regs_vector_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_stall_read_ports : std_logic;
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

  function reg(x: integer) return std_logic_vector is
  begin
    return to_vector(x, C_NUM_REGS);
  end function;

  function elem(x: integer) return std_logic_vector is
  begin
    return to_vector(x, C_LOG2_VEC_REG_ELEMENTS);
  end function;
begin
  regs_vector_0: entity work.regs_vector
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall_read_ports => s_stall_read_ports,
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
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      sel_a : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      element_a : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
      sel_b : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      element_b : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
      we : std_logic;
      data_w : std_logic_vector(C_WORD_SIZE-1 downto 0);
      sel_w : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      element_w : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);

      -- Expected outputs
      data_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
      data_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- Write a value to V1[0].
        (reg(0), elem(0), reg(0), elem(0), '1', X"00001234", reg(1), elem(0), X"00000000", X"00000000"),

        -- Write a value to V2[1].
        (reg(0), elem(0), reg(0), elem(0), '1', X"00012340", reg(2), elem(1), X"00000000", X"00000000"),

        -- Write a value to V3[2].
        (reg(0), elem(0), reg(0), elem(0), '1', X"00123400", reg(3), elem(2), X"00000000", X"00000000"),

        -- Read V1[0] and V2[1].
        (reg(1), elem(0), 5X"02", elem(1), '0', X"00000000", reg(0), elem(0), X"00001234", X"00012340"),

        -- Read V3[2].
        (reg(3), elem(2), reg(0), elem(0), '0', X"00000000", reg(0), elem(0), X"00123400", X"00000000")
      );
  begin
    -- Reset all inputs.
    s_stall_read_ports <= '0';
    s_sel_a <= reg(0);
    s_element_a <= elem(0);
    s_sel_b <= reg(0);
    s_element_b <= elem(0);
    s_we <= '0';
    s_data_w <= "00000000000000000000000000000000";
    s_sel_w <= reg(0);
    s_element_w <= elem(0);
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

    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      wait until s_clk = '0';

      --  Set the inputs.
      s_sel_a <= patterns(i).sel_a;
      s_element_a <= patterns(i).element_a;
      s_sel_b <= patterns(i).sel_b;
      s_element_b <= patterns(i).element_b;
      s_we <= patterns(i).we;
      s_data_w <= patterns(i).data_w;
      s_sel_w <= patterns(i).sel_w;
      s_element_w <= patterns(i).element_w;

      -- Tick the clock.
      wait for C_HALF_PERIOD;
      s_clk <= '1';

      -- Wait for the result to be produced.
      wait for C_HALF_PERIOD;

      --  Check the outputs.
      assert s_data_a = patterns(i).data_a
        report "Bad port A value (" & integer'image(i) & "):" & lf &
               "  Vn[e]=" & to_string(s_data_a) & " (expected " & to_string(patterns(i).data_a) &  ")"
          severity error;
      assert s_data_b = patterns(i).data_b
        report "Bad port B value (" & integer'image(i) & "):" & lf &
               "  Vn[e]=" & to_string(s_data_b) & " (expected " & to_string(patterns(i).data_b) &  ")"
          severity error;

      -- Tick the clock.
      s_clk <= '0';
    end loop;

    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

