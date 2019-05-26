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
use work.config.all;

entity clz32 is
  port(
      i_src : in std_logic_vector(31 downto 0);
      i_packed_mode : in T_PACKED_MODE;
      o_result : out std_logic_vector(31 downto 0)
    );
end clz32;


---------------------------------------------------------------------------------------------------
-- The CLZ (count leading zeros) function is implemented as a 5-level combinatorial network.
--
-- At each level, groups of two bits are evaluated in parallel (at the highest level, 16 bit pairs
-- are evaluated, while at the lowest level, a single bit pair is evaluated). For each bit pair a
-- leading zero count is determined:
--
--  * The two most significant bits of the count are determined from the two inputs:
--
--    Count zeros (lvl 1):     Count ones (lvl 2+):
--
--     a1 a0 | c1 c0           a1 a0 | c1 c0
--     ------+------           ------+------
--      0  0 | 1  0  (2)        0  0 | 0  0  (0)
--      0  1 | 0  1  (1)        0  1 | 0  0  (0)
--      1  0 | 0  0  (0)        1  0 | 0  1  (1)
--      1  1 | 0  0  (0)        1  1 | 1  0  (2)
--
--  * The least significant bits of the count are propagated from the parent level: If the MSB of
--    the most significant (left) parent is 1, select the bits from the least significant (right)
--    parent. Otherwise select the bits from the most significant (left) parent.
---------------------------------------------------------------------------------------------------

architecture rtl of clz32 is
  -- Level 1
  signal s_c1_1 : std_logic_vector(15 downto 0);
  signal s_c1_0 : std_logic_vector(15 downto 0);

  -- Level 2
  signal s_c2_2 : std_logic_vector(7 downto 0);
  signal s_c2_1 : std_logic_vector(7 downto 0);
  signal s_c2_0 : std_logic_vector(7 downto 0);

  -- Level 3
  signal s_c3_3 : std_logic_vector(3 downto 0);
  signal s_c3_2 : std_logic_vector(3 downto 0);
  signal s_c3_1 : std_logic_vector(3 downto 0);
  signal s_c3_0 : std_logic_vector(3 downto 0);

  -- Level 4
  signal s_c4_4 : std_logic_vector(1 downto 0);
  signal s_c4_3 : std_logic_vector(1 downto 0);
  signal s_c4_2 : std_logic_vector(1 downto 0);
  signal s_c4_1 : std_logic_vector(1 downto 0);
  signal s_c4_0 : std_logic_vector(1 downto 0);

  -- Level 5
  signal s_c5_5 : std_logic;
  signal s_c5_4 : std_logic;
  signal s_c5_3 : std_logic;
  signal s_c5_2 : std_logic;
  signal s_c5_1 : std_logic;
  signal s_c5_0 : std_logic;

  signal s_result_32 : std_logic_vector(31 downto 0);
  signal s_result_16 : std_logic_vector(31 downto 0);
  signal s_result_8 : std_logic_vector(31 downto 0);
