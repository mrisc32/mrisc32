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
-- This is a configurable FTOI pipeline. The pipeline can be instantiated for different sizes (e.g.
-- 32-bit, 16-bit and 8-bit floating point).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity ftoi is
  generic(
    WIDTH : positive := 32;  -- Note: Must be a power of two.
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
    i_round : in std_logic;
    i_unsigned : in std_logic;
    i_props : in T_FLOAT_PROPS;
    i_exponent : in std_logic_vector(EXP_BITS-1 downto 0);
    i_significand : in std_logic_vector(FRACT_BITS downto 0);
    i_exponent_bias : in std_logic_vector(WIDTH-1 downto 0);

    -- Outputs (async).
    o_result : out std_logic_vector(WIDTH-1 downto 0);
    o_result_ready : out std_logic
  );
end ftoi;

architecture rtl of ftoi is
  -- F1 signals.
  signal s_f1_next_right_shift : unsigned(EXP_BITS+1 downto 0);
  signal s_f1_next_overflow : std_logic;
  signal s_f1_next_is_zero : std_logic;
  signal s_f1_next_round : std_logic;
  signal s_f1_next_unsigned : std_logic;

  signal s_f1_enable : std_logic;
  signal s_f1_round : std_logic;
  signal s_f1_unsigned : std_logic;
  signal s_f1_overflow : std_logic;
  signal s_f1_is_zero : std_logic;
  signal s_f1_is_neg : std_logic;
  signal s_f1_right_shift : unsigned(EXP_BITS+1 downto 0);
  signal s_f1_significand : std_logic_vector(FRACT_BITS downto 0);

  -- F2 signals.
  signal s_f2_next_significand : unsigned(WIDTH downto 0);
  signal s_f2_next_overflow : std_logic;

  signal s_f2_enable : std_logic;
  signal s_f2_round : std_logic;
  signal s_f2_unsigned : std_logic;
  signal s_f2_overflow : std_logic;
  signal s_f2_is_zero : std_logic;
  signal s_f2_is_neg : std_logic;
  signal s_f2_significand : unsigned(WIDTH downto 0);

  -- F3 signals.
  signal s_f3_round : unsigned(0 downto 0);
  signal s_f3_value_rounded : unsigned(WIDTH+1 downto 0);
  signal s_f3_final_value : unsigned(WIDTH-1 downto 0);
  signal s_f3_signed_overflow : std_logic;
  signal s_f3_unsigned_overflow : std_logic;
  signal s_f3_overflow : std_logic;
  signal s_f3_next_result : std_logic_vector(WIDTH-1 downto 0);
