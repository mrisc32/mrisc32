----------------------------------------------------------------------------------------------------
-- Copyright (c) 2019 Marcus Geelnard
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
use work.types.all;
use work.config.all;

entity cpuid is
  port(
      i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_result : out std_logic_vector(C_WORD_SIZE-1 downto 0)
    );
end cpuid;

architecture rtl of cpuid is
begin
  process(i_src_a, i_src_b)
  begin
    if (i_src_a = to_word(0)) and (i_src_b = to_word(0)) then
      -- 00000000:00000000 => Max vector length
      o_result <= to_word(C_VEC_REG_ELEMENTS);
    elsif (i_src_a = to_word(0)) and (i_src_b = to_word(1)) then
      -- 00000000:00000001 => log2(Max vector length)
      o_result <= to_word(C_LOG2_VEC_REG_ELEMENTS);
    elsif (i_src_a = to_word(1)) and (i_src_b = to_word(0)) then
      -- 00000001:00000000 => CPU features
      o_result(0) <= to_std_logic(C_CPU_HAS_VEC);
      o_result(1) <= to_std_logic(C_CPU_HAS_PO);
      o_result(2) <= to_std_logic(C_CPU_HAS_MUL);
      o_result(3) <= to_std_logic(C_CPU_HAS_DIV);
      o_result(4) <= to_std_logic(C_CPU_HAS_SA);
      o_result(5) <= to_std_logic(C_CPU_HAS_FP);
      o_result(6) <= to_std_logic(C_CPU_HAS_SQRT);
      o_result(C_WORD_SIZE-1 downto 7) <= (others => '0');
    else
      -- All unsupported commands return zero.
      o_result <= (others => '0');
    end if;
  end process;
end rtl;