begin
  -- Level 1
  Lvl1Gen: for k in 15 downto 0 generate
    s_c1_1(k) <= not (i_src(2*k+1) or i_src(2*k));
    s_c1_0(k) <= (not i_src(2*k+1)) and i_src(2*k);
  end generate;

  -- Level 2
  Lvl2Gen: for k in 7 downto 0 generate
    s_c2_2(k) <= s_c1_1(2*k+1) and s_c1_1(2*k);
    s_c2_1(k) <= s_c1_1(2*k+1) and (not s_c1_1(2*k));
    s_c2_0(k) <= s_c1_0(2*k+1) or (s_c1_1(2*k+1) and s_c1_0(2*k));
  end generate;

  -- Level 3
  Lvl3Gen: for k in 3 downto 0 generate
    s_c3_3(k) <= s_c2_2(2*k+1) and s_c2_2(2*k);
    s_c3_2(k) <= s_c2_2(2*k+1) and (not s_c2_2(2*k));
    s_c3_1(k) <= s_c2_1(2*k+1) or (s_c2_2(2*k+1) and s_c2_1(2*k));
    s_c3_0(k) <= s_c2_0(2*k+1) or (s_c2_2(2*k+1) and s_c2_0(2*k));
  end generate;

  -- Level 4
  Lvl4Gen: for k in 1 downto 0 generate
    s_c4_4(k) <= s_c3_3(2*k+1) and s_c3_3(2*k);
    s_c4_3(k) <= s_c3_3(2*k+1) and (not s_c3_3(2*k));
    s_c4_2(k) <= s_c3_2(2*k+1) or (s_c3_3(2*k+1) and s_c3_2(2*k));
    s_c4_1(k) <= s_c3_1(2*k+1) or (s_c3_3(2*k+1) and s_c3_1(2*k));
    s_c4_0(k) <= s_c3_0(2*k+1) or (s_c3_3(2*k+1) and s_c3_0(2*k));
  end generate;

  -- Level 5 (final level)
  s_c5_5 <= s_c4_4(1) and s_c4_4(0);
  s_c5_4 <= s_c4_4(1) and (not s_c4_4(0));
  s_c5_3 <= s_c4_3(1) or (s_c4_4(1) and s_c4_3(0));
  s_c5_2 <= s_c4_2(1) or (s_c4_4(1) and s_c4_2(0));
  s_c5_1 <= s_c4_1(1) or (s_c4_4(1) and s_c4_1(0));
  s_c5_0 <= s_c4_0(1) or (s_c4_4(1) and s_c4_0(0));

  -- 32-bit result.
  s_result_32(31 downto 6) <= (others => '0');
  s_result_32(5) <= s_c5_5;
  s_result_32(4) <= s_c5_4;
  s_result_32(3) <= s_c5_3;
  s_result_32(2) <= s_c5_2;
  s_result_32(1) <= s_c5_1;
  s_result_32(0) <= s_c5_0;

  PACKED_GEN: if C_CPU_HAS_PO generate
    -- 16x2-bit result.
    s_result_16(31 downto 21) <= (others => '0');
    s_result_16(20) <= s_c4_4(1);
    s_result_16(19) <= s_c4_3(1);
    s_result_16(18) <= s_c4_2(1);
    s_result_16(17) <= s_c4_1(1);
    s_result_16(16) <= s_c4_0(1);
    s_result_16(15 downto 5) <= (others => '0');
    s_result_16(4) <= s_c4_4(0);
    s_result_16(3) <= s_c4_3(0);
    s_result_16(2) <= s_c4_2(0);
    s_result_16(1) <= s_c4_1(0);
    s_result_16(0) <= s_c4_0(0);

    -- 8x4-bit result.
    s_result_8(31 downto 28) <= (others => '0');
    s_result_8(27) <= s_c3_3(3);
    s_result_8(26) <= s_c3_2(3);
    s_result_8(25) <= s_c3_1(3);
    s_result_8(24) <= s_c3_0(3);
    s_result_8(23 downto 20) <= (others => '0');
    s_result_8(19) <= s_c3_3(2);
    s_result_8(18) <= s_c3_2(2);
    s_result_8(17) <= s_c3_1(2);
    s_result_8(16) <= s_c3_0(2);
    s_result_8(15 downto 12) <= (others => '0');
    s_result_8(11) <= s_c3_3(1);
    s_result_8(10) <= s_c3_2(1);
    s_result_8(9) <= s_c3_1(1);
    s_result_8(8) <= s_c3_0(1);
    s_result_8(7 downto 4) <= (others => '0');
    s_result_8(3) <= s_c3_3(0);
    s_result_8(2) <= s_c3_2(0);
    s_result_8(1) <= s_c3_1(0);
    s_result_8(0) <= s_c3_0(0);

    -- Select outputs.
    o_result <= s_result_8  when i_packed_mode = C_PACKED_BYTE else
                s_result_16 when i_packed_mode = C_PACKED_HALF_WORD else
                s_result_32;
  else generate
    -- In unpacked mode we only have to consider the 32-bit result.
    o_result <= s_result_32;
  end generate;
end rtl;
