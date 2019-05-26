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

entity cmp32 is
  port(
      i_src_a : in std_logic_vector(31 downto 0);
      i_src_b : in std_logic_vector(31 downto 0);
      i_op : in T_ALU_OP;
      i_packed_mode : in T_PACKED_MODE;
      o_set_res : out std_logic_vector(31 downto 0);
      o_min_res : out std_logic_vector(31 downto 0);
      o_max_res : out std_logic_vector(31 downto 0);
      o_minu_res : out std_logic_vector(31 downto 0);
      o_maxu_res : out std_logic_vector(31 downto 0)
    );
end cmp32;

architecture rtl of cmp32 is
  signal s_eq_8 : std_logic_vector(3 downto 0);
  signal s_lt_8 : std_logic_vector(3 downto 0);
  signal s_ltu_8 : std_logic_vector(3 downto 0);
  signal s_eq_16 : std_logic_vector(1 downto 0);
  signal s_lt_16 : std_logic_vector(1 downto 0);
  signal s_ltu_16 : std_logic_vector(1 downto 0);
  signal s_eq_32 : std_logic_vector(0 downto 0);
  signal s_lt_32 : std_logic_vector(0 downto 0);
  signal s_ltu_32 : std_logic_vector(0 downto 0);

  signal s_compare_eq : std_logic_vector(3 downto 0);
  signal s_compare_lt : std_logic_vector(3 downto 0);
  signal s_compare_ltu : std_logic_vector(3 downto 0);

  signal s_compare_ne : std_logic_vector(3 downto 0);
  signal s_compare_le : std_logic_vector(3 downto 0);
  signal s_compare_leu : std_logic_vector(3 downto 0);

  signal s_set_bit : std_logic_vector(3 downto 0);

  function CondAssign(a : std_logic_vector(31 downto 0);
                      b : std_logic_vector(31 downto 0);
                      cond : std_logic_vector(3 downto 0)) return std_logic_vector is
    variable v_lo : integer;
    variable v_hi : integer;
    variable v_result : std_logic_vector(31 downto 0);
  begin
    for k in 0 to 3 loop
      v_lo := k * 8;
      v_hi := v_lo + 7;
      if cond(k) = '1' then
        v_result(v_hi downto v_lo) := a(v_hi downto v_lo);
      else
        v_result(v_hi downto v_lo) := b(v_hi downto v_lo);
      end if;
    end loop;
    return v_result;
  end function;
