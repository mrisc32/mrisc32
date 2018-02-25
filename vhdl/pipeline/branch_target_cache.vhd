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
-- Branch Target Cache
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.consts.all;

entity branch_target_cache is
  port(
      -- Control signals.
      i_clk : in std_logic;
      i_rst : in std_logic;
      i_invalidate : in std_logic;

      -- Cache lookup (async).
      i_read_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_predict_taken : out std_logic;
      o_predict_target : out std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- Cache update (sync).
      i_write_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_write_is_branch : in std_logic;
      i_write_is_taken : in std_logic;
      i_write_target : in std_logic_vector(C_WORD_SIZE-1 downto 0)
    );
end branch_target_cache;

architecture rtl of branch_target_cache is
begin
  -- TODO(m): Right now we always predict "not taken". Implement a proper cache!
  o_predict_taken <= '0';
  o_predict_taken <= (others => '0');
end rtl;

