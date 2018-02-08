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

entity shift32 is
  port(
      i_right      : in  std_logic;  -- '1' for right shifts, '0' for left
      i_arithmetic : in  std_logic;  -- '1' for arihtmetic shifts, '0' for logic
      i_src        : in  std_logic_vector(31 downto 0);
      i_shift      : in  std_logic_vector(4 downto 0);
      o_result     : out std_logic_vector(31 downto 0)
    );
end shift32;

architecture rtl of shift32 is
  signal s_lsr_res : std_logic_vector(31 downto 0);
  signal s_asr_res : std_logic_vector(31 downto 0);
  signal s_lsl_res : std_logic_vector(31 downto 0);
  signal s_op : std_logic_vector(1 downto 0);
begin
  -- TODO(m): This can probably be done with less logic.
  s_lsr_res <= std_logic_vector(shift_right(unsigned(i_src), to_integer(unsigned(i_shift))));
  s_asr_res <= std_logic_vector(shift_right(signed(i_src), to_integer(unsigned(i_shift))));
  s_lsl_res <= std_logic_vector(shift_left(unsigned(i_src), to_integer(unsigned(i_shift))));

  s_op(1) <= i_right;
  s_op(0) <= i_arithmetic;
  ResultMux: with s_op select
    o_result <=
      s_lsr_res when "10",
      s_asr_res when "11",
      s_lsl_res when others;
end rtl;

