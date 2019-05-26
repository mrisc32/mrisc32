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
use work.config.all;

--  A testbench has no ports.
entity shuf32_tb is
end shuf32_tb;

architecture behav of shuf32_tb is
  signal s_src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  --  Component instantiation.
  shuf32_0: entity work.shuf32
    port map (
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      o_result => s_result
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
      src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- Expected outputs
      result : std_logic_vector(C_WORD_SIZE-1 downto 0);
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        (X"860F3355",
         32B"0000001010011",
         X"55330F86"),
        (X"860F3355",
         32B"0001001000000",
         X"33335555"),
        (X"860F3355",
         32B"0100101110111",
         X"00000000"),
        (X"860F3355",
         32B"1100101110111",
         X"000000FF"),
        (X"860F3355",
         32B"1111011110010",
         X"FF86000F")
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
      assert s_result = patterns(i).result
        report "Bad SHUF32 result:" & lf &
               "  a=" & to_string(s_src_a) & lf &
               "  b=" & to_string(s_src_b) & lf &
               "  r=" & to_string(s_result) & lf &
               " (e=" & to_string(patterns(i).result) & ")"
            severity error;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behav;