begin
  -- 32-bit comparisons.
  s_eq_32(0) <= '1' when i_src_a = i_src_b else '0';
  s_lt_32(0) <= '1' when signed(i_src_a) < signed(i_src_b) else '0';
  s_ltu_32(0) <= '1' when unsigned(i_src_a) < unsigned(i_src_b) else '0';

  PACKED_GEN: if C_CPU_HAS_PO generate
    -- 16-bit comparisons.
    s_eq_16(0) <= '1' when i_src_a(15 downto 0) = i_src_b(15 downto 0) else '0';
    s_eq_16(1) <= '1' when i_src_a(31 downto 16) = i_src_b(31 downto 16) else '0';
    s_lt_16(0) <= '1' when signed(i_src_a(15 downto 0)) < signed(i_src_b(15 downto 0)) else '0';
    s_lt_16(1) <= '1' when signed(i_src_a(31 downto 16)) < signed(i_src_b(31 downto 16)) else '0';
    s_ltu_16(0) <= '1' when unsigned(i_src_a(15 downto 0)) < unsigned(i_src_b(15 downto 0)) else '0';
    s_ltu_16(1) <= '1' when unsigned(i_src_a(31 downto 16)) < unsigned(i_src_b(31 downto 16)) else '0';

    -- 8-bit comparisons.
    s_eq_8(0) <= '1' when i_src_a(7 downto 0) = i_src_b(7 downto 0) else '0';
    s_eq_8(1) <= '1' when i_src_a(15 downto 8) = i_src_b(15 downto 8) else '0';
    s_eq_8(2) <= '1' when i_src_a(23 downto 16) = i_src_b(23 downto 16) else '0';
    s_eq_8(3) <= '1' when i_src_a(31 downto 24) = i_src_b(31 downto 24) else '0';
    s_lt_8(0) <= '1' when signed(i_src_a(7 downto 0)) < signed(i_src_b(7 downto 0)) else '0';
    s_lt_8(1) <= '1' when signed(i_src_a(15 downto 8)) < signed(i_src_b(15 downto 8)) else '0';
    s_lt_8(2) <= '1' when signed(i_src_a(23 downto 16)) < signed(i_src_b(23 downto 16)) else '0';
    s_lt_8(3) <= '1' when signed(i_src_a(31 downto 24)) < signed(i_src_b(31 downto 24)) else '0';
    s_ltu_8(0) <= '1' when unsigned(i_src_a(7 downto 0)) < unsigned(i_src_b(7 downto 0)) else '0';
    s_ltu_8(1) <= '1' when unsigned(i_src_a(15 downto 8)) < unsigned(i_src_b(15 downto 8)) else '0';
    s_ltu_8(2) <= '1' when unsigned(i_src_a(23 downto 16)) < unsigned(i_src_b(23 downto 16)) else '0';
    s_ltu_8(3) <= '1' when unsigned(i_src_a(31 downto 24)) < unsigned(i_src_b(31 downto 24)) else '0';

    -- Select the relevant camparison results depending on the packed mode.
    CmpGen1: for k in 0 to 3 generate
      s_compare_eq(k) <= s_eq_8(k) when i_packed_mode = C_PACKED_BYTE else
                         s_eq_16(k/2) when i_packed_mode = C_PACKED_HALF_WORD else
                         s_eq_32(0);
      s_compare_lt(k) <= s_lt_8(k) when i_packed_mode = C_PACKED_BYTE else
                         s_lt_16(k/2) when i_packed_mode = C_PACKED_HALF_WORD else
                         s_lt_32(0);
      s_compare_ltu(k) <= s_ltu_8(k) when i_packed_mode = C_PACKED_BYTE else
                          s_ltu_16(k/2) when i_packed_mode = C_PACKED_HALF_WORD else
                          s_ltu_32(0);
    end generate;
  else generate
    -- In unpacked mode we only have to consider the 32-bit result.
    CmpGenUnpacked: for k in 0 to 3 generate
      s_compare_eq(k) <= s_eq_32(0);
      s_compare_lt(k) <= s_lt_32(0);
      s_compare_ltu(k) <= s_ltu_32(0);
    end generate;
  end generate;

  -- Derive further comparison results.
  CmpGen2: for k in 0 to 3 generate
    s_compare_ne(k) <= not s_compare_eq(k);
    s_compare_le(k) <= s_compare_eq(k) or s_compare_lt(k);
    s_compare_leu(k) <= s_compare_eq(k) or s_compare_ltu(k);
  end generate;

  -- Compare and set operations.
  SetGen: for k in 0 to 3 generate
    CmpMux: with i_op select
      s_set_bit(k) <=
        s_compare_eq(k) when C_ALU_SEQ,
        s_compare_ne(k) when C_ALU_SNE,
        s_compare_lt(k) when C_ALU_SLT,
        s_compare_ltu(k) when C_ALU_SLTU,
        s_compare_le(k) when C_ALU_SLE,
        s_compare_leu(k) when C_ALU_SLEU,
        '-' when others;

    o_set_res(8*(k+1)-1 downto 8*k) <= (others => s_set_bit(k));
  end generate;

  -- Min/Max operations.
  o_min_res <= CondAssign(i_src_a, i_src_b, s_compare_lt);
  o_max_res <= CondAssign(i_src_b, i_src_a, s_compare_lt);
  o_minu_res <= CondAssign(i_src_a, i_src_b, s_compare_ltu);
  o_maxu_res <= CondAssign(i_src_b, i_src_a, s_compare_ltu);
end rtl;
