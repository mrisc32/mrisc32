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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use work.config.all;

---------------------------------------------------------------------------------------------------
-- This implements the vector state logic.
--
-- The vector control logic is primarily a state machine that keeps track of:
--   * The source and target vector elements during any given cycle.
--   * Whether or not the upstream pipeline stages need to be stalled.
--   * Whether or not we should send a bubble down the pipeline (due to an empty vector opertaion).
--
-- This entity supports the following cases:
--   * Scalar instruction -> no vector operation.
--   * Vector instruction, length 1 to max VL.
--   * Vector instruction, length = 0 or length > max VL -> bubble.
--   * Stall requests from downstream pipeline stages.
---------------------------------------------------------------------------------------------------

entity vector_control is
  port (
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;
    i_cancel : in std_logic;

    i_is_vector_op : in std_logic;
    i_vl : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_fold : in std_logic;

    o_element_a : out std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
    o_element_b : out std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
    o_is_vector_op_busy : out std_logic;
    o_is_first_vector_op_cycle : out std_logic;
    o_bubble : out std_logic
  );
end vector_control;

architecture rtl of vector_control is
  -- State machine signal.
  type T_STATE is (START, BUSY, LAST);
	signal s_state : T_STATE;

	signal s_vl : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS downto 0);
	signal s_last_element : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS downto 0);
	signal s_is_first_element_of_many : std_logic;

	signal s_count : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS downto 0);
  signal s_count_plus_1 : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS downto 0);
  signal s_folded_index : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
  signal s_next_element_is_the_last : std_logic;

  constant C_VL_ZERO : std_logic_vector := to_vector(0, C_LOG2_VEC_REG_ELEMENTS+1);
  constant C_VL_ONE : std_logic_vector := to_vector(1, C_LOG2_VEC_REG_ELEMENTS+1);
  constant C_VL_TWO : std_logic_vector := to_vector(2, C_LOG2_VEC_REG_ELEMENTS+1);

  -- Debug signals (should be optimized away during synthesis).
  signal s_debug_state : std_logic_vector(1 downto 0);

  -- Sanitize the VL data. We support the range [0, C_VEC_REG_ELEMENTS]. Anything outside of that
  -- range is set to zero.
  function sanitize_vl(vl: std_logic_vector(C_WORD_SIZE-1 downto 0)) return std_logic_vector is
    variable v_result : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS downto 0);
  begin
    if unsigned(vl(C_WORD_SIZE-1 downto C_LOG2_VEC_REG_ELEMENTS+1)) /= 0 then
      v_result := C_VL_ZERO;
    elsif vl(C_LOG2_VEC_REG_ELEMENTS) = '1' and unsigned(vl(C_LOG2_VEC_REG_ELEMENTS-1 downto 0)) /= 0 then
      v_result := C_VL_ZERO;
    else
      v_result := vl(C_LOG2_VEC_REG_ELEMENTS downto 0);
    end if;
    return v_result;
  end function;
begin
  -- State machine.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_state <= START;
      s_count <= C_VL_ZERO;
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        if i_cancel = '1' then
          s_state <= START;
          s_count <= C_VL_ZERO;
        else
          case s_state is
            when START =>
              if i_is_vector_op = '0' then
                -- Scalar operation.
                s_count <= C_VL_ZERO;
              else
                -- Single cycle vector operation.
                if s_vl = C_VL_ZERO or s_vl = C_VL_ONE then
                  s_count <= C_VL_ZERO;
                else
                  s_count <= s_count_plus_1;
                  if s_vl = C_VL_TWO then
                    -- First vector operation of two.
                    s_state <= LAST;
                  else
                    -- First vector operation of many.
                    s_state <= BUSY;
                  end if;
                end if;
              end if;

            when BUSY =>
              -- Vector operation: at least one element left.
              s_count <= s_count_plus_1;
              if s_next_element_is_the_last = '1' then
                s_state <= LAST;
              end if;

            when LAST =>
              -- Vector operation: final element.
              s_count <= C_VL_ZERO;
              s_state <= START;

            when others =>
              s_state <= START;
          end case;
        end if;
      end if;
    end if;
  end process;

  -- Determine the vector length.
  s_vl <= sanitize_vl(i_vl);
  s_last_element <= std_logic_vector(unsigned(s_vl) - 1);

  -- Increment the count.
  s_count_plus_1 <= std_logic_vector(unsigned(s_count) + 1);
  s_next_element_is_the_last <= '1' when s_count_plus_1 = s_last_element else '0';

  -- Calculate the folded index for src B.
  s_folded_index <= std_logic_vector(
      unsigned(s_count(C_LOG2_VEC_REG_ELEMENTS-1 downto 0)) +
      unsigned(s_vl(C_LOG2_VEC_REG_ELEMENTS-1 downto 0))
      );

  -- Is this the first element in a multi-element vector loop?
  s_is_first_element_of_many <=
      '1' when
        s_state = START and
        i_is_vector_op = '1' and
        s_vl /= C_VL_ZERO and
        s_vl /= C_VL_ONE
      else '0';

  -- Outputs.
  o_element_a <= s_count(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
  o_element_b <= s_folded_index when i_fold = '1' else s_count(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);

  -- Should we stall the IF stage?
  o_is_vector_op_busy <= '1' when s_state = BUSY or s_is_first_element_of_many = '1' else '0';

  -- Should we bubble (i.e. we're doing a zero lenght vector operatoin)?
  o_bubble <= i_is_vector_op when s_vl = C_VL_ZERO else '0';

  -- Signal whether or not a vector operation was just started.
  o_is_first_vector_op_cycle <= '1' when s_state = START and i_is_vector_op = '1' else '0';

  -- Debug signals (should be optimized away during synthesis).
  DebugStateMux: with s_state select
    s_debug_state <=
      "01" when START,
      "10" when BUSY,
      "11" when LAST,
      (others => '0') when others;
end rtl;
