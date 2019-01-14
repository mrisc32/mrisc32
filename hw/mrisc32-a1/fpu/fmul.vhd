----------------------------------------------------------------------------------------------------
-- Copyright (c) 2019 Marcus Geelnard
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
-- This is a configurable FMUL pipeline. The pipeline can be instantiated for different sizes (e.g.
-- 32-bit, 16-bit and 8-bit floating point).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity fmul is
  generic(
    WIDTH : positive := 32;
    EXP_BITS : positive := 8;
    EXP_BIAS : positive := 127;
    FRACT_BITS : positive := 23
  );
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;

    -- Inputs (async).
    i_enable : in std_logic;

    i_props_a : in T_FLOAT_PROPS;
    i_exponent_a : in std_logic_vector(EXP_BITS-1 downto 0);
    i_significand_a : in std_logic_vector(FRACT_BITS downto 0);

    i_props_b : in T_FLOAT_PROPS;
    i_exponent_b : in std_logic_vector(EXP_BITS-1 downto 0);
    i_significand_b : in std_logic_vector(FRACT_BITS downto 0);

    -- Outputs (async).
    o_props : out T_FLOAT_PROPS;
    o_exponent : out std_logic_vector(EXP_BITS-1 downto 0);
    o_significand : out std_logic_vector(FRACT_BITS downto 0);
    o_result_ready : out std_logic
  );
end fmul;

architecture rtl of fmul is
  -- Constants.
  constant SIGNIFICAND_BITS : positive := FRACT_BITS + 1;
  constant PRODUCT_BITS : positive := SIGNIFICAND_BITS * 2;

  -- F1 signals.
  signal s_f1_next_props : T_FLOAT_PROPS;
  signal s_f1_next_exponent : std_logic_vector(EXP_BITS+1 downto 0);

  -- Signals from F1 to F2 (sync).
  signal s_f1_enable : std_logic;
  signal s_f1_props : T_FLOAT_PROPS;
  signal s_f1_exponent : std_logic_vector(EXP_BITS+1 downto 0);

  signal s_f1_significand_a : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_f1_significand_b : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);

  -- F2 signals.
  signal s_f2_next_product : unsigned(PRODUCT_BITS-1 downto 0);

  -- Signals from F2 to F3 (sync).
  signal s_f2_enable : std_logic;
  signal s_f2_props : T_FLOAT_PROPS;
  signal s_f2_exponent : std_logic_vector(EXP_BITS+1 downto 0);
  signal s_f2_product : unsigned(PRODUCT_BITS-1 downto 0);

  -- F3 signals.

  -- Rounding.
  signal s_f3_round_offset : unsigned(1 downto 0);
  signal s_f3_product_rounded : unsigned(SIGNIFICAND_BITS+2 downto 0);

  -- Adjustment.
  signal s_f3_top_bits : unsigned(1 downto 0);
  signal s_f3_adjust : unsigned(1 downto 0);
  signal s_f3_product_adjusted : std_logic_vector(SIGNIFICAND_BITS+2 downto 0);
  signal s_f3_exponent_adjusted : unsigned(EXP_BITS+1 downto 0);

  -- Overflow/underflow.
  signal s_f3_overflow : std_logic;
  signal s_f3_underflow : std_logic;
