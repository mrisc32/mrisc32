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

entity adder_tb is
end adder_tb;
 
architecture behavioral of adder_tb is
  component adder
    generic(WIDTH : positive);
    port(
        i_subtract : in  std_logic;
        i_src_a    : in  std_logic_vector(WIDTH-1 downto 0);
        i_src_b    : in  std_logic_vector(WIDTH-1 downto 0);
        o_result   : out std_logic_vector(WIDTH-1 downto 0);
        o_c_out    : out std_logic
      );
  end component;

  signal s_subtract : std_logic;
  signal s_src_a    : std_logic_vector(7 downto 0);
  signal s_src_b    : std_logic_vector(7 downto 0);
  signal s_result   : std_logic_vector(7 downto 0);
  signal s_c_out    : std_logic;
begin
  adder_0: entity work.adder
    generic map (
      WIDTH => 8
    )
    port map (
      i_subtract => s_subtract,
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      o_result => s_result,
      o_c_out => s_c_out
    );
   
  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      subtract : std_logic;
      src_a    : std_logic_vector(7 downto 0);
      src_b    : std_logic_vector(7 downto 0);

      -- Expected outputs
      result : std_logic_vector(7 downto 0);
      c_out  : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        ('0', "00000001", "00000001", "00000010", '0'),
        ('1', "00000001", "00000111", "00000110", '1'),
        ('0', "11111111", "00000001", "00000000", '1'),
        ('1', "00000001", "11111110", "11111101", '1')
      );
  begin
    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_subtract <= patterns(i).subtract;
      s_src_a <= patterns(i).src_a;
      s_src_b <= patterns(i).src_b;

      --  Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_result = patterns(i).result
        report "Bad sum value" severity error;
      assert s_c_out = patterns(i).c_out
        report "Bad carray out value" severity error;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

