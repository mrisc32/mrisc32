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
use work.config.all;

entity agu is
  port(
      i_clk : in std_logic;
      i_rst : in std_logic;
      i_stall : in std_logic;

      i_is_first_vector_op_cycle : in std_logic;
      i_address_offset_is_stride : in std_logic;
      i_base : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_offset : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_offset_shift : in std_logic_vector(1 downto 0);
      o_result : out std_logic_vector(C_WORD_SIZE-1 downto 0)
    );
end agu;
 
architecture rtl of agu is
  signal s_scaled_offset : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_stride_offset : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_offset : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  -- Scale the index offset.
  s_scaled_offset <= i_offset(C_WORD_SIZE-2 downto 0) & "0" when i_offset_shift = "01" else
                     i_offset(C_WORD_SIZE-3 downto 0) & "00" when i_offset_shift = "10" else
                     i_offset(C_WORD_SIZE-4 downto 0) & "000" when i_offset_shift = "11" else
                     i_offset;

  -- Stride generation (for certain vector memory addressing modes).
  vector_stride_gen_1: entity work.vector_stride_gen
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => i_stall,
      i_is_first_vector_op_cycle => i_is_first_vector_op_cycle,
      i_stride => s_scaled_offset,
      o_offset => s_stride_offset
    );

  -- Select which offset to use: constant offset or stride offset.
  s_offset <= s_stride_offset when i_address_offset_is_stride = '1' else s_scaled_offset;

  -- The resulting address is the base address plus the offset.
  o_result <= std_logic_vector(unsigned(i_base) + unsigned(s_offset));
end rtl;

