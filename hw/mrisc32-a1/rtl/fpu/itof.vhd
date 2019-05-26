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
-- This is a configurable ITOF pipeline. The pipeline can be instantiated for different sizes (e.g.
-- 32-bit, 16-bit and 8-bit floating point).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity itof is
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
    i_unsigned : in std_logic;
    i_integer : in std_logic_vector(WIDTH-1 downto 0);
    i_exponent_bias : in std_logic_vector(WIDTH-1 downto 0);

    -- Outputs (async).
    o_props : out T_FLOAT_PROPS;
    o_exponent : out std_logic_vector(EXP_BITS-1 downto 0);
    o_significand : out std_logic_vector(FRACT_BITS downto 0);
    o_result_ready : out std_logic
  );
end itof;

architecture rtl of itof is
  -- Constants.
  constant LOG2_WIDTH : positive := log2(WIDTH);
  constant SIGNIFICAND_BITS : positive := FRACT_BITS + 1;

  -- F1 signals.
  signal s_f1_unsigned : std_logic;
  signal s_f1_next_is_neg : std_logic;
  signal s_f1_abs_int : unsigned(WIDTH-1 downto 0);
  signal s_f1_next_is_zero : std_logic;
  signal s_f1_next_overflow : std_logic;
  signal s_f1_next_underflow : std_logic;
  signal s_f1_next_shifted_int : std_logic_vector(WIDTH-1 downto 0);
  signal s_f1_next_left_shift : std_logic_vector(LOG2_WIDTH-1 downto 0);
  signal s_f1_next_exponent_biased : unsigned(EXP_BITS+1 downto 0);

  signal s_f1_enable : std_logic;
  signal s_f1_is_neg : std_logic;
  signal s_f1_is_zero : std_logic;
  signal s_f1_overflow : std_logic;
  signal s_f1_shifted_int : unsigned(WIDTH-1 downto 0);
  signal s_f1_left_shift : unsigned(LOG2_WIDTH-1 downto 0);
  signal s_f1_exponent_biased : unsigned(EXP_BITS+1 downto 0);

  -- F2 signals.
  signal s_f2_int_shifted : unsigned(WIDTH-1 downto 0);
  signal s_f2_significand_rounded : unsigned(SIGNIFICAND_BITS+1 downto 0);
  signal s_f2_exponent_adjust : unsigned(0 downto 0);
  signal s_f2_next_significand : unsigned(SIGNIFICAND_BITS-1 downto 0);
  signal s_f2_next_exponent : unsigned(EXP_BITS+1 downto 0);

  signal s_f2_enable : std_logic;
  signal s_f2_is_neg : std_logic;
  signal s_f2_is_zero : std_logic;
  signal s_f2_overflow : std_logic;
  signal s_f2_significand : unsigned(SIGNIFICAND_BITS-1 downto 0);
  signal s_f2_exponent : unsigned(EXP_BITS+1 downto 0);

  -- F3 signals.
  signal s_f3_overflow : std_logic;
  signal s_f3_underflow : std_logic;
