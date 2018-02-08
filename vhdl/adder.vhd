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

entity adder is
  generic(WIDTH : positive := 32);
  port(
      i_subtract : in  std_logic;
      i_src_a    : in  std_logic_vector(WIDTH-1 downto 0);
      i_src_b    : in  std_logic_vector(WIDTH-1 downto 0);
      o_result   : out std_logic_vector(WIDTH-1 downto 0);
      o_c_out    : out std_logic
    );
end adder;
 
architecture rtl of adder is
  signal s_xor_mask : std_logic_vector(WIDTH-1 downto 0);
  signal s_carry : unsigned(0 downto 0);
  signal s_result : unsigned(WIDTH downto 0);
begin
  s_xor_mask <= (others => i_subtract);
  s_carry(0) <= i_subtract;
  s_result <= resize(unsigned(i_src_a xor s_xor_mask), WIDTH+1) +
              resize(unsigned(i_src_b), WIDTH+1) +
              s_carry;
  o_result <= std_logic_vector(s_result(WIDTH-1 downto 0));
  o_c_out <= s_result(WIDTH);
end rtl;

