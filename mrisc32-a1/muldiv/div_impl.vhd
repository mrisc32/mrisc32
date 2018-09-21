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
-- This is a looping divider for signed or unsigned integers.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity div_impl is
  generic(
    WIDTH : positive;
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

    -- Outputs (async).
    o_next_result : out std_logic_vector(WIDTH-1 downto 0);
    o_next_result_ready : out std_logic
  );
end div_impl;

architecture rtl of div_impl is
  constant NUM_STEPS : integer := WIDTH;

  type T_DIV_STATE is record
    n : std_logic_vector(WIDTH-1 downto 0);
    d : std_logic_vector(WIDTH-1 downto 0);
    q : std_logic_vector(WIDTH-1 downto 0);
    r : std_logic_vector(WIDTH-1 downto 0);
  end record;

  type T_DIV_STATE_ARRAY is array (0 to STEPS_PER_CYCLE) of T_DIV_STATE;

  -- D1 signals.
  signal s_is_unsigned_op : std_logic;
  signal s_src_a_is_neg : std_logic;
  signal s_src_b_is_neg : std_logic;

  signal s_d1_next_state : T_DIV_STATE;
  signal s_d1_next_op : T_DIV_OP;
  signal s_d1_next_negate_q : std_logic;
  signal s_d1_next_negate_r : std_logic;
  signal s_d1_next_enable : std_logic;

  signal s_d1_state : T_DIV_STATE;
  signal s_d1_op : T_DIV_OP;
  signal s_d1_negate_q : std_logic;
  signal s_d1_negate_r : std_logic;
  signal s_d1_enable : std_logic;

  -- D2 signals.
  signal s_is_first_iteration : std_logic;
  signal s_prev_is_loop_busy : std_logic;
  signal s_is_loop_busy : std_logic;
  signal s_loop_state : T_DIV_STATE_ARRAY;

  signal s_d2_next_op : T_DIV_OP;
  signal s_d2_next_negate_q : std_logic;
  signal s_d2_next_negate_r : std_logic;
  signal s_d2_next_iteration : unsigned(CNT_BITS-1 downto 0);
  signal s_d2_next_done : std_logic;

  signal s_d2_iteration : unsigned(CNT_BITS-1 downto 0);
  signal s_d2_state : T_DIV_STATE;
  signal s_d2_op : T_DIV_OP;
  signal s_d2_negate_q : std_logic;
  signal s_d2_negate_r : std_logic;
  signal s_d2_done : std_logic;

  -- D3 signals.
  signal s_q : std_logic_vector(WIDTH-1 downto 0);
  signal s_r : std_logic_vector(WIDTH-1 downto 0);

  signal s_next_result : std_logic_vector(WIDTH-1 downto 0);
  signal s_next_result_ready : std_logic;
  signal s_result : std_logic_vector(WIDTH-1 downto 0);
  signal s_result_ready : std_logic;

  function conditional_negate(x: std_logic_vector; neg: std_logic) return std_logic_vector is
    variable mask : std_logic_vector(x'range);
    variable carry : unsigned(x'range);
  begin
    mask := (others => neg);
    carry := (0 => neg, others => '0');
    return std_logic_vector(unsigned(x xor mask) + carry);
  end function;
begin
  --------------------------------------------------------------------------------------------------
  -- D1 - Pipeline stage 1
  -- Decode and prepare the operation.
  --------------------------------------------------------------------------------------------------

  -- Handle sign.
  s_is_unsigned_op <= i_op(0);
  s_src_a_is_neg <= i_src_a(WIDTH-1) and not s_is_unsigned_op;
  s_src_b_is_neg <= i_src_b(WIDTH-1) and not s_is_unsigned_op;

  -- Prepare the state for the first iteration.
  s_d1_next_state.n <= conditional_negate(i_src_a, s_src_a_is_neg);
  s_d1_next_state.d <= conditional_negate(i_src_b, s_src_b_is_neg);
  s_d1_next_state.q <= (others => '0');
  s_d1_next_state.r <= (others => '0');
  s_d1_next_op <= i_op;
  s_d1_next_negate_q <= s_src_a_is_neg xor s_src_b_is_neg;
  s_d1_next_negate_r <= s_src_a_is_neg;

  -- Start a new operation?
  s_d1_next_enable <= i_enable and not s_is_loop_busy;

  -- Signals from D1 to D2.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_d1_state.n <= (others => '0');
      s_d1_state.d <= (others => '0');
      s_d1_state.q <= (others => '0');
      s_d1_state.r <= (others => '0');
      s_d1_op <= (others => '0');
      s_d1_negate_q <= '0';
      s_d1_negate_r <= '0';
      s_d1_enable <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_d1_state <= s_d1_next_state;
        s_d1_op <= s_d1_next_op;
        s_d1_negate_q <= s_d1_next_negate_q;
        s_d1_negate_r <= s_d1_next_negate_r;
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
  s_d2_next_iteration <= to_unsigned((WIDTH/STEPS_PER_CYCLE)-1, CNT_BITS) when s_is_first_iteration = '1' else
                         s_d2_iteration - 1;

  s_d2_next_done <= s_prev_is_loop_busy when s_d2_iteration = to_unsigned(1, CNT_BITS) else '0';

  s_is_loop_busy <= '1' when s_is_first_iteration = '1' else
                    '0' when s_d2_next_done = '1' else
                    s_prev_is_loop_busy;

  -- Two divider stage.
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
  s_d2_next_op <= s_d1_op when s_is_first_iteration = '1' else s_d2_op;
  s_d2_next_negate_q <= s_d1_negate_q when s_is_first_iteration = '1' else s_d2_negate_q;
  s_d2_next_negate_r <= s_d1_negate_r when s_is_first_iteration = '1' else s_d2_negate_r;

  -- Signals from D2 to D3.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
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
        s_d2_state <= s_loop_state(STEPS_PER_CYCLE);
        s_d2_op <= s_d2_next_op;
        s_d2_negate_q <= s_d2_next_negate_q;
        s_d2_negate_r <= s_d2_next_negate_r;
        s_d2_iteration <= s_d2_next_iteration;
        s_d2_done <= s_d2_next_done;
        s_prev_is_loop_busy <= s_is_loop_busy;
      end if;
    end if;
  end process;


  --------------------------------------------------------------------------------------------------
  -- D3 - Pipeline stage 3
  -- Finalize the result.
  --------------------------------------------------------------------------------------------------

  -- Handle sign.
  s_q <= conditional_negate(s_d2_state.q, s_d2_negate_q);
  s_r <= conditional_negate(s_d2_state.r, s_d2_negate_r);

  -- Prepare the output signals.
  ResultMux: with s_d2_op select
  s_next_result <=
    s_q when C_DIV_DIV | C_DIV_DIVU,
    s_r when C_DIV_REM | C_DIV_REMU,
    (others => '-') when others;

  s_next_result_ready <= s_d2_done;

  -- Latch the result from D2.
  -- The result from D2 is only valid during one cycle, but we need to repeat it for
  -- multiple cycles if o_stall (i.e. s_is_loop_busy) is high.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_result <= (others => '0');
      s_result_ready <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        if s_d2_done = '1' then
          s_result <= s_next_result;
          s_result_ready <= s_is_loop_busy;
        elsif s_is_loop_busy = '0' then
          s_result_ready <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Outputs (select newly produced or old latched result).
  o_next_result <= s_next_result when s_d2_done = '1' else s_result;
  o_next_result_ready <= s_next_result_ready when s_d2_done = '1' else s_result_ready;

  -- Do we need to stall the outside world?
  o_stall <= s_is_loop_busy;
end rtl;

