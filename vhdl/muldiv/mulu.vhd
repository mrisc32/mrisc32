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
-- Simple looping integer multiplier.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mulu is
  generic(
      WIDTH : positive := 32;
      COUNTER_BITS : positive := 5  -- Must be able to hold WIDTH-1
  );
  port(
      -- Control signals.
      i_clk : in std_logic;
      i_rst : in std_logic;

      -- Inputs.
      i_src_a : in std_logic_vector(WIDTH-1 downto 0);
      i_src_b : in std_logic_vector(WIDTH-1 downto 0);
      i_start_op : in std_logic;

      -- Outputs (sync).
      o_result : out std_logic_vector(2*WIDTH-1 downto 0);
      o_result_ready : out std_logic;

      -- Outputs (async).
      o_next_result : out std_logic_vector(2*WIDTH-1 downto 0);
      o_next_result_ready : out std_logic
    );
end mulu;

architecture rtl of mulu is
  -- Widened input argument.
  signal s_src_a_wide : std_logic_vector(2*WIDTH-1 downto 0);

  -- Internal synchronous state.
  signal s_sum : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_shifted_a : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_shifted_b : std_logic_vector(WIDTH-1 downto 0);
  signal s_counter : std_logic_vector(COUNTER_BITS-1 downto 0);

  signal s_a_mul_b0 : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_sum_plus_a_mul_b0 : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_a : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_b : std_logic_vector(WIDTH-1 downto 0);
  signal s_counter_minus_1 : std_logic_vector(COUNTER_BITS-1 downto 0);

  signal s_next_sum : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_next_shifted_a : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_next_shifted_b : std_logic_vector(WIDTH-1 downto 0);
  signal s_next_counter : std_logic_vector(COUNTER_BITS-1 downto 0);
  signal s_next_result_ready : std_logic;

  constant C_ONE : unsigned(0 downto 0) := "1";
  constant C_COUNTER_ZERO : std_logic_vector(COUNTER_BITS-1 downto 0) := (others => '0');
  constant C_COUNTER_START : std_logic_vector(COUNTER_BITS-1 downto 0) := std_logic_vector(to_unsigned(WIDTH-1, COUNTER_BITS));
begin
  -- Widen the input signal.
  s_src_a_wide(WIDTH-1 downto 0) <= i_src_a;
  s_src_a_wide(2*WIDTH-1 downto WIDTH) <= (others => '0');

  -- Select source operators for this pass.
  s_a <= s_shifted_a when i_start_op = '0' else s_src_a_wide;
  s_b <= s_shifted_b when i_start_op = '0' else i_src_b;

  -- Multiply a by lowest bit of b.
  s_a_mul_b0 <= s_a when s_b(0) = '1' else (others => '0');

  -- Update the sum.
  s_sum_plus_a_mul_b0 <= std_logic_vector(unsigned(s_sum) + unsigned(s_a_mul_b0));
  s_next_sum <= s_sum_plus_a_mul_b0 when i_start_op = '0' else s_a_mul_b0;

  -- Shift a to the left.
  s_next_shifted_a <= s_a(2*WIDTH-2 downto 0) & '0';

  -- Shift b to the right.
  s_next_shifted_b <= '0' & s_b(WIDTH-1 downto 1);

  -- Update the counter.
  s_counter_minus_1 <= std_logic_vector(unsigned(s_counter) - C_ONE);
  s_next_counter <= s_counter_minus_1 when i_start_op = '0' else C_COUNTER_START;

  -- Will the operation be finished after this cycle?
  s_next_result_ready <= '1' when s_next_counter = C_COUNTER_ZERO else '0';

  -- Asynchronous outputs.
  o_next_result <= s_next_sum;
  o_next_result_ready <= s_next_result_ready;

  -- Synchronous output.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_result <= (others => '0');
      o_result_ready <= '0';
    elsif rising_edge(i_clk) then
      o_result <= s_next_sum;
      o_result_ready <= s_next_result_ready;
    end if;
  end process;

  -- Internal synchronous state.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_sum <= (others => '0');
      s_shifted_a <= (others => '0');
      s_shifted_b <= (others => '0');
      s_counter <= (others => '1');
    elsif rising_edge(i_clk) then
      s_sum <= s_next_sum;
      s_shifted_a <= s_next_shifted_a;
      s_shifted_b <= s_next_shifted_b;
      s_counter <= s_next_counter;
    end if;
  end process;
end rtl;
