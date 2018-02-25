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

entity icache_tb is
end icache_tb;

architecture behavioral of icache_tb is
  signal s_clk : std_logic;
  signal s_rst : std_logic;

  signal s_cpu_read : std_logic;
  signal s_cpu_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_cpu_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_cpu_data_ready : std_logic;
  signal s_mem_read : std_logic;
  signal s_mem_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_mem_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_mem_ready : std_logic;

  -- Clock period.
  constant C_HALF_PERIOD : time := 2 ns;
begin
  icache_0: entity work.icache
    generic map (
      LOG2_NUM_LINES => 7,
      LOG2_LINE_SIZE => 4
    )
    port map (
      i_clk => s_clk,
      i_rst => s_rst,
      i_cpu_read => s_cpu_read,
      i_cpu_addr => s_cpu_addr,
      o_cpu_data => s_cpu_data,
      o_cpu_data_ready => s_cpu_data_ready,
      o_mem_read => s_mem_read,
      o_mem_addr => s_mem_addr,
      i_mem_data => s_mem_data,
      i_mem_ready => s_mem_ready
    );

  process
  begin
    -- Reset all inputs.
    s_clk <= '0';
    s_cpu_read <= '0';
    s_cpu_addr <= "00000000000000000000000000000000";
    s_mem_data <= "00000000000000000000000000000000";
    s_mem_ready <= '0';

    -- Start by resetting the cache.
    s_rst <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';
    s_rst <= '0';
    wait for C_HALF_PERIOD;
    s_clk <= '1';
    wait for C_HALF_PERIOD;
    s_clk <= '0';

    -- TODO(m): Implement some tests!

    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

