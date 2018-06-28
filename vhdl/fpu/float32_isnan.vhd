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

entity float32_isnan is
  port(
      i_src : in  std_logic_vector(31 downto 0);
      o_is_nan : out std_logic
    );
end float32_isnan;

architecture rtl of float32_isnan is
  signal s_exponent_is_all_ones : std_logic;
  signal s_fraction_is_not_zero : std_logic;
begin
  -- The definition of an IEEE 754 NaN is:
  --  sign = either 0 or 1.
  --  biased exponent = all 1 bits.
  --  fraction = anything except all 0 bits.
  s_exponent_is_all_ones <= '1' when (i_src(30 downto 23) = 8X"FF") else '0';
  s_fraction_is_not_zero <= '1' when (i_src(22 downto 0) /= 23X"0") else '0';
  o_is_nan <= s_exponent_is_all_ones and s_fraction_is_not_zero;
end rtl;
