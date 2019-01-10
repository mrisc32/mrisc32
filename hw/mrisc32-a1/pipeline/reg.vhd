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

entity reg is
  generic(WIDTH : positive := 32);
  port(
    i_clk : in std_logic;
    i_rst : in std_logic;

    i_we : in std_logic;                               -- Write enable
    i_data_w : in std_logic_vector(WIDTH-1 downto 0);  -- Data to be written
    o_data : out std_logic_vector(WIDTH-1 downto 0)    -- Register content (read data)
  );
end reg;

architecture behavioural of reg is
begin
  -- We update the register content on positive clock edges.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_data <= (others => '0');
    elsif rising_edge(i_clk) then
      if (i_we = '1') then
        o_data <= i_data_w;
      end if;
    end if;
  end process;
end behavioural;
