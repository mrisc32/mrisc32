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

entity mem_arbiter_tb is
end mem_arbiter_tb;

architecture behavioral of mem_arbiter_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;

  -- Instruction interface.
  signal s_instr_cyc : std_logic;
  signal s_instr_stb : std_logic;
  signal s_instr_adr : std_logic_vector(C_WORD_SIZE-1 downto 2);

  signal s_instr_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_instr_ack : std_logic;
  signal s_instr_stall : std_logic;
  signal s_instr_err : std_logic;

  -- Data interface.
  signal s_data_cyc : std_logic;
  signal s_data_stb : std_logic;
  signal s_data_we : std_logic;
  signal s_data_sel :std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_data_adr : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_data_dat_w : std_logic_vector(C_WORD_SIZE-1 downto 0);

  signal s_data_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_data_ack : std_logic;
  signal s_data_stall : std_logic;
  signal s_data_err : std_logic;

  -- Memory interface.
  signal s_mem_cyc : std_logic;
  signal s_mem_stb : std_logic;
  signal s_mem_we : std_logic;
  signal s_mem_sel : std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_mem_adr : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_mem_dat_w : std_logic_vector(C_WORD_SIZE-1 downto 0);

  signal s_mem_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_mem_ack : std_logic;
  signal s_mem_stall : std_logic;
  signal s_mem_err : std_logic;
