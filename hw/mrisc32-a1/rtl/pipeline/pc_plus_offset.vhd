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
-- Increment a PC by a 21-bit signed word-offset.
--
-- This is implemented as a (21+9)-bit adder, and the two least significant bits are set to zero.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config.all;

entity pc_plus_offset is
  generic(
      OFFSET_SIZE : integer := 21  -- Number of bits for the offset signal.
    );
  port(
      i_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_offset : in std_logic_vector(OFFSET_SIZE-1 downto 0);
      o_result : out std_logic_vector(C_WORD_SIZE-1 downto 0)
    );
end pc_plus_offset;

architecture rtl of pc_plus_offset is
  signal s_offset_sign_extended : std_logic_vector(C_WORD_SIZE-3 downto 0); 
  signal s_pc : unsigned(C_WORD_SIZE-3 downto 0);
  signal s_offset : unsigned(C_WORD_SIZE-3 downto 0);
  signal s_result : unsigned(C_WORD_SIZE-3 downto 0);
begin
  -- Sign-extend the offset.
  s_offset_sign_extended(C_WORD_SIZE-3 downto OFFSET_SIZE-1) <= (others => i_offset(OFFSET_SIZE-1));
  s_offset_sign_extended(OFFSET_SIZE-2 downto 0) <= i_offset(OFFSET_SIZE-2 downto 0);

  -- Convert the signals to unsigned and add.
  s_pc <= resize(unsigned(i_pc(C_WORD_SIZE-1 downto 2)), C_WORD_SIZE-2);
  s_offset <= resize(unsigned(s_offset_sign_extended), C_WORD_SIZE-2);
  s_result <= s_pc + s_offset;

  -- Convert the result back to std_logic_vector, and append two zeros.
  o_result(C_WORD_SIZE-1 downto 2) <= std_logic_vector(s_result);
  o_result(1 downto 0) <= "00";
end rtl;

