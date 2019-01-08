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

entity shuf32 is
  port(
      i_src_a : in std_logic_vector(31 downto 0);
      i_src_b : in std_logic_vector(31 downto 0);
      o_result : out std_logic_vector(31 downto 0)
    );
end shuf32;

architecture rtl of shuf32 is
  signal s_sign_fill : std_logic;
  signal s_fill_bit_0 : std_logic;
  signal s_fill_bit_1 : std_logic;
  signal s_fill_bit_2 : std_logic;
  signal s_fill_bit_3 : std_logic;
begin
  -- Is this a sign-fill or zero-fill operation?
  s_sign_fill <= i_src_b(12);

  -- Determine fill bits for the four different source bytes.
  s_fill_bit_0 <= i_src_a(7) and s_sign_fill;
  s_fill_bit_1 <= i_src_a(15) and s_sign_fill;
  s_fill_bit_2 <= i_src_a(23) and s_sign_fill;
  s_fill_bit_3 <= i_src_a(31) and s_sign_fill;

  -- Select the outputs for the four result bytes.
  ShufMux1: with i_src_b(2 downto 0) select
    o_result(7 downto 0) <=
      i_src_a(7 downto 0) when "000",
      i_src_a(15 downto 8) when "001",
      i_src_a(23 downto 16) when "010",
      i_src_a(31 downto 24) when "011",
      (others => s_fill_bit_0) when "100",
      (others => s_fill_bit_1) when "101",
      (others => s_fill_bit_2) when "110",
      (others => s_fill_bit_3) when "111",
      (others => '-') when others;

  ShufMux2: with i_src_b(5 downto 3) select
    o_result(15 downto 8) <=
      i_src_a(7 downto 0) when "000",
      i_src_a(15 downto 8) when "001",
      i_src_a(23 downto 16) when "010",
      i_src_a(31 downto 24) when "011",
      (others => s_fill_bit_0) when "100",
      (others => s_fill_bit_1) when "101",
      (others => s_fill_bit_2) when "110",
      (others => s_fill_bit_3) when "111",
      (others => '-') when others;

  ShufMux3: with i_src_b(8 downto 6) select
    o_result(23 downto 16) <=
      i_src_a(7 downto 0) when "000",
      i_src_a(15 downto 8) when "001",
      i_src_a(23 downto 16) when "010",
      i_src_a(31 downto 24) when "011",
      (others => s_fill_bit_0) when "100",
      (others => s_fill_bit_1) when "101",
      (others => s_fill_bit_2) when "110",
      (others => s_fill_bit_3) when "111",
      (others => '-') when others;

  ShufMux4: with i_src_b(11 downto 9) select
    o_result(31 downto 24) <=
      i_src_a(7 downto 0) when "000",
      i_src_a(15 downto 8) when "001",
      i_src_a(23 downto 16) when "010",
      i_src_a(31 downto 24) when "011",
      (others => s_fill_bit_0) when "100",
      (others => s_fill_bit_1) when "101",
      (others => s_fill_bit_2) when "110",
      (others => s_fill_bit_3) when "111",
      (others => '-') when others;
end rtl;