begin
  mem_arbiter_0: entity work.mem_arbiter
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      i_instr_cyc => s_instr_cyc,
      i_instr_stb => s_instr_stb,
      i_instr_adr => s_instr_adr,
      o_instr_dat => s_instr_dat,
      o_instr_ack => s_instr_ack,
      o_instr_stall => s_instr_stall,
      o_instr_err => s_instr_err,

      -- Data interface.
      i_data_cyc => s_data_cyc,
      i_data_stb => s_data_stb,
      i_data_we => s_data_we,
      i_data_sel => s_data_sel,
      i_data_adr => s_data_adr,
      i_data_dat_w => s_data_dat_w,
      o_data_dat => s_data_dat,
      o_data_ack => s_data_ack,
      o_data_stall => s_data_stall,
      o_data_err => s_data_err,

      -- Memory interface.
      o_mem_cyc => s_mem_cyc,
      o_mem_stb => s_mem_stb,
      o_mem_we => s_mem_we,
      o_mem_sel => s_mem_sel,
      o_mem_adr => s_mem_adr,
      o_mem_dat_w => s_mem_dat_w,
      i_mem_dat => s_mem_dat,
      i_mem_ack => s_mem_ack,
      i_mem_stall => s_mem_stall,
      i_mem_err => s_mem_err
    );

  process
    -- Patterns to apply.
    type pattern_type is record
      -- Instruction interface.
      instr_cyc : std_logic;
      instr_stb : std_logic;
      instr_adr : std_logic_vector(C_WORD_SIZE-1 downto 2);

      instr_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
      instr_ack : std_logic;
      instr_stall : std_logic;
      instr_err : std_logic;

      -- Data interface.
      data_cyc : std_logic;
      data_stb : std_logic;
      data_we : std_logic;
      data_sel :std_logic_vector(C_WORD_SIZE/8-1 downto 0);
      data_adr : std_logic_vector(C_WORD_SIZE-1 downto 2);
      data_dat_w : std_logic_vector(C_WORD_SIZE-1 downto 0);

      data_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
      data_ack : std_logic;
      data_stall : std_logic;
      data_err : std_logic;

      -- Memory interface.
      mem_cyc : std_logic;
      mem_stb : std_logic;
      mem_we : std_logic;
      mem_sel : std_logic_vector(C_WORD_SIZE/8-1 downto 0);
      mem_adr : std_logic_vector(C_WORD_SIZE-1 downto 2);
      mem_dat_w : std_logic_vector(C_WORD_SIZE-1 downto 0);

      mem_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
      mem_ack : std_logic;
      mem_stall : std_logic;
      mem_err : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        -- Instr In        Instr Out             Data In                             Data Out              Mem Out                             Mem In
        ('0','0',30x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0'),

        -- Instruction read - single + burst, with wait state.
        -- Instr In        Instr Out             Data In                             Data Out              Mem Out                             Mem In
        ('1','1',30x"010", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '1','1','0',x"f",30x"010",32x"000", 32x"000",'0','0','0'),
        ('1','0',30x"000", 32x"123",'1','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"123",'1','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0'),
        ('1','1',30x"011", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '1','1','0',x"f",30x"011",32x"000", 32x"000",'0','0','0'),
        ('1','1',30x"012", 32x"124",'1','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '1','1','0',x"f",30x"012",32x"000", 32x"124",'1','0','0'),
        ('1','0',30x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0'),
        ('1','0',30x"000", 32x"125",'1','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"125",'1','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0'),

        -- Data read - single + burst, with wait state.
        -- Instr In        Instr Out             Data In                             Data Out              Mem Out                             Mem In
        ('0','0',30x"000", 32x"000",'0','0','0', '1','1','0',x"f",30x"010",32x"000", 32x"000",'0','0','0', '1','1','0',x"f",30x"010",32x"000", 32x"000",'0','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"123",'1','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"123",'1','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '1','1','0',x"f",30x"011",32x"000", 32x"000",'0','0','0', '1','1','0',x"f",30x"011",32x"000", 32x"000",'0','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '1','1','0',x"f",30x"012",32x"000", 32x"124",'1','0','0', '1','1','0',x"f",30x"012",32x"000", 32x"124",'1','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"125",'1','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"125",'1','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0'),

        -- Data write - single + burst.
        -- Instr In        Instr Out             Data In                             Data Out              Mem Out                             Mem In
        ('0','0',30x"000", 32x"000",'0','0','0', '1','1','1',x"f",30x"010",32x"123", 32x"000",'0','0','0', '1','1','1',x"f",30x"010",32x"123", 32x"000",'0','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"000",'1','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"000",'1','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '1','1','1',x"3",30x"011",32x"124", 32x"000",'0','0','0', '1','1','1',x"3",30x"011",32x"124", 32x"000",'0','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '1','1','1',x"7",30x"012",32x"125", 32x"000",'1','0','0', '1','1','1',x"7",30x"012",32x"125", 32x"000",'1','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"000",'1','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"000",'1','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0'),

        -- Instruction + data read - data first, instruction second.
        -- Instr In        Instr Out             Data In                             Data Out              Mem Out                             Mem In
        ('1','1',30x"010", 32x"000",'0','1','0', '1','1','0',x"f",30x"020",32x"000", 32x"000",'0','0','0', '1','1','0',x"f",30x"020",32x"000", 32x"000",'0','0','0'),
        ('1','1',30x"010", 32x"000",'0','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"245",'1','0','0', '1','1','0',x"f",30x"010",32x"000", 32x"245",'1','0','0'),
        ('1','0',30x"000", 32x"123",'1','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '1','0','0',x"0",30x"000",32x"000", 32x"123",'1','0','0'),

        -- Tail: NOP:s.
        ('0','0',30x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0'),
        ('0','0',30x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0', '0','0','0',x"0",30x"000",32x"000", 32x"000",'0','0','0')
      );
  begin
    -- Clear all input signals.
    s_instr_cyc <= '0';
    s_instr_stb <= '0';
    s_instr_adr <= (others => '0');

    s_data_cyc <= '0';
    s_data_stb <= '0';
    s_data_we <= '0';
    s_data_sel <= (others => '0');
    s_data_adr <= (others => '0');
    s_data_dat_w <= (others => '0');

    s_mem_dat <= (others => '0');
    s_mem_ack <= '0';
    s_mem_stall <= '0';
    s_mem_err <= '0';

    -- Start by resetting the mem_arbiterister (to have a defined state).
    s_rst <= '1';
    s_clk <= '0';

    wait for 1 ns;
    s_rst <= '0';
    s_clk <= '1';
    wait for 1 ns;
    s_clk <= '0';
    wait for 1 ns;

    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_clk <= '1';

      --  Set the inputs.
      s_instr_cyc <= patterns(i).instr_cyc;
      s_instr_stb <= patterns(i).instr_stb;
      s_instr_adr <= patterns(i).instr_adr;

      s_data_cyc <= patterns(i).data_cyc;
      s_data_stb <= patterns(i).data_stb;
      s_data_we <= patterns(i).data_we;
      s_data_sel <= patterns(i).data_sel;
      s_data_adr <= patterns(i).data_adr;
      s_data_dat_w <= patterns(i).data_dat_w;

      s_mem_dat <= patterns(i).mem_dat;
      s_mem_ack <= patterns(i).mem_ack;
      s_mem_stall <= patterns(i).mem_stall;
      s_mem_err <= patterns(i).mem_err;

      --  Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_instr_dat = patterns(i).instr_dat or s_instr_ack = '0'
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  instr_dat = " & to_string(s_instr_dat) & lf &
               "  expected " & to_string(patterns(i).instr_dat)
            severity error;
      assert s_instr_ack = patterns(i).instr_ack
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  instr_ack = " & to_string(s_instr_ack) & lf &
               "  expected " & to_string(patterns(i).instr_ack)
            severity error;
      assert s_instr_stall = patterns(i).instr_stall
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  instr_stall = " & to_string(s_instr_stall) & lf &
               "  expected " & to_string(patterns(i).instr_stall)
            severity error;
      assert s_instr_err = patterns(i).instr_err
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  instr_err = " & to_string(s_instr_err) & lf &
               "  expected " & to_string(patterns(i).instr_err)
            severity error;

      assert s_data_dat = patterns(i).data_dat or s_data_ack = '0'
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  data_dat = " & to_string(s_data_dat) & lf &
               "  expected " & to_string(patterns(i).data_dat)
            severity error;
      assert s_data_ack = patterns(i).data_ack
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  data_ack = " & to_string(s_data_ack) & lf &
               "  expected " & to_string(patterns(i).data_ack)
            severity error;
      assert s_data_stall = patterns(i).data_stall
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  data_stall = " & to_string(s_data_stall) & lf &
               "  expected " & to_string(patterns(i).data_stall)
            severity error;
      assert s_data_err = patterns(i).data_err
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  data_err = " & to_string(s_data_err) & lf &
               "  expected " & to_string(patterns(i).data_err)
            severity error;

      assert s_mem_cyc = patterns(i).mem_cyc
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  mem_cyc = " & to_string(s_mem_cyc) & lf &
               "  expected " & to_string(patterns(i).mem_cyc)
            severity error;
      assert s_mem_stb = patterns(i).mem_stb
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  mem_stb = " & to_string(s_mem_stb) & lf &
               "  expected " & to_string(patterns(i).mem_stb)
            severity error;
      assert s_mem_we = patterns(i).mem_we or (s_mem_cyc and s_mem_stb) = '0'
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  mem_we = " & to_string(s_mem_we) & lf &
               "  expected " & to_string(patterns(i).mem_we)
            severity error;
      assert s_mem_sel = patterns(i).mem_sel or (s_mem_cyc and s_mem_stb) = '0'
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  mem_sel = " & to_string(s_mem_sel) & lf &
               "  expected " & to_string(patterns(i).mem_sel)
            severity error;
      assert s_mem_adr = patterns(i).mem_adr or (s_mem_cyc and s_mem_stb) = '0'
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  mem_adr = " & to_string(s_mem_adr) & lf &
               "  expected " & to_string(patterns(i).mem_adr)
            severity error;
      assert s_mem_dat_w = patterns(i).mem_dat_w or (s_mem_cyc and s_mem_stb) = '0'
        report "Bad result (" & integer'image(i) & "):" & lf &
               "  mem_dat_w = " & to_string(s_mem_dat_w) & lf &
               "  expected " & to_string(patterns(i).mem_dat_w)
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

