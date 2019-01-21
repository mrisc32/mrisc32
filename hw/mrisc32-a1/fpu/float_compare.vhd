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

----------------------------------------------------------------------------------------------------
-- Compare floating point numbers.
-- TODO(m): Handle NaNs.
----------------------------------------------------------------------------------------------------

entity float_compare is
  generic(
      WIDTH : positive := 32
    );
  port(
      i_src_a : in std_logic_vector(WIDTH-1 downto 0);
      i_src_b : in std_logic_vector(WIDTH-1 downto 0);

      o_magn_lt : out std_logic;
      o_eq : out std_logic;
      o_ne : out std_logic;
      o_lt : out std_logic;
      o_le : out std_logic
    );
end float_compare;

architecture rtl of float_compare is
  signal s_sign_a : std_logic;
  signal s_sign_b : std_logic;
  signal s_magn_a : unsigned(WIDTH-2 downto 0);
  signal s_magn_b : unsigned(WIDTH-2 downto 0);

  signal s_magn_eq : std_logic;
  signal s_magn_lt : std_logic;

  signal s_eq : std_logic;
  signal s_lt : std_logic;
begin
  -- Decompose.
  s_sign_a <= i_src_a(WIDTH-1);
  s_sign_b <= i_src_b(WIDTH-1);
  s_magn_a <= unsigned(i_src_a(WIDTH-2 downto 0));
  s_magn_b <= unsigned(i_src_b(WIDTH-2 downto 0));

  -- Compare exponents and magnitudes.
  s_magn_eq <= '1' when s_magn_a = s_magn_b else '0';
  s_magn_lt <= '1' when s_magn_a < s_magn_b else '0';

  -- Equal?
  s_eq <= (not (s_sign_a xor s_sign_b)) and s_magn_eq;

  -- Less than?
  s_lt <= s_magn_lt when (s_sign_a = '0' and s_sign_b = '0') else
          (not (s_eq or s_magn_lt)) when (s_sign_a = '1' and s_sign_b = '1') else
          '1' when (s_sign_a = '1' and s_sign_b = '0') else
          '0';

  -- Outputs.
  o_magn_lt <= s_magn_lt;
  o_eq <= s_eq;
  o_ne <= not s_eq;
  o_lt <= s_lt;
  o_le <= s_eq or s_lt;
end rtl;
