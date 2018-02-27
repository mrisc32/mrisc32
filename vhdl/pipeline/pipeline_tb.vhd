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

entity pipeline_tb is
end pipeline_tb;

architecture behavioral of pipeline_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;

  -- ICache interface.
  signal s_icache_read : std_logic;
  signal s_icache_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_icache_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_icache_data_ready : std_logic;

  -- DCache interface.
  signal s_dcache_enable : std_logic;
  signal s_dcache_write : std_logic;
  signal s_dcache_size : std_logic_vector(1 downto 0);
  signal s_dcache_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_dcache_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_dcache_data_ready : std_logic;
begin
  pipeline_0: entity work.pipeline
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- ICache interface.
      o_icache_read => s_icache_read,
      o_icache_addr => s_icache_addr,
      i_icache_data => s_icache_data,
      i_icache_data_ready => s_icache_data_ready,

      -- DCache interface.
      o_dcache_enable => s_dcache_enable,
      o_dcache_write => s_dcache_write,
      o_dcache_size => s_dcache_size,
      o_dcache_addr => s_dcache_addr,
      i_dcache_data => s_dcache_data,
      i_dcache_data_ready => s_dcache_data_ready
    );

  process
    -- Program to run (from pipeline_tb_prg.s).
    type T_INSTRUCTION_ARRAY is array (natural range <>) of std_logic_vector(31 downto 0);
    constant C_PROGRAM_MEM : T_INSTRUCTION_ARRAY := (
        X"10081234",  -- OR  S1,Z,0x1234
        X"10101111",  -- OR  S2,Z,0x1111
        X"00000000",  -- NOP (.loop)
        X"00000000",  -- NOP
        X"00000000",  -- NOP
        X"00184415",  -- ADD S3,S1,S2
        X"00208216",  -- SUB S4,S1,S2
        X"15084001",  -- ADD S1,S1,1
        X"3007fffa"   -- B   .loop
      );

    constant C_TEST_CYCLES : integer := 20;

    variable v_prg_idx : integer;
    variable v_instr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  begin
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

    -- Run the program.
    for i in 0 to C_TEST_CYCLES-1 loop
      -- Positive clock flank -> we should get a PC address on the ICache interface.
      s_clk <= '1';
      wait for 0.5 ns;

      -- Convert the PC address to a program array index.
      v_prg_idx := (to_integer(unsigned(s_icache_addr)) - 512) / 4;
      if (v_prg_idx >= C_PROGRAM_MEM'left) and (v_prg_idx <= C_PROGRAM_MEM'right) then
        v_instr := C_PROGRAM_MEM(v_prg_idx);
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

