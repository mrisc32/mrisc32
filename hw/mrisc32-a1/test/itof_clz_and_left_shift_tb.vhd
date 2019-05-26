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
use work.config.all;

--  A testbench has no ports.
entity itof_clz_and_left_shift_tb is
end itof_clz_and_left_shift_tb;

architecture behav of itof_clz_and_left_shift_tb is
  signal s_src : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_left_shift : std_logic_vector(C_LOG2_WORD_SIZE-1 downto 0);
begin
  --  Component instantiation.
  itof_clz_and_left_shift_0: entity work.itof_clz_and_left_shift
    port map (
      i_src => s_src,
      o_result => s_result,
      o_left_shift => s_left_shift
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      src : std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- Expected outputs
      result : std_logic_vector(C_WORD_SIZE-1 downto 0);
      left_shift : std_logic_vector(C_LOG2_WORD_SIZE-1 downto 0);
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        ("00000000000000000000000000000000",
         "00000000000000000000000000000000",
         5X"1f"),
        ("00000000000000000000000000000001",
         "10000000000000000000000000000000",
         5X"1f"),
        ("00000000000000000000000000000010",
         "10000000000000000000000000000000",
         5X"1e"),
        ("00000000000000000000000000000101",
         "10100000000000000000000000000000",
         5X"1d"),
        ("00000000000000000000000000001010",
         "10100000000000000000000000000000",
         5X"1c"),
        ("00000000000000000000000000010100",
         "10100000000000000000000000000000",
         5X"1b"),
        ("00000000000000000000000000101000",
         "10100000000000000000000000000000",
         5X"1a"),
        ("00000000000000000000000001010001",
         "10100010000000000000000000000000",
         5X"19"),
        ("00000000000000000000000010100010",
         "10100010000000000000000000000000",
         5X"18"),
        ("00000000000000000000000101000101",
         "10100010100000000000000000000000",
         5X"17"),
        ("00000000000000000000001010001010",
         "10100010100000000000000000000000",
         5X"16"),
        ("00000000000000000000010100010100",
         "10100010100000000000000000000000",
         5X"15"),
        ("00000000000000000000101000101000",
         "10100010100000000000000000000000",
         5X"14"),
        ("00000000000000000001010001010000",
         "10100010100000000000000000000000",
         5X"13"),
        ("00000000000000000010100010100001",
         "10100010100001000000000000000000",
         5X"12"),
        ("00000000000000000101000101000010",
         "10100010100001000000000000000000",
         5X"11"),
        ("00000000000000001010001010000100",
         "10100010100001000000000000000000",
         5X"10"),
        ("00000000000000010100010100001000",
         "10100010100001000000000000000000",
         5X"0f"),
        ("00000000000000101000101000010001",
         "10100010100001000100000000000000",
         5X"0e"),
        ("00000000000001010001010000100010",
         "10100010100001000100000000000000",
         5X"0d"),
        ("00000000000010100010100001000100",
         "10100010100001000100000000000000",
         5X"0c"),
        ("00000000000101000101000010001000",
         "10100010100001000100000000000000",
         5X"0b"),
        ("00000000001010001010000100010000",
         "10100010100001000100000000000000",
         5X"0a"),
        ("00000000010100010100001000100001",
         "10100010100001000100001000000000",
         5X"09"),
        ("00000000101000101000010001000010",
         "10100010100001000100001000000000",
         5X"08"),
        ("00000001010001010000100010000100",
         "10100010100001000100001000000000",
         5X"07"),
        ("00000010100010100001000100001000",
         "10100010100001000100001000000000",
         5X"06"),
        ("00000101000101000010001000010000",
         "10100010100001000100001000000000",
         5X"05"),
        ("00001010001010000100010000100000",
         "10100010100001000100001000000000",
         5X"04"),
        ("00010100010100001000100001000000",
         "10100010100001000100001000000000",
         5X"03"),
        ("00101000101000010001000010000000",
         "10100010100001000100001000000000",
         5X"02"),
        ("01010001010000100010000100000000",
         "10100010100001000100001000000000",
         5X"01"),
        ("10100010100001000100001000000001",
         "10100010100001000100001000000001",
         5X"00")
      );
  begin
    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_src <= patterns(i).src;

      --  Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_result = patterns(i).result and s_left_shift = patterns(i).left_shift
        report "Bad result (" & integer'image(i) & "):" & lf &
               "    result=" & to_string(s_result) & lf &
               " (expected=" & to_string(patterns(i).result) & ")" & lf &
               "  left_shift=" & to_string(s_left_shift) & lf &
               "   (expected=" & to_string(patterns(i).left_shift) & ")"
            severity error;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behav;
