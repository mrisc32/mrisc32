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
use work.common.all;

entity muldiv is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;
    o_stall : out std_logic;

    -- Inputs.
    i_op : in T_MULDIV_OP;
    i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_start_op : in std_logic;

    -- Outputs (async).
    o_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_result_ready : out std_logic
  );
end muldiv;

architecture rtl of muldiv is
  -- Multiply signals.
  signal s_signed_mul : std_logic;
  signal s_mul_result : std_logic_vector(2*C_WORD_SIZE-1 downto 0);

  signal s_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  -- Instantiate a multiply unit.
  s_signed_mul <= '1' when i_op = OP_MULHI else '0';
  mul32_1: entity work.mul32
    port map (
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      i_signed_op => s_signed_mul,
      o_result => s_mul_result
    );

  MuldivMux: with i_op select
    s_result <=
      -- TODO(m): Support more ops.
      s_mul_result(C_WORD_SIZE-1 downto 0) when OP_MUL,
      s_mul_result(C_WORD_SIZE*2-1 downto C_WORD_SIZE) when OP_MULHIU | OP_MULHI,
      (others => '0') when others;

  -- Outputs.
  o_result <= s_result;
  o_result_ready <= '1';
  o_stall <= '0';
end rtl;

