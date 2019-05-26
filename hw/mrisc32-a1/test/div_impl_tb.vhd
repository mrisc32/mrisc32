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

entity div_impl_tb is
end div_impl_tb;
 
architecture behavioral of div_impl_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_stall : std_logic;
  signal s_enable : std_logic;
  signal s_op : T_DIV_OP;
  signal s_src_a : std_logic_vector(7 downto 0);
  signal s_src_b : std_logic_vector(7 downto 0);
  signal s_d3_next_result : std_logic_vector(7 downto 0);
  signal s_d3_next_result_ready : std_logic;
  signal s_d4_next_result : std_logic_vector(7 downto 0);
  signal s_d4_next_result_ready : std_logic;
begin
  div_impl_0: entity work.div_impl
    generic map (
      WIDTH => 8,
      EXP_BITS => F8_EXP_BITS,
      EXP_BIAS => F8_EXP_BIAS,
      FRACT_BITS => F8_FRACT_BITS,
      CNT_BITS => 2,
      STEPS_PER_CYCLE => 2
    )
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall => '0',
      o_stall => s_stall,
      i_enable => s_enable,
      i_op => s_op,
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      o_d3_next_result => s_d3_next_result,
      o_d3_next_result_ready => s_d3_next_result_ready,
      o_d4_next_result => s_d4_next_result,
      o_d4_next_result_ready => s_d4_next_result_ready
    );
   
  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      enable : std_logic;
      op : T_DIV_OP;
      src_a : std_logic_vector(7 downto 0);
      src_b : std_logic_vector(7 downto 0);

      -- Expected outputs
      stall : std_logic;
      d3_next_result : std_logic_vector(7 downto 0);
      d3_next_result_ready : std_logic;
      d4_next_result : std_logic_vector(7 downto 0);
      d4_next_result_ready : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- TODO(m): Add more test vectors.

        -- 7 / 3 = 2 + 1/3
        ('1', C_DIV_DIV,  X"07", X"03", '0', X"00", '0', X"00", '0'),
        ('1', C_DIV_REM,  X"07", X"03", '1', X"00", '0', X"00", '0'),
        ('1', C_DIV_REM,  X"07", X"03", '1', X"00", '0', X"00", '0'),
        ('1', C_DIV_REM,  X"07", X"03", '1', X"00", '0', X"00", '0'),
        ('1', C_DIV_REM,  X"07", X"03", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '1', X"02", '1', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '1', X"02", '1', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '1', X"02", '1', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '0', X"02", '1', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '0', X"01", '1', X"00", '0'),

        -- -7 / 3 = -2,   13 % -5 = 3
        ('1', C_DIV_DIV,  X"F9", X"03", '0', X"00", '0', X"00", '0'),
        ('1', C_DIV_REM,  X"0D", X"FB", '1', X"00", '0', X"00", '0'),
        ('1', C_DIV_REM,  X"0D", X"FB", '1', X"00", '0', X"00", '0'),
        ('1', C_DIV_REM,  X"0D", X"FB", '1', X"00", '0', X"00", '0'),
        ('1', C_DIV_REM,  X"0D", X"FB", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '1', X"FE", '1', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '1', X"FE", '1', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '1', X"FE", '1', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '0', X"FE", '1', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '0', X"03", '1', X"00", '0'),

        -- 8-bit floating point:
        --   0.140625 = 00100001 = 0x21
        --   1.0      = 00111000 = 0x38
        --   2.25     = 01000001 = 0x41
        --   3.0      = 01000100 = 0x44
        --   7.0      = 01001110 = 0x4e
        --  18.0      = 01011001 = 0x59
        -- 120.0      = 01101111 = 0x6f

        -- 7.0 / 1.0 = 7.0
        ('1', C_DIV_FDIV, X"4e", X"38", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '1', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '1', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"4e", '1'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"00", '0'),

        -- 1.0 / 7.0 = 0.142857... ~= 0.140625
        ('1', C_DIV_FDIV, X"38", X"4e", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '1', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '1', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"21", '1'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"00", '0'),

        -- 7.0 / 3.0 = 2.333... ~= 2.25
        ('1', C_DIV_FDIV, X"4e", X"44", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '1', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '1', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"41", '1'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"00", '0'),

        -- 120.0 / 7.0 = 17.142857... ~= 18.0 (rounded)
        -- 7.0 / 3.0 = 2.333... ~= 2.25
        ('1', C_DIV_FDIV, X"6f", X"4e", '0', X"00", '0', X"00", '0'),
        ('1', C_DIV_FDIV, X"4e", X"44", '1', X"00", '0', X"00", '0'),
        ('1', C_DIV_FDIV, X"4e", X"44", '1', X"00", '0', X"00", '0'),
        ('1', C_DIV_FDIV, X"4e", X"44", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '1', X"00", '0', X"00", '0'),
        ('0', C_DIV_FDIV, X"00", X"00", '1', X"00", '0', X"59", '1'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"59", '1'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"59", '1'),
        ('0', C_DIV_FDIV, X"00", X"00", '0', X"00", '0', X"41", '1'),

        -- Tail cycles...
        ('0', C_DIV_REM,  X"00", X"00", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '0', X"00", '0', X"00", '0'),
        ('0', C_DIV_REM,  X"00", X"00", '0', X"00", '0', X"00", '0')
      );
  begin
    -- Start by resetting the signals.
    s_clk <= '0';
    s_rst <= '1';
    s_enable <= '0';
    s_op <= (others => '0');
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
      s_src_a <= patterns(i).src_a;
      s_src_b <= patterns(i).src_b;

      -- Wait for the result to be produced.
      wait for 1 ns;

      --  Check the outputs.
      assert s_d3_next_result = patterns(i).d3_next_result or s_d3_next_result_ready = '0'
        report "Bad D3 result value (" & integer'image(i) & "):" & lf &
            "  r=" & to_string(s_d3_next_result) & " (expected " & to_string(patterns(i).d3_next_result) & ")"
            severity error;
      assert s_d3_next_result_ready = patterns(i).d3_next_result_ready
        report "Bad D3 result ready signal (" & integer'image(i) & "):" & lf &
            "  r=" & to_string(s_d3_next_result_ready) & " (expected " & to_string(patterns(i).d3_next_result_ready) & ")"
            severity error;
      assert s_d4_next_result = patterns(i).d4_next_result or s_d4_next_result_ready = '0'
        report "Bad D4 result value (" & integer'image(i) & "):" & lf &
            "  r=" & to_string(s_d4_next_result) & " (expected " & to_string(patterns(i).d4_next_result) & ")"
            severity error;
      assert s_d4_next_result_ready = patterns(i).d4_next_result_ready
        report "Bad D4 result ready signal (" & integer'image(i) & "):" & lf &
            "  r=" & to_string(s_d4_next_result_ready) & " (expected " & to_string(patterns(i).d4_next_result_ready) & ")"
            severity error;
      assert s_stall = patterns(i).stall
        report "Bad stall signal (" & integer'image(i) & "):" & lf &
            "  r=" & to_string(s_stall) & " (expected " & to_string(patterns(i).stall) & ")"
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