begin
  --================================================================================================
  -- F1: Stage 1 of the pipeline.
  --================================================================================================

  -- Note: Avoid undefined results (i_unsigned may be undefined).
  s_f1_unsigned <= i_unsigned when i_enable = '1' else '0';

  -- 1a) Should we negate the two's complement input value?
  s_f1_next_is_neg <= i_integer(WIDTH-1) and not s_f1_unsigned;
  s_f1_abs_int <= unsigned(-signed(i_integer)) when s_f1_next_is_neg = '1' else unsigned(i_integer);

  -- 1b) Is the input zero?
  s_f1_next_is_zero <= '1' when unsigned(i_integer) = to_unsigned(0, WIDTH) else '0';

  -- 1c) Check if i_exponent_bias is out of range?
  s_f1_next_overflow <= '1' when i_exponent_bias(WIDTH-1) = '1' and
                                 signed(i_exponent_bias(WIDTH-2 downto EXP_BITS+2)) /= to_signed(-1, WIDTH-EXP_BITS-1)
                         else '0';
  s_f1_next_underflow <= '1' when i_exponent_bias(WIDTH-1) = '0' and
                                  unsigned(i_exponent_bias(WIDTH-2 downto EXP_BITS+2)) /= to_unsigned(0, WIDTH-EXP_BITS-1)
                          else '0';

  -- 1d) Apply the exponent bias (the adjustments for left shift and rounding comes later).
  s_f1_next_exponent_biased <= to_unsigned(EXP_BIAS + WIDTH - 1, EXP_BITS+2) -
                               unsigned(i_exponent_bias(EXP_BITS+1 downto 0));

  -- 2) Left-shift the integer while determining the number of leading zeros.
  itof_clz_and_left_shift_0: entity work.itof_clz_and_left_shift
    generic map (
      WIDTH => WIDTH,
      LOG2_WIDTH => LOG2_WIDTH
    )
    port map (
      i_src => std_logic_vector(s_f1_abs_int),
      o_result => s_f1_next_shifted_int,
      o_left_shift => s_f1_next_left_shift
    );

  -- Signals to the next stage.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_f1_enable <= '0';
      s_f1_is_neg <= '0';
      s_f1_is_zero <= '0';
      s_f1_overflow <= '0';
      s_f1_shifted_int <= (others => '0');
      s_f1_left_shift <= (others => '0');
      s_f1_exponent_biased <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_f1_enable <= i_enable;
        s_f1_is_neg <= s_f1_next_is_neg;
        s_f1_is_zero <= s_f1_next_is_zero or s_f1_next_underflow;
        s_f1_overflow <= s_f1_next_overflow;
        s_f1_shifted_int <= unsigned(s_f1_next_shifted_int);
        s_f1_left_shift <= unsigned(s_f1_next_left_shift);
        s_f1_exponent_biased <= s_f1_next_exponent_biased;
      end if;
    end if;
  end process;


  --==================================================================================================
  -- F2: Stage 2 of the pipeline.
  --==================================================================================================

  -- 1) Round the significand.
  s_f2_significand_rounded <= ('0' & s_f1_shifted_int(WIDTH-1 downto WIDTH-SIGNIFICAND_BITS-1)) +
                              to_unsigned(1, SIGNIFICAND_BITS+2);
  s_f2_exponent_adjust <= s_f2_significand_rounded(SIGNIFICAND_BITS+1 downto SIGNIFICAND_BITS+1);

  -- 2a) Final adjustment of the significand.
  s_f2_next_significand <= s_f2_significand_rounded(SIGNIFICAND_BITS+1 downto 2)
                           when s_f2_exponent_adjust = "1" else
                           s_f2_significand_rounded(SIGNIFICAND_BITS downto 1);

  -- 2b) Calculate the rounding-adjusted exponent.
  s_f2_next_exponent <= s_f1_exponent_biased -
                        resize(s_f1_left_shift, EXP_BITS+2) +
                        resize(s_f2_exponent_adjust, EXP_BITS+2);

  -- Signals to the next stage.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_f2_enable <= '0';
      s_f2_is_neg <= '0';
      s_f2_is_zero <= '0';
      s_f2_overflow <= '0';
      s_f2_exponent <= (others => '0');
      s_f2_significand <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_f2_enable <= s_f1_enable;
        s_f2_is_neg <= s_f1_is_neg;
        s_f2_is_zero <= s_f1_is_zero;
        s_f2_overflow <= s_f1_overflow;
        s_f2_exponent <= s_f2_next_exponent;
        s_f2_significand <= s_f2_next_significand;
      end if;
    end if;
  end process;


  --==================================================================================================
  -- F3: Stage 3 of the pipeline.
  --==================================================================================================

  -- 3) Overflow/underflow.
  s_f3_overflow <= '1' when s_f2_exponent(EXP_BITS+1) = '0' and
                            s_f2_exponent(EXP_BITS downto 0) >= to_unsigned((2**EXP_BITS)-1, EXP_BITS+1)
                   else '0';
  s_f3_underflow <= '1' when s_f2_exponent(EXP_BITS+1) = '1' or
                             s_f2_exponent(EXP_BITS downto 0) = to_unsigned(0, EXP_BITS+1)
                    else '0';

  -- Output the result.
  o_props.is_neg <= s_f2_is_neg;
  o_props.is_nan <= '0';
  o_props.is_inf <= s_f2_overflow or s_f3_overflow;
  o_props.is_zero <= s_f2_is_zero or s_f3_underflow;
  o_significand <= std_logic_vector(s_f2_significand);
  o_exponent <= std_logic_vector(s_f2_exponent(EXP_BITS-1 downto 0));

  -- Result ready?
  o_result_ready <= s_f2_enable;
end rtl;

