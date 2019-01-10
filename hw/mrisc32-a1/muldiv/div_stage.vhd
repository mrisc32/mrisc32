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

----------------------------------------------------------------------------------------------------
-- This is single stage of an unsigned integer divider.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity div_stage is
  generic(
    WIDTH : positive
  );
  port(
    -- Inputs (async).
    i_n : in std_logic_vector(WIDTH-1 downto 0);
    i_d : in std_logic_vector(WIDTH-1 downto 0);
    i_q : in std_logic_vector(WIDTH-1 downto 0);
    i_r : in std_logic_vector(WIDTH-1 downto 0);

    -- Outputs (async).
    o_n : out std_logic_vector(WIDTH-1 downto 0);
    o_d : out std_logic_vector(WIDTH-1 downto 0);
    o_q : out std_logic_vector(WIDTH-1 downto 0);
    o_r : out std_logic_vector(WIDTH-1 downto 0)
  );
end div_stage;

architecture rtl of div_stage is
  signal s_prim : std_logic_vector(WIDTH-1 downto 0);
  signal s_prim_minus_d : std_logic_vector(WIDTH downto 0);
  signal s_no_underflow : std_logic;
begin
  -- Calculate R' = (R << 1) | N(WIDTH-1)
  s_prim <= i_r(WIDTH-2 downto 0) & i_n(WIDTH-1);

  -- Calculate R' - D.
  s_prim_minus_d <= std_logic_vector(resize(unsigned(s_prim), WIDTH+1) - resize(unsigned(i_d), WIDTH+1));
  s_no_underflow <= not s_prim_minus_d(WIDTH);

  -- N = N << 1
  o_n <= i_n(WIDTH-2 downto 0) & "0";

  -- D = D
  o_d <= i_d;

  -- Q = (Q << 1) | s_no_underflow
  o_q <= i_q(WIDTH-2 downto 0) & s_no_underflow;

  -- R = R' > D ? (R' - D) : R'
  o_r <= s_prim_minus_d(WIDTH-1 downto 0) when s_no_underflow = '1' else s_prim;
end rtl;
