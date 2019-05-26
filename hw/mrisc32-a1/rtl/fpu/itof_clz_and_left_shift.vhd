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

----------------------------------------------------------------------------------------------------
-- Left-shift an integer until there are no more leasing zeros, and count the number of leading
-- zeros (i.e. the shift amount) at the same time.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity itof_clz_and_left_shift is
  generic(
    WIDTH : positive := 32;
    LOG2_WIDTH : positive := 5
  );
  port(
    -- Inputs (async).
    i_src : in std_logic_vector(WIDTH-1 downto 0);

    -- Outputs (async).
    o_result : out std_logic_vector(WIDTH-1 downto 0);
    o_left_shift : out std_logic_vector(LOG2_WIDTH-1 downto 0)
  );
end itof_clz_and_left_shift;

architecture rtl of itof_clz_and_left_shift is
begin
  process(i_src)
    variable v_shifted_src : unsigned(WIDTH-1 downto 0);
    variable v_lz_chunk_size : integer range 0 to WIDTH/2;
    variable v_lz_bit_no : integer range -1 to LOG2_WIDTH-1;
    variable v_left_shift : unsigned(LOG2_WIDTH-1 downto 0);
  begin
    v_shifted_src := unsigned(i_src);
    v_lz_bit_no := LOG2_WIDTH-1;
    v_lz_chunk_size := WIDTH/2;
    while v_lz_chunk_size > 0 loop
      if v_shifted_src(WIDTH-1 downto WIDTH-v_lz_chunk_size) = to_unsigned(0, v_lz_chunk_size) then
        v_left_shift(v_lz_bit_no) := '1';
        v_shifted_src := v_shifted_src(WIDTH-1-v_lz_chunk_size downto 0) & to_unsigned(0, v_lz_chunk_size);
      else
        v_left_shift(v_lz_bit_no) := '0';
      end if;
      v_lz_bit_no := v_lz_bit_no - 1;
      v_lz_chunk_size := v_lz_chunk_size / 2;
    end loop;

    -- Output signals.
    o_result <= std_logic_vector(v_shifted_src);
    o_left_shift <= std_logic_vector(v_left_shift);
  end process;
end rtl;

