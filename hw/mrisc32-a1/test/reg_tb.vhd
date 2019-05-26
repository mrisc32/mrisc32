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

entity reg_tb is
end reg_tb;

architecture behavioral of reg_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_we : std_logic;
  signal s_data_w : std_logic_vector(3 downto 0);
  signal s_data : std_logic_vector(3 downto 0);
begin
  reg_0: entity work.reg
    generic map (
      WIDTH => 4
    )
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_we => s_we,
      i_data_w => s_data_w,
      o_data => s_data
    );

  process
    -- Patterns to apply.
    type pattern_type is record
      -- Inputs
      clk : std_logic;
      rst : std_logic;
      we : std_logic;
      data_w : std_logic_vector(3 downto 0);

      -- Expected outputs
      data : std_logic_vector(3 downto 0);
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        ('1', '0', '0', "1111", "0000"),
        ('0', '0', '1', "1111", "0000"),
        ('1', '0', '1', "1111", "1111"),
        ('0', '0', '0', "0011", "1111"),
        ('1', '0', '0', "0011", "1111"),
        ('0', '0', '1', "0011", "1111"),
        ('1', '0', '1', "0011", "0011"),
        ('0', '1', '0', "0011", "0000")
      );
  begin
    -- Start by resetting the register (to have defined signals).
    s_rst <= '1';
    s_clk <= '0';
    s_we <= '0';
    s_data_w <= "1010";

    wait for 1 ns;
    s_rst <= '0';

    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_clk <= patterns(i).clk;
      s_rst <= patterns(i).rst;
      s_we <= patterns(i).we;
      s_data_w <= patterns(i).data_w;

      --  Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_data = patterns(i).data
        report "Bad register data:" & lf &
               "  i      = " & integer'image(i) & lf &
               "  data   = " & to_string(s_data) & lf &
               " (expected " & to_string(patterns(i).data) & ")"
            severity error;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

