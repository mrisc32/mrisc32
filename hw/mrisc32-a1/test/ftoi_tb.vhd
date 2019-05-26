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
entity ftoi_tb is
end ftoi_tb;

architecture behav of ftoi_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_stall : std_logic;
  signal s_enable : std_logic;
  signal s_round : std_logic;
  signal s_unsigned : std_logic;
  signal s_props : T_FLOAT_PROPS;
  signal s_exponent : std_logic_vector(F32_EXP_BITS-1 downto 0);
  signal s_significand : std_logic_vector(F32_FRACT_BITS downto 0);
  signal s_exponent_bias : std_logic_vector(F32_WIDTH-1 downto 0);

  signal s_result : std_logic_vector(F32_WIDTH-1 downto 0);
  signal s_result_ready : std_logic;
begin
  --  Component instantiation.
  ftoi_0: entity work.ftoi
    generic map (
      WIDTH => F32_WIDTH,
      EXP_BITS => F32_EXP_BITS,
      EXP_BIAS => F32_EXP_BIAS,
      FRACT_BITS => F32_FRACT_BITS
    )
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall => s_stall,
      i_enable => s_enable,
      i_round => s_round,
      i_unsigned => s_unsigned,
      i_props => s_props,
      i_exponent => s_exponent,
      i_significand => s_significand,
      i_exponent_bias => s_exponent_bias,
      o_result => s_result,
      o_result_ready => s_result_ready
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      round : std_logic;
      unsigned : std_logic;
      props : T_FLOAT_PROPS;
      exponent : std_logic_vector(F32_EXP_BITS-1 downto 0);
      significand : std_logic_vector(F32_FRACT_BITS downto 0);
      exponent_bias : std_logic_vector(F32_WIDTH-1 downto 0);

      -- Expected outputs
      result : std_logic_vector(F32_WIDTH-1 downto 0);
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- Zero
        ('0', '0', ('0', '0', '0', '1'), 8X"00", 24X"000000",
         X"00000000",
         X"00000000"),

        -- Positive numbers.
        ('0', '0', ('0', '0', '0', '0'), 8X"8b", 24X"91a000",
         X"00000000",
         X"00001234"),
        ('0', '0', ('0', '0', '0', '0'), 8X"8b", 24X"91a000",
         X"00000004",
         X"00012340"),

        -- Negative numbers.
        ('0', '0', ('1', '0', '0', '0'), 8X"8b", 24X"91a000",
         X"00000000",
         X"ffffedcc"),
        ('0', '0', ('1', '0', '0', '0'), 8X"8b", 24X"91a000",
         X"00000004",
         X"fffedcc0"),

        -- Rounding.
        ('0', '0', ('0', '0', '0', '0'), 8X"88", 24X"91a000",
         X"00000000",
         X"00000246"),
        ('1', '0', ('0', '0', '0', '0'), 8X"88", 24X"91a000",
         X"00000000",
         X"00000247"),

        -- Overflow.
        ('0', '0', ('0', '0', '0', '0'), 8X"9d", 24X"ffffff",  -- 2147483520 = ok
         X"00000000",
         X"7fffff80"),
        ('0', '0', ('1', '0', '0', '0'), 8X"9e", 24X"800000",  -- -2147483648 = ok
         X"00000000",
         X"80000000"),
        ('0', '1', ('0', '0', '0', '0'), 8X"9e", 24X"800000",  -- Unsigned 2147483648 = ok
         X"00000000",
         X"80000000"),
        ('0', '0', ('1', '0', '0', '0'), 8X"80", 24X"800000",  -- Signed -2 = ok
         X"00000000",
         X"fffffffe"),
        ('0', '1', ('1', '0', '0', '0'), 8X"80", 24X"800000",  -- Unsigned -2 = overflow
         X"00000000",
         X"ffffffff"),
        ('0', '0', ('0', '0', '0', '0'), 8X"9e", 24X"800000",  -- 2147483648 > 2147483647 = overflow
         X"00000000",
         X"ffffffff"),
        ('0', '0', ('1', '0', '0', '0'), 8X"9e", 24X"800001",  -- -2147483904 < -2147483648 = overflow
         X"00000000",
         X"ffffffff"),
        ('0', '0', ('0', '1', '0', '0'), 8X"00", 24X"000000",  -- NaN
         X"00000000",
         X"ffffffff"),
        ('0', '0', ('0', '0', '1', '0'), 8X"00", 24X"000000",  -- +Inf
         X"00000000",
         X"ffffffff"),
        ('0', '0', ('1', '0', '1', '0'), 8X"00", 24X"000000",  -- -Inf
         X"00000000",
         X"ffffffff"),
        ('0', '0', ('0', '0', '0', '0'), 8X"8b", 24X"91a000",  -- exponent + offset = ok
         X"00000012",
         X"48d00000"),
        ('0', '0', ('0', '0', '0', '0'), 8X"8b", 24X"91a000",  -- exponent + offset = overflow
         X"00000013",
         X"ffffffff")
      );
  begin
    -- Clear inputs and reset.
    s_rst <= '1';
    s_stall <= '0';
    s_enable <= '0';
    s_round <= '0';
    s_unsigned <= '0';
    s_props <= ('0', '0', '0', '0');
    s_exponent <= (others => '0');
    s_significand <= (others => '0');
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
      s_round <= patterns(i).round;
      s_unsigned <= patterns(i).unsigned;
      s_props <= patterns(i).props;
      s_exponent <= patterns(i).exponent;
      s_significand <= patterns(i).significand;
      s_exponent_bias <= patterns(i).exponent_bias;

      --  Wait for the results.
      wait for 1 ns;
      s_clk <= '1';
      wait for 1 ns;
      s_clk <= '0';
      s_enable <= '0';
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

      assert s_result = patterns(i).result
        report "Bad result (" & integer'image(i) & "):" & lf &
               "    result=" & to_string(s_result) & lf &
               "  expected=" & to_string(patterns(i).result)
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
