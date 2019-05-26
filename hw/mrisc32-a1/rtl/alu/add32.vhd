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
use work.types.all;
use work.config.all;

entity add32 is
  port(
      i_src_a       : in  std_logic_vector(31 downto 0);
      i_src_b       : in  std_logic_vector(31 downto 0);
      i_packed_mode : in  T_PACKED_MODE;
      o_result      : out std_logic_vector(31 downto 0)
    );
end add32;

architecture rtl of add32 is
  signal s_res_32 : unsigned(31 downto 0);

  signal s_res_16_0 : unsigned(15 downto 0);
  signal s_res_16_1 : unsigned(15 downto 0);

  signal s_res_8_0 : unsigned(7 downto 0);
  signal s_res_8_1 : unsigned(7 downto 0);
  signal s_res_8_2 : unsigned(7 downto 0);
  signal s_res_8_3 : unsigned(7 downto 0);
begin
  -- 32-bit addition.
  s_res_32 <= unsigned(i_src_a) + unsigned(i_src_b);

  PACKED_GEN: if C_CPU_HAS_PO generate
    -- 2x 16-bit addition.
    s_res_16_0 <= unsigned(i_src_a(15 downto 0)) + unsigned(i_src_b(15 downto 0));
    s_res_16_1 <= unsigned(i_src_a(31 downto 16)) + unsigned(i_src_b(31 downto 16));

    -- 4x 8-bit addition.
    s_res_8_0 <= unsigned(i_src_a(7 downto 0)) + unsigned(i_src_b(7 downto 0));
    s_res_8_1 <= unsigned(i_src_a(15 downto 8)) + unsigned(i_src_b(15 downto 8));
    s_res_8_2 <= unsigned(i_src_a(23 downto 16)) + unsigned(i_src_b(23 downto 16));
    s_res_8_3 <= unsigned(i_src_a(31 downto 24)) + unsigned(i_src_b(31 downto 24));

    -- Output the result.
    o_result(7 downto 0) <=
        std_logic_vector(s_res_8_0)              when i_packed_mode = C_PACKED_BYTE else
        std_logic_vector(s_res_16_0(7 downto 0)) when i_packed_mode = C_PACKED_HALF_WORD else
        std_logic_vector(s_res_32(7 downto 0));
    o_result(15 downto 8) <=
        std_logic_vector(s_res_8_1)               when i_packed_mode = C_PACKED_BYTE else
        std_logic_vector(s_res_16_0(15 downto 8)) when i_packed_mode = C_PACKED_HALF_WORD else
        std_logic_vector(s_res_32(15 downto 8));
    o_result(23 downto 16) <=
        std_logic_vector(s_res_8_2)              when i_packed_mode = C_PACKED_BYTE else
        std_logic_vector(s_res_16_1(7 downto 0)) when i_packed_mode = C_PACKED_HALF_WORD else
        std_logic_vector(s_res_32(23 downto 16));
    o_result(31 downto 24) <=
        std_logic_vector(s_res_8_3)               when i_packed_mode = C_PACKED_BYTE else
        std_logic_vector(s_res_16_1(15 downto 8)) when i_packed_mode = C_PACKED_HALF_WORD else
        std_logic_vector(s_res_32(31 downto 24));
  else generate
    -- In unpacked mode we only have to consider the 32-bit result.
    o_result <= std_logic_vector(s_res_32);
  end generate;
end rtl;
