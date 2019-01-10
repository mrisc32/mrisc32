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

----------------------------------------------------------------------------------------------------
-- This is a configurable synchronous dual port RAM (one read port and one write port).
--
-- Altera/Intel: Synthesizes to dedicated RAM blocks.
-- Xilinx:       Should synthesize to block RAM (untested).
----------------------------------------------------------------------------------------------------

entity ram_dual_port is
  generic(
    WIDTH : positive := 32;
    ADDR_BITS : positive := 10
  );
  port(
    i_clk: in std_logic;
    i_write_data: in std_logic_vector(WIDTH-1 downto 0);
    i_write_addr: in std_logic_vector(ADDR_BITS-1 downto 0);
    i_we: in std_logic;
    i_read_addr: in std_logic_vector(ADDR_BITS-1 downto 0);
    o_read_data: out std_logic_vector(WIDTH-1 downto 0)
  );
end ram_dual_port;

architecture rtl of ram_dual_port is
  constant C_NUM_WORDS : positive := 2**ADDR_BITS;

  type T_RAM_BLOC is array (0 to C_NUM_WORDS-1) of std_logic_vector(WIDTH-1 downto 0);
  signal ram_block : T_RAM_BLOC;
begin
  process(i_clk)
    variable v_write_addr : integer range 0 to C_NUM_WORDS-1;
    variable v_read_addr : integer range 0 to C_NUM_WORDS-1;
  begin
    if rising_edge(i_clk) then
      if i_we = '1' then
        v_write_addr := to_integer(unsigned(i_write_addr));
        ram_block(v_write_addr) <= i_write_data;
      end if;
      v_read_addr := to_integer(unsigned(i_read_addr));
      o_read_data <= ram_block(v_read_addr);
    end if;
  end process;
end rtl;

