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
-- This is a multi-cycle multiplier for unsigned integers.
--
-- * The multiplication operation is (re)started when i_start_op is high.
-- * The oparands i_src_a and i_src_b are read (must be defined) when i_start_op is high.
-- * If at least one more cycle is required to complete the operation, o_stall is high.
-- * When the operation is done, o_result_ready is high during one cycle.
--
-- The looping implementation takes N+1 cycles to complete, where N is the position of the most
-- significant non-zero bit in i_src_b (N=0 if i_src_b is zero). Some examples are:
--
--                i_src_b             | Cycles
--  ----------------------------------+--------
--   00000000000000000000000000000000 |    1
--   00000000000000000000000000000001 |    1
--   00000000000000000000000000000011 |    2
--   00000000000000000000000011110011 |    8
--   10000000000000000000000000000000 |   32
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mulu is
  generic(
    WIDTH : positive := 32
  );
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;
    o_stall : out std_logic;

    -- Inputs.
    i_src_a : in std_logic_vector(WIDTH-1 downto 0);
    i_src_b : in std_logic_vector(WIDTH-1 downto 0);
    i_start_op : in std_logic;

    -- Outputs (async).
    o_result : out std_logic_vector(2*WIDTH-1 downto 0);
    o_result_ready : out std_logic
  );
end mulu;

architecture rtl of mulu is
  -- Widened input argument.
  signal s_src_a_wide : std_logic_vector(2*WIDTH-1 downto 0);

  -- Internal synchronous state.
  signal s_continue : std_logic;
  signal s_prev_result : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_shifted_a : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_shifted_b : std_logic_vector(WIDTH-1 downto 0);

  -- Intermediate results.
  signal s_busy : std_logic;
  signal s_a_mul_b0 : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_prev_result_plus_a_mul_b0 : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_a : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_b : std_logic_vector(WIDTH-1 downto 0);
  signal s_only_zeros_left : std_logic;

  -- Internal state produced during this cycle.
  signal s_next_continue : std_logic;
  signal s_result : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_next_shifted_a : std_logic_vector(2*WIDTH-1 downto 0);
  signal s_next_shifted_b : std_logic_vector(WIDTH-1 downto 0);
  signal s_result_ready : std_logic;

  -- Constants.
  constant C_B_ZERO : std_logic_vector(WIDTH-2 downto 0) := (others => '0');
begin
  -- Are we busy during this cycle?
  s_busy <= i_start_op or s_continue;

  -- Widen the input signal.
  s_src_a_wide(WIDTH-1 downto 0) <= i_src_a;
  s_src_a_wide(2*WIDTH-1 downto WIDTH) <= (others => '0');

  -- Select source operators for this pass.
  s_a <= s_shifted_a when i_start_op = '0' else s_src_a_wide;
  s_b <= s_shifted_b when i_start_op = '0' else i_src_b;

  -- Multiply a by lowest bit of b.
  s_a_mul_b0 <= s_a when s_b(0) = '1' else (others => '0');

  -- Update the result (may be intermediate or final).
  s_prev_result_plus_a_mul_b0 <= std_logic_vector(unsigned(s_prev_result) + unsigned(s_a_mul_b0));
  s_result <= s_prev_result_plus_a_mul_b0 when i_start_op = '0' else s_a_mul_b0;

  -- Shift a to the left.
  s_next_shifted_a <= s_a(2*WIDTH-2 downto 0) & '0';

  -- Shift b to the right.
  s_next_shifted_b <= '0' & s_b(WIDTH-1 downto 1);

  -- Will the operation be finished during this cycle?
  s_only_zeros_left <= '1' when s_b(WIDTH-1 downto 1) = C_B_ZERO else '0';
  s_result_ready <= s_busy and s_only_zeros_left;

  -- Should the loop continue during the next cycle?
  s_next_continue <= s_busy and (not s_only_zeros_left);

  -- Asynchronous outputs.
  o_stall <= s_busy and not s_result_ready;
  o_result <= s_result;
  o_result_ready <= s_result_ready;

  -- Internal synchronous state.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_continue <= '0';
      s_prev_result <= (others => '0');
      s_shifted_a <= (others => '0');
      s_shifted_b <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_continue <= s_next_continue;
        s_prev_result <= s_result;
        s_shifted_a <= s_next_shifted_a;
        s_shifted_b <= s_next_shifted_b;
      end if;
    end if;
  end process;
end rtl;
