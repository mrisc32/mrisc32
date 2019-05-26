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
-- This is a configurable FADD (and FSUB) pipeline. The pipeline can be instantiated for different
-- sizes (e.g. 32-bit, 16-bit and 8-bit floating point).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity fadd is
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
    i_subtract : in std_logic;

    i_props_a : in T_FLOAT_PROPS;
    i_exponent_a : in std_logic_vector(EXP_BITS-1 downto 0);
    i_significand_a : in std_logic_vector(FRACT_BITS downto 0);

    i_props_b : in T_FLOAT_PROPS;
    i_exponent_b : in std_logic_vector(EXP_BITS-1 downto 0);
    i_significand_b : in std_logic_vector(FRACT_BITS downto 0);

    i_magn_a_lt_magn_b : in std_logic;  -- |a| < |b|

    -- Outputs (async).
    o_props : out T_FLOAT_PROPS;
    o_exponent : out std_logic_vector(EXP_BITS-1 downto 0);
    o_significand : out std_logic_vector(FRACT_BITS downto 0);
    o_result_ready : out std_logic
  );
end fadd;

architecture rtl of fadd is
  -- Constants.
  constant SIGNIFICAND_BITS : positive := FRACT_BITS + 1;
  constant LEADING_ZEROS_WIDTH : positive := log2(SIGNIFICAND_BITS+1)+1;

  -- F1 signals.
  signal s_f1_enable : std_logic;
  signal s_f1_props : T_FLOAT_PROPS;
  signal s_f1_exponent : unsigned(EXP_BITS-1 downto 0);
  signal s_f1_significand_a : unsigned(SIGNIFICAND_BITS-1 downto 0);
  signal s_f1_significand_b : unsigned(SIGNIFICAND_BITS-1 downto 0);
  signal s_f1_right_shift : unsigned(EXP_BITS-1 downto 0);
  signal s_f1_do_subtract : std_logic;
  signal s_f1_negate_result : std_logic;

  -- F2 signals.
  signal s_f2_enable : std_logic;
  signal s_f2_props : T_FLOAT_PROPS;
  signal s_f2_exponent : unsigned(EXP_BITS-1 downto 0);
  signal s_f2_significand : unsigned(SIGNIFICAND_BITS downto 0);

  -- F3 signals.
  signal s_f3_enable : std_logic;
  signal s_f3_props : T_FLOAT_PROPS;
  signal s_f3_exponent : unsigned(EXP_BITS downto 0);
  signal s_f3_exponent_adjust : unsigned(LEADING_ZEROS_WIDTH-1 downto 0);
  signal s_f3_significand : unsigned(SIGNIFICAND_BITS downto 0);
  signal s_f3_significand_is_zero : std_logic;

  -- F4 signals.
  signal s_f4_significand_shifted : unsigned(SIGNIFICAND_BITS downto 0);
  signal s_f4_exponent : unsigned(EXP_BITS+1 downto 0);
  signal s_f4_overflow : std_logic;
  signal s_f4_underflow : std_logic;
