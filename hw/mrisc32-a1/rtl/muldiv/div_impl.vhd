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
-- This is a looping divider for signed and unsigned integers, as well as floating point numbers.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity div_impl is
  generic(
    WIDTH : positive := 32;
    EXP_BITS : positive := 8;
    EXP_BIAS : positive := 127;
    FRACT_BITS : positive := 23;
    CNT_BITS : positive;
    STEPS_PER_CYCLE : positive := 1
  );
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;
    o_stall : out std_logic;

    -- Inputs (async).
    i_enable : in std_logic;
    i_op : in T_DIV_OP;                                  -- Operation
    i_src_a : in std_logic_vector(WIDTH-1 downto 0);     -- Source operand A
    i_src_b : in std_logic_vector(WIDTH-1 downto 0);     -- Source operand B

    -- D4 outputs (async).
    o_d3_next_result : out std_logic_vector(WIDTH-1 downto 0);
    o_d3_next_result_ready : out std_logic;

    -- D4 outputs (async).
    o_d4_next_result : out std_logic_vector(WIDTH-1 downto 0);
    o_d4_next_result_ready : out std_logic
  );
end div_impl;

architecture rtl of div_impl is
  -- Constants.
  constant SIGNIFICAND_BITS : positive := FRACT_BITS + 1;

  -- Number of extra division steps that are carried out during floating point division
  -- due to SIGNIFICAND_BITS + 2 not being a multiple of STEPS_PER_CYCLE.
  constant EXTRA_FLOAT_DIV_STEPS : integer := (STEPS_PER_CYCLE - ((SIGNIFICAND_BITS + 2) mod STEPS_PER_CYCLE)) mod STEPS_PER_CYCLE;

  type T_DIV_STATE is record
    n : std_logic_vector(WIDTH-1 downto 0);
    d : std_logic_vector(WIDTH-1 downto 0);
    q : std_logic_vector(WIDTH-1 downto 0);
    r : std_logic_vector(WIDTH-1 downto 0);
  end record;

  type T_DIV_STATE_ARRAY is array (0 to STEPS_PER_CYCLE) of T_DIV_STATE;

  -- D1 signals.
  signal s_is_unsigned_op : std_logic;
  signal s_is_division_by_zero : std_logic;
  signal s_src_a_is_neg : std_logic;
  signal s_src_b_is_neg : std_logic;

  signal s_props_a : T_FLOAT_PROPS;
  signal s_exponent_a : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_significand_a : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);

  signal s_props_b : T_FLOAT_PROPS;
  signal s_exponent_b : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_significand_b : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);

  signal s_d1_next_is_fdiv : std_logic;
  signal s_d1_next_state_int : T_DIV_STATE;
  signal s_d1_next_state_float : T_DIV_STATE;
  signal s_d1_next_state : T_DIV_STATE;
  signal s_d1_next_op : T_DIV_OP;
  signal s_d1_next_negate_q : std_logic;
  signal s_d1_next_negate_r : std_logic;
  signal s_d1_next_enable : std_logic;
  signal s_d1_next_props : T_FLOAT_PROPS;
  signal s_d1_next_exponent : std_logic_vector(EXP_BITS+1 downto 0);

  signal s_d1_is_fdiv : std_logic;
  signal s_d1_state : T_DIV_STATE;
  signal s_d1_op : T_DIV_OP;
  signal s_d1_negate_q : std_logic;
  signal s_d1_negate_r : std_logic;
  signal s_d1_enable : std_logic;
  signal s_d1_props : T_FLOAT_PROPS;
  signal s_d1_exponent : std_logic_vector(EXP_BITS+1 downto 0);

  -- D2 signals.
  signal s_is_first_iteration : std_logic;
  signal s_prev_is_loop_busy : std_logic;
  signal s_is_loop_busy : std_logic;
  signal s_loop_state : T_DIV_STATE_ARRAY;

  signal s_d2_next_is_fdiv : std_logic;
  signal s_d2_next_op : T_DIV_OP;
  signal s_d2_next_negate_q : std_logic;
  signal s_d2_next_negate_r : std_logic;
  signal s_d2_next_props : T_FLOAT_PROPS;
  signal s_d2_next_exponent : std_logic_vector(EXP_BITS+1 downto 0);
  signal s_d2_next_iteration : unsigned(CNT_BITS-1 downto 0);
  signal s_d2_next_done : std_logic;

  signal s_d2_iteration : unsigned(CNT_BITS-1 downto 0);
  signal s_d2_is_fdiv : std_logic;
  signal s_d2_state : T_DIV_STATE;
  signal s_d2_op : T_DIV_OP;
  signal s_d2_negate_q : std_logic;
  signal s_d2_negate_r : std_logic;
  signal s_d2_props : T_FLOAT_PROPS;
  signal s_d2_exponent : std_logic_vector(EXP_BITS+1 downto 0);
  signal s_d2_done : std_logic;

  -- D3 signals.
  signal s_q : std_logic_vector(WIDTH-1 downto 0);
  signal s_r : std_logic_vector(WIDTH-1 downto 0);

  signal s_d3_next_result : std_logic_vector(WIDTH-1 downto 0);
  signal s_d3_next_integer_result_done : std_logic;
  signal s_d3_result : std_logic_vector(WIDTH-1 downto 0);
  signal s_d3_result_ready : std_logic;

  signal s_d3_quotient : unsigned(SIGNIFICAND_BITS+1 downto 0);
  signal s_d3_round_offset : unsigned(1 downto 0);
  signal s_d3_next_quotient_rounded : unsigned(SIGNIFICAND_BITS+1 downto 0);
  signal s_d3_next_do_adjust : std_logic;
  signal s_d3_props : T_FLOAT_PROPS;
  signal s_d3_exponent : std_logic_vector(EXP_BITS+1 downto 0);
  signal s_d3_quotient_rounded : unsigned(SIGNIFICAND_BITS+1 downto 0);
  signal s_d3_do_adjust : std_logic;
  signal s_d3_next_float_result_done : std_logic;
  signal s_d3_float_done : std_logic;

  -- D4 signals.
  signal s_d4_significand : std_logic_vector(SIGNIFICAND_BITS-1 downto 0);
  signal s_d4_exponent_minus_1 : unsigned(EXP_BITS+1 downto 0);
  signal s_d4_exponent_adjusted : unsigned(EXP_BITS+1 downto 0);
  signal s_d4_overflow : std_logic;
  signal s_d4_underflow : std_logic;
  signal s_d4_props : T_FLOAT_PROPS;
  signal s_d4_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_d4_next_result : std_logic_vector(WIDTH-1 downto 0);
  signal s_d4_next_result_ready : std_logic;

  function conditional_negate(x: std_logic_vector; neg: std_logic) return std_logic_vector is
    variable mask : std_logic_vector(x'range);
    variable carry : unsigned(x'range);
  begin
    mask := (others => neg);
    carry := (0 => neg, others => '0');
    return std_logic_vector(unsigned(x xor mask) + carry);
  end function;

  function float_to_width(x: std_logic_vector) return std_logic_vector is
  begin
    return to_vector(0, WIDTH - SIGNIFICAND_BITS) & x;
  end function;

  function loop_count(is_float: std_logic) return unsigned is
    variable v_num_bits : positive;
  begin
    if is_float = '1' then
      v_num_bits := SIGNIFICAND_BITS + 2;
    else
      v_num_bits := WIDTH;
    end if;
    -- Note: We round up.
    return to_unsigned(((v_num_bits+STEPS_PER_CYCLE-1)/STEPS_PER_CYCLE)-1, CNT_BITS);
  end function;
begin
  --------------------------------------------------------------------------------------------------
  -- D1 - Pipeline stage 1
  -- Decode and prepare the operation.
  --------------------------------------------------------------------------------------------------

  --------------------------------------------------------------------------------------------------
  -- Integer preparation.
  --------------------------------------------------------------------------------------------------

  -- Handle sign.
  s_is_unsigned_op <= i_op(0);
  s_is_division_by_zero <= is_zero(i_src_b);
  s_src_a_is_neg <= i_src_a(WIDTH-1) and not s_is_unsigned_op;
  s_src_b_is_neg <= i_src_b(WIDTH-1) and not s_is_unsigned_op;

  s_d1_next_negate_q <= (s_src_a_is_neg xor s_src_b_is_neg) and not s_is_division_by_zero;
  s_d1_next_negate_r <= s_src_a_is_neg;

  -- Initial conditions.
  s_d1_next_state_int.n <= conditional_negate(i_src_a, s_src_a_is_neg);
  s_d1_next_state_int.d <= conditional_negate(i_src_b, s_src_b_is_neg);
  s_d1_next_state_int.q <= (others => '0');
  s_d1_next_state_int.r <= (others => '0');

  --------------------------------------------------------------------------------------------------
  -- Floating point preparation.
  --------------------------------------------------------------------------------------------------

  -- Decompose the floating point numbers.
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

  -- Determine the preliminary properties of the result (may be adjusted by final rounding).
  s_d1_next_props.is_neg <= s_props_a.is_neg xor s_props_b.is_neg;
  s_d1_next_props.is_nan <= s_props_a.is_nan or
                            s_props_b.is_nan or
                            (s_props_a.is_zero and s_props_b.is_zero) or
                            (s_props_a.is_inf and s_props_b.is_inf);
  s_d1_next_props.is_inf <= s_props_a.is_inf or s_props_b.is_zero;
  s_d1_next_props.is_zero <= s_props_a.is_zero;

  -- Calculate the preliminary exponent of the result (may be adjusted by final rounding).
  -- Note: We add two bits to accomodate for both overflow and underflow.
  s_d1_next_exponent <= std_logic_vector(unsigned("00" & s_exponent_a) -
                                         unsigned("00" & s_exponent_b) +
                                         EXP_BIAS);

  -- Initial conditions.
  -- Here we simulate a WIDTH+SIGNIFICAND_BITS division by skipping the first WIDTH-1 steps of the
  -- long division. Why? The first iterations always produce zeros since the two significands
  -- (D and N) have their most significand bits set. Thus:
  --   N = Nin << (WIDTH - 1)
  --   D = Din
  --   Q = 0
  --   R = Nin >> 1
  s_d1_next_state_float.n <= s_significand_a(0) & to_vector(0, WIDTH-1);
  s_d1_next_state_float.d <= float_to_width(s_significand_b);
  s_d1_next_state_float.q <= (others => '0');
  s_d1_next_state_float.r <= to_vector(0, WIDTH-SIGNIFICAND_BITS+1) & s_significand_a(SIGNIFICAND_BITS-1 downto 1);


  --------------------------------------------------------------------------------------------------
  -- Common (int and float).
  --------------------------------------------------------------------------------------------------

  -- Start a new operation?
  s_d1_next_enable <= i_enable and not s_is_loop_busy;

  -- Floating point or integer operation?
  s_d1_next_is_fdiv <= '0' when (i_op = C_DIV_DIV or
                                 i_op = C_DIV_DIVU or
                                 i_op = C_DIV_REM or
                                 i_op = C_DIV_REMU) else
                       '1';

  -- Prepare the state for the first iteration.
  s_d1_next_state <= s_d1_next_state_float when s_d1_next_is_fdiv = '1' else s_d1_next_state_int;
  s_d1_next_op <= i_op;

  -- Signals from D1 to D2.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_d1_is_fdiv <= '0';
      s_d1_state.n <= (others => '0');
      s_d1_state.d <= (others => '0');
      s_d1_state.q <= (others => '0');
      s_d1_state.r <= (others => '0');
      s_d1_op <= (others => '0');
      s_d1_negate_q <= '0';
      s_d1_negate_r <= '0';
      s_d1_props <= ('0', '0', '0', '0');
      s_d1_exponent <= (others => '0');
      s_d1_enable <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_d1_is_fdiv <= s_d1_next_is_fdiv;
        s_d1_state <= s_d1_next_state;
        s_d1_op <= s_d1_next_op;
        s_d1_negate_q <= s_d1_next_negate_q;
        s_d1_negate_r <= s_d1_next_negate_r;
        s_d1_props <= s_d1_next_props;
        s_d1_exponent <= s_d1_next_exponent;
        s_d1_enable <= s_d1_next_enable;
      end if;
    end if;
  end process;


  --------------------------------------------------------------------------------------------------
  -- D2 - Pipeline stage 2
  -- Blocking loop until done.
  --------------------------------------------------------------------------------------------------

  s_is_first_iteration <= s_d1_enable;

  -- Select the first iteration state (d1) or the looping iteration state (d2).
  s_loop_state(0) <= s_d1_state when s_is_first_iteration = '1' else s_d2_state;

  -- Iteration counter.
  -- TODO(m): This is most likely broken for 16-bit floating point (since it has an odd number of
  -- significand bits).
  s_d2_next_iteration <= loop_count(s_d1_is_fdiv) when s_is_first_iteration = '1' else
                         s_d2_iteration - 1;

  s_d2_next_done <= s_prev_is_loop_busy when s_d2_iteration = to_unsigned(1, CNT_BITS) else '0';

  s_is_loop_busy <= '1' when s_is_first_iteration = '1' else
                    '0' when s_d2_next_done = '1' else
                    s_prev_is_loop_busy;

  -- N divider stages per iteration.
  DivStagesGen: for k in 0 to STEPS_PER_CYCLE-1 generate
  begin
    div_stage_x: entity work.div_stage
      generic map (
        WIDTH => WIDTH
      )
      port map (
        i_n => s_loop_state(k).n,
        i_d => s_loop_state(k).d,
        i_q => s_loop_state(k).q,
        i_r => s_loop_state(k).r,
        o_n => s_loop_state(k+1).n,
        o_d => s_loop_state(k+1).d,
        o_q => s_loop_state(k+1).q,
        o_r => s_loop_state(k+1).r
      );
  end generate;

  -- Propagate operation definition.
  s_d2_next_is_fdiv <= s_d1_is_fdiv when s_is_first_iteration = '1' else s_d2_is_fdiv;
  s_d2_next_op <= s_d1_op when s_is_first_iteration = '1' else s_d2_op;
  s_d2_next_negate_q <= s_d1_negate_q when s_is_first_iteration = '1' else s_d2_negate_q;
  s_d2_next_negate_r <= s_d1_negate_r when s_is_first_iteration = '1' else s_d2_negate_r;
  s_d2_next_props <= s_d1_props when s_is_first_iteration = '1' else s_d2_props;
  s_d2_next_exponent <= s_d1_exponent when s_is_first_iteration = '1' else s_d2_exponent;

  -- Signals from D2 to D3.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_d2_is_fdiv <= '0';
      s_d2_state.n <= (others => '0');
      s_d2_state.d <= (others => '0');
      s_d2_state.q <= (others => '0');
      s_d2_state.r <= (others => '0');
      s_d2_op <= (others => '0');
      s_d2_negate_q <= '0';
      s_d2_negate_r <= '0';
      s_d2_iteration <= (others => '1');
      s_d2_done <= '0';
      s_prev_is_loop_busy <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_d2_is_fdiv <= s_d2_next_is_fdiv;
        s_d2_state <= s_loop_state(STEPS_PER_CYCLE);
        s_d2_op <= s_d2_next_op;
        s_d2_negate_q <= s_d2_next_negate_q;
        s_d2_negate_r <= s_d2_next_negate_r;
        s_d2_props <= s_d2_next_props;
        s_d2_exponent <= s_d2_next_exponent;
        s_d2_iteration <= s_d2_next_iteration;
        s_d2_done <= s_d2_next_done;
        s_prev_is_loop_busy <= s_is_loop_busy;
      end if;
    end if;
  end process;


  --------------------------------------------------------------------------------------------------
  -- D3 - Pipeline stage 3
  --------------------------------------------------------------------------------------------------

  --------------------------------------------------------------------------------------------------
  -- Integer: Finalize the result and return it.
  --------------------------------------------------------------------------------------------------

  -- Handle sign.
  s_q <= conditional_negate(s_d2_state.q, s_d2_negate_q);
  s_r <= conditional_negate(s_d2_state.r, s_d2_negate_r);

  -- Prepare the output signals.
  ResultMux: with s_d2_op select
  s_d3_next_result <=
    s_q when C_DIV_DIV | C_DIV_DIVU,
    s_r when C_DIV_REM | C_DIV_REMU,
    (others => '-') when others;

  s_d3_next_integer_result_done <= s_d2_done and not s_d2_is_fdiv;

  -- Latch integer results.
  -- The result from D2 is only valid during one cycle, but we need to repeat it for
  -- multiple cycles if o_stall (i.e. s_is_loop_busy) is high.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_d3_result <= (others => '0');
      s_d3_result_ready <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        if s_d3_next_integer_result_done = '1' then
          s_d3_result <= s_d3_next_result;
          s_d3_result_ready <= s_is_loop_busy;
        elsif s_is_loop_busy = '0' then
          s_d3_result_ready <= '0';
        end if;
      end if;
    end if;
  end process;

  -- D3 outputs (select newly produced or old latched result).
  o_d3_next_result <= s_d3_next_result when s_d2_done = '1' else s_d3_result;
  o_d3_next_result_ready <= s_d3_next_integer_result_done when s_d2_done = '1' else s_d3_result_ready;


  --------------------------------------------------------------------------------------------------
  -- Floating point: We're not really done yet.
  --------------------------------------------------------------------------------------------------

  -- 1a) Extract the quotient significand from the D2 output.
  s_d3_quotient <= unsigned(s_d2_state.q(SIGNIFICAND_BITS+1+EXTRA_FLOAT_DIV_STEPS downto EXTRA_FLOAT_DIV_STEPS));

  -- 1b) Perform rounding.
  s_d3_round_offset <= s_d3_quotient(SIGNIFICAND_BITS+1) & not s_d3_quotient(SIGNIFICAND_BITS+1);
  s_d3_next_quotient_rounded <= s_d3_quotient + resize(s_d3_round_offset, SIGNIFICAND_BITS+2);

  -- 2) Is exponent adjustment needed?
  s_d3_next_do_adjust <= s_d3_next_quotient_rounded(SIGNIFICAND_BITS+1);

  s_d3_next_float_result_done <= s_d2_done and s_d2_is_fdiv;

  -- Float results from D3 to D4.
  -- Note: We repeat the result if o_stall (i.e. s_is_loop_busy) is high.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_d3_props <= ('0', '0', '0', '0');
      s_d3_exponent <= (others => '0');
      s_d3_quotient_rounded <= (others => '0');
      s_d3_do_adjust <= '0';
      s_d3_float_done <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        if s_d3_next_float_result_done = '1' then
          s_d3_props <= s_d2_props;
          s_d3_exponent <= s_d2_exponent;
          s_d3_quotient_rounded <= s_d3_next_quotient_rounded;
          s_d3_do_adjust <= s_d3_next_do_adjust;
          s_d3_float_done <= s_d3_next_float_result_done;
        elsif s_prev_is_loop_busy = '0' then
          s_d3_float_done <= '0';
        end if;
      end if;
    end if;
  end process;


  --------------------------------------------------------------------------------------------------
  -- D4 - Pipeline stage 4 (final floating point stage)
  --------------------------------------------------------------------------------------------------

  -- 1a) Normalize (shift) the significand.
  s_d4_significand <=
      std_logic_vector(s_d3_quotient_rounded(SIGNIFICAND_BITS+1 downto 2)) when s_d3_do_adjust = '1' else
      std_logic_vector(s_d3_quotient_rounded(SIGNIFICAND_BITS downto 1));

  -- 1b) Adjust the exponent.
  s_d4_exponent_minus_1 <= unsigned(s_d3_exponent) - to_unsigned(1, 1);
  s_d4_exponent_adjusted <= unsigned(s_d3_exponent) when s_d3_do_adjust = '1' else
                            s_d4_exponent_minus_1;

  -- 2) Check for overflow/underflow.
  s_d4_overflow <= '1' when s_d4_exponent_adjusted(EXP_BITS+1 downto EXP_BITS) = "01" or
                            s_d4_exponent_adjusted(EXP_BITS+1 downto 0) = "00" & (EXP_BITS-1 downto 0 => '1')
                   else '0';
  s_d4_underflow <= '1' when s_d4_exponent_adjusted(EXP_BITS+1) = '1' or
                             s_d4_exponent_adjusted(EXP_BITS+1 downto 0) = (EXP_BITS+1 downto 0 => '0')
                    else '0';

  -- Determine the final float properties.
  s_d4_props.is_neg <= s_d3_props.is_neg;
  s_d4_props.is_nan <= s_d3_props.is_nan;
  s_d4_props.is_inf <= (s_d3_props.is_inf or s_d4_overflow) and not s_d3_props.is_nan;
  s_d4_props.is_zero <= (s_d3_props.is_zero or s_d4_underflow) and not s_d3_props.is_nan;

  -- Extract the final exponent.
  s_d4_exponent <= std_logic_vector(s_d4_exponent_adjusted(EXP_BITS-1 downto 0));

  -- Compose the final result.
  ComposeResult: entity work.float_compose
    generic map (
      WIDTH => WIDTH,
      EXP_BITS => EXP_BITS,
      FRACT_BITS => FRACT_BITS
    )
    port map (
      i_props => s_d4_props,
      i_exponent => s_d4_exponent,
      i_significand => s_d4_significand,
      o_result => s_d4_next_result
    );

  -- Is the result ready?
  s_d4_next_result_ready <= s_d3_float_done;

  -- D4 outputs.
  o_d4_next_result <= s_d4_next_result;
  o_d4_next_result_ready <= s_d4_next_result_ready;


  --------------------------------------------------------------------------------------------------
  -- Stall logic
  --------------------------------------------------------------------------------------------------

  -- Do we need to stall the outside world?
  o_stall <= s_is_loop_busy;

end rtl;

