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

entity mul is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;

    -- Inputs (async).
    i_enable : in std_logic;
    i_op : in T_MUL_OP;                                     -- Operation
    i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);  -- Source operand A
    i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);  -- Source operand B

    -- Outputs (async).
    o_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);  -- Result
    o_result_ready : out std_logic                            -- 1 when a result is produced
  );
end mul;

architecture rtl of mul is
  signal s_mul32_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_mul32_result_ready : std_logic;
begin
  -- 32-bit multiply pipeline
  MUL32_0: entity work.mul_impl
    generic map (
      WIDTH => 32
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => i_stall,
      i_enable => i_enable,
      i_op => i_op,
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      o_result => s_mul32_result,
      o_result_ready => s_mul32_result_ready
    );

  -- TODO(m): Add 16-bit and 8-bit multiplication units too.

  -- Select outputs.
  o_result <= s_mul32_result;
  o_result_ready <= s_mul32_result_ready;
end rtl;
