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
-- Note: FDIV is not implemented here, but in the division unit.
--
-- Different operations may take different number of cycles to complete.
--
-- Single-cycle operations:
--   FSEQ, FSNE, FSLT, FSLE, FSNAN, FMIN, FMAX
--
-- Four-cycle operations:
--   FADD, FSUB, FMUL
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity fpu_impl is
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
    i_op : in T_FPU_OP;
    i_src_a : in std_logic_vector(WIDTH-1 downto 0);
    i_src_b : in std_logic_vector(WIDTH-1 downto 0);

    -- Outputs (async).
    o_f1_next_result : out std_logic_vector(WIDTH-1 downto 0);
    o_f1_next_result_ready : out std_logic;
    o_f3_next_result : out std_logic_vector(WIDTH-1 downto 0);
    o_f3_next_result_ready : out std_logic;
    o_f4_next_result : out std_logic_vector(WIDTH-1 downto 0);
    o_f4_next_result_ready : out std_logic
  );
end fpu_impl;

architecture rtl of fpu_impl is
  -- Constants.
  constant SIGNIFICAND_BITS : positive := FRACT_BITS + 1;

  -- Operation decode signals.
  signal s_is_itof_op : std_logic;
  signal s_is_ftoi_op : std_logic;
  signal s_is_compare_op : std_logic;
  signal s_is_minmax_op : std_logic;
  signal s_is_add_op : std_logic;
  signal s_is_mul_op : std_logic;
  signal s_is_single_cycle_op : std_logic;

  -- Decomposed inputs.
  signal s_props_a : T_FLOAT_PROPS;
  signal s_exponent_a : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_significand_a : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);

  signal s_props_b : T_FLOAT_PROPS;
  signal s_exponent_b : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_significand_b : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);

  -- ITOF operations.
  signal s_itof_enable : std_logic;
  signal s_itof_unsigned : std_logic;
  signal s_itof_props : T_FLOAT_PROPS;
  signal s_itof_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_itof_significand : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_itof_result_ready : std_logic;

  -- FTOI operations.
  signal s_ftoi_enable : std_logic;
  signal s_ftoi_round : std_logic;
  signal s_ftoi_unsigned : std_logic;
  signal s_ftoi_result : std_logic_vector(WIDTH-1 downto 0);
  signal s_ftoi_result_ready : std_logic;

  -- Compare/set operations.
  signal s_compare_magn_lt : std_logic;
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

  -- FADD signals.
  signal s_fadd_enable : std_logic;
  signal s_fadd_subtract : std_logic;
  signal s_fadd_props : T_FLOAT_PROPS;
  signal s_fadd_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_fadd_significand : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_fadd_result_ready : std_logic;

  -- FMUL signals.
  signal s_fmul_enable : std_logic;
  signal s_fmul_props : T_FLOAT_PROPS;
  signal s_fmul_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_fmul_significand : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_fmul_result_ready : std_logic;

  -- Three-cycle results.
  signal s_f3_props : T_FLOAT_PROPS;
  signal s_f3_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_f3_significand : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_f3_next_result : std_logic_vector(WIDTH-1 downto 0);

  -- Four-cycle results.
  signal s_f4_props : T_FLOAT_PROPS;
  signal s_f4_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_f4_significand : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
