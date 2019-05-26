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
use ieee.numeric_std.all;
use work.types.all;
use work.config.all;

entity fetch_tb is
end fetch_tb;

architecture behavioral of fetch_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;
  signal s_stall : std_logic;
  signal s_cancel : std_logic;

  signal s_pccorr_source : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_pccorr_target : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_pccorr_is_branch : std_logic;
  signal s_pccorr_is_taken : std_logic;
  signal s_pccorr_adjust : std_logic;
  signal s_pccorr_adjusted_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);

  signal s_wb_cyc : std_logic;
  signal s_wb_stb : std_logic;
  signal s_wb_adr : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_wb_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_wb_ack : std_logic;
  signal s_wb_stall : std_logic;
  signal s_wb_err : std_logic;

  signal s_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_instr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_bubble : std_logic;
begin
  fetch_0: entity work.fetch
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_stall => s_stall,
      i_cancel => s_cancel,

      i_pccorr_source => s_pccorr_source,
      i_pccorr_target => s_pccorr_target,
      i_pccorr_is_branch => s_pccorr_is_branch,
      i_pccorr_is_taken => s_pccorr_is_taken,
      i_pccorr_adjust => s_pccorr_adjust,
      i_pccorr_adjusted_pc => s_pccorr_adjusted_pc,

      o_wb_cyc => s_wb_cyc,
      o_wb_stb => s_wb_stb,
      o_wb_adr => s_wb_adr,
      i_wb_dat => s_wb_dat,
      i_wb_ack => s_wb_ack,
      i_wb_stall => s_wb_stall,
      i_wb_err => s_wb_err,

      o_pc => s_pc,
      o_instr => s_instr,
      o_bubble => s_bubble
    );

  process
    -- Patterns to apply.
    type pattern_type is record
      -- Inputs
      stall : std_logic;
      cancel : std_logic;

      pccorr_source : std_logic_vector(C_WORD_SIZE-1 downto 0);
      pccorr_target : std_logic_vector(C_WORD_SIZE-1 downto 0);
      pccorr_is_branch : std_logic;
      pccorr_is_taken : std_logic;
      pccorr_adjust : std_logic;
      pccorr_adjusted_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);

      wb_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
      wb_ack : std_logic;
      wb_stall : std_logic;
      wb_err : std_logic;

      -- Expected outputs
      wb_cyc : std_logic;
      wb_stb : std_logic;
      wb_adr : std_logic_vector(C_WORD_SIZE-1 downto 2);

      pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
      instr : std_logic_vector(C_WORD_SIZE-1 downto 0);
      bubble : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- ===[ Inputs ]=====================================================    ===[ Outputs ]=======================

        -- No response from the memory (it's bysy, so WB stall).
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','1','0', '1','1',30x"080", 32x"000",32x"000",'1'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','1','0', '1','1',30x"080", 32x"000",32x"000",'1'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','1','0', '1','1',30x"080", 32x"000",32x"000",'1'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','1','0', '1','1',30x"080", 32x"000",32x"000",'1'),

        -- Pipelined read burst from the memory, with one cycle WB stall.
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','0','0', '1','1',30x"080", 32x"000",32x"000",'1'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"123",'1','0','0', '1','1',30x"081", 32x"000",32x"000",'1'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"456",'1','0','0', '1','1',30x"082", 32x"200",32x"123",'0'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"789",'1','1','0', '1','1',30x"083", 32x"204",32x"456",'0'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"fff",'0','0','0', '1','1',30x"083", 32x"208",32x"789",'0'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"abc",'1','0','0', '1','1',30x"084", 32x"20c",32x"789",'1'),

        -- Long (multi cycle) memory request.
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','0','0', '1','0',30x"085", 32x"20c",32x"abc",'0'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','0','0', '1','0',30x"085", 32x"20c",32x"abc",'1'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','0','0', '1','0',30x"085", 32x"20c",32x"abc",'1'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"def",'1','0','0', '1','1',30x"085", 32x"20c",32x"abc",'1'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"321",'1','0','0', '1','1',30x"086", 32x"210",32x"def",'0'),

        -- PC correction.
        ('0','1', 32x"210",32x"204",'1','1','1',32x"204", 32x"654",'1','0','0', '1','1',30x"081", 32x"214",32x"321",'0'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"456",'1','0','0', '1','1',30x"082", 32x"218",32x"654",'1'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"789",'1','0','0', '1','1',30x"083", 32x"204",32x"456",'0'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"abc",'1','0','0', '1','1',30x"084", 32x"208",32x"789",'0'),

        -- BTB prediction based on previous PC correction.
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"def",'1','0','0', '1','1',30x"081", 32x"20c",32x"abc",'0'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"456",'1','0','0', '1','1',30x"082", 32x"210",32x"def",'0'),

        -- Pipeline stall, with an ack during the stall.
        ('1','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','0','0', '1','0',30x"083", 32x"204",32x"456",'0'),
        ('1','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"789",'1','0','0', '1','0',30x"083", 32x"204",32x"456",'0'),
        ('1','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','0','0', '0','0',30x"083", 32x"204",32x"456",'0'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','0','0', '1','1',30x"083", 32x"204",32x"456",'0'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"abc",'1','0','0', '1','1',30x"084", 32x"208",32x"789",'0'),

        -- Pipeline stall, with:
        --  * BTB prediction during stall.
        --  * ACK during stall.
        --  * PC correction during stall.
        -- TODO(m): Do these tests independently of each other!
        ('1','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"def",'1','0','0', '1','0',30x"081", 32x"20c",32x"abc",'0'),  -- BTB & ACK
        ('1','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','0','0', '0','0',30x"081", 32x"20c",32x"abc",'0'),
        ('1','1', 32x"203",32x"214",'1','1','1',32x"214", 32x"000",'0','0','0', '0','0',30x"085", 32x"20c",32x"abc",'0'),  -- PC corr
        ('1','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','0','0', '0','0',30x"085", 32x"20c",32x"abc",'0'),
        ('1','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','0','0', '0','0',30x"085", 32x"20c",32x"abc",'0'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"000",'0','0','0', '1','1',30x"085", 32x"20c",32x"abc",'0'),
        ('0','0', 32x"000",32x"000",'0','0','0',32x"000", 32x"fed",'1','0','0', '1','1',30x"086", 32x"210",32x"def",'1')

        -- TODO(m): wb_stall during stall.
      );
  begin
    -- Clear all input signals.
    s_stall <= '0';
    s_cancel <= '0';
    s_pccorr_source <= (others => '0');
    s_pccorr_target <= (others => '0');
    s_pccorr_is_branch <= '0';
    s_pccorr_is_taken <= '0';
    s_pccorr_adjust <= '0';
    s_pccorr_adjusted_pc <= (others => '0');
    s_wb_dat <= (others => '0');
    s_wb_ack <= '0';
    s_wb_stall <= '0';
    s_wb_err <= '0';

    -- Start by resetting the DUT (to have a defined state).
    s_rst <= '1';
    s_clk <= '0';
    wait for 1 ns;
    s_clk <= '1';
    wait for 1 ns;
    s_clk <= '0';
    s_rst <= '0';
    wait for 1 ns;

    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      -- Positivie clock flank (tick registers).
      s_clk <= '1';
      wait until s_clk = '1';

      -- Set the inputs for this cycle.
      s_stall <= patterns(i).stall;
      s_cancel <= patterns(i).cancel;
      s_pccorr_source <= patterns(i).pccorr_source;
      s_pccorr_target <= patterns(i).pccorr_target;
      s_pccorr_is_branch <= patterns(i).pccorr_is_branch;
      s_pccorr_is_taken <= patterns(i).pccorr_is_taken;
      s_pccorr_adjust <= patterns(i).pccorr_adjust;
      s_pccorr_adjusted_pc <= patterns(i).pccorr_adjusted_pc;
      s_wb_dat <= patterns(i).wb_dat;
      s_wb_ack <= patterns(i).wb_ack;
      s_wb_stall <= patterns(i).wb_stall;
      s_wb_err <= patterns(i).wb_err;

      -- Wait for the results.
      wait for 1 ns;

      -- Check the outputs.
      assert s_wb_cyc = patterns(i).wb_cyc
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  wb_cyc = " & to_string(s_wb_cyc) & lf &
               "  expected " & to_string(patterns(i).wb_cyc)
            severity error;
      assert s_wb_stb = patterns(i).wb_stb
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  wb_stb = " & to_string(s_wb_stb) & lf &
               "  expected " & to_string(patterns(i).wb_stb)
            severity error;
      assert s_wb_adr = patterns(i).wb_adr or (s_wb_stb and s_wb_cyc) = '0'
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  wb_adr = " & to_string(s_wb_adr) & lf &
               "  expected " & to_string(patterns(i).wb_adr)
            severity error;
      assert s_pc = patterns(i).pc or s_bubble = '1'
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  pc     = " & to_string(s_pc) & lf &
               "  expected " & to_string(patterns(i).pc)
            severity error;
      assert s_instr = patterns(i).instr or s_bubble = '1'
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  instr  = " & to_string(s_instr) & lf &
               "  expected " & to_string(patterns(i).instr)
            severity error;
      assert s_bubble = patterns(i).bubble
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  bubble = " & to_string(s_bubble) & lf &
               "  expected " & to_string(patterns(i).bubble)
            severity error;

      -- Tick the clock.
      s_clk <= '0';
      wait for 1 ns;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

