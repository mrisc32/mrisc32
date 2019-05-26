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
-- This is a configurable four-stage FMUL pipeline. The pipeline can be instantiated for different
-- sizes (e.g. 32-bit, 16-bit and 8-bit floating point).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

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
  signal s_f3_enable : std_logic;
  signal s_f3_props : T_FLOAT_PROPS;
  signal s_f3_next_product_rounded : unsigned(SIGNIFICAND_BITS+1 downto 0);
  signal s_f3_next_do_adjust : std_logic;
  signal s_f3_round_offset : unsigned(1 downto 0);
  signal s_f3_exponent : std_logic_vector(EXP_BITS+1 downto 0);
  signal s_f3_product_rounded : unsigned(SIGNIFICAND_BITS+1 downto 0);
  signal s_f3_do_adjust : std_logic;

  -- F4 signals.
  signal s_f4_product_adjusted : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_f4_exponent_plus_1 : unsigned(EXP_BITS+1 downto 0);
  signal s_f4_exponent_adjusted : unsigned(EXP_BITS+1 downto 0);
  signal s_f4_overflow : std_logic;
  signal s_f4_underflow : std_logic;
begin
  --================================================================================================
  -- F1: Stage 1 of the pipeline.
  -- * Preparation of inputs for the integer multiplier.
  -- * Preliminary properties (NaN, Inf etc) for the final result.
  --================================================================================================

  -- Determine the preliminary properties of the result (may be adjusted by final rounding).
  s_f1_next_props.is_neg <= i_props_a.is_neg xor i_props_b.is_neg;
  s_f1_next_props.is_nan <= i_props_a.is_nan or
                            i_props_b.is_nan or
                            (i_props_a.is_inf and i_props_b.is_zero) or
                            (i_props_a.is_zero and i_props_b.is_inf);
  s_f1_next_props.is_inf <= i_props_a.is_inf or i_props_b.is_inf;
  s_f1_next_props.is_zero <= i_props_a.is_zero or i_props_b.is_zero;

  -- Calculate the preliminary exponent of the result (may be adjusted by final rounding).
  -- Note: We add two bits to accomodate for both overflow and underflow.
  s_f1_next_exponent <= std_logic_vector(unsigned("00" & i_exponent_a) +
                                         unsigned("00" & i_exponent_b) -
                                         EXP_BIAS);

  -- Signals from stage 1 to stage 2 of the pipeline.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_f1_enable <= '0';
      s_f1_props <= ('0', '0', '0', '0');
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
  -- * Integer multiplication.
  --==================================================================================================

  -- Perform the integer multiplication.
  s_f2_next_product <= unsigned(s_f1_significand_a) * unsigned(s_f1_significand_b);

  -- Signals from stage 2 to stage 3 of the pipeline.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_f2_enable <= '0';
      s_f2_props <= ('0', '0', '0', '0');
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
  -- * Rounding.
  --==================================================================================================

  -- 1) Perform rounding.
  -- We currently only implement IEEE 754 "Round to nearest, ties away from zero", as it's the
  -- easiest to implement.
  -- TODO(m): Implement "Round to nearest, ties to even" instead as it's free from bias, and more
  -- importantly it's the default rounding mode in IEEE 754. See:
  -- https://en.wikipedia.org/wiki/Rounding#Round_half_to_even
  s_f3_round_offset <= s_f2_product(PRODUCT_BITS-1) & not s_f2_product(PRODUCT_BITS-1);
  s_f3_next_product_rounded <= s_f2_product(PRODUCT_BITS-1 downto SIGNIFICAND_BITS-2) +
                               resize(s_f3_round_offset, SIGNIFICAND_BITS+2);

  -- 2) Is exponent adjustment needed?
  s_f3_next_do_adjust <= s_f3_next_product_rounded(SIGNIFICAND_BITS+1);

  -- Signals from stage 2 to stage 3 of the pipeline.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_f3_enable <= '0';
      s_f3_props <= ('0', '0', '0', '0');
      s_f3_exponent <= (others => '0');
      s_f3_product_rounded <= (others => '0');
      s_f3_do_adjust <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_f3_enable <= s_f2_enable;
        s_f3_props <= s_f2_props;
        s_f3_exponent <= s_f2_exponent;
        s_f3_product_rounded <= s_f3_next_product_rounded;
        s_f3_do_adjust <= s_f3_next_do_adjust;
      end if;
    end if;
  end process;


  --==================================================================================================
  -- F4: Stage 4 of the pipeline.
  -- * Final normalization.
  -- * Final floating point properties.
  --==================================================================================================

  -- 1a) Normalize (shift) the significand.
  s_f4_product_adjusted <=
      std_logic_vector(s_f3_product_rounded(SIGNIFICAND_BITS+1 downto 2)) when s_f3_do_adjust = '1' else
      std_logic_vector(s_f3_product_rounded(SIGNIFICAND_BITS downto 1));

  -- 1b) Adjust the exponent.
  s_f4_exponent_plus_1 <= unsigned(s_f3_exponent) + to_unsigned(1, 1);
  s_f4_exponent_adjusted <= s_f4_exponent_plus_1 when s_f3_do_adjust = '1' else
                            unsigned(s_f3_exponent);

  -- 2) Check for overflow/underflow.
  s_f4_overflow <= '1' when s_f4_exponent_adjusted(EXP_BITS+1 downto EXP_BITS) = "01" or
                            s_f4_exponent_adjusted(EXP_BITS+1 downto 0) = "00" & (EXP_BITS-1 downto 0 => '1')
                   else '0';
  s_f4_underflow <= '1' when s_f4_exponent_adjusted(EXP_BITS+1) = '1' or
                             s_f4_exponent_adjusted(EXP_BITS+1 downto 0) = (EXP_BITS+1 downto 0 => '0')
                    else '0';

  -- Output the result.
  o_props.is_neg <= s_f3_props.is_neg;
  o_props.is_nan <= s_f3_props.is_nan;
  o_props.is_inf <= (s_f3_props.is_inf or s_f4_overflow) and not s_f3_props.is_nan;
  o_props.is_zero <= (s_f3_props.is_zero or s_f4_underflow) and not s_f3_props.is_nan;
  o_significand <= s_f4_product_adjusted;
  o_exponent <= std_logic_vector(s_f4_exponent_adjusted(EXP_BITS-1 downto 0));

  -- Result ready?
  o_result_ready <= s_f3_enable;
end rtl;

