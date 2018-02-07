library ieee;
use ieee.std_logic_1164.all;

entity clz32 is
  port(
      i_src : in  std_logic_vector(31 downto 0);
      o_cnt : out std_logic_vector(5 downto 0)
    );
end clz32;


---------------------------------------------------------------------------------------------------
-- The CLZ (count leading zeros) function is implemented as a 5-level combinatorial network, with a
-- total gate delay of about 10.
--
-- At each level, groups of two bits are evaluated in parallel (at the highest level, 16 bit pairs
-- are evaluated, while at the lowest level, a single bit pair is evaluated). For each bit pair a
-- "both are zeros" signal and a leading zero count is determined.
---------------------------------------------------------------------------------------------------

architecture rtl of clz32 is
  -- Level 1
  signal s_z1 : std_logic_vector(15 downto 0);
  signal s_c1_0 : std_logic_vector(15 downto 0);

  -- Level 2
  signal s_z2 : std_logic_vector(7 downto 0);
  signal s_c2_1 : std_logic_vector(7 downto 0);
  signal s_c2_0 : std_logic_vector(7 downto 0);

  -- Level 3
  signal s_z3 : std_logic_vector(3 downto 0);
  signal s_c3_2 : std_logic_vector(3 downto 0);
  signal s_c3_1 : std_logic_vector(3 downto 0);
  signal s_c3_0 : std_logic_vector(3 downto 0);

  -- Level 4
  signal s_z4 : std_logic_vector(1 downto 0);
  signal s_c4_3 : std_logic_vector(1 downto 0);
  signal s_c4_2 : std_logic_vector(1 downto 0);
  signal s_c4_1 : std_logic_vector(1 downto 0);
  signal s_c4_0 : std_logic_vector(1 downto 0);
begin
  -- Level 1
  Lvl1Gen: for k in 15 downto 0 generate
    s_z1(k) <= not (i_src(2*k+1) or i_src(2*k));
    s_c1_0(k) <= (not i_src(2*k+1)) and i_src(2*k);
  end generate;

  -- Level 2
  Lvl2Gen: for k in 7 downto 0 generate
    s_z2(k) <= s_z1(2*k+1) and s_z1(2*k);
    s_c2_1(k) <= s_z1(2*k+1) and (not s_z1(2*k));
    s_c2_0(k) <= s_c1_0(2*k+1) or (s_z1(2*k+1) and s_c1_0(2*k));
  end generate;

  -- Level 3
  Lvl3Gen: for k in 3 downto 0 generate
    s_z3(k) <= s_z2(2*k+1) and s_z2(2*k);
    s_c3_2(k) <= s_z2(2*k+1) and (not s_z2(2*k));
    s_c3_1(k) <= s_c2_1(2*k+1) or (s_z2(2*k+1) and s_c2_1(2*k));
    s_c3_0(k) <= s_c2_0(2*k+1) or (s_z2(2*k+1) and s_c2_0(2*k));
  end generate;

  -- Level 4
  Lvl4Gen: for k in 1 downto 0 generate
    s_z4(k) <= s_z3(2*k+1) and s_z3(2*k);
    s_c4_3(k) <= s_z3(2*k+1) and (not s_z3(2*k));
    s_c4_2(k) <= s_c3_2(2*k+1) or (s_z3(2*k+1) and s_c3_2(2*k));
    s_c4_1(k) <= s_c3_1(2*k+1) or (s_z3(2*k+1) and s_c3_1(2*k));
    s_c4_0(k) <= s_c3_0(2*k+1) or (s_z3(2*k+1) and s_c3_0(2*k));
  end generate;

  -- Level 5 (final level)
  o_cnt(5) <= s_z4(1) and s_z4(0);
  o_cnt(4) <= s_z4(1) and (not s_z4(0));
  o_cnt(3) <= s_c4_3(1) or (s_z4(1) and s_c4_3(0));
  o_cnt(2) <= s_c4_2(1) or (s_z4(1) and s_c4_2(0));
  o_cnt(1) <= s_c4_1(1) or (s_z4(1) and s_c4_1(0));
  o_cnt(0) <= s_c4_0(1) or (s_z4(1) and s_c4_0(0));
end rtl;
