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
-- This is a configurable FPU pipeline. The pipeline can be instantiated for different sizes (e.g.
-- 32-bit, 16-bit and 8-bit floating point).
--
-- Different operations may take different number of cycles to complete.
--
-- Single-cycle operations:
--   FSEQ, FSNE, FSLT, FSLE, FSNAN, FMIN, FMAX
--
-- Three-cycle operations:
--   FADD, FSUB, FMUL
--
-- Multi-cycle operations (stalls the pipeline):
--   FDIV, FSQRT
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity fpu_pipe is
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
    o_stall : out std_logic;

    -- Inputs (async).
    i_enable : in std_logic;
    i_op : in T_FPU_OP;
    i_src_a : in std_logic_vector(WIDTH-1 downto 0);
    i_src_b : in std_logic_vector(WIDTH-1 downto 0);

    -- Outputs (async).
    o_f1_next_result : out std_logic_vector(WIDTH-1 downto 0);
    o_f1_next_result_ready : out std_logic;
    o_f3_next_result : out std_logic_vector(WIDTH-1 downto 0);
    o_f3_next_result_ready : out std_logic
  );
end fpu_pipe;

architecture rtl of fpu_pipe is
  -- Constants.
  constant SIGNIFICAND_BITS : positive := FRACT_BITS + 1;

  -- F1 signals.
  signal s_is_compare_op : std_logic;
  signal s_is_minmax_op : std_logic;
  signal s_is_add_op : std_logic;
  signal s_is_mul_op : std_logic;
  signal s_is_div_op : std_logic;
  signal s_is_sqrt_op : std_logic;
  signal s_is_single_cycle_op : std_logic;

  -- Set operations.
  signal s_compare_eq : std_logic;
  signal s_compare_ne : std_logic;
  signal s_compare_lt : std_logic;
  signal s_compare_le : std_logic;
  signal s_is_any_src_nan : std_logic;
  signal s_set_bit : std_logic;
  signal s_set_res : std_logic_vector(WIDTH-1 downto 0);

  -- Min/Max operations.
  signal s_is_max_op : std_logic;
  signal s_minmax_sel_a : std_logic;
  signal s_minmax_res : std_logic_vector(WIDTH-1 downto 0);

  signal s_f1_next_add_en : std_logic;
  signal s_f1_next_mul_en : std_logic;
  signal s_f1_next_div_en : std_logic;
  signal s_f1_next_sqrt_en : std_logic;

  signal s_f1_next_src_a_sign : std_logic;
  signal s_f1_next_src_a_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_f1_next_src_a_significand : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_f1_next_src_a_is_nan : std_logic;
  signal s_f1_next_src_a_is_inf : std_logic;
  signal s_f1_next_src_a_is_zero : std_logic;

  signal s_f1_next_src_b_sign : std_logic;
  signal s_f1_next_src_b_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_f1_next_src_b_significand : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_f1_next_src_b_is_nan : std_logic;
  signal s_f1_next_src_b_is_inf : std_logic;
  signal s_f1_next_src_b_is_zero : std_logic;

  -- Signals from F1 to F2 (sync).
  signal s_f1_add_en : std_logic;
  signal s_f1_mul_en : std_logic;
  signal s_f1_div_en : std_logic;
  signal s_f1_sqrt_en : std_logic;

  signal s_f1_src_a_sign : std_logic;
  signal s_f1_src_a_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_f1_src_a_significand : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_f1_src_a_is_nan : std_logic;
  signal s_f1_src_a_is_inf : std_logic;
  signal s_f1_src_a_is_zero : std_logic;

  signal s_f1_src_b_sign : std_logic;
  signal s_f1_src_b_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_f1_src_b_significand : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_f1_src_b_is_nan : std_logic;
  signal s_f1_src_b_is_inf : std_logic;
  signal s_f1_src_b_is_zero : std_logic;

  -- F2 signals.
  signal s_fmul_significand : unsigned((2*SIGNIFICAND_BITS)-1 downto 0);

  signal s_f2_next_result_sign : std_logic;
  signal s_f2_next_result_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_f2_next_result_significand : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_f2_next_result_is_nan : std_logic;
  signal s_f2_next_result_is_inf : std_logic;
  signal s_f2_next_result_is_zero : std_logic;

  -- Signals from F2 to F3 (sync).
  signal s_f2_add_en : std_logic;
  signal s_f2_mul_en : std_logic;
  signal s_f2_div_en : std_logic;
  signal s_f2_sqrt_en : std_logic;

  signal s_f2_result_sign : std_logic;
  signal s_f2_result_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_f2_result_significand : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_f2_result_is_nan : std_logic;
  signal s_f2_result_is_inf : std_logic;
  signal s_f2_result_is_zero : std_logic;

  -- F3 signals.
  signal s_f3_next_result : std_logic_vector(WIDTH-1 downto 0);
