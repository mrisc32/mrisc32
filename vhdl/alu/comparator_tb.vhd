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

entity comparator_tb is
end comparator_tb;

architecture behavioral of comparator_tb is
  signal s_src : std_logic_vector(7 downto 0);
  signal s_eq  : std_logic;
  signal s_lt  : std_logic;
  signal s_le  : std_logic;
begin
  comparator_0: entity work.comparator
    generic map (
      WIDTH => 8
    )
    port map (
      i_src => s_src,
      o_eq => s_eq,
      o_lt => s_lt,
      o_le => s_le
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      src : std_logic_vector(7 downto 0);

      -- Expected outputs
      eq : std_logic;
      lt : std_logic;
      le : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        ("00000000", '1', '0', '1'),
        ("00000001", '0', '0', '0'),
        ("01111111", '0', '0', '0'),
        ("11000000", '0', '1', '1'),
        ("11111111", '0', '1', '1')
      );
  begin
    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_src <= patterns(i).src;

      --  Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_eq = patterns(i).eq
        report "Bad EQ value" severity error;
      assert s_lt = patterns(i).lt
        report "Bad LT value" severity error;
      assert s_le = patterns(i).le
        report "Bad LE value" severity error;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