begin
  --------------------------------------------------------------------------------------------------
  -- Decode the FPU operation.
  --------------------------------------------------------------------------------------------------

  DecodeOpMux1: with i_op select
    s_is_itof_op <=
      '1' when C_FPU_ITOF | C_FPU_UTOF,
      '0' when others;

  DecodeOpMux2: with i_op select
    s_is_ftoi_op <=
      '1' when C_FPU_FTOI | C_FPU_FTOU | C_FPU_FTOIR | C_FPU_FTOUR,
      '0' when others;

  DecodeOpMux3: with i_op select
    s_is_compare_op <=
      '1' when C_FPU_FSEQ | C_FPU_FSNE | C_FPU_FSLT | C_FPU_FSLE | C_FPU_FSNAN,
      '0' when others;

  DecodeOpMux4: with i_op select
    s_is_minmax_op <=
      '1' when C_FPU_FMIN | C_FPU_FMAX,
      '0' when others;

  DecodeOpMux5: with i_op select
    s_is_add_op <=
      '1' when C_FPU_FADD | C_FPU_FSUB,
      '0' when others;

  s_is_mul_op <= '1' when i_op = C_FPU_FMUL else '0';

  -- Is this a single cycle operation?
  s_is_single_cycle_op <= s_is_compare_op or s_is_minmax_op;


  --------------------------------------------------------------------------------------------------
  -- Decompose source operands (mostly for multi-cycle ops).
  --------------------------------------------------------------------------------------------------

  DecomposeA: entity work.float_decompose
    generic map (
      WIDTH => WIDTH,
      EXP_BITS => EXP_BITS,
      FRACT_BITS => FRACT_BITS
    )
    port map (
      i_src => i_src_a,
      o_exponent => s_exponent_a,
      o_significand => s_significand_a,
      o_props => s_props_a
    );

  DecomposeB: entity work.float_decompose
    generic map (
      WIDTH => WIDTH,
      EXP_BITS => EXP_BITS,
      FRACT_BITS => FRACT_BITS
    )
    port map (
      i_src => i_src_b,
      o_exponent => s_exponent_b,
      o_significand => s_significand_b,
      o_props => s_props_b
    );


  --------------------------------------------------------------------------------------------------
  -- Single cycle compare/min/max operations.
  --------------------------------------------------------------------------------------------------

  -- Camparison results.
  Cmp: entity work.float_compare
    generic map (
      WIDTH => WIDTH
    )
    port map (
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      o_magn_lt => s_compare_magn_lt,
      o_eq => s_compare_eq,
      o_ne => s_compare_ne,
      o_lt => s_compare_lt,
      o_le => s_compare_le
    );

  -- Min/Max operations.
  s_is_max_op <= i_op(0);
  s_minmax_sel_a <= s_compare_lt xor s_is_max_op;
  s_minmax_res <= i_src_a when s_minmax_sel_a = '1' else i_src_b;

  -- Compare and set operations.
  s_is_any_src_nan <= s_props_a.is_nan or s_props_b.is_nan;
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


  --================================================================================================
  -- Three-cycle FPU operations.
  --================================================================================================

  --------------------------------------------------------------------------------------------------
  -- ITOF/UTOF
  --------------------------------------------------------------------------------------------------

  s_itof_enable <= i_enable and s_is_itof_op;
  s_itof_unsigned <= '1' when i_op = C_FPU_UTOF else
                     '0' when i_op = C_FPU_ITOF else
                     '-';

  ITOF: entity work.itof
    generic map (
      WIDTH => WIDTH,
      EXP_BITS => EXP_BITS,
      EXP_BIAS => EXP_BIAS,
      FRACT_BITS => FRACT_BITS
    )
    port map (
      -- Control.
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => i_stall,
      i_enable => s_itof_enable,

      -- Inputs (async).
      i_unsigned => s_itof_unsigned,
      i_integer => i_src_a,
      i_exponent_bias => i_src_b,

      -- Outputs (async).
      o_props => s_itof_props,
      o_exponent => s_itof_exponent,
      o_significand => s_itof_significand,
      o_result_ready => s_itof_result_ready
    );


  --------------------------------------------------------------------------------------------------
  -- FTOI/FTOU/FTOIR/FTOUR
  --------------------------------------------------------------------------------------------------

  s_ftoi_enable <= i_enable and s_is_ftoi_op;
  s_ftoi_round <= '1' when i_op = C_FPU_FTOIR or i_op = C_FPU_FTOUR else
                  '0' when i_op = C_FPU_FTOI or i_op = C_FPU_FTOU else
                  '-';
  s_ftoi_unsigned <= '1' when i_op = C_FPU_FTOU or i_op = C_FPU_FTOUR else
                     '0' when i_op = C_FPU_FTOI or i_op = C_FPU_FTOIR else
                     '-';

  FTOI: entity work.ftoi
    generic map (
      WIDTH => WIDTH,
      EXP_BITS => EXP_BITS,
      EXP_BIAS => EXP_BIAS,
      FRACT_BITS => FRACT_BITS
    )
    port map (
      -- Control.
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => i_stall,
      i_enable => s_ftoi_enable,

      -- Inputs (async).
      i_round => s_ftoi_round,
      i_unsigned => s_ftoi_unsigned,
      i_props => s_props_a,
      i_exponent => s_exponent_a,
      i_significand => s_significand_a,
      i_exponent_bias => i_src_b,

      -- Outputs (async).
      o_result => s_ftoi_result,
      o_result_ready => s_ftoi_result_ready
    );


  --------------------------------------------------------------------------------------------------
  -- Compose the final result for three-cycle operations.
  --------------------------------------------------------------------------------------------------

  -- Select the decomposed results from the active unit.
  s_f3_props <= s_itof_props;
  s_f3_exponent <= s_itof_exponent;
  s_f3_significand <= s_itof_significand;

  ComposeResultF2: entity work.float_compose
    generic map (
      WIDTH => WIDTH,
      EXP_BITS => EXP_BITS,
      FRACT_BITS => FRACT_BITS
    )
    port map (
      i_props => s_f3_props,
      i_exponent => s_f3_exponent,
      i_significand => s_f3_significand,
      o_result => s_f3_next_result
    );

  o_f3_next_result <= s_f3_next_result when s_itof_result_ready else
                      s_ftoi_result;
  o_f3_next_result_ready <= s_itof_result_ready or s_ftoi_result_ready;


  --================================================================================================
  -- Four-cycle FPU operations.
  --================================================================================================

  --------------------------------------------------------------------------------------------------
  -- FADD
  --------------------------------------------------------------------------------------------------

  s_fadd_enable <= i_enable and s_is_add_op;
  s_fadd_subtract <= '1' when i_op = C_FPU_FSUB else '0';

  FADD: entity work.fadd
    generic map (
      WIDTH => WIDTH,
      EXP_BITS => EXP_BITS,
      EXP_BIAS => EXP_BIAS,
      FRACT_BITS => FRACT_BITS
    )
    port map (
      -- Control.
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => i_stall,
      i_enable => s_fadd_enable,
      i_subtract => s_fadd_subtract,

      -- Inputs (async).
      i_props_a => s_props_a,
      i_exponent_a => s_exponent_a,
      i_significand_a => s_significand_a,

      i_props_b => s_props_b,
      i_exponent_b => s_exponent_b,
      i_significand_b => s_significand_b,

      i_magn_a_lt_magn_b => s_compare_magn_lt,

      -- Outputs (async).
      o_props => s_fadd_props,
      o_exponent => s_fadd_exponent,
      o_significand => s_fadd_significand,
      o_result_ready => s_fadd_result_ready
    );

  --------------------------------------------------------------------------------------------------
  -- FMUL
  --------------------------------------------------------------------------------------------------

  s_fmul_enable <= i_enable and s_is_mul_op;

  FMUL: entity work.fmul
    generic map (
      WIDTH => WIDTH,
      EXP_BITS => EXP_BITS,
      EXP_BIAS => EXP_BIAS,
      FRACT_BITS => FRACT_BITS
    )
    port map (
      -- Control.
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => i_stall,
      i_enable => s_fmul_enable,

      -- Inputs (async).
      i_props_a => s_props_a,
      i_exponent_a => s_exponent_a,
      i_significand_a => s_significand_a,

      i_props_b => s_props_b,
      i_exponent_b => s_exponent_b,
      i_significand_b => s_significand_b,

      -- Outputs (async).
      o_props => s_fmul_props,
      o_exponent => s_fmul_exponent,
      o_significand => s_fmul_significand,
      o_result_ready => s_fmul_result_ready
    );


  --------------------------------------------------------------------------------------------------
  -- Compose the final result for four-cycle operations.
  --------------------------------------------------------------------------------------------------

  -- Select the decomposed results from the active unit.
  s_f4_props <= s_fadd_props when s_fadd_result_ready = '1' else
                s_fmul_props;
  s_f4_exponent <= s_fadd_exponent when s_fadd_result_ready = '1' else
                   s_fmul_exponent;
  s_f4_significand <= s_fadd_significand when s_fadd_result_ready = '1' else
                      s_fmul_significand;

  ComposeResultF4: entity work.float_compose
    generic map (
      WIDTH => WIDTH,
      EXP_BITS => EXP_BITS,
      FRACT_BITS => FRACT_BITS
    )
    port map (
      i_props => s_f4_props,
      i_exponent => s_f4_exponent,
      i_significand => s_f4_significand,
      o_result => o_f4_next_result
    );

  o_f4_next_result_ready <= s_fadd_result_ready or s_fmul_result_ready;
end rtl;
