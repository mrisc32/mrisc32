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
use work.common.all;

entity float_decompose_tb is
end float_decompose_tb;

architecture behavioral of float_decompose_tb is
  signal s_src : std_logic_vector(31 downto 0);
  signal s_sign : std_logic;
  signal s_is_nan : std_logic;
  signal s_is_inf : std_logic;
  signal s_is_zero : std_logic;
begin
  float_decompose_0: entity work.float_decompose
    generic map (
      WIDTH => F32_WIDTH,
      EXP_BITS => F32_EXP_BITS,
      FRACT_BITS => F32_FRACT_BITS
    )
    port map (
      i_src => s_src,
      o_sign => s_sign,
      o_is_nan => s_is_nan,
      o_is_inf => s_is_inf,
      o_is_zero => s_is_zero
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      src : std_logic_vector(31 downto 0);

      -- Expected outputs
      sign : std_logic;
      is_nan : std_logic;
      is_inf : std_logic;
      is_zero : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        (X"00000000", '0', '0', '0', '1'),
        (X"80000000", '1', '0', '0', '1'),
        (X"7F800000", '0', '0', '1', '0'),
        (X"FF800000", '1', '0', '1', '0'),
        (X"7FFFFFFF", '0', '1', '0', '0'),
        (X"FFFFFFFF", '1', '1', '0', '0'),
        (X"7F800010", '0', '1', '0', '0'),
        (X"7FC00000", '0', '1', '0', '0'),
        (X"FFC00000", '1', '1', '0', '0'),
        (X"80000001", '1', '0', '0', '1')
      );
  begin
    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_src <= patterns(i).src;

      --  Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_sign = patterns(i).sign
        report "Incorrect sign value:" & lf &
               "  src=" & to_string(s_src) & lf &
               "  sign=" & to_string(s_sign) & lf &
               "  expected: " & to_string(patterns(i).sign)
            severity error;

      assert s_is_nan = patterns(i).is_nan
        report "Incorrect is_nan value:" & lf &
               "  src=" & to_string(s_src) & lf &
               "  is_nan=" & to_string(s_is_nan) & lf &
               "  expected: " & to_string(patterns(i).is_nan)
            severity error;

      assert s_is_inf = patterns(i).is_inf
        report "Incorrect is_inf value:" & lf &
               "  src=" & to_string(s_src) & lf &
               "  is_inf=" & to_string(s_is_inf) & lf &
               "  expected: " & to_string(patterns(i).is_inf)
            severity error;

      assert s_is_zero = patterns(i).is_zero
        report "Incorrect is_zero value:" & lf &
               "  src=" & to_string(s_src) & lf &
               "  is_zero=" & to_string(s_is_zero) & lf &
               "  expected: " & to_string(patterns(i).is_zero)
            severity error;

    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

