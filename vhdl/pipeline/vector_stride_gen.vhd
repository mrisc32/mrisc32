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
use work.common.all;

---------------------------------------------------------------------------------------------------
-- This implements the vector memory address offset generation logic.
---------------------------------------------------------------------------------------------------

entity vector_stride_gen is
  port (
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;

    i_is_first_vector_op_cycle : in std_logic;
    i_stride : in std_logic_vector(C_WORD_SIZE-1 downto 0);

    o_offset : out std_logic_vector(C_WORD_SIZE-1 downto 0)
  );
end vector_stride_gen;

architecture rtl of vector_stride_gen is
  signal s_stride : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_offset : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_next_offset : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  -- State machine.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_offset <= (others => '0');
      s_stride <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        if i_is_first_vector_op_cycle = '1' then
          s_stride <= i_stride;
        end if;
        s_offset <= s_next_offset;
      end if;
    end if;
  end process;

  -- Calculate the next offset.
  s_next_offset <=
      i_stride when i_is_first_vector_op_cycle = '1' else
      std_logic_vector(unsigned(s_offset) + unsigned(s_stride));

  -- Outputs.
  o_offset <= (others => '0') when i_is_first_vector_op_cycle = '1' else s_offset;
end rtl;
