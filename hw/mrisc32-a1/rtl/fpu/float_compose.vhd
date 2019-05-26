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
-- This entity composes floating point number components into an IEEE 754 binary floating point
-- number.
--
-- IEEE 754 incompatibilities/simplifications:
--  - Denormals are not supported.
----------------------------------------------------------------------------------------------------

entity float_compose is
  generic(
      WIDTH : positive := 32;
      EXP_BITS : positive := 8;
      FRACT_BITS : positive := 23
    );
  port(
      i_props : in T_FLOAT_PROPS;
      i_exponent : in std_logic_vector(EXP_BITS-1 downto 0);
      i_significand : in std_logic_vector(FRACT_BITS downto 0);

      o_result : out std_logic_vector(WIDTH-1 downto 0)
    );
end float_compose;

architecture rtl of float_compose is
begin
  -- We currently always flush denormals to zero.
  o_result(WIDTH-1) <= i_props.is_neg;
  o_result(WIDTH-2 downto FRACT_BITS) <=
      (WIDTH-2 downto FRACT_BITS => '1') when (i_props.is_nan or i_props.is_inf) = '1' else
      (WIDTH-2 downto FRACT_BITS => '0') when i_props.is_zero = '1' else
      i_exponent;
  o_result(FRACT_BITS-1 downto 0) <=
      (FRACT_BITS-1 downto 0 => '1') when i_props.is_nan = '1' else
      (FRACT_BITS-1 downto 0 => '0') when (i_props.is_inf or i_props.is_zero) = '1' else
      i_significand(FRACT_BITS-1 downto 0);
end rtl;
