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
entity fpu_tb is
end fpu_tb;

architecture behav of fpu_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_stall : std_logic;
  signal s_enable : std_logic;
  signal s_op : T_FPU_OP;
  signal s_packed_mode : T_PACKED_MODE;
  signal s_src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f1_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f1_next_result_ready : std_logic;
  signal s_f4_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f4_next_result_ready : std_logic;
begin
  --  Component instantiation.
  fpu_0: entity work.fpu
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall => s_stall,
      i_enable => s_enable,
      i_op => s_op,
      i_packed_mode => s_packed_mode,
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      o_f1_next_result => s_f1_next_result,
      o_f1_next_result_ready => s_f1_next_result_ready,
      o_f4_next_result => s_f4_next_result,
      o_f4_next_result_ready => s_f4_next_result_ready
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs.
      enable : std_logic;
      op : T_FPU_OP;
      packed_mode : T_PACKED_MODE;
      src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
      src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- Expected outputs.
      f1_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
      f1_next_result_ready : std_logic;
      f4_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
      f4_next_result_ready : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        ----------------------------------------------------------------------
        ('1', C_FPU_FSEQ, "00",
         X"12345678",
         X"12345678",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSEQ, "01",
         X"12345678",
         X"12345678",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSEQ, "10",
         X"12345678",
         X"12345678",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSEQ, "00",
         X"12345678",
         X"12345679",
         X"00000000", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSEQ, "01",
         X"12345678",
         X"12345679",
         X"FFFFFF00", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSEQ, "10",
         X"12345678",
         X"12345679",
         X"FFFF0000", '1',
         X"00000000", '0'),

        ----------------------------------------------------------------------
        ('1', C_FPU_FSNE, "00",
         X"12345678",
         X"12345678",
         X"00000000", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSNE, "01",
         X"12345678",
         X"12345678",
         X"00000000", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSNE, "10",
         X"12345678",
         X"12345678",
         X"00000000", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSNE, "00",
         X"12345678",
         X"12345679",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSNE, "01",
         X"12345678",
         X"12345679",
         X"000000FF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSNE, "10",
         X"12345678",
         X"12345679",
         X"0000FFFF", '1',
         X"00000000", '0'),

        ----------------------------------------------------------------------
        ('1', C_FPU_FSLT, "00",
         X"12345678",
         X"12345678",
         X"00000000", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSLT, "01",
         X"12345678",
         X"12345678",
         X"00000000", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSLT, "10",
         X"12345678",
         X"12345678",
         X"00000000", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSLT, "00",
         X"12345678",
         X"12345679",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSLT, "01",
         X"12345678",
         X"12345679",
         X"000000FF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSLT, "10",
         X"12345678",
         X"12345679",
         X"0000FFFF", '1',
         X"00000000", '0'),

        ----------------------------------------------------------------------
        ('1', C_FPU_FSLE, "00",
         X"12345678",
         X"12345678",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSLE, "01",
         X"12345678",
         X"12345678",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSLE, "10",
         X"12345678",
         X"12345678",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSLE, "00",
         X"12345678",
         X"12345679",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSLE, "01",
         X"12345678",
         X"12345679",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSLE, "10",
         X"12345678",
         X"12345679",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ----------------------------------------------------------------------
        ('1', C_FPU_FSNAN, "00",
         X"7F800001",
         X"12345678",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSNAN, "01",
         X"79010079",
         X"12345678",
         X"FF0000FF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSNAN, "10",
         X"7C010000",
         X"12345678",
         X"FFFF0000", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSNAN, "00",
         X"12345678",
         X"7F800001",
         X"FFFFFFFF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSNAN, "01",
         X"12345678",
         X"79010079",
         X"FF0000FF", '1',
         X"00000000", '0'),

        ('1', C_FPU_FSNAN, "10",
         X"12345678",
         X"7C010000",
         X"FFFF0000", '1',
         X"00000000", '0'),

        ----------------------------------------------------------------------
        ('1', C_FPU_FMIN, "00",
         X"12345678",
         X"23456789",
         X"12345678", '1',
         X"00000000", '0'),

        ('1', C_FPU_FMIN, "01",
         X"12345678",
         X"23456789",
         X"12345689", '1',
         X"00000000", '0'),

        ('1', C_FPU_FMIN, "10",
         X"12345678",
         X"23456789",
         X"12345678", '1',
         X"00000000", '0'),

        ----------------------------------------------------------------------
        ('1', C_FPU_FMAX, "00",
         X"12345678",
         X"23456789",
         X"23456789", '1',
         X"00000000", '0'),

        ('1', C_FPU_FMAX, "01",
         X"12345678",
         X"23456789",
         X"23456778", '1',
         X"00000000", '0'),

        ('1', C_FPU_FMAX, "10",
         X"12345678",
         X"23456789",
         X"23456789", '1',
         X"00000000", '0'),

        --( 36 )--------------------------------------------------------------
        ('1', C_FPU_FMUL, "00",
         X"40490fdb",  -- 3.1415927
         X"c0f8a3d7",  -- -7.77
         X"00000000", '0',
         X"00000000", '0'),

        ('1', C_FPU_FMUL, "00",
         X"40490fdb",  -- 3.1415927
         X"40f8a3d7",  -- 7.77
         X"00000000", '0',
         X"00000000", '0'),

        ('1', C_FPU_FMUL, "00",
         X"7f000000",  -- 1.7014118e38
         X"ff000000",  -- -1.7014118e38
         X"00000000", '0',
         X"00000000", '0'),

        ('1', C_FPU_FMUL, "00",
         X"00000000",  -- 0.0
         X"7f800000",  -- +Inf
         X"00000000", '0',
         X"c1c3480a", '1'),  -- 3.1415927 * -7.77 = -24.410175

        ('0', C_FPU_FMUL, "00",
         X"00000000",  -- 0.0
         X"00000000",  -- 0.0
         X"00000000", '0',
         X"41c3480a", '1'),  -- 3.1415927 * 7.77 = 24.410175

        ('0', C_FPU_FMUL, "00",
         X"00000000",  -- 0.0
         X"00000000",  -- 0.0
         X"00000000", '0',
         X"ff800000", '1'),  -- 1.7014118e38 * -1.7014118e38  = -Inf

        ('0', C_FPU_FMUL, "00",
         X"00000000",  -- 0.0
         X"00000000",  -- 0.0
         X"00000000", '0',
         X"7fffffff", '1'),  -- 0.0 * Inf = NaN

        --( 43 )--------------------------------------------------------------
        ('1', C_FPU_FADD, "00",
         X"40490fdb",  -- 3.1415927
         X"40f8a3d7",  -- 7.77
         X"00000000", '0',
         X"00000000", '0'),

        ('1', C_FPU_FADD, "00",
         X"3f800000",  -- 1.0
         X"3f800000",  -- 1.0
         X"00000000", '0',
         X"00000000", '0'),

        ('1', C_FPU_FADD, "00",
         X"40490fdb",  -- 3.1415927
         X"c0f8a3d7",  -- -7.77
         X"00000000", '0',
         X"00000000", '0'),

        ('1', C_FPU_FADD, "00",
         X"40f8a3d7",  -- 7.77
         X"c0f8a3d7",  -- -7.77
         X"00000000", '0',
         X"412e95e2", '1'), -- 3.1415927 + 7.77 = 10.911592

        ('1', C_FPU_FADD, "00",
         X"7f000000",  -- 1.7014118e+38
         X"7f000000",  -- 1.7014118e+38
         X"00000000", '0',
         X"40000000", '1'), -- 1.0 + 1.0 = 2.0

        ('1', C_FPU_FADD, "00",
         X"00880000",  -- 1.2489627e-38
         X"80800000",  -- -1.1754944e-38
         X"00000000", '0',
         X"c0941bea", '1'), -- 3.1415927 + -7.77 = -4.6284075

        ('0', C_FPU_FADD, "00",
         X"00000000",  -- 0.0
         X"00000000",  -- 0.0
         X"00000000", '0',
         X"00000000", '1'), -- 7.77 + -7.77 = 0.0

        ('0', C_FPU_FADD, "00",
         X"00000000",  -- 0.0
         X"00000000",  -- 0.0
         X"00000000", '0',
         X"7f800000", '1'), -- 1.7014118e+38 + 1.7014118e+38 = inf

        ('0', C_FPU_FADD, "00",
         X"00000000",  -- 0.0
         X"00000000",  -- 0.0
         X"00000000", '0',
         X"00000000", '1')  -- 1.2489627e-38 + -1.1754944e-38 = 0.0
      );
  begin
    -- Reset all inputs.
    s_stall <= '0';
    s_enable <= '0';
    s_op <= (others => '0');
    s_packed_mode <= (others => '0');
    s_src_a <= (others => '0');
    s_src_b <= (others => '0');

    -- Reset the entity.
    s_clk <= '0';
    s_rst <= '1';
    wait for 1 ns;
    s_clk <= '1';
    wait for 1 ns;
    s_clk <= '0';
    s_rst <= '0';
    wait for 1 ns;

    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      -- Wait for a positive edge on the clock.
      s_clk <= '1';
      wait until s_clk = '1';

      --  Set the inputs.
      s_enable <= patterns(i).enable;
      s_op <= patterns(i).op;
      s_packed_mode <= patterns(i).packed_mode;
      s_src_a <= patterns(i).src_a;
      s_src_b <= patterns(i).src_b;

      --  Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_f1_next_result = patterns(i).f1_next_result or s_f1_next_result_ready = '0'
        report "Bad FPU F1 result (" & integer'image(i) & "):" & lf &
               "  op=" & to_string(s_op) & lf &
               "  a=" & to_string(s_src_a) & lf &
               "  b=" & to_string(s_src_b) & lf &
               "  r=" & to_string(s_f1_next_result) & lf &
               " (e=" & to_string(patterns(i).f1_next_result) & ")"
            severity error;

      assert s_f1_next_result_ready = patterns(i).f1_next_result_ready
        report "Bad FPU F1 result ready (" & integer'image(i) & "):" & lf &
               "  op=" & to_string(s_op) & lf &
               "  a=" & to_string(s_src_a) & lf &
               "  b=" & to_string(s_src_b) & lf &
               "  r=" & to_string(s_f1_next_result_ready) & lf &
               " (e=" & to_string(patterns(i).f1_next_result_ready) & ")"
            severity error;

      assert s_f4_next_result = patterns(i).f4_next_result or s_f4_next_result_ready = '0'
        report "Bad FPU F4 result (" & integer'image(i) & "):" & lf &
               "  op=" & to_string(s_op) & lf &
               "  a=" & to_string(s_src_a) & lf &
               "  b=" & to_string(s_src_b) & lf &
               "  r=" & to_string(s_f4_next_result) & lf &
               " (e=" & to_string(patterns(i).f4_next_result) & ")"
            severity error;

      assert s_f4_next_result_ready = patterns(i).f4_next_result_ready
        report "Bad FPU F4 result ready (" & integer'image(i) & "):" & lf &
               "  op=" & to_string(s_op) & lf &
               "  a=" & to_string(s_src_a) & lf &
               "  b=" & to_string(s_src_b) & lf &
               "  r=" & to_string(s_f4_next_result_ready) & lf &
               " (e=" & to_string(patterns(i).f4_next_result_ready) & ")"
            severity error;

      -- Tick the clock.
      s_clk <= '0';
      wait for 1 ns;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behav;
