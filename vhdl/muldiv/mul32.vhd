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
-- This is a pipelined (two-stage) 32-bit multiplier for signed or unsigned integers.
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

    -- Inputs (async).
    i_enable : in std_logic;
    i_op : in T_MUL_OP;                                        -- Operation
    i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);     -- Source operand A
    i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);     -- Source operand B

    -- Outputs (async).
    o_result : out std_logic_vector(C_WORD_SIZE-1 downto 0) ;  -- Result
    o_result_ready : out std_logic                             -- 1 when a result is produced
  );
end mul32;

architecture rtl of mul32 is
  -- Decoded operation.
  signal s_signed_op : std_logic;
  signal s_next_return_high_bits : std_logic;
  signal s_return_high_bits : std_logic;

  -- Widened input arguments.
  signal s_src_a_wide : std_logic_vector(32 downto 0);
  signal s_src_b_wide : std_logic_vector(32 downto 0);

  signal s_next_result : signed(65 downto 0);
  signal s_result : std_logic_vector(63 downto 0);

  signal s_next_result_ready : std_logic;
begin
  -- Decode the multiplication operation.
  s_signed_op <= not i_op(0);
  s_next_return_high_bits <= i_op(1);

  -- Widen the input signals (extend with a sign-bit for signed operations, or zero for unsigned
  -- operations).
  s_src_a_wide(31 downto 0) <= i_src_a;
  s_src_a_wide(32) <= i_src_a(31) and s_signed_op;
  s_src_b_wide(31 downto 0) <= i_src_b;
  s_src_b_wide(32) <= i_src_b(31) and s_signed_op;

  -- Perform the multiplication.
  s_next_result <= signed(s_src_a_wide) * signed(s_src_b_wide);

  -- Registers.
  -- NOTE: These registers ensure that we utilize hardened DSP blocks optimally in FPGAs. Also, they
  -- give us some extra headroom for operand forwarding.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_result <= (others => '0');
      s_return_high_bits <= '0';
      o_result_ready <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_result <= std_logic_vector(s_next_result(63 downto 0));
        s_return_high_bits <= s_next_return_high_bits;
        o_result_ready <= i_enable;
      end if;
    end if;
  end process;

  -- Select high or low word for the result.
  o_result <= s_result(63 downto 32) when s_return_high_bits = '1' else s_result(31 downto 0);
end rtl;
