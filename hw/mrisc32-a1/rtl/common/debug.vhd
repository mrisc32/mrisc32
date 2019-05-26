----------------------------------------------------------------------------------------------------
-- Copyright (c) 2019 Marcus Geelnard
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
use work.config.all;

package debug is
  -- Set this to true to enable debug trace output.
  constant C_DEBUG_ENABLE_TRACE : boolean := false;

  type T_DEBUG_TRACE is record
    valid : std_logic;
    src_a_valid : std_logic;
    src_b_valid : std_logic;
    src_c_valid : std_logic;
    pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
    src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
    src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
    src_c : std_logic_vector(C_WORD_SIZE-1 downto 0);
  end record T_DEBUG_TRACE;
end package;
