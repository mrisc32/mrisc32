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

entity vector_control_tb is
end vector_control_tb;

architecture behavioral of vector_control_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_stall : std_logic;
  signal s_cancel : std_logic;
  signal s_is_vector_op : std_logic;
  signal s_vl : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_fold : std_logic;
  signal s_element_a : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
  signal s_element_b : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
  signal s_is_vector_op_busy : std_logic;
  signal s_is_first_vector_op_cycle : std_logic;
  signal s_bubble : std_logic;

  -- Clock period.
  constant C_HALF_PERIOD : time := 2 ns;

  function vl(x: integer) return std_logic_vector is
  begin
    return to_vector(x, C_WORD_SIZE);
  end function;

  function elem(x: integer) return std_logic_vector is
  begin
    return to_vector(x, C_LOG2_VEC_REG_ELEMENTS);
  end function;
begin
  vector_control_0: entity work.vector_control
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall => s_stall,
      i_cancel => s_cancel,
      i_is_vector_op => s_is_vector_op,
      i_vl => s_vl,
      i_fold => s_fold,
      o_element_a => s_element_a,
      o_element_b => s_element_b,
      o_is_vector_op_busy => s_is_vector_op_busy,
      o_is_first_vector_op_cycle => s_is_first_vector_op_cycle,
      o_bubble => s_bubble
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      stall : std_logic;
      cancel : std_logic;
      is_vector_op : std_logic;
      vl : std_logic_vector(C_WORD_SIZE-1 downto 0);
      fold : std_logic;

      -- Expected outputs
      element_a : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
      element_b : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
      is_vector_op_busy : std_logic;
      is_first_vector_op_cycle : std_logic;
      bubble : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- The first state should be zero.
        ('0', '0', '0', vl(4), '0', elem(0), elem(0), '0', '0', '0'),
        ('0', '0', '0', vl(4), '0', elem(0), elem(0), '0', '0', '0'),

        -- Perform a vector operation of length 4.
        ('0', '0', '1', vl(4), '0', elem(0), elem(0), '1', '1', '0'),
        ('0', '0', '1', vl(4), '0', elem(1), elem(1), '1', '0', '0'),
        ('0', '0', '1', vl(4), '0', elem(2), elem(2), '1', '0', '0'),
        ('0', '0', '1', vl(4), '0', elem(3), elem(3), '0', '0', '0'),

        -- Scalar operations...
        ('0', '0', '0', vl(4), '0', elem(0), elem(0), '0', '0', '0'),
        ('0', '0', '0', vl(4), '0', elem(0), elem(0), '0', '0', '0'),

        -- Perform a vector operation of length 3.
        ('0', '0', '1', vl(3), '0', elem(0), elem(0), '1', '1', '0'),
        ('0', '0', '1', vl(3), '0', elem(1), elem(1), '1', '0', '0'),
        ('0', '0', '1', vl(3), '0', elem(2), elem(2), '0', '0', '0'),

        -- ...and then a new vector operation.
        ('0', '0', '1', vl(3), '0', elem(0), elem(0), '1', '1', '0'),
        ('0', '0', '1', vl(3), '0', elem(1), elem(1), '1', '0', '0'),
        ('0', '0', '1', vl(3), '0', elem(2), elem(2), '0', '0', '0'),

        -- Perform a vector operation of length 0: Should bubble.
        ('0', '0', '1', vl(0), '0', elem(0), elem(0), '0', '1', '1'),

        -- Perform a vector operation of length 1.
        ('0', '0', '1', vl(1), '0', elem(0), elem(0), '0', '1', '0'),

        -- Scalar operations...
        ('0', '0', '0', vl(1), '0', elem(0), elem(0), '0', '0', '0'),
        ('0', '0', '0', vl(2), '0', elem(0), elem(0), '0', '0', '0'),

        -- Perform a vector operation of length 2.
        ('0', '0', '1', vl(2), '0', elem(0), elem(0), '1', '1', '0'),
        ('0', '0', '1', vl(2), '0', elem(1), elem(1), '0', '0', '0'),

        -- Perform a vector operation of length 999999: Should bubble.
        ('0', '0', '1', vl(999999), '0', elem(0), elem(0), '0', '1', '1'),

        -- Perform a vector operation of length 3, with stalling.
        ('0', '0', '1', vl(3), '0', elem(0), elem(0), '1', '1', '0'),
        ('1', '0', '1', vl(3), '0', elem(1), elem(1), '1', '0', '0'),
        ('1', '0', '1', vl(3), '0', elem(1), elem(1), '1', '0', '0'),
        ('1', '0', '1', vl(3), '0', elem(1), elem(1), '1', '0', '0'),
        ('0', '0', '1', vl(3), '0', elem(1), elem(1), '1', '0', '0'),
        ('0', '0', '1', vl(3), '0', elem(2), elem(2), '0', '0', '0'),

        -- Perform a vector operation of length 2, with folding.
        ('0', '0', '1', vl(2), '1', elem(0), elem(2), '1', '1', '0'),
        ('0', '0', '1', vl(2), '1', elem(1), elem(3), '0', '0', '0'),

        -- (tail)
        ('0', '0', '0', vl(4), '0', elem(0), elem(0), '0', '0', '0'),
        ('0', '0', '0', vl(4), '0', elem(0), elem(0), '0', '0', '0'),
        ('0', '0', '0', vl(4), '0', elem(0), elem(0), '0', '0', '0')
      );
  begin
    -- Reset all inputs.
    s_clk <= '0';
    s_stall <= '0';
    s_is_vector_op <= '0';
    s_vl <= vl(0);
    s_fold <= '0';

    -- Start by resetting the register file.
    s_rst <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';
    s_rst <= '0';
    wait for C_HALF_PERIOD;
    s_clk <= '1';

    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      wait until s_clk = '1';

      -- Set the inputs.
      s_stall <= patterns(i).stall;
      s_is_vector_op <= patterns(i).is_vector_op;
      s_vl <= patterns(i).vl;
      s_fold <= patterns(i).fold;

      -- Tick the clock.
      wait for C_HALF_PERIOD;
      s_clk <= '0';

      -- Wait for the result to be produced.
      wait until s_clk = '0';

      --  Check the outputs.
      assert s_element_a = patterns(i).element_a
        report "Bad reg A element (" & integer'image(i) & "):" & lf &
               "  " & to_string(s_element_a) & " (expected " & to_string(patterns(i).element_a) &  ")"
          severity error;
      assert s_element_b = patterns(i).element_b
        report "Bad reg B element (" & integer'image(i) & "):" & lf &
               "  " & to_string(s_element_b) & " (expected " & to_string(patterns(i).element_b) &  ")"
          severity error;
      assert s_is_vector_op_busy = patterns(i).is_vector_op_busy
        report "Bad is_vector_op_busy value (" & integer'image(i) & "):" & lf &
               "  " & to_string(s_is_vector_op_busy) & " (expected " & to_string(patterns(i).is_vector_op_busy) &  ")"
          severity error;
      assert s_is_first_vector_op_cycle = patterns(i).is_first_vector_op_cycle
        report "Bad is_first_vector_op_cycle value (" & integer'image(i) & "):" & lf &
               "  " & to_string(s_is_first_vector_op_cycle) & " (expected " & to_string(patterns(i).is_first_vector_op_cycle) &  ")"
          severity error;
      assert s_bubble = patterns(i).bubble
        report "Bad bubble value (" & integer'image(i) & "):" & lf &
               "  " & to_string(s_bubble) & " (expected " & to_string(patterns(i).bubble) &  ")"
          severity error;

      -- Tick the clock.
      wait for C_HALF_PERIOD;
      s_clk <= '1';
    end loop;

    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