begin
  --================================================================================================
  -- F1: Stage 1 of the pipeline.
  --================================================================================================

  -- Determin the preliminary properties of the result (may be overridden by final rounding).
  s_f1_next_props.is_neg <= i_props_a.is_neg xor i_props_b.is_neg;
  s_f1_next_props.is_nan <= i_props_a.is_nan or
                            i_props_b.is_nan or
                            (i_props_a.is_inf and i_props_b.is_zero) or
                            (i_props_a.is_zero and i_props_b.is_inf);
  s_f1_next_props.is_inf <= i_props_a.is_inf or i_props_b.is_inf;
  s_f1_next_props.is_zero <= i_props_a.is_zero or i_props_b.is_zero;

  -- Calculate the preliminary exponent of the result (may be overridden by final rounding).
  -- Note: We add two bits to accomodate for both overflow and underflow.
  s_f1_next_exponent <= std_logic_vector(unsigned("00" & i_exponent_a) +
                                         unsigned("00" & i_exponent_b) -
                                         EXP_BIAS);

  -- Signals from stage 1 to stage 2 of the pipeline.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_f1_enable <= '0';
      s_f1_props.is_neg <= '0';
      s_f1_props.is_nan <= '0';
      s_f1_props.is_inf <= '0';
      s_f1_props.is_zero <= '0';
      s_f1_exponent <= (others => '0');
      s_f1_significand_a <= (others => '0');
      s_f1_significand_b <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_f1_enable <= i_enable;
        s_f1_props <= s_f1_next_props;
        s_f1_exponent <= s_f1_next_exponent;
        s_f1_significand_a <= i_significand_a;
        s_f1_significand_b <= i_significand_b;
      end if;
    end if;
  end process;


  --==================================================================================================
  -- F2: Stage 2 of the pipeline.
  --==================================================================================================

  -- Perform the integer multiplication.
  s_f2_next_product <= unsigned(s_f1_significand_a) * unsigned(s_f1_significand_b);

  -- Signals from stage 2 to stage 3 of the pipeline.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_f2_enable <= '0';
      s_f2_props.is_neg <= '0';
      s_f2_props.is_nan <= '0';
      s_f2_props.is_inf <= '0';
      s_f2_props.is_zero <= '0';
      s_f2_exponent <= (others => '0');
      s_f2_product <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_f2_enable <= s_f1_enable;
        s_f2_props <= s_f1_props;
        s_f2_exponent <= s_f1_exponent;
        s_f2_product <= s_f2_next_product;
      end if;
    end if;
  end process;


  --==================================================================================================
  -- F3: Stage 3 of the pipeline.
  -- Final rounding and normalization.
  --==================================================================================================

  -- 1) Perform rounding.
  -- We currently only implement IEEE 754 "Round to nearest, ties away from zero", as it's the
  -- easiest to implement.
  -- TODO(m): Implement "Round to nearest, ties to even" instead as it's free from bias, and more
  -- importantly it's the default rounding mode in IEEE 754. See:
  -- https://en.wikipedia.org/wiki/Rounding#Round_half_to_even
  s_f3_round_offset <= s_f2_product(PRODUCT_BITS-1) & not s_f2_product(PRODUCT_BITS-1);
  s_f3_product_rounded <= ("0" & s_f2_product(PRODUCT_BITS-1 downto SIGNIFICAND_BITS-2)) +
                          resize(s_f3_round_offset, SIGNIFICAND_BITS+3);

  -- 2) Determine the required exponent adjustment (and hence, the significand shift).
  s_f3_top_bits <= s_f3_product_rounded(SIGNIFICAND_BITS+2 downto SIGNIFICAND_BITS+1);
  F3AdjustMux: with s_f3_top_bits select
    s_f3_adjust <=
        2X"2" when "10" | "11",  -- TODO(m): Can this ever occurr?!?
        2X"1" when "01",
        2X"0" when others;

  -- 3a) Normalize (shift) the significand.
  s_f3_product_adjusted <= std_logic_vector(shift_right(s_f3_product_rounded, to_integer(s_f3_adjust)));

  -- 3b) Adjust the exponent.
  s_f3_exponent_adjusted <= unsigned(s_f2_exponent) + s_f3_adjust;

  -- 4) Check for overflow/underflow.
  s_f3_overflow <= '1' when s_f3_exponent_adjusted(EXP_BITS+1 downto EXP_BITS) = "01" else '0';
  s_f3_underflow <= s_f3_exponent_adjusted(EXP_BITS+1);

  -- Output the result.
  o_props.is_neg <= s_f2_props.is_neg;
  o_props.is_nan <= s_f2_props.is_nan;
  o_props.is_inf <= s_f2_props.is_inf or s_f3_overflow;
  o_props.is_zero <= s_f2_props.is_zero or s_f3_underflow;
  o_significand <= s_f3_product_adjusted(SIGNIFICAND_BITS downto 1);
  o_exponent <= std_logic_vector(s_f3_exponent_adjusted(EXP_BITS-1 downto 0));

  -- Result ready?
  o_result_ready <= s_f2_enable;
end rtl;