begin
  --================================================================================================
  -- F1: Stage 1 of the pipeline.
  --================================================================================================

  process(i_clk, i_rst)
    variable v_invalid_sum : std_logic;
    variable v_is_negative_infinity : std_logic;

    variable v_swap_operands : std_logic;
    variable v_a_is_neg : std_logic;
    variable v_b_is_neg : std_logic;
    variable v_negate_result : std_logic;
    variable v_do_subtract : std_logic;

    variable v_right_shift : unsigned(EXP_BITS-1 downto 0);
    variable v_max_exponent : unsigned(EXP_BITS-1 downto 0);
    variable v_max_exp_significand : unsigned(SIGNIFICAND_BITS-1 downto 0);
    variable v_min_exp_significand : unsigned(SIGNIFICAND_BITS-1 downto 0);
  begin
    if i_rst = '1' then
      s_f1_enable <= '0';
      s_f1_props <= ('0', '0', '0', '0');
      s_f1_exponent <= (others => '0');
      s_f1_significand_a <= (others => '0');
      s_f1_significand_b <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        -- Should we swap the operands?
        v_swap_operands := i_magn_a_lt_magn_b;

        -- The signs of the operands depend on the operation (negate b for subtraction).
        v_a_is_neg := i_props_a.is_neg;
        v_b_is_neg := i_props_b.is_neg xor i_subtract;

        -- Is this an invalid operation?
        --  - Adding infinities with different signs is an invalid operation.
        v_invalid_sum := i_props_a.is_inf and i_props_b.is_inf and
                         (v_a_is_neg xor v_b_is_neg);

        -- Negative or positive infinity?
        -- Note: This assumes one of the following cases:
        --   1) Only one of the terms is infinity, in which case the sign is determined by that term
        --   2) Both terms are infinity, and they have the same sign
        --   3) Both terms are infinity, but with opposite signs => NaN (v_invalid_sum = '1')
        --   4) None of the terms is infinity => the sign is determined later by the adder
        v_is_negative_infinity := (v_a_is_neg and i_props_a.is_inf) or
                                  (v_b_is_neg and i_props_b.is_inf);

        -- Handle signs: Should we add or subtract, and/or should we negate the final result?
        v_do_subtract := v_a_is_neg xor v_b_is_neg;
        v_negate_result := ((not v_a_is_neg) and v_b_is_neg and v_swap_operands) or
                           (v_a_is_neg and not ((not v_b_is_neg) and v_swap_operands));

        -- Calculate the exponent delta.
        if (v_swap_operands = '1') then
          v_right_shift := unsigned(i_exponent_b) - unsigned(i_exponent_a);
        else
          v_right_shift := unsigned(i_exponent_a) - unsigned(i_exponent_b);
        end if;

        -- Select the maximum exponent.
        if (v_swap_operands = '1') then
          v_max_exponent := unsigned(i_exponent_b);
          v_max_exp_significand := unsigned(i_significand_b);
          v_min_exp_significand := unsigned(i_significand_a);
        else
          v_max_exponent := unsigned(i_exponent_a);
          v_max_exp_significand := unsigned(i_significand_a);
          v_min_exp_significand := unsigned(i_significand_b);
        end if;

        -- Signals to the next stage.
        s_f1_enable <= i_enable;
        s_f1_exponent <= v_max_exponent;
        s_f1_significand_a <= v_max_exp_significand;
        s_f1_significand_b <= v_min_exp_significand;
        s_f1_right_shift <= v_right_shift;
        s_f1_do_subtract <= v_do_subtract;
        s_f1_negate_result <= v_negate_result;

        -- Preliminary floating point properties.
        s_f1_props.is_neg <= v_is_negative_infinity;
        s_f1_props.is_nan <= i_props_a.is_nan or i_props_b.is_nan or v_invalid_sum;
        s_f1_props.is_inf <= i_props_a.is_inf or i_props_b.is_inf;
        s_f1_props.is_zero <= i_props_a.is_zero and i_props_b.is_zero;
      end if;
    end if;
  end process;


  --==================================================================================================
  -- F2: Stage 2 of the pipeline.
  --==================================================================================================

  process(i_clk, i_rst)
    variable v_significand_b_shifted : unsigned(SIGNIFICAND_BITS-1 downto 0);
    variable v_a : signed(SIGNIFICAND_BITS downto 0);
    variable v_b : signed(SIGNIFICAND_BITS downto 0);
    variable v_sum : signed(SIGNIFICAND_BITS downto 0);
    variable v_diff : signed(SIGNIFICAND_BITS downto 0);
    variable v_diff_is_neg : std_logic;
    variable v_result : unsigned(SIGNIFICAND_BITS downto 0);
    variable v_result_is_neg : std_logic;
  begin
    if i_rst = '1' then
      s_f2_enable <= '0';
      s_f2_props <= ('0', '0', '0', '0');
      s_f2_exponent <= (others => '0');
      s_f2_significand <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        -- Right shift the significand with the minimum exponent.
        -- TODO(m): Keep enough shifted bits to do rounding.
        v_significand_b_shifted := shift_right(s_f1_significand_b, to_integer(s_f1_right_shift));

        -- Calcualte the sum and difference.
        -- Note: Add an extra bit to each input to avoid overflow.
        v_a := signed('0' & s_f1_significand_a);
        v_b := signed('0' & v_significand_b_shifted);
        v_sum := v_a + v_b;
        v_diff := v_a - v_b;

        -- Negative difference?
        v_diff_is_neg := s_f1_do_subtract and v_diff(SIGNIFICAND_BITS);
        v_result_is_neg := v_diff_is_neg xor s_f1_negate_result;

        -- Select the resulting significand.
        if s_f1_do_subtract = '1' then
          if v_diff_is_neg = '1' then
            v_result := '0' & unsigned(-v_diff(SIGNIFICAND_BITS-1 downto 0));
          else
            v_result := '0' & unsigned(v_diff(SIGNIFICAND_BITS-1 downto 0));
          end if;
        else
          v_result := unsigned(v_sum);
        end if;

        -- Signals to the next stage.
        s_f2_enable <= s_f1_enable;
        s_f2_props.is_neg <= s_f1_props.is_neg or (v_result_is_neg and (not s_f1_props.is_nan) and
                                                                       (not s_f1_props.is_inf) and
                                                                       (not s_f1_props.is_zero));
        s_f2_props.is_nan <= s_f1_props.is_nan;
        s_f2_props.is_inf <= s_f1_props.is_inf;
        s_f2_props.is_zero <= s_f1_props.is_zero;
        s_f2_exponent <= s_f1_exponent;
        s_f2_significand <= v_result;
      end if;
    end if;
  end process;


  --==================================================================================================
  -- F3: Stage 3 of the pipeline.
  --==================================================================================================

  process(i_clk, i_rst)
    variable v_leading_zeros : integer;
    variable v_exponent_without_leading_zeros : unsigned(EXP_BITS downto 0);
    variable v_significan_is_zero : std_logic;
  begin
    if i_rst = '1' then
      s_f3_enable <= '0';
      s_f3_props <= ('0', '0', '0', '0');
      s_f3_exponent <= (others => '0');
      s_f3_exponent_adjust <= (others => '0');
      s_f3_significand <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        -- Determine the number of leading zeros.
        -- TODO(m): Use something like the clz32 implementation.
        v_leading_zeros := SIGNIFICAND_BITS + 1;
        for i in SIGNIFICAND_BITS downto 0 loop
          if s_f2_significand(i) = '1' then
            v_leading_zeros := SIGNIFICAND_BITS - i;
            exit;
          end if;
        end loop;

        -- Is the resulting significand zero (e.g. A - A)?
        if s_f2_significand = to_unsigned(0, SIGNIFICAND_BITS) then
          v_significan_is_zero := '1';
        else
          v_significan_is_zero := '0';
        end if;

        -- The expected exponent, if there are no leading zeros.
        -- Note: We add 1, since we have an extra MSB compared to the original significand.
        v_exponent_without_leading_zeros := ('0' & s_f2_exponent) + to_unsigned(1, 1);

        -- Signals to the next stage.
        s_f3_enable <= s_f2_enable;
        s_f3_props <= s_f2_props;
        s_f3_exponent <= v_exponent_without_leading_zeros;
        s_f3_exponent_adjust <= to_unsigned(v_leading_zeros, LEADING_ZEROS_WIDTH);
        s_f3_significand <= s_f2_significand;
        s_f3_significand_is_zero <= v_significan_is_zero;
      end if;
    end if;
  end process;


  --==================================================================================================
  -- F4: Stage 4 of the pipeline.
  --==================================================================================================

  -- Normalize the significand and the exponent.
  s_f4_significand_shifted <= shift_left(s_f3_significand, to_integer(s_f3_exponent_adjust));
  s_f4_exponent <= ('0' & s_f3_exponent) - resize(s_f3_exponent_adjust, EXP_BITS + 2);

  -- Rounding.
  -- TODO(m): Implement me!

  -- Overflow/underflow.
  s_f4_overflow <= '1' when s_f4_exponent(EXP_BITS+1 downto EXP_BITS) = "01" or
                            s_f4_exponent(EXP_BITS+1 downto 0) = "00" & (EXP_BITS-1 downto 0 => '1')
                   else '0';
  s_f4_underflow <= '1' when s_f4_exponent(EXP_BITS+1) = '1' or
                             s_f4_exponent(EXP_BITS+1 downto 0) = (EXP_BITS+1 downto 0 => '0')
                    else '0';

  -- Output the result.
  o_props.is_neg <= s_f3_props.is_neg;
  o_props.is_nan <= s_f3_props.is_nan;
  o_props.is_inf <= (s_f3_props.is_inf or s_f4_overflow)
                    and not s_f3_props.is_nan;
  o_props.is_zero <= (s_f3_props.is_zero or s_f3_significand_is_zero or s_f4_underflow)
                     and not s_f3_props.is_nan;
  o_significand <= std_logic_vector(s_f4_significand_shifted(SIGNIFICAND_BITS downto 1));
  o_exponent <= std_logic_vector(s_f4_exponent(EXP_BITS-1 downto 0));

  -- Result ready?
  o_result_ready <= s_f3_enable;
end rtl;

