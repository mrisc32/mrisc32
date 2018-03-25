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
-- This is a single-cycle 32-bit multiplier for signed or unsigned integers.
-- TODO(m): Turn this into a pipelined multi-cycle operation.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity mul32 is
  port(
    -- Inputs.
    i_src_a : in std_logic_vector(31 downto 0);
    i_src_b : in std_logic_vector(31 downto 0);
    i_signed_op : in std_logic;

    -- Outputs (async).
    o_result : out std_logic_vector(63 downto 0)
  );
end mul32;

architecture rtl of mul32 is
  -- Widened input arguments.
  signal s_src_a_wide : std_logic_vector(32 downto 0);
  signal s_src_b_wide : std_logic_vector(32 downto 0);

  signal s_result_wide : signed(65 downto 0);
begin
  -- Widen the input signals.
  s_src_a_wide(31 downto 0) <= i_src_a;
  s_src_a_wide(32) <= i_src_a(31) and i_signed_op;
  s_src_b_wide(31 downto 0) <= i_src_b;
  s_src_b_wide(32) <= i_src_b(31) and i_signed_op;

  -- Perform the multiplication.
  s_result_wide <= signed(s_src_a_wide) * signed(s_src_b_wide);

  -- Asynchronous outputs.
  -- TODO(m): We should use registered outputs to get the maxium performance out of FPGA DSP
  -- blocks.
  o_result <= std_logic_vector(s_result_wide(63 downto 0));
end rtl;

