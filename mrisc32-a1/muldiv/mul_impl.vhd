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
-- This is a pipelined (two-stage) multiplier for signed or unsigned integers (including fixed
-- point).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity mul_impl is
  generic(
    WIDTH : positive := 32
  );
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;

    -- Inputs (async).
    i_enable : in std_logic;
    i_op : in T_MUL_OP;                                  -- Operation
    i_src_a : in std_logic_vector(WIDTH-1 downto 0);     -- Source operand A
    i_src_b : in std_logic_vector(WIDTH-1 downto 0);     -- Source operand B

    -- Outputs (async).
    o_result : out std_logic_vector(WIDTH-1 downto 0) ;  -- Result
    o_result_ready : out std_logic                       -- 1 when a result is produced
  );
end mul_impl;

architecture rtl of mul_impl is
  type T_RETURN_BITS is (Q_BITS, LO_BITS, HI_BITS);

  -- Decoded operation.
  signal s_signed_op : std_logic;
  signal s_next_return_bits : T_RETURN_BITS;
  signal s_return_bits : T_RETURN_BITS;

  -- Widened input arguments.
  signal s_src_a_wide : std_logic_vector(WIDTH downto 0);
  signal s_src_b_wide : std_logic_vector(WIDTH downto 0);

  signal s_next_result : signed(WIDTH*2+1 downto 0);
  signal s_result : std_logic_vector(WIDTH*2-1 downto 0);

  signal s_next_result_ready : std_logic;
begin
  -- Decode the multiplication operation.
  s_signed_op <= not i_op(0);

  ReturnBitsMux: with i_op select
    s_next_return_bits <=
      Q_BITS when C_MUL_MULQ,
      LO_BITS when C_MUL_MUL,
      HI_BITS when others;

  -- Widen the input signals (extend with a sign-bit for signed operations, or zero for unsigned
  -- operations).
  s_src_a_wide <= (i_src_a(WIDTH-1) and s_signed_op) & i_src_a;
  s_src_b_wide <= (i_src_b(WIDTH-1) and s_signed_op) & i_src_b;

  -- Perform the multiplication.
  s_next_result <= signed(s_src_a_wide) * signed(s_src_b_wide);

  -- Registers.
  -- NOTE: These registers ensure that we utilize hardened DSP blocks optimally in FPGAs. Also, they
  -- give us some extra headroom for operand forwarding.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_result <= (others => '0');
      s_return_bits <= LO_BITS;
      o_result_ready <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_result <= std_logic_vector(s_next_result(WIDTH*2-1 downto 0));
        s_return_bits <= s_next_return_bits;
        o_result_ready <= i_enable;
      end if;
    end if;
  end process;

  -- Select which bits of the result to return.
  ResultMux: with s_return_bits select
    o_result <=
      s_result(WIDTH*2-2 downto WIDTH-1) when Q_BITS,
      s_result(WIDTH-1 downto 0) when LO_BITS,
      s_result(WIDTH*2-1 downto WIDTH) when HI_BITS,
      (others => '-') when others;
end rtl;
