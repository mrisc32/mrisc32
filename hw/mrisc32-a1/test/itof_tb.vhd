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

--  A testbench has no ports.
entity itof_tb is
end itof_tb;

architecture behav of itof_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_stall : std_logic;
  signal s_enable : std_logic;
  signal s_unsigned : std_logic;
  signal s_integer : std_logic_vector(F32_WIDTH-1 downto 0);
  signal s_exponent_bias : std_logic_vector(F32_WIDTH-1 downto 0);

  signal s_props : T_FLOAT_PROPS;
  signal s_exponent : std_logic_vector(F32_EXP_BITS-1 downto 0);
  signal s_significand : std_logic_vector(F32_FRACT_BITS downto 0);
  signal s_result_ready : std_logic;
begin
  --  Component instantiation.
  itof_0: entity work.itof
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall => s_stall,
      i_enable => s_enable,
      i_unsigned => s_unsigned,
      i_integer => s_integer,
      i_exponent_bias => s_exponent_bias,
      o_props => s_props,
      o_exponent => s_exponent,
      o_significand => s_significand,
      o_result_ready => s_result_ready
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      unsigned : std_logic;
      int : std_logic_vector(F32_WIDTH-1 downto 0);
      exponent_bias : std_logic_vector(F32_WIDTH-1 downto 0);

      -- Expected outputs
      props : T_FLOAT_PROPS;
      exponent : std_logic_vector(F32_EXP_BITS-1 downto 0);
      significand : std_logic_vector(F32_FRACT_BITS downto 0);
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- Zero
        ('0', X"00000000", X"00000000",
         ('0', '0', '0', '1'), 8X"00", 24X"000000"),

        -- Positive numbers.
        ('0', X"00001234", X"00000000",
         ('0', '0', '0', '0'), 8X"8b", 24X"91a000"),
        ('0', X"00012340", X"00000004",
         ('0', '0', '0', '0'), 8X"8b", 24X"91a000"),

        -- Large unsigned numbers.
        ('1', X"ffffedcc", X"00000000",
         ('0', '0', '0', '0'), 8X"9e", 24X"ffffee"),
        ('1', X"ffffedcc", X"00000004",
         ('0', '0', '0', '0'), 8X"9a", 24X"ffffee"),

        -- Negative numbers.
        ('0', X"ffffedcc", X"00000000",
         ('1', '0', '0', '0'), 8X"8b", 24X"91a000"),
        ('0', X"ffffedcc", X"00000003",
         ('1', '0', '0', '0'), 8X"88", 24X"91a000"),

        -- Largest positive/negative numbers.
        ('0', X"7fffffff", X"00000000",
         ('0', '0', '0', '0'), 8X"9e", 24X"800000"),  -- Rounded.
        ('0', X"80000000", X"00000000",
         ('1', '0', '0', '0'), 8X"9e", 24X"800000"),

        -- Overflow/underflow.
        ('0', X"10000000", X"ff000000",
         ('0', '0', '1', '0'), 8X"00", 24X"000000"),
        ('0', X"10000000", X"ffffff80",
         ('0', '0', '1', '0'), 8X"00", 24X"000000"),
        ('0', X"00000001", X"00000080",
         ('0', '0', '0', '1'), 8X"00", 24X"000000"),
        ('0', X"00000001", X"7fffffff",
         ('0', '0', '0', '1'), 8X"00", 24X"000000")
      );
  begin
    -- Clear inputs and reset.
    s_rst <= '1';
    s_stall <= '0';
    s_enable <= '0';
    s_unsigned <= '0';
    s_integer <= (others => '0');
    s_exponent_bias <= (others => '0');
    s_clk <= '0';
    wait for 1 ns;
    s_clk <= '1';
    wait for 1 ns;
    s_clk <= '0';
    s_rst <= '0';
    wait for 1 ns;
    s_clk <= '1';
    wait for 1 ns;
    s_clk <= '0';

    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_enable <= '1';
      s_unsigned <= patterns(i).unsigned; 
      s_integer <= patterns(i).int;
      s_exponent_bias <= patterns(i).exponent_bias;

      --  Wait for the results.
      wait for 1 ns;
      s_clk <= '1';
      wait for 1 ns;
      s_clk <= '0';
      wait for 1 ns;
      s_clk <= '1';
      wait for 1 ns;

      --  Check the outputs.
      assert s_props = patterns(i).props
        report "Bad props (" & integer'image(i) & "):" & lf &
               "    result=" & to_string(s_props.is_neg) & "," &
                               to_string(s_props.is_nan) & "," &
                               to_string(s_props.is_inf) & "," &
                               to_string(s_props.is_zero) & lf &
               "  expected=" & to_string(patterns(i).props.is_neg) & "," &
                               to_string(patterns(i).props.is_nan) & "," &
                               to_string(patterns(i).props.is_inf) & "," &
                               to_string(patterns(i).props.is_zero)
            severity error;

      assert s_exponent = patterns(i).exponent or (s_props.is_inf = '1' or s_props.is_zero = '1')
        report "Bad exponent (" & integer'image(i) & "):" & lf &
               "    result=" & to_string(s_exponent) & lf &
               "  expected=" & to_string(patterns(i).exponent)
            severity error;

      assert s_significand = patterns(i).significand or (s_props.is_inf = '1' or s_props.is_zero = '1')
        report "Bad significand (" & integer'image(i) & "):" & lf &
               "    result=" & to_string(s_significand) & lf &
               "  expected=" & to_string(patterns(i).significand)
            severity error;

      assert s_result_ready = '1'
        report "Bad result_ready (" & integer'image(i) & "):" & lf &
               "    result=" & to_string(s_result_ready) & lf &
               "  expected=1"
            severity error;

      --  Tick the clock.
      s_clk <= '0';
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behav;
