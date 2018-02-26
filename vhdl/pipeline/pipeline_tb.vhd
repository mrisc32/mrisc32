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
    -- Program to run.
    type instruction_type is record
      data : std_logic_vector(31 downto 0);
      data_ready : std_logic;
    end record;
    type instruction_array is array (natural range <>) of instruction_type;
    constant program : instruction_array := (
        (X"10081234", '1'),  -- OR  S1,Z,0x1234
        (X"10101111", '1'),  -- OR  S2,Z,0x1111
        (X"00000000", '1'),  -- NOP
        (X"00000000", '1'),  -- NOP
        (X"00000000", '1'),  -- NOP
        (X"00000000", '1'),  -- NOP
        (X"00184415", '1'),  -- ADD S3,S1,S2
        (X"00208216", '1')   -- SUB S4,S1,S2
      );
  begin
    -- Start by resetting the pipeline (to have defined signals).
    s_rst <= '1';
    s_clk <= '0';

    wait for 1 ns;
    s_rst <= '0';

    -- Run the program.
    for i in program'range loop
      -- Load an instruction from the program memory.
      s_icache_data <= program(i).data;
      s_icache_data_ready <= program(i).data_ready;

      -- Tick the clock.
      wait for 1 ns;
      s_clk <= '1';
      wait for 1 ns;
      s_clk <= '0';
    end loop;

    -- Run a few cycles to flush the pipeline.
    for i in 0 to 6 loop
      s_icache_data <= X"00000000";  -- nop
      s_icache_data_ready <= '1';

      -- Tick the clock.
      wait for 1 ns;
      s_clk <= '1';
      wait for 1 ns;
      s_clk <= '0';
    end loop;

    --  Wait forever; this will finish the simulation.
    assert false report "End of test" severity note;
    wait;
  end process;
end behavioral;

