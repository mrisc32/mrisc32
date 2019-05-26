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
use work.config.all;

entity rev32 is
  port(
      i_src         : in  std_logic_vector(31 downto 0);
      i_packed_mode : in  T_PACKED_MODE;
      o_result      : out std_logic_vector(31 downto 0)
    );
end rev32;

architecture rtl of rev32 is
begin
  PACKED_GEN: if C_CPU_HAS_PO generate
    process(i_src, i_packed_mode)
      variable v_lo : integer;
      variable v_hi : integer;
    begin
      if i_packed_mode = C_PACKED_BYTE then
        for k in 0 to 3 loop
          v_lo := k * 8;
          v_hi := v_lo + 7;
          for j in 0 to 7 loop
            o_result(v_lo + j) <= i_src(v_hi - j);
          end loop;
        end loop;
      elsif i_packed_mode = C_PACKED_HALF_WORD then
        for k in 0 to 1 loop
          v_lo := k * 16;
          v_hi := v_lo + 15;
          for j in 0 to 15 loop
            o_result(v_lo + j) <= i_src(v_hi - j);
          end loop;
        end loop;
      else
        -- C_PACKED_NONE
        for j in 0 to 31 loop
          o_result(j) <= i_src(31 - j);
        end loop;
      end if;
    end process;
  else generate
    -- In unpacked mode we only have to consider the 32-bit result.
    Rev32Gen: for j in 0 to 31 generate
      o_result(j) <= i_src(31 - j);
    end generate;
  end generate;
end rtl;