begin
  --================================================================================================
  -- F1: Stage 1 of the pipeline.
  --================================================================================================

  -- Overflow (or NaN)?
  -- We consider the upper bits of i_exponent_bias (the lower are treated later).
  s_f1_next_overflow <= '1' when i_exponent_bias(WIDTH-1) = '1' and
                                 signed(i_exponent_bias(WIDTH-2 downto EXP_BITS+2)) /= to_signed(-1, WIDTH-EXP_BITS-1)
                        else
                        i_props.is_inf or i_props.is_nan;

  -- Zero (or underflow)?
  -- We consider the upper bits of i_exponent_bias (the lower are treated later).
  s_f1_next_is_zero <= '1' when i_exponent_bias(WIDTH-1) = '0' and
                                unsigned(i_exponent_bias(WIDTH-2 downto EXP_BITS+2)) /= to_unsigned(0, WIDTH-EXP_BITS-1)
                       else
                       i_props.is_zero;

  -- Calculate the right-shift for the significand.
  s_f1_next_right_shift <= to_unsigned(EXP_BIAS + WIDTH - 1, EXP_BITS+2) -
                           unsigned("00" & i_exponent) -
                           unsigned(i_exponent_bias(EXP_BITS+1 downto 0));

  -- Rounding.
  -- Note: Avoid undefined results (i_round may be undefined).
  s_f1_next_round <= i_round when i_enable = '1' else '0';

  -- Sign.
  -- Note: Avoid undefined results (i_unsigned may be undefined).
  s_f1_next_unsigned <= i_unsigned when i_enable = '1' else '0';

  -- Signals to the next stage.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_f1_enable <= '0';
      s_f1_round <= '0';
      s_f1_unsigned <= '0';
      s_f1_overflow <= '0';
      s_f1_is_zero <= '0';
      s_f1_is_neg <= '0';
      s_f1_right_shift <= (others => '0');
      s_f1_significand <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_f1_enable <= i_enable;
        s_f1_round <= s_f1_next_round;
        s_f1_unsigned <= s_f1_next_unsigned;
        s_f1_overflow <= s_f1_next_overflow;
        s_f1_is_zero <= s_f1_next_is_zero;
        s_f1_is_neg <= i_props.is_neg;
        s_f1_right_shift <= s_f1_next_right_shift;
        s_f1_significand <= i_significand;
      end if;
    end if;
  end process;


  --==================================================================================================
  -- F2: Stage 2 of the pipeline.
  --==================================================================================================

  -- Right-shift the significand (we keep one extra LSB for rounding).
  s_f2_next_significand <= shift_right(unsigned(s_f1_significand) &
                                       to_unsigned(0, WIDTH-FRACT_BITS),
                                       to_integer(s_f1_right_shift));

  -- Overflow?
  -- If the right-shift is negative, we have overflow.
  s_f2_next_overflow <= s_f1_right_shift(EXP_BITS+1) or s_f1_overflow;

  -- Signals to the next stage.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_f2_enable <= '0';
      s_f2_round <= '0';
      s_f2_unsigned <= '0';
      s_f2_overflow <= '0';
      s_f2_is_zero <= '0';
      s_f2_is_neg <= '0';
      s_f2_significand <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_f2_enable <= s_f1_enable;
        s_f2_round <= s_f1_round;
        s_f2_unsigned <= s_f1_unsigned;
        s_f2_overflow <= s_f2_next_overflow;
        s_f2_is_zero <= s_f1_is_zero;
        s_f2_is_neg <= s_f1_is_neg;
        s_f2_significand <= s_f2_next_significand;
      end if;
    end if;
  end process;


  --==================================================================================================
  -- F3: Stage 3 of the pipeline.
  --==================================================================================================

  -- 1a) Round the shifted significand.
  s_f3_round(0) <= s_f2_round;
  s_f3_value_rounded <= ('0' & s_f2_significand) + s_f3_round;
  s_f3_final_value <= s_f3_value_rounded(WIDTH downto 1);

  -- 1b) Overflow?
  -- * For signed numbers the valid range for the significand is: -0x80000000..0x7fffffff.
  -- * For unsigned numbers the valid range for the significand is: 0x00000000..0xffffffff.
  -- Note: Overflow can never happen due to rounding (since the significand is always a few bits
  -- smaller than WIDTH), so we can check the significand before rounding (this shortens the logic
  -- path).
  s_f3_signed_overflow <= s_f2_significand(WIDTH) when s_f2_is_neg = '0' or s_f2_significand(WIDTH-1 downto 1) /= to_unsigned(0, 31) else
                          '0';
  s_f3_unsigned_overflow <= s_f2_is_neg when s_f2_significand(WIDTH downto 1) /= to_unsigned(0, 32) else
                            '0';
  s_f3_overflow <= s_f3_unsigned_overflow when s_f2_unsigned = '1' else s_f3_signed_overflow;

  -- 2) Select result.
  s_f3_next_result <= (others => '0') when s_f2_is_zero = '1' else
                      (others => '1') when (s_f2_overflow or s_f3_overflow) = '1' else
                      std_logic_vector(-signed(s_f3_final_value)) when s_f2_is_neg = '1' else
                      std_logic_vector(s_f3_final_value);

  -- Output the result.
  o_result <= s_f3_next_result;

  -- Result ready?
  o_result_ready <= s_f2_enable;
end rtl;

