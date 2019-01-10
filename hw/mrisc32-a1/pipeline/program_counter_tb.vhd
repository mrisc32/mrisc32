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

entity program_counter_tb is
end program_counter_tb;

architecture behavioral of program_counter_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_stall : std_logic;
  signal s_pccorr_source : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_pccorr_target : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_pccorr_is_branch : std_logic;
  signal s_pccorr_is_taken : std_logic;
  signal s_pccorr_adjust : std_logic;
  signal s_pccorr_adjusted_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  program_counter_0: entity work.program_counter
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall => s_stall,
      i_pccorr_source => s_pccorr_source,
      i_pccorr_target => s_pccorr_target,
      i_pccorr_is_branch => s_pccorr_is_branch,
      i_pccorr_is_taken => s_pccorr_is_taken,
      i_pccorr_adjust => s_pccorr_adjust,
      i_pccorr_adjusted_pc => s_pccorr_adjusted_pc,
      o_pc => s_pc
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      stall : std_logic;
      pccorr_source : std_logic_vector(C_WORD_SIZE-1 downto 0);
      pccorr_target : std_logic_vector(C_WORD_SIZE-1 downto 0);
      pccorr_is_branch : std_logic;
      pccorr_is_taken : std_logic;
      pccorr_adjust : std_logic;
      pccorr_adjusted_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- Expected outputs
      pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- After reset, the PC should be 0x00000200, and increment by +4 at each cycle.
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"00000200"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"00000204"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"00000208"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"0000020C"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"00000210"),

        -- Inject a branch correction.
        ('0', X"0000020C", X"00000204", '1', '1', '1', X"00000204", X"00000214"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"00000204"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"00000208"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"0000020C"),

        -- At this point the branch prediction should give the right suggestion.
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"00000204"),

        -- And we should get a confirmation that it's a branch, but without correction.
        ('0', X"0000020C", X"00000204", '1', '1', '0', X"00000204", X"00000208"),

        -- Inject stalls.
        ('1', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"0000020C"),
        ('1', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"0000020C"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"0000020C"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"00000204"),
        ('1', X"0000020C", X"00000204", '1', '1', '0', X"00000204", X"00000208"),
        ('0', X"0000020C", X"00000204", '1', '1', '0', X"00000204", X"00000208"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"0000020C"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"00000204"),

        -- Let the branch be un-taken, so correction is needed.
        ('0', X"0000020C", X"00000204", '1', '0', '1', X"00000210", X"00000208"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"00000210"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"00000214"),
        ('0', X"00000000", X"00000000", '0', '0', '0', X"00000000", X"00000218")
      );
  begin
    -- Start by resetting the input signals.
    s_clk <= '0';
    s_rst <= '1';
    s_stall <= '0';
    s_pccorr_source <= (others => '0');
    s_pccorr_target <= (others => '0');
    s_pccorr_is_branch <= '0';
    s_pccorr_is_taken <= '0';
    s_pccorr_adjust <= '0';
    s_pccorr_adjusted_pc <= (others => '0');

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
      s_stall <= patterns(i).stall;
      s_pccorr_source <= patterns(i).pccorr_source;
      s_pccorr_target <= patterns(i).pccorr_target;
      s_pccorr_is_branch <= patterns(i).pccorr_is_branch;
      s_pccorr_is_taken <= patterns(i).pccorr_is_taken;
      s_pccorr_adjust <= patterns(i).pccorr_adjust;
      s_pccorr_adjusted_pc <= patterns(i).pccorr_adjusted_pc;

      -- Wait for the result to be produced.
      wait for 1 ns;

      --  Check the outputs.
      assert s_pc = patterns(i).pc
        report "Bad PC (" & integer'image(i) & "):" & lf &
            "  PC=" & to_string(s_pc) & " (expected " & to_string(patterns(i).pc) & ")"
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
