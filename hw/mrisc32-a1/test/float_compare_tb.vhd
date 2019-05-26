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
use work.types.all;

entity float_compare_tb is
end float_compare_tb;

architecture behavioral of float_compare_tb is
  signal s_src_a : std_logic_vector(31 downto 0);
  signal s_src_b : std_logic_vector(31 downto 0);
  signal s_eq : std_logic;
  signal s_ne : std_logic;
  signal s_lt : std_logic;
  signal s_le : std_logic;
begin
  float_compare_0: entity work.float_compare
    generic map (
      WIDTH => F32_WIDTH
    )
    port map (
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      o_eq => s_eq,
      o_ne => s_ne,
      o_lt => s_lt,
      o_le => s_le
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      src_a : std_logic_vector(31 downto 0);
      src_b : std_logic_vector(31 downto 0);

      -- Expected outputs
      eq : std_logic;
      ne : std_logic;
      lt : std_logic;
      le : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        (X"00000000", X"00000000", '1', '0', '0', '1'),
        (X"12345678", X"12345678", '1', '0', '0', '1'),
        (X"12345678", X"12345679", '0', '1', '1', '1'),
        (X"12345679", X"12345678", '0', '1', '0', '0'),
        (X"92345678", X"12345678", '0', '1', '1', '1'),
        (X"12345678", X"92345678", '0', '1', '0', '0'),
        (X"92345678", X"92345678", '1', '0', '0', '1'),
        (X"92345678", X"92345679", '0', '1', '0', '0'),
        (X"92345679", X"92345678", '0', '1', '1', '1')
      );
  begin
    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_src_a <= patterns(i).src_a;
      s_src_b <= patterns(i).src_b;

      --  Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_eq = patterns(i).eq
        report "Incorrect eq value:" & lf &
               "  src_a=" & to_string(s_src_a) & lf &
               "  src_b=" & to_string(s_src_b) & lf &
               "  actual:   " & to_string(s_eq) & lf &
               "  expected: " & to_string(patterns(i).eq)
            severity error;

      assert s_ne = patterns(i).ne
        report "Incorrect ne value:" & lf &
               "  src_a=" & to_string(s_src_a) & lf &
               "  src_b=" & to_string(s_src_b) & lf &
               "  actual:   " & to_string(s_eq) & lf &
               "  expected: " & to_string(patterns(i).ne)
            severity error;

      assert s_lt = patterns(i).lt
        report "Incorrect lt value:" & lf &
               "  src_a=" & to_string(s_src_a) & lf &
               "  src_b=" & to_string(s_src_b) & lf &
               "  actual:   " & to_string(s_eq) & lf &
               "  expected: " & to_string(patterns(i).lt)
            severity error;

      assert s_le = patterns(i).le
        report "Incorrect le value:" & lf &
               "  src_a=" & to_string(s_src_a) & lf &
               "  src_b=" & to_string(s_src_b) & lf &
               "  actual:   " & to_string(s_eq) & lf &
               "  expected: " & to_string(patterns(i).le)
            severity error;

    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

