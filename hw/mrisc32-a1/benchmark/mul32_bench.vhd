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

entity mul32_bench is
  port(
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_src_a : in std_logic_vector(31 downto 0);
    i_src_b : in std_logic_vector(31 downto 0);
    i_signed_op : in std_logic;
    o_result : out std_logic_vector(63 downto 0)
  );
end mul32_bench;

architecture rtl of mul32_bench is
  signal s_src_a : std_logic_vector(31 downto 0);
  signal s_src_b : std_logic_vector(31 downto 0);
  signal s_signed_op : std_logic;
  signal s_next_result : std_logic_vector(63 downto 0);
begin
  dut_0: entity work.mul32
    port map (
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      i_signed_op => s_signed_op,
      o_result => s_next_result
    );

  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_src_a <= (others => '0');
      s_src_b <= (others => '0');
      s_signed_op <= '0';
      o_result <= (others => '0');
    elsif rising_edge(i_clk) then
      s_src_a <= i_src_a;
      s_src_b <= i_src_b;
      s_signed_op <= i_signed_op;
      o_result <= s_next_result;
    end if;
  end process;
end rtl;
