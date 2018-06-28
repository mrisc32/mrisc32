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

entity float32_isnan_tb is
end float32_isnan_tb;

architecture behavioral of float32_isnan_tb is
  signal s_src : std_logic_vector(31 downto 0);
  signal s_is_nan : std_logic;
begin
  float32_isnan_0: entity work.float32_isnan
    port map (
      i_src => s_src,
      o_is_nan => s_is_nan
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      src : std_logic_vector(31 downto 0);

      -- Expected outputs
      is_nan : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        (X"00000000", '0'),
        (X"7F800000", '0'),
        (X"FF800000", '0'),
        (X"7FFFFFFF", '1'),
        (X"FFFFFFFF", '1'),
        (X"7F800010", '1'),
        (X"7FC00000", '1'),
        (X"FFC00000", '1')
      );
  begin
    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_src <= patterns(i).src;

      --  Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_is_nan = patterns(i).is_nan
        report "Incorrect result:" & lf &
               "  src=" & to_string(s_src) & lf &
               "  is_nan=" & to_string(s_is_nan) & lf &
               "  expected: " & to_string(patterns(i).is_nan)
            severity error;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

