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
use work.types.all;

----------------------------------------------------------------------------------------------------
-- This entity decomposes an IEEE 754 binary floating point number into its components, and reports
-- various properties (such as NaN and infinity).
--
-- IEEE 754 compatibility:
--  - The sign, exponent and significand components are extracted.
--  - NaN is correctly identified.
--  - +/- infinity is correctly identified.
--  - +/- zero is correctly identified.
--
-- Incompatibilities/simplifications:
--  - Denormals are always reported as zero.
----------------------------------------------------------------------------------------------------

entity float_decompose is
  generic(
      WIDTH : positive := 32;
      EXP_BITS : positive := 8;
      FRACT_BITS : positive := 23
    );
  port(
      i_src : in std_logic_vector(WIDTH-1 downto 0);

      o_props : out T_FLOAT_PROPS;
      o_exponent : out std_logic_vector(EXP_BITS-1 downto 0);
      o_significand : out std_logic_vector(FRACT_BITS downto 0)
    );
end float_decompose;

architecture rtl of float_decompose is
  signal s_exponent : std_logic_vector(EXP_BITS-1 downto 0);
  signal s_fraction : std_logic_vector(FRACT_BITS-1 downto 0);

  signal s_exponent_is_all_ones : std_logic;
  signal s_exponent_is_all_zero : std_logic;
  signal s_fraction_is_all_zero : std_logic;
  signal s_is_zero : std_logic;
begin
  -- Decompose the floating point number.
  s_exponent <= i_src(WIDTH-2 downto FRACT_BITS);
  s_fraction <= i_src(FRACT_BITS-1 downto 0);

  -- Analyze the different parts.
  s_exponent_is_all_ones <= '1' when (s_exponent = (s_exponent'range => '1')) else '0';
  s_exponent_is_all_zero <= '1' when (s_exponent = (s_exponent'range => '0')) else '0';
  s_fraction_is_all_zero <= '1' when (s_fraction = (s_fraction'range => '0')) else '0';

  -- The number is negative when the MSB is set.
  o_props.is_neg <= i_src(WIDTH-1);

  -- The definition of an IEEE 754 NaN is:
  --  sign = either 0 or 1.
  --  biased exponent = all 1 bits.
  --  fraction = anything except all 0 bits.
  o_props.is_nan <= s_exponent_is_all_ones and not s_fraction_is_all_zero;

  -- The definition of an IEEE 754 Infinity is:
  --  sign = 0 for positive infinity, 1 for negative infinity.
  --  biased exponent = all 1 bits.
  --  fraction = all 0 bits.
  o_props.is_inf <= s_exponent_is_all_ones and s_fraction_is_all_zero;

  -- According to IEEE 754 a number is zero when:
  --  biased exponent = all 0 bits.
  --  fraction = all 0 bits.
  -- Note: We ignore the fraction part, so we effectively treat denormals as zeros too.
  s_is_zero <= s_exponent_is_all_zero;
  o_props.is_zero <= s_is_zero;

  o_exponent <= s_exponent;
  o_significand <= '1' & s_fraction when s_is_zero = '0' else (others => '0');
end rtl;
