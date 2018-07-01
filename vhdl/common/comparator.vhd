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

entity comparator is
  generic(WIDTH : positive := 32);
  port(
      i_src : in  std_logic_vector(WIDTH-1 downto 0);
      o_z  : out std_logic;
      o_nz : out std_logic;
      o_s  : out std_logic;
      o_ns : out std_logic;
      o_lt : out std_logic;
      o_ge : out std_logic;
      o_le : out std_logic;
      o_gt : out std_logic
    );
end comparator;

architecture rtl of comparator is
  constant ALL_ZEROS : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
  constant ALL_ONES : std_logic_vector(WIDTH-1 downto 0) := (others => '1');
  signal s_z : std_logic;
  signal s_s : std_logic;
  signal s_lt : std_logic;
  signal s_ge : std_logic;
begin
  -- Evaluate the sign and zero/one:ness.
  s_z <= '1' when i_src = ALL_ZEROS else '0';
  s_s <= '1' when i_src = ALL_ONES else '0';
  s_lt <= i_src(WIDTH-1);
  s_ge <= not i_src(WIDTH-1);

  -- Generate output signals.
  o_z <= s_z;
  o_nz <= not s_z;
  o_s <= s_s;
  o_ns <= not s_s;
  o_lt <= s_lt;
  o_ge <= s_ge;
  o_le <= s_z or s_lt;
  o_gt <= s_ge and not s_z;
end rtl;

