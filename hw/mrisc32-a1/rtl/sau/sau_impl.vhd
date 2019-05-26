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

----------------------------------------------------------------------------------------------------
-- This is a configurable SAU (Saturating Arithmetic Unit) pipeline. The pipeline can be
-- instantiated for different sizes (e.g. 32-bit, 16-bit and 8-bit word sizes).
--
-- All instructions take two clock cycles to complete.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity sau_impl is
  generic(
    WIDTH : positive := 32
  );
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;

    -- Inputs (async).
    i_enable : in std_logic;
    i_op : in T_SAU_OP;
    i_src_a : in std_logic_vector(WIDTH-1 downto 0);
    i_src_b : in std_logic_vector(WIDTH-1 downto 0);

    -- Outputs (async).
    o_next_result : out std_logic_vector(WIDTH-1 downto 0);
    o_next_result_ready : out std_logic
  );
end sau_impl;

architecture rtl of sau_impl is
  -- S1 signals.
  signal s_src_a_ext : std_logic_vector(WIDTH downto 0);
  signal s_src_b_ext : std_logic_vector(WIDTH downto 0);
  signal s_add_result : unsigned(WIDTH downto 0);
  signal s_sub_result : unsigned(WIDTH downto 0);

  signal s_s1_enable : std_logic;
  signal s_s1_next_is_saturating : std_logic;
  signal s_s1_is_saturating : std_logic;
  signal s_s1_next_is_signed : std_logic;
  signal s_s1_is_signed : std_logic;
  signal s_s1_next_is_sub_op : std_logic;
  signal s_s1_is_sub_op : std_logic;
  signal s_s1_next_result : unsigned(WIDTH downto 0);
  signal s_s1_result : std_logic_vector(WIDTH downto 0);

  -- S2 signals.
  signal s_saturate_select : std_logic_vector(3 downto 0);
  signal s_saturate_result : std_logic_vector(WIDTH-1 downto 0);
  signal s_halve_result : std_logic_vector(WIDTH-1 downto 0);

  signal s_s2_next_result : std_logic_vector(WIDTH-1 downto 0);

  function min_unsigned(size: integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(0, size));
  end function;

  function max_unsigned(size: integer) return std_logic_vector is
  begin
    return std_logic_vector(to_signed(-1, size));
  end function;

  function min_signed(size: integer) return std_logic_vector is
    variable v_result : std_logic_vector(size-1 downto 0);
  begin
    v_result(size-1) := '1';
    v_result(size-2 downto 0) := (others => '0');
    return v_result;
  end function;

  function max_signed(size: integer) return std_logic_vector is
    variable v_result : std_logic_vector(size-1 downto 0);
  begin
    v_result(size-1) := '0';
    v_result(size-2 downto 0) := (others => '1');
    return v_result;
  end function;
begin
  --==================================================================================================
  -- S1: Stage 1 of the SAU pipeline.
  --==================================================================================================

  -- Decode the SAU operation.
  s_s1_next_is_sub_op <= i_op(2);
  s_s1_next_is_saturating <= not i_op(1);
  s_s1_next_is_signed <= not i_op(0);

  -- Widen the input signals, with / without sign extension.
  s_src_a_ext(WIDTH) <= i_src_a(WIDTH-1) and s_s1_next_is_signed;
  s_src_a_ext(WIDTH-1 downto 0) <= i_src_a;
  s_src_b_ext(WIDTH) <= i_src_b(WIDTH-1) and s_s1_next_is_signed;
  s_src_b_ext(WIDTH-1 downto 0) <= i_src_b;

  -- Perform the addition/subtraction.
  s_add_result <= unsigned(s_src_a_ext) + unsigned(s_src_b_ext);
  s_sub_result <= unsigned(s_src_a_ext) - unsigned(s_src_b_ext);
  s_s1_next_result <= s_sub_result when s_s1_next_is_sub_op = '1' else s_add_result;

  -- Signals from stage 1 to stage 2 of the SAU.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_s1_enable <= '0';
      s_s1_is_saturating <= '0';
      s_s1_is_signed <= '0';
      s_s1_is_sub_op <= '0';
      s_s1_result <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_s1_enable <= i_enable;
        s_s1_is_saturating <= s_s1_next_is_saturating;
        s_s1_is_signed <= s_s1_next_is_signed;
        s_s1_is_sub_op <= s_s1_next_is_sub_op;
        s_s1_result <= std_logic_vector(s_s1_next_result);
      end if;
    end if;
  end process;


  --==================================================================================================
  -- S2: Stage 2 of the SAU pipeline.
  --==================================================================================================

  -- Saturate.
  --  Signed:   00xxx -> 0xxx
  --            01xxx -> 0111 (max_signed)
  --            10xxx -> 1000 (min_signed)
  --            11xxx -> 1xxx
  --  Unsigned add:
  --            0xxxx -> xxxx
  --            1xxxx -> 1111 (max_unsigned)
  --  Unsigned sub:
  --            0xxxx -> xxxx
  --            1xxxx -> 0000 (min_unsigned)
  s_saturate_select <= s_s1_is_sub_op & s_s1_is_signed & s_s1_result(WIDTH downto WIDTH-1);
  SaturateMux: with s_saturate_select select
    s_saturate_result <=
      min_signed(WIDTH)             when "0110" | "1110",
      max_signed(WIDTH)             when "0101" | "1101",
      min_unsigned(WIDTH)           when "1010" | "1011",
      max_unsigned(WIDTH)           when "0010" | "0011",
      s_s1_result(WIDTH-1 downto 0) when others;

  -- Halve.
  s_halve_result <= s_s1_result(WIDTH downto 1);

  -- Output signals.
  o_next_result <= s_saturate_result when s_s1_is_saturating = '1' else s_halve_result;
  o_next_result_ready <= s_s1_enable;
end rtl;
