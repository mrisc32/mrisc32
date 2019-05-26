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
-- This file contains the configuration options for MRISC32-A1.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package config is
  --------------------------------------------------------------------------------------------------
  -- CPU word size.
  -- NOTE: The word size must currently be 32 bits, so this must not be changed.
  --------------------------------------------------------------------------------------------------
  constant C_LOG2_WORD_SIZE : integer := 5;
  constant C_WORD_SIZE : integer := 2**C_LOG2_WORD_SIZE;

  --------------------------------------------------------------------------------------------------
  -- Number of registers.
  -- NOTE: The the number of register must currently be 32, so this must not be changed.
  --------------------------------------------------------------------------------------------------
  constant C_LOG2_NUM_REGS : integer := 5;
  constant C_NUM_REGS : integer := 2**C_LOG2_NUM_REGS;

  --------------------------------------------------------------------------------------------------
  -- Number of vector elements in each vector register.
  -- NOTE: The the number of vector elements should be at least 16.
  --------------------------------------------------------------------------------------------------
  constant C_LOG2_VEC_REG_ELEMENTS : integer := 4;
  constant C_VEC_REG_ELEMENTS : integer := 2**C_LOG2_VEC_REG_ELEMENTS;

  ------------------------------------------------------------------------------------------------
  -- Hardware allocated registers.
  -- NOTE: Changing these values should be possible, but it has not been tested so it may be
  -- broken.
  ------------------------------------------------------------------------------------------------
  constant C_Z_REG  : integer := 0;   -- Z  = S0
  constant C_VL_REG : integer := 29;  -- VL = S29
  constant C_LR_REG : integer := 30;  -- LR = S30
  constant C_PC_REG : integer := 31;  -- PC = S31

  --------------------------------------------------------------------------------------------------
  -- The start PC after reset.
  --------------------------------------------------------------------------------------------------
  constant C_RESET_PC : std_logic_vector(C_WORD_SIZE-1 downto 0) := X"00000200";

  --------------------------------------------------------------------------------------------------
  -- Support vector operations (including the register file, V0-V31).
  --------------------------------------------------------------------------------------------------
  constant C_CPU_HAS_VEC : boolean := true;

  --------------------------------------------------------------------------------------------------
  -- Support packed operations (i.e. .B, .H versions of instructions).
  --------------------------------------------------------------------------------------------------
  constant C_CPU_HAS_PO : boolean := true;

  --------------------------------------------------------------------------------------------------
  -- Include hardware multiply (integer only).
  --------------------------------------------------------------------------------------------------
  constant C_CPU_HAS_MUL : boolean := true;

  --------------------------------------------------------------------------------------------------
  -- Include hardware division (integer and floating point).
  --------------------------------------------------------------------------------------------------
  constant C_CPU_HAS_DIV : boolean := true;

  --------------------------------------------------------------------------------------------------
  -- Support saturating and halving arithmetic operations.
  --------------------------------------------------------------------------------------------------
  constant C_CPU_HAS_SA : boolean := true;

  --------------------------------------------------------------------------------------------------
  -- Include an FPU.
  -- NOTE: For full floating point support, C_CPU_HAS_DIV must also be true.
  --------------------------------------------------------------------------------------------------
  constant C_CPU_HAS_FP : boolean := true;

  --------------------------------------------------------------------------------------------------
  -- Support the FSQRT instruction.
  -- NOTE: This has not yet been implemented, so this flag should always be set to false.
  --------------------------------------------------------------------------------------------------
  constant C_CPU_HAS_SQRT : boolean := false;
end package;
