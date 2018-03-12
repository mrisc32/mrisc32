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
library std;
use std.textio.all;
use work.common.all;

entity pipeline_tb is
end pipeline_tb;

architecture behavioral of pipeline_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;

  -- ICache interface.
  signal s_icache_req : std_logic;
  signal s_icache_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_icache_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_icache_data_ready : std_logic;

  -- DCache interface.
  signal s_dcache_req : std_logic;
  signal s_dcache_we : std_logic;
  signal s_dcache_size : std_logic_vector(1 downto 0);
  signal s_dcache_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_dcache_write_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_dcache_read_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_dcache_read_data_ready : std_logic;
begin
  pipeline_0: entity work.pipeline
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- ICache interface.
      o_icache_req => s_icache_req,
      o_icache_addr => s_icache_addr,
      i_icache_data => s_icache_data,
      i_icache_data_ready => s_icache_data_ready,

      -- DCache interface.
      o_dcache_req => s_dcache_req,
      o_dcache_we => s_dcache_we,
      o_dcache_size => s_dcache_size,
      o_dcache_addr => s_dcache_addr,
      o_dcache_write_data => s_dcache_write_data,
      i_dcache_read_data => s_dcache_read_data,
      i_dcache_read_data_ready => s_dcache_read_data_ready
    );

  process
    type T_CHAR_FILE is file of character;
    file f_char_file : T_CHAR_FILE;
    variable v_word : std_logic_vector(C_WORD_SIZE-1 downto 0);

    type T_INSTRUCTION_ARRAY is array (0 to 10000) of std_logic_vector(31 downto 0);
    variable v_program_mem : T_INSTRUCTION_ARRAY;
    variable v_program_len : integer;

    constant C_TEST_CYCLES : integer := 40;

    variable v_prg_idx : integer;
    variable v_instr : std_logic_vector(C_WORD_SIZE-1 downto 0);

    function read_word32(file f : T_CHAR_FILE) return std_logic_vector is
      variable v_char : character;
      variable v_byte : std_logic_vector(7 downto 0);
      variable v_word : std_logic_vector(C_WORD_SIZE-1 downto 0);
    begin
      for i in 0 to (C_WORD_SIZE/8)-1 loop
        read(f, v_char);
        v_byte := std_logic_vector(to_unsigned(character'pos(v_char), 8));
        v_word(((i+1)*8)-1 downto i*8) := v_byte;
      end loop;
      return v_word;
    end function;
  begin
    -- Read the program to run from the binary file pipeline_tb_prg.bin.
    file_open(f_char_file, "pipeline/pipeline_tb_prg.bin");
    v_word := read_word32(f_char_file);  -- Skip first word (program start addr).
    v_program_len := 0;
    while not endfile(f_char_file) loop
      v_program_mem(v_program_len) := read_word32(f_char_file);
      v_program_len := v_program_len + 1;
    end loop;
    file_close(f_char_file);

    -- Start by resetting the pipeline (to have defined signals).
    s_rst <= '1';
    s_clk <= '1';
    wait for 1 ns;
    s_clk <= '0';
    wait for 1 ns;
    s_clk <= '1';
    wait for 1 ns;
    s_rst <= '0';
    s_clk <= '0';
    wait for 1 ns;

    -- Reset the data cache signals.
    -- TODO(m): Simulate the data memory instead.
    s_dcache_read_data <= (others => '0');
    s_dcache_read_data_ready <= '1';

    -- Run the program.
    for i in 0 to C_TEST_CYCLES-1 loop
      -- Positive clock flank -> we should get a PC address on the ICache interface.
      s_clk <= '1';
      wait for 0.5 ns;

      -- Convert the PC address to a program array index.
      v_prg_idx := (to_integer(unsigned(s_icache_addr)) - 512) / 4;
      if (v_prg_idx >= 0) and (v_prg_idx < v_program_len) then
        v_instr := v_program_mem(v_prg_idx);
      else
        v_instr := X"00000000";  -- NOP
      end if;

      -- Load an instruction from the program memory.
      s_icache_data <= v_instr;
      s_icache_data_ready <= '1';

      -- Tick the clock.
      wait for 0.5 ns;
      s_clk <= '0';
      wait for 1 ns;
    end loop;

    --  Wait forever; this will finish the simulation.
    assert false report "End of test" severity note;
    wait;
  end process;
end behavioral;