begin
  --==================================================================================================
  -- F1: Stage 1 of the FPU pipeline.
  --==================================================================================================

  ----------------------------------------------------------------------------------------------------
  -- Decode the FPU operation.
  ----------------------------------------------------------------------------------------------------

  DecodeOpMux1: with i_op select
    s_is_compare_op <=
      '1' when C_FPU_FSEQ | C_FPU_FSNE | C_FPU_FSLT | C_FPU_FSLE | C_FPU_FSNAN,
      '0' when others;

  DecodeOpMux2: with i_op select
    s_is_minmax_op <=
      '1' when C_FPU_FMIN | C_FPU_FMAX,
      '0' when others;

  DecodeOpMux3: with i_op select
    s_is_add_op <=
      '1' when C_FPU_FADD | C_FPU_FSUB,
      '0' when others;

  s_is_mul_op <= '1' when i_op = C_FPU_FMUL else '0';
  s_is_div_op <= '1' when i_op = C_FPU_FDIV else '0';
  s_is_sqrt_op <= '1' when i_op = C_FPU_FSQRT else '0';

  s_f1_next_add_en <= s_is_add_op and i_enable;
  s_f1_next_mul_en <= s_is_mul_op and i_enable;
  s_f1_next_div_en <= s_is_div_op and i_enable;
  s_f1_next_sqrt_en <= s_is_sqrt_op and i_enable;

  -- Is this a single cycle operation?
  s_is_single_cycle_op <= s_is_compare_op or s_is_minmax_op;


  ----------------------------------------------------------------------------------------------------
  -- Decompose source operands (mostly for multi-cycle ops).
  ----------------------------------------------------------------------------------------------------

  DecomposeA: entity work.float_decompose
    generic map (
      WIDTH => WIDTH,
      EXP_BITS => EXP_BITS,
      FRACT_BITS => FRACT_BITS
    )
    port map (
      i_src => i_src_a,
      o_sign => s_f1_next_src_a_sign,
      o_exponent => s_f1_next_src_a_exponent,
      o_significand => s_f1_next_src_a_significand,
      o_is_nan => s_f1_next_src_a_is_nan,
      o_is_inf => s_f1_next_src_a_is_inf,
      o_is_zero => s_f1_next_src_a_is_zero
    );

  DecomposeB: entity work.float_decompose
    generic map (
      WIDTH => WIDTH,
      EXP_BITS => EXP_BITS,
      FRACT_BITS => FRACT_BITS
    )
    port map (
      i_src => i_src_b,
      o_sign => s_f1_next_src_b_sign,
      o_exponent => s_f1_next_src_b_exponent,
      o_significand => s_f1_next_src_b_significand,
      o_is_nan => s_f1_next_src_b_is_nan,
      o_is_inf => s_f1_next_src_b_is_inf,
      o_is_zero => s_f1_next_src_b_is_zero
    );


  ----------------------------------------------------------------------------------------------------
  -- Single cycle compare/min/max operations.
  ----------------------------------------------------------------------------------------------------

  -- Camparison results.
  Cmp: entity work.float_compare
    generic map (
      WIDTH => WIDTH
    )
    port map (
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      o_eq => s_compare_eq,
      o_ne => s_compare_ne,
      o_lt => s_compare_lt,
      o_le => s_compare_le
    );

  -- Min/Max operations.
  s_is_max_op <= not i_op(0);
  s_minmax_sel_a <= s_compare_lt xor s_is_max_op;
  s_minmax_res <= i_src_a when s_minmax_sel_a = '1' else i_src_b;

  -- Compare and set operations.
  s_is_any_src_nan <= s_f1_next_src_a_is_nan or s_f1_next_src_b_is_nan;
  CmpMux: with i_op select
    s_set_bit <=
      s_compare_eq when C_FPU_FSEQ,
      s_compare_ne when C_FPU_FSNE,
      s_compare_lt when C_FPU_FSLT,
      s_compare_le when C_FPU_FSLE,
      s_is_any_src_nan when C_FPU_FSNAN,
      '0' when others;
  s_set_res <= (others => s_set_bit);

  -- Select the result from the first FPU stage.
  o_f1_next_result <= s_set_res when s_is_compare_op = '1' else s_minmax_res;
  o_f1_next_result_ready <= s_is_single_cycle_op and i_enable;

  -- Signals from stage 1 to stage 2 of the FPU.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_f1_add_en <= '0';
      s_f1_mul_en <= '0';
      s_f1_div_en <= '0';
      s_f1_sqrt_en <= '0';
      s_f1_src_a_sign <= '0';
      s_f1_src_a_exponent <= (others => '0');
      s_f1_src_a_significand <= (others => '0');
      s_f1_src_a_is_nan <= '0';
      s_f1_src_a_is_inf <= '0';
      s_f1_src_a_is_zero <= '0';
      s_f1_src_b_sign <= '0';
      s_f1_src_b_exponent <= (others => '0');
      s_f1_src_b_significand <= (others => '0');
      s_f1_src_b_is_nan <= '0';
      s_f1_src_b_is_inf <= '0';
      s_f1_src_b_is_zero <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_f1_add_en <= s_f1_next_add_en;
        s_f1_mul_en <= s_f1_next_mul_en;
        s_f1_div_en <= s_f1_next_div_en;
        s_f1_sqrt_en <= s_f1_next_sqrt_en;
        s_f1_src_a_sign <= s_f1_next_src_a_sign;
        s_f1_src_a_exponent <= s_f1_next_src_a_exponent;
        s_f1_src_a_significand <= s_f1_next_src_a_significand;
        s_f1_src_a_is_nan <= s_f1_next_src_a_is_nan;
        s_f1_src_a_is_inf <= s_f1_next_src_a_is_inf;
        s_f1_src_a_is_zero <= s_f1_next_src_a_is_zero;
        s_f1_src_b_sign <= s_f1_next_src_b_sign;
        s_f1_src_b_exponent <= s_f1_next_src_b_exponent;
        s_f1_src_b_significand <= s_f1_next_src_b_significand;
        s_f1_src_b_is_nan <= s_f1_next_src_b_is_nan;
        s_f1_src_b_is_inf <= s_f1_next_src_b_is_inf;
        s_f1_src_b_is_zero <= s_f1_next_src_b_is_zero;
      end if;
    end if;
  end process;


  --==================================================================================================
  -- F2: Stage 2 of the FPU pipeline.
  --==================================================================================================

  -- TODO(m): Implement me!
  -- Currently we implement a fake form of FMUL just to get some data through.
  s_f2_next_result_sign <= s_f1_src_a_sign xor s_f1_src_b_sign;
  s_f2_next_result_exponent <= std_logic_vector(unsigned(s_f1_src_a_exponent) + unsigned(s_f1_src_b_exponent) - to_unsigned(EXP_BIAS, EXP_BITS));
  s_fmul_significand <= unsigned(s_f1_src_a_significand) * unsigned(s_f1_src_b_significand);
  s_f2_next_result_significand <= std_logic_vector(s_fmul_significand((SIGNIFICAND_BITS*2)-1 downto SIGNIFICAND_BITS));
  s_f2_next_result_is_nan <= s_f1_src_a_is_nan or s_f1_src_b_is_nan;
  s_f2_next_result_is_inf <= s_f1_src_a_is_inf or s_f1_src_b_is_inf;
  s_f2_next_result_is_zero <= s_f1_src_a_is_zero or s_f1_src_b_is_zero;

  -- Signals from stage 1 to stage 2 of the FPU.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_f2_add_en <= '0';
      s_f2_mul_en <= '0';
      s_f2_div_en <= '0';
      s_f2_sqrt_en <= '0';
      s_f2_result_sign <= '0';
      s_f2_result_exponent <= (others => '0');
      s_f2_result_significand <= (others => '0');
      s_f2_result_is_nan <= '0';
      s_f2_result_is_inf <= '0';
      s_f2_result_is_zero <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_f2_add_en <= s_f1_add_en;
        s_f2_mul_en <= s_f1_mul_en;
        s_f2_div_en <= s_f1_div_en;
        s_f2_sqrt_en <= s_f1_sqrt_en;
        s_f2_result_sign <= s_f2_next_result_sign;
        s_f2_result_exponent <= s_f2_next_result_exponent;
        s_f2_result_significand <= s_f2_next_result_significand;
        s_f2_result_is_nan <= s_f2_next_result_is_nan;
        s_f2_result_is_inf <= s_f2_next_result_is_inf;
        s_f2_result_is_zero <= s_f2_next_result_is_zero;
      end if;
    end if;
  end process;


  --==================================================================================================
  -- F3: Stage 3 of the FPU pipeline.
  --==================================================================================================

  -- Compose the result.
  ComposeResult: entity work.float_compose
    generic map (
      WIDTH => WIDTH,
      EXP_BITS => EXP_BITS,
      FRACT_BITS => FRACT_BITS
    )
    port map (
      i_sign => s_f2_result_sign,
      i_exponent => s_f2_result_exponent,
      i_significand => s_f2_result_significand,
      i_is_nan => s_f2_result_is_nan,
      i_is_inf => s_f2_result_is_inf,
      i_is_zero => s_f2_result_is_zero,
      o_result => s_f3_next_result
    );

  o_f3_next_result <= s_f3_next_result;
  o_f3_next_result_ready <= s_f2_add_en or s_f2_mul_en or s_f2_div_en or s_f2_sqrt_en;

  -- Stall logic.
  -- TODO(m): Longer operations (DIV, SQRT) may stall.
  o_stall <= '0';
end rtl;
