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

entity mul32_tb is
end mul32_tb;
 
architecture behavioral of mul32_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_start_op : std_logic;
  signal s_src_a : std_logic_vector(31 downto 0);
  signal s_src_b : std_logic_vector(31 downto 0);
  signal s_signed_op : std_logic;
  signal s_result : std_logic_vector(63 downto 0);
  signal s_result_ready : std_logic;
begin
  mul32_0: entity work.mul32
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall => '0',
      i_start_op => s_start_op,
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      i_signed_op => s_signed_op,
      o_result => s_result,
      o_result_ready => s_result_ready
    );
   
  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      start_op : std_logic;
      src_a : std_logic_vector(31 downto 0);
      src_b : std_logic_vector(31 downto 0);
      signed_op : std_logic;

      -- Expected outputs
      result : std_logic_vector(63 downto 0);
      result_ready : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- 1 x 1 = 1
        ('1', X"00000001", X"00000001", '0', X"0000000000000000", '0'),
        ('0', X"00000001", X"00000001", '0', X"0000000000000001", '1'),
        ('1', X"00000001", X"00000001", '1', X"0000000000000001", '0'),
        ('0', X"00000001", X"00000001", '1', X"0000000000000001", '1'),
        ('1', X"00000001", X"FFFFFFFF", '1', X"0000000000000001", '0'),
        ('0', X"00000001", X"FFFFFFFF", '1', X"FFFFFFFFFFFFFFFF", '1'),
        ('1', X"FFFFFFFF", X"FFFFFFFF", '1', X"FFFFFFFFFFFFFFFF", '0'),
        ('0', X"FFFFFFFF", X"FFFFFFFF", '1', X"0000000000000001", '1'),

        -- 99 x 99 = 1
        ('1', X"00000063", X"00000063", '0', X"0000000000000001", '0'),
        ('0', X"00000063", X"00000063", '0', X"0000000000002649", '1'),
        ('1', X"00000063", X"00000063", '1', X"0000000000002649", '0'),
        ('0', X"00000063", X"00000063", '1', X"0000000000002649", '1'),
        ('1', X"00000063", X"FFFFFF9D", '1', X"0000000000002649", '0'),
        ('0', X"00000063", X"FFFFFF9D", '1', X"FFFFFFFFFFFFD9B7", '1')
      );
  begin
    -- Start by resetting the signals.
    s_clk <= '0';
    s_rst <= '1';
    s_start_op <= '0';
    s_src_a <= (others => '0');
    s_src_b <= (others => '0');
    s_signed_op <= '0';

    wait for 1 ns;
    s_clk <= '1';
    wait for 1 ns;
    s_rst <= '0';
    s_clk <= '0';
    wait for 1 ns;
    s_clk <= '1';

    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      wait until s_clk = '1';

      --  Set the inputs.
      s_start_op <= patterns(i).start_op;
      s_src_a <= patterns(i).src_a;
      s_src_b <= patterns(i).src_b;
      s_signed_op <= patterns(i).signed_op;

      -- Wait for the result to be produced.
      wait for 1 ns;

      --  Check the outputs.
      assert s_result = patterns(i).result
        report "Bad result value (" & integer'image(i) & "):" & lf &
            "  a=" & to_string(s_src_a) & lf &
            "  b=" & to_string(s_src_b) & lf &
            "  r=" & to_string(s_result) & " (expected " & to_string(patterns(i).result) & ")"
            severity error;
      assert s_result_ready = patterns(i).result_ready
        report "Bad result ready signal (" & integer'image(i) & "):" & lf &
            "  r=" & to_string(s_result_ready) & " (expected " & to_string(patterns(i).result_ready) & ")"
            severity error;

      -- Tick the clock.
      s_clk <= '0';
      wait for 1 ns;
      s_clk <= '1';
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;
