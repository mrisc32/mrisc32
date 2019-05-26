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
use work.types.all;

entity shift32 is
  port(
      i_right       : in  std_logic;  -- '1' for right shifts, '0' for left
      i_arithmetic  : in  std_logic;  -- '1' for arihtmetic shifts, '0' for logic
      i_src         : in  std_logic_vector(31 downto 0);
      i_shift       : in  std_logic_vector(31 downto 0);
      i_packed_mode : in  T_PACKED_MODE;
      o_result      : out std_logic_vector(31 downto 0)
    );
end shift32;

architecture rtl of shift32 is
begin
  -- TODO(m): Optimize this when C_CPU_HAS_PO = false.

  process(i_right, i_arithmetic, i_src, i_shift, i_packed_mode)
    variable v_shift : integer;
    variable v_lo : integer;
    variable v_hi : integer;
  begin
    if i_packed_mode = C_PACKED_BYTE then
      for k in 0 to 3 loop
        v_lo := k * 8;
        v_hi := v_lo + 7;
        v_shift := to_integer(unsigned(i_shift(v_lo + 2 downto v_lo)));
        if i_right = '1' and i_arithmetic = '1' then
          -- ASR
          o_result(v_hi downto v_lo) <=
              std_logic_vector(shift_right(signed(i_src(v_hi downto v_lo)), v_shift));
        elsif i_right = '1' and i_arithmetic = '0' then
          -- LSR
          o_result(v_hi downto v_lo) <=
              std_logic_vector(shift_right(unsigned(i_src(v_hi downto v_lo)), v_shift));
        else
          -- LSL
          o_result(v_hi downto v_lo) <=
              std_logic_vector(shift_left(unsigned(i_src(v_hi downto v_lo)), v_shift));
        end if;
      end loop;
    elsif i_packed_mode = C_PACKED_HALF_WORD then
      for k in 0 to 1 loop
        v_lo := k * 16;
        v_hi := v_lo + 15;
        v_shift := to_integer(unsigned(i_shift(v_lo + 3 downto v_lo)));
        if i_right = '1' and i_arithmetic = '1' then
          -- ASR
          o_result(v_hi downto v_lo) <=
              std_logic_vector(shift_right(signed(i_src(v_hi downto v_lo)), v_shift));
        elsif i_right = '1' and i_arithmetic = '0' then
          -- LSR
          o_result(v_hi downto v_lo) <=
              std_logic_vector(shift_right(unsigned(i_src(v_hi downto v_lo)), v_shift));
        else
          -- LSL
          o_result(v_hi downto v_lo) <=
              std_logic_vector(shift_left(unsigned(i_src(v_hi downto v_lo)), v_shift));
        end if;
      end loop;
    else
      -- C_PACKED_NONE
      v_shift := to_integer(unsigned(i_shift(4 downto 0)));
      if i_right = '1' and i_arithmetic = '1' then
        -- ASR
        o_result <= std_logic_vector(shift_right(signed(i_src), v_shift));
      elsif i_right = '1' and i_arithmetic = '0' then
        -- LSR
        o_result <= std_logic_vector(shift_right(unsigned(i_src), v_shift));
      else
        -- LSL
        o_result <= std_logic_vector(shift_left(unsigned(i_src), v_shift));
      end if;
    end if;
  end process;
end rtl;
