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

entity div_pipelined_tb is
end div_pipelined_tb;
 
architecture behavioral of div_pipelined_tb is
  constant C_DIVIDER_WIDTH : positive := 8;

  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_enable : std_logic;
  signal s_op : T_DIV_OP;
  signal s_src_a : std_logic_vector(C_DIVIDER_WIDTH-1 downto 0);
  signal s_src_b : std_logic_vector(C_DIVIDER_WIDTH-1 downto 0);
  signal s_dst_reg : T_DST_REG;
  signal s_result : std_logic_vector(C_DIVIDER_WIDTH-1 downto 0);
  signal s_result_dst_reg : T_DST_REG;
  signal s_result_ready : std_logic;

  function make_dst_reg(reg: integer; element: integer; is_vector: std_logic) return T_DST_REG is
  begin
    return ('1',
            to_vector(reg, C_LOG2_NUM_REGS),
            to_vector(element, C_LOG2_VEC_REG_ELEMENTS),
            is_vector);
  end function;

  function empty_dst_reg return T_DST_REG is
  begin
    return ('0',
            to_vector(0, C_LOG2_NUM_REGS),
            to_vector(0, C_LOG2_VEC_REG_ELEMENTS),
            '0');
  end function;
begin
  div_pipelined_0: entity work.div_pipelined
    generic map (
      WIDTH => 8
    )
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_enable => s_enable,
      i_op => s_op,
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      i_dst_reg => s_dst_reg,
      o_result => s_result,
      o_result_dst_reg => s_result_dst_reg,
      o_result_ready => s_result_ready
    );
   
  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      enable : std_logic;
      op : T_DIV_OP;
      src_a : std_logic_vector(C_DIVIDER_WIDTH-1 downto 0);
      src_b : std_logic_vector(C_DIVIDER_WIDTH-1 downto 0);
      dst_reg : T_DST_REG;

      -- Expected outputs
      result : std_logic_vector(C_DIVIDER_WIDTH-1 downto 0);
      result_dst_reg : T_DST_REG;
      result_ready : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- TODO(m): Add more test vectors.

        -- 127 / 3 = 42 + 1/3
        ('1', C_DIV_DIVU, X"7F", X"03", make_dst_reg(1, 0, '0'), X"00",  empty_dst_reg,           '0'),
        ('1', C_DIV_REMU, X"7F", X"03", make_dst_reg(2, 0, '0'), X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"2A",  make_dst_reg(1, 0, '0'), '1'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"01",  make_dst_reg(2, 0, '0'), '1'),

        -- 255 / 77 = 3 + 24/77
        ('1', C_DIV_DIVU, X"FF", X"4D", make_dst_reg(1, 0, '0'), X"00",  empty_dst_reg,           '0'),
        ('1', C_DIV_REMU, X"FF", X"4D", make_dst_reg(2, 0, '0'), X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"03",  make_dst_reg(1, 0, '0'), '1'),
        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"18",  make_dst_reg(2, 0, '0'), '1'),

        ('0', C_DIV_DIVU, X"00", X"00", empty_dst_reg,           X"00",  empty_dst_reg,           '0')
      );
  begin
    -- Start by resetting the signals.
    s_clk <= '0';
    s_rst <= '1';
    s_enable <= '0';
    s_op <= (others => '0');
    s_src_a <= (others => '0');
    s_src_b <= (others => '0');
    s_dst_reg <= empty_dst_reg;

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
      s_dst_reg <= patterns(i).dst_reg;

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
      assert s_result_dst_reg.reg = patterns(i).result_dst_reg.reg
        report "Bad destination register (" & integer'image(i) & "):" & lf &
            "  r=" & to_string(s_result_dst_reg.reg) & " (expected " & to_string(patterns(i).result_dst_reg.reg) & ")"
            severity error;
      assert s_result_dst_reg.element = patterns(i).result_dst_reg.element
        report "Bad destination element (" & integer'image(i) & "):" & lf &
            "  r=" & to_string(s_result_dst_reg.element) & " (expected " & to_string(patterns(i).result_dst_reg.element) & ")"
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
