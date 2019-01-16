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
-- This is a configurable FADD (and FSUB) pipeline. The pipeline can be instantiated for different
-- sizes (e.g. 32-bit, 16-bit and 8-bit floating point).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity fadd is
  generic(
    WIDTH : positive := 32;
    EXP_BITS : positive := 8;
    EXP_BIAS : positive := 127;
    FRACT_BITS : positive := 23
  );
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;

    -- Inputs (async).
    i_enable : in std_logic;

    i_props_a : in T_FLOAT_PROPS;
    i_exponent_a : in std_logic_vector(EXP_BITS-1 downto 0);
    i_significand_a : in std_logic_vector(FRACT_BITS downto 0);

    i_props_b : in T_FLOAT_PROPS;
    i_exponent_b : in std_logic_vector(EXP_BITS-1 downto 0);
    i_significand_b : in std_logic_vector(FRACT_BITS downto 0);

    -- Outputs (async).
    o_props : out T_FLOAT_PROPS;
    o_exponent : out std_logic_vector(EXP_BITS-1 downto 0);
    o_significand : out std_logic_vector(FRACT_BITS downto 0);
    o_result_ready : out std_logic
  );
end fadd;

architecture rtl of fadd is
  -- Constants.
  constant SIGNIFICAND_BITS : positive := FRACT_BITS + 1;
  constant PRODUCT_BITS : positive := SIGNIFICAND_BITS * 2;

begin
  --================================================================================================
  -- F1: Stage 1 of the pipeline.
  --================================================================================================

  -- TODO(m): Implement me!


  --==================================================================================================
  -- F2: Stage 2 of the pipeline.
  --==================================================================================================

  -- TODO(m): Implement me!


  --==================================================================================================
  -- F3: Stage 3 of the pipeline.
  --==================================================================================================

  -- TODO(m): Implement me!

  -- Output the result.
  o_props.is_neg <= '0';
  o_props.is_nan <= '0';
  o_props.is_inf <= '0';
  o_props.is_zero <= '0';
  o_significand <= (others => '0');
  o_exponent <= (others => '0');

  -- Result ready?
  o_result_ready <= '0';
end rtl;

