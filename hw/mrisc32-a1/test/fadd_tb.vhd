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
use ieee.numeric_std.all;
use work.types.all;

--  A testbench has no ports.
entity fadd_tb is
end fadd_tb;

architecture behav of fadd_tb is
  -- IEEE 754 binary-32
  constant WIDTH : positive := 32;
  constant EXP_BITS : positive := 8;
  constant EXP_BIAS : positive := 127;
  constant FRACT_BITS : positive := 23;

  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_stall : std_logic;
  signal s_enable : std_logic;
  signal s_subtract : std_logic;

  signal s_props_a : T_FLOAT_PROPS;
  signal s_exponent_a : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_significand_a : std_logic_vector(FRACT_BITS downto 0);

  signal s_props_b : T_FLOAT_PROPS;
  signal s_exponent_b : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_significand_b : std_logic_vector(FRACT_BITS downto 0);

  signal s_flt32_a : std_logic_vector(WIDTH-1 downto 0);
  signal s_flt32_b : std_logic_vector(WIDTH-1 downto 0);
  signal s_magn_a_lt_magn_b : std_logic;

  signal s_props : T_FLOAT_PROPS;
  signal s_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_significand : std_logic_vector(FRACT_BITS downto 0);
  signal s_result_ready : std_logic;
begin
  --  Component instantiation.
  fadd_0: entity work.fadd
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall => s_stall,
      i_enable => s_enable,
      i_subtract => s_subtract,

      i_props_a => s_props_a,
      i_exponent_a => s_exponent_a,
      i_significand_a => s_significand_a,

      i_props_b => s_props_b,
      i_exponent_b => s_exponent_b,
      i_significand_b => s_significand_b,

      i_magn_a_lt_magn_b => s_magn_a_lt_magn_b,

      o_props => s_props,
      o_exponent => s_exponent,
      o_significand => s_significand,
      o_result_ready => s_result_ready
    );

  -- Use a float_compare entity to produce s_magn_a_lt_magn_b.
  cmp_0: entity work.float_compare
    port map (
      i_src_a => s_flt32_a,
      i_src_b => s_flt32_b,
      o_magn_lt => s_magn_a_lt_magn_b
    );


  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs.
      subtract : std_logic;

      props_a : T_FLOAT_PROPS;
      exponent_a : std_logic_vector(EXP_BITS-1 downto 0);
      significand_a : std_logic_vector(FRACT_BITS downto 0);

      props_b : T_FLOAT_PROPS;
      exponent_b : std_logic_vector(EXP_BITS-1 downto 0);
      significand_b : std_logic_vector(FRACT_BITS downto 0);

      -- Expected outputs.
      props : T_FLOAT_PROPS;
      exponent : std_logic_vector(EXP_BITS-1 downto 0);
      significand : std_logic_vector(FRACT_BITS downto 0);
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        (
         -- 0.0 + 0.0 = 0.0
         '0',
         ('0', '0', '0', '1'), 8X"00", 24X"000000",
         ('0', '0', '0', '1'), 8X"00", 24X"000000",
         ('0', '0', '0', '1'), 8X"00", 24X"000000"
        ),
        (
         -- 1.0 + 1.0 = 2.0
         '0',
         ('0', '0', '0', '0'), 8X"7f", 24X"800000",
         ('0', '0', '0', '0'), 8X"7f", 24X"800000",
         ('0', '0', '0', '0'), 8X"80", 24X"800000"
        ),
        (
         -- -2.0 + 1.0 = -1.0
         '0',
         ('1', '0', '0', '0'), 8X"80", 24X"800000",
         ('0', '0', '0', '0'), 8X"7f", 24X"800000",
         ('1', '0', '0', '0'), 8X"7f", 24X"800000"
        ),
        (
         -- 1.0 + NaN = NaN
         '0',
         ('0', '0', '0', '0'), 8X"7f", 24X"800000",
         ('0', '1', '0', '0'), 8X"ff", 24X"ffffff",
         ('0', '1', '0', '0'), 8X"ff", 24X"ffffff"
        ),
        (
         -- Inf + NaN = NaN
         '0',
         ('0', '0', '1', '0'), 8X"ff", 24X"800000",
         ('0', '1', '0', '0'), 8X"ff", 24X"ffffff",
         ('0', '1', '0', '0'), 8X"ff", 24X"ffffff"
        ),
        (
         -- Inf + Inf = Inf
         '0',
         ('1', '0', '1', '0'), 8X"ff", 24X"800000",
         ('1', '0', '1', '0'), 8X"ff", 24X"800000",
         ('1', '0', '1', '0'), 8X"ff", 24X"800000"
        ),
        (
         -- -Inf + -Inf = -Inf
         '0',
         ('1', '0', '1', '0'), 8X"ff", 24X"800000",
         ('1', '0', '1', '0'), 8X"ff", 24X"800000",
         ('1', '0', '1', '0'), 8X"ff", 24X"800000"
        ),
        (
         -- Inf + -Inf = -NaN
         '0',
         ('0', '0', '1', '0'), 8X"ff", 24X"800000",
         ('1', '0', '1', '0'), 8X"ff", 24X"800000",
         ('1', '1', '0', '0'), 8X"ff", 24X"ffffff"
        ),
        (
         -- Inf - Inf = -NaN
         '1',
         ('0', '0', '1', '0'), 8X"ff", 24X"800000",
         ('0', '0', '1', '0'), 8X"ff", 24X"800000",
         ('1', '1', '0', '0'), 8X"ff", 24X"ffffff"
        ),
        (
         -- -Inf - -Inf = -NaN
         '1',
         ('1', '0', '1', '0'), 8X"ff", 24X"800000",
         ('1', '0', '1', '0'), 8X"ff", 24X"800000",
         ('1', '1', '0', '0'), 8X"ff", 24X"ffffff"
        ),
        (
         -- -2.0 + Inf = Inf
         '0',
         ('1', '0', '0', '0'), 8X"80", 24X"800000",
         ('0', '0', '1', '0'), 8X"ff", 24X"800000",
         ('0', '0', '1', '0'), 8X"ff", 24X"800000"
        )
      );

    variable v_ignore_number : std_logic;
  begin
    -- Reset all inputs.
    s_stall <= '0';
    s_enable <= '0';
    s_subtract <= '0';
    s_props_a <= ('0', '0', '0', '0');
    s_exponent_a <= (others => '0');
    s_significand_a <= (others => '0');
    s_props_b <= ('0', '0', '0', '0');
    s_exponent_b <= (others => '0');
    s_significand_b <= (others => '0');

    -- Reset the entity.
    s_clk <= '0';
    s_rst <= '1';
    wait for 1 ns;
    s_clk <= '1';
    wait for 1 ns;
    s_clk <= '0';
    s_rst <= '0';
    wait for 1 ns;
    s_clk <= '1';
    wait until s_clk = '1';

    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      -- Convert inputs to float32 format (for float_compare inputs).
      s_flt32_a <= patterns(i).props_a.is_neg &
                   patterns(i).exponent_a &
                   patterns(i).significand_a(FRACT_BITS-1 downto 0);
      s_flt32_b <= patterns(i).props_b.is_neg &
                   patterns(i).exponent_b &
                   patterns(i).significand_b(FRACT_BITS-1 downto 0);

      -- Set the inputs.
      s_enable <= '1';
      s_subtract <= patterns(i).subtract;
      s_props_a <= patterns(i).props_a;
      s_exponent_a <= patterns(i).exponent_a;
      s_significand_a <= patterns(i).significand_a;
      s_props_b <= patterns(i).props_b;
      s_exponent_b <= patterns(i).exponent_b;
      s_significand_b <= patterns(i).significand_b;

      -- Run the necessary 3 cycles to get the results.
      wait for 1 ns;
      s_clk <= '0';
      wait for 1 ns;
      s_clk <= '1';
      wait until s_clk = '1';
      s_enable <= '0';
      wait for 1 ns;
      s_clk <= '0';
      wait for 1 ns;
      s_clk <= '1';
      wait for 1 ns;
      s_clk <= '0';
      wait for 1 ns;
      s_clk <= '1';
      wait for 1 ns;
      s_clk <= '0';
      wait for 1 ns;
      s_clk <= '1';
      wait until s_clk = '1';

      --  Check the outputs.
      v_ignore_number := s_props.is_nan or s_props.is_inf or s_props.is_zero;
      assert s_props.is_neg = patterns(i).props.is_neg
        report "Bad is_neg result (" & integer'image(i) & "):" & lf &
               "  r=" & to_string(s_props.is_neg) &
               " (e=" & to_string(patterns(i).props.is_neg) & ")"
            severity error;

      assert s_props.is_nan = patterns(i).props.is_nan
        report "Bad is_nan result (" & integer'image(i) & "):" & lf &
               "  r=" & to_string(s_props.is_nan) &
               " (e=" & to_string(patterns(i).props.is_nan) & ")"
            severity error;

      assert s_props.is_inf = patterns(i).props.is_inf
        report "Bad is_inf result (" & integer'image(i) & "):" & lf &
               "  r=" & to_string(s_props.is_inf) &
               " (e=" & to_string(patterns(i).props.is_inf) & ")"
            severity error;

      assert s_props.is_zero = patterns(i).props.is_zero
        report "Bad is_zero result (" & integer'image(i) & "):" & lf &
               "  r=" & to_string(s_props.is_zero) &
               " (e=" & to_string(patterns(i).props.is_zero) & ")"
            severity error;

      assert s_exponent = patterns(i).exponent or v_ignore_number = '1'
        report "Bad exponent result (" & integer'image(i) & "):" & lf &
               "  r=" & to_string(s_exponent) & lf &
               " (e=" & to_string(patterns(i).exponent) & ")"
            severity error;

      assert s_significand = patterns(i).significand or v_ignore_number = '1'
        report "Bad significand result (" & integer'image(i) & "):" & lf &
               "  r=" & to_string(s_significand) & lf &
               " (e=" & to_string(patterns(i).significand) & ")"
            severity error;

    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behav;
