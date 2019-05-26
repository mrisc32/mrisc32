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

entity sau_tb is
end sau_tb;
 
architecture behavioral of sau_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_enable : std_logic;
  signal s_op : T_SAU_OP;
  signal s_packed_mode : T_PACKED_MODE;
  signal s_src_a : std_logic_vector(31 downto 0);
  signal s_src_b : std_logic_vector(31 downto 0);
  signal s_next_result : std_logic_vector(31 downto 0);
  signal s_next_result_ready : std_logic;
begin
  sau_0: entity work.sau
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall => '0',
      i_enable => s_enable,
      i_op => s_op,
      i_packed_mode => s_packed_mode,
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      o_next_result => s_next_result,
      o_next_result_ready => s_next_result_ready
    );
   
  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      enable : std_logic;
      op : T_SAU_OP;
      packed_mode : T_PACKED_MODE;
      src_a : std_logic_vector(31 downto 0);
      src_b : std_logic_vector(31 downto 0);

      -- Expected outputs
      next_result : std_logic_vector(31 downto 0);
      next_result_ready : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- ADDS
        ('1', C_SAU_ADDS,  C_PACKED_NONE,      X"12345678", X"12345678", X"00000000", '0'),
        ('1', C_SAU_ADDS,  C_PACKED_NONE,      X"7FFFFFFF", X"12345678", X"2468ACF0", '1'),
        ('1', C_SAU_ADDS,  C_PACKED_NONE,      X"7FFFFFFF", X"7FFFFFFF", X"7FFFFFFF", '1'),
        ('1', C_SAU_ADDS,  C_PACKED_NONE,      X"80000000", X"EDCBA988", X"7FFFFFFF", '1'),
        ('1', C_SAU_ADDS,  C_PACKED_NONE,      X"80000000", X"80000000", X"80000000", '1'),
        ('0', C_SAU_ADDS,  C_PACKED_NONE,      X"00000001", X"00000001", X"80000000", '1'),

        -- ADDSU
        ('1', C_SAU_ADDSU, C_PACKED_NONE,      X"12345678", X"12345678", X"00000000", '0'),
        ('1', C_SAU_ADDSU, C_PACKED_NONE,      X"7FFFFFFF", X"12345678", X"2468ACF0", '1'),
        ('1', C_SAU_ADDSU, C_PACKED_NONE,      X"FFFFFFFF", X"12345678", X"92345677", '1'),
        ('1', C_SAU_ADDSU, C_PACKED_NONE,      X"7FFFFFFF", X"7FFFFFFF", X"FFFFFFFF", '1'),
        ('1', C_SAU_ADDSU, C_PACKED_NONE,      X"FFFFFFFF", X"FFFFFFFF", X"FFFFFFFE", '1'),
        ('1', C_SAU_ADDSU, C_PACKED_NONE,      X"80000000", X"EDCBA988", X"FFFFFFFF", '1'),
        ('1', C_SAU_ADDSU, C_PACKED_NONE,      X"80000000", X"80000000", X"FFFFFFFF", '1'),
        ('0', C_SAU_ADDSU, C_PACKED_NONE,      X"00000001", X"00000001", X"FFFFFFFF", '1'),

        -- ADDH
        ('1', C_SAU_ADDH,  C_PACKED_NONE,      X"12345678", X"12345678", X"00000000", '0'),
        ('1', C_SAU_ADDH,  C_PACKED_NONE,      X"7FFFFFFF", X"12345678", X"12345678", '1'),
        ('1', C_SAU_ADDH,  C_PACKED_NONE,      X"7FFFFFFF", X"7FFFFFFF", X"491A2B3B", '1'),
        ('1', C_SAU_ADDH,  C_PACKED_NONE,      X"80000000", X"EDCBA988", X"7FFFFFFF", '1'),
        ('1', C_SAU_ADDH,  C_PACKED_NONE,      X"FFFFFFFF", X"80000000", X"B6E5D4C4", '1'),
        ('1', C_SAU_ADDH,  C_PACKED_NONE,      X"FFFFFFFF", X"00000001", X"BFFFFFFF", '1'),
        ('0', C_SAU_ADDH,  C_PACKED_NONE,      X"00000001", X"00000001", X"00000000", '1'),

        -- ADDHU
        ('1', C_SAU_ADDHU, C_PACKED_NONE,      X"12345678", X"12345678", X"00000000", '0'),
        ('1', C_SAU_ADDHU, C_PACKED_NONE,      X"7FFFFFFF", X"12345678", X"12345678", '1'),
        ('1', C_SAU_ADDHU, C_PACKED_NONE,      X"7FFFFFFF", X"7FFFFFFF", X"491A2B3B", '1'),
        ('1', C_SAU_ADDHU, C_PACKED_NONE,      X"80000000", X"EDCBA988", X"7FFFFFFF", '1'),
        ('1', C_SAU_ADDHU, C_PACKED_NONE,      X"FFFFFFFF", X"80000000", X"B6E5D4C4", '1'),
        ('1', C_SAU_ADDHU, C_PACKED_NONE,      X"FFFFFFFF", X"00000001", X"BFFFFFFF", '1'),
        ('0', C_SAU_ADDHU, C_PACKED_NONE,      X"00000001", X"00000001", X"80000000", '1'),

        -- SUBS
        ('1', C_SAU_SUBS,  C_PACKED_NONE,      X"12345678", X"12345678", X"00000000", '0'),
        ('1', C_SAU_SUBS,  C_PACKED_NONE,      X"7FFFFFFF", X"FFFF0000", X"00000000", '1'),
        ('1', C_SAU_SUBS,  C_PACKED_NONE,      X"FFFF0000", X"7FFFFFFF", X"7FFFFFFF", '1'),
        ('1', C_SAU_SUBS,  C_PACKED_NONE,      X"00000000", X"EDCBA988", X"80000000", '1'),
        ('1', C_SAU_SUBS,  C_PACKED_NONE,      X"FFFFFFFF", X"12345678", X"12345678", '1'),
        ('0', C_SAU_SUBS,  C_PACKED_NONE,      X"00000001", X"00000001", X"EDCBA987", '1'),

        -- SUBSU
        ('1', C_SAU_SUBSU, C_PACKED_NONE,      X"12345678", X"12345678", X"00000000", '0'),
        ('1', C_SAU_SUBSU, C_PACKED_NONE,      X"7FFFFFFF", X"FFFF0000", X"00000000", '1'),
        ('1', C_SAU_SUBSU, C_PACKED_NONE,      X"FFFF0000", X"7FFFFFFF", X"00000000", '1'),
        ('1', C_SAU_SUBSU, C_PACKED_NONE,      X"00000000", X"EDCBA988", X"7FFF0001", '1'),
        ('1', C_SAU_SUBSU, C_PACKED_NONE,      X"FFFFFFFF", X"12345678", X"00000000", '1'),
        ('0', C_SAU_SUBSU, C_PACKED_NONE,      X"00000001", X"00000001", X"EDCBA987", '1'),

        -- SUBH
        ('1', C_SAU_SUBH,  C_PACKED_NONE,      X"12345678", X"12345678", X"00000000", '0'),
        ('1', C_SAU_SUBH,  C_PACKED_NONE,      X"7FFFFFFF", X"FFFF0000", X"00000000", '1'),
        ('1', C_SAU_SUBH,  C_PACKED_NONE,      X"FFFF0000", X"7FFFFFFF", X"40007FFF", '1'),
        ('1', C_SAU_SUBH,  C_PACKED_NONE,      X"00000000", X"EDCBA988", X"BFFF8000", '1'),
        ('1', C_SAU_SUBH,  C_PACKED_NONE,      X"FFFFFFFF", X"12345678", X"091A2B3C", '1'),
        ('0', C_SAU_SUBH,  C_PACKED_NONE,      X"00000001", X"00000001", X"F6E5D4C3", '1'),

        -- SUBHU
        ('1', C_SAU_SUBHU, C_PACKED_NONE,      X"12345678", X"12345678", X"00000000", '0'),
        ('1', C_SAU_SUBHU, C_PACKED_NONE,      X"7FFFFFFF", X"FFFF0000", X"00000000", '1'),
        ('1', C_SAU_SUBHU, C_PACKED_NONE,      X"FFFF0000", X"7FFFFFFF", X"C0007FFF", '1'),
        ('1', C_SAU_SUBHU, C_PACKED_NONE,      X"00000000", X"EDCBA988", X"3FFF8000", '1'),
        ('1', C_SAU_SUBHU, C_PACKED_NONE,      X"FFFFFFFF", X"12345678", X"891A2B3C", '1'),
        ('0', C_SAU_SUBHU, C_PACKED_NONE,      X"00000001", X"00000001", X"76E5D4C3", '1')

        -- TODO(m): Add test vectors for packed operations.
      );
  begin
    -- Start by resetting the signals.
    s_clk <= '0';
    s_rst <= '1';
    s_enable <= '0';
    s_op <= (others => '0');
    s_packed_mode <= C_PACKED_NONE;
    s_src_a <= (others => '0');
    s_src_b <= (others => '0');

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
      s_enable <= patterns(i).enable;
      s_op <= patterns(i).op;
      s_packed_mode <= patterns(i).packed_mode;
      s_src_a <= patterns(i).src_a;
      s_src_b <= patterns(i).src_b;

      -- Wait for the result to be produced.
      wait for 1 ns;

      --  Check the outputs.
      assert s_next_result = patterns(i).next_result or s_next_result_ready = '0'
        report "Bad result value (" & integer'image(i) & "):" & lf &
            "  a=" & to_string(patterns(i-1).src_a) & lf &
            "  b=" & to_string(patterns(i-1).src_b) & lf &
            "  r=" & to_string(s_next_result) & " (expected " & to_string(patterns(i).next_result) & ")"
            severity error;
      assert s_next_result_ready = patterns(i).next_result_ready
        report "Bad result ready signal (" & integer'image(i) & "):" & lf &
            "  r=" & to_string(s_next_result_ready) & " (expected " & to_string(patterns(i).next_result_ready) & ")"
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
