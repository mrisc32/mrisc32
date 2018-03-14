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

entity mulu_tb is
end mulu_tb;
 
architecture behavioral of mulu_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_src_a : std_logic_vector(3 downto 0);
  signal s_src_b : std_logic_vector(3 downto 0);
  signal s_start_op : std_logic;
  signal s_result : std_logic_vector(7 downto 0);
  signal s_result_ready : std_logic;
begin
  mulu_0: entity work.mulu
    generic map (
      WIDTH => 4,
      COUNTER_BITS => 2
    )
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      i_start_op => s_start_op,
      o_result => s_result,
      o_result_ready => s_result_ready
    );
   
  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      start_op : std_logic;
      src_a : std_logic_vector(3 downto 0);
      src_b : std_logic_vector(3 downto 0);

      -- Expected outputs
      result : std_logic_vector(7 downto 0);
      result_ready : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- 1 x 1 = 1
        ('1', "0001", "0001", "00000000", '0'),
        ('0', "0001", "0001", "00000001", '0'),
        ('0', "0001", "0001", "00000001", '0'),
        ('0', "0001", "0001", "00000001", '0'),
        ('0', "0001", "0001", "00000001", '1'),

        -- 1 x 0 = 0
        ('1', "0001", "0000", "00000001", '0'),
        ('0', "0001", "0000", "00000000", '0'),
        ('0', "0001", "0000", "00000000", '0'),
        ('0', "0001", "0000", "00000000", '0'),
        ('0', "0001", "0000", "00000000", '1'),

        -- 3 x 10 = 30
        ('1', "0011", "1010", "00000000", '0'),
        ('0', "0011", "1010", "00000000", '0'),
        ('0', "0011", "1010", "00000110", '0'),
        ('0', "0011", "1010", "00000110", '0'),
        ('0', "0011", "1010", "00011110", '1')
      );
  begin
    -- Start by resetting the entity.
    s_rst <= '1';
    s_clk <= '0';
    s_start_op <= '0';
    s_src_a <= (others => '0');
    s_src_b <= (others => '0');
    wait for 1 ns;
    s_clk <= '1';
    wait for 1 ns;
    s_rst <= '0';
    s_clk <= '0';
    wait for 1 ns;

    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_start_op <= patterns(i).start_op;
      s_src_a <= patterns(i).src_a;
      s_src_b <= patterns(i).src_b;

      -- Tick the clock.
      s_clk <= '1';
      wait for 1 ns;
      s_clk <= '0';
      wait for 1 ns;

      --  Check the outputs.
      assert s_result = patterns(i).result
        report "Bad result value (" & integer'image(i) & "):" & lf &
            "  a=" & to_string(s_src_a) & lf &
            "  b=" & to_string(s_src_b) & lf &
            "  r=" & to_string(s_result) & " (expected " & to_string(patterns(i).result) & ")"
            severity error;
      assert s_result_ready = patterns(i).result_ready
        report "Bad result ready (" & integer'image(i) & "):" & lf &
            "  r=" & to_string(s_result_ready) & " (expected " & to_string(patterns(i).result_ready) & ")"
            severity error;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;
