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
-- This is a two-cycle 32-bit multiplier for signed or unsigned integers.
--
-- It can easily be turned into a pipelined multiplier that can start one multiplication per cycle,
-- but right now it is blocking (since that is the expected behavior in the EX stage).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity mul32 is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;
    o_stall : out std_logic;

    -- Inputs.
    i_start_op : in std_logic;
    i_src_a : in std_logic_vector(31 downto 0);
    i_src_b : in std_logic_vector(31 downto 0);
    i_signed_op : in std_logic;

    -- Outputs (async).
    o_result : out std_logic_vector(63 downto 0);
    o_result_ready : out std_logic
  );
end mul32;

architecture rtl of mul32 is
  -- Widened input arguments.
  signal s_src_a_wide : std_logic_vector(32 downto 0);
  signal s_src_b_wide : std_logic_vector(32 downto 0);

  signal s_next_result : signed(65 downto 0);
  signal s_result : std_logic_vector(63 downto 0);

  signal s_next_result_ready : std_logic;
  signal s_result_ready : std_logic;
begin
  -- Widen the input signals (extend with a sign-bit for signed operations, or zero for unsigned
  -- operations).
  s_src_a_wide(31 downto 0) <= i_src_a;
  s_src_a_wide(32) <= i_src_a(31) and i_signed_op;
  s_src_b_wide(31 downto 0) <= i_src_b;
  s_src_b_wide(32) <= i_src_b(31) and i_signed_op;

  -- Perform the multiplication.
  s_next_result <= signed(s_src_a_wide) * signed(s_src_b_wide);
  s_next_result_ready <= i_start_op;

  -- Registers.
  -- NOTE: These registers ensure that we utilize hardened DSP blocks optimally in FPGAs. Also, they
  -- give us some extra headroom for operand forwarding.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_result <= (others => '0');
      s_result_ready <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_result <= std_logic_vector(s_next_result(63 downto 0));
        s_result_ready <= s_next_result_ready;
      end if;
    end if;
  end process;

  -- We stall the pipeline for one cycle after we have start the operation.
  o_stall <= i_start_op;

  -- Asynchronous outputs.
  o_result <= s_result;
  o_result_ready <= s_result_ready;
end rtl;
