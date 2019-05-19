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
use work.common.all;

entity vector_stride_gen_tb is
end vector_stride_gen_tb;

architecture behavioral of vector_stride_gen_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_stall : std_logic;
  signal s_is_first_vector_op_cycle : std_logic;
  signal s_stride : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_offset : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Clock period.
  constant C_HALF_PERIOD : time := 2 ns;
begin
  vector_stride_gen_0: entity work.vector_stride_gen
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall => s_stall,
      i_is_first_vector_op_cycle => s_is_first_vector_op_cycle,
      i_stride => s_stride,
      o_offset => s_offset
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      stall : std_logic;
      is_first_vector_op_cycle : std_logic;
      stride : std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- Expected outputs
      offset : std_logic_vector(C_WORD_SIZE-1 downto 0);
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- The first state should be zero.
        ('0', '0', to_word(0), to_word(0)),
        ('0', '0', to_word(0), to_word(0)),

        -- Run a vector operation with stride 8.
        ('0', '1', to_word(8), to_word(0)),
        ('0', '0', to_word(8), to_word(8)),
        ('0', '0', to_word(8), to_word(16)),
        ('0', '0', to_word(8), to_word(24)),
        ('0', '0', to_word(8), to_word(32)),
        ('0', '0', to_word(8), to_word(40)),

        -- Stall...
        ('1', '0', to_word(8), to_word(48)),
        ('1', '0', to_word(8), to_word(48)),
        ('1', '0', to_word(8), to_word(48)),
        ('1', '0', to_word(8), to_word(48)),

        -- Continue.
        ('0', '0', to_word(8), to_word(48)),
        ('0', '0', to_word(8), to_word(56)),

        -- Restart with a stride of 96.
        ('0', '1', to_word(96), to_word(0)),
        ('0', '0', to_word(96), to_word(96)),

        -- Restart with a stride of -20.
        ('0', '1', to_word(-20), to_word(0)),
        ('0', '0', to_word(-20), to_word(-20)),
        ('0', '0', to_word(-20), to_word(-40)),
        ('0', '0', to_word(-20), to_word(-60)),
        ('0', '0', to_word(-20), to_word(-80)),

        -- Change the stride without restarting: should not affect the result.
        ('0', '0', to_word(123), to_word(-100)),
        ('0', '0', to_word(1), to_word(-120)),
        ('0', '0', to_word(0), to_word(-140))
      );
  begin
    -- Reset all inputs.
    s_clk <= '0';
    s_stall <= '0';
    s_is_first_vector_op_cycle <= '0';
    s_stride <= (others => '0');

    -- Start by resetting the register file.
    s_rst <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';
    s_rst <= '0';
    wait for C_HALF_PERIOD;
    s_clk <= '1';

    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      wait until s_clk = '1';

      -- Set the inputs.
      s_stall <= patterns(i).stall;
      s_is_first_vector_op_cycle <= patterns(i).is_first_vector_op_cycle;
      s_stride <= patterns(i).stride;

      -- Tick the clock.
      wait for C_HALF_PERIOD;
      s_clk <= '0';

      -- Wait for the result to be produced.
      wait until s_clk = '0';

      --  Check the outputs.
      assert s_offset = patterns(i).offset
        report "Bad offset (" & integer'image(i) & "):" & lf &
               "  " & to_string(s_offset) & " (expected " & to_string(patterns(i).offset) &  ")"
          severity error;

      -- Tick the clock.
      wait for C_HALF_PERIOD;
      s_clk <= '1';
    end loop;

    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

