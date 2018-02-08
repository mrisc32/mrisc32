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

package consts is
  ------------------------------------------------------------------------------------------------
  -- Machine configuration
  ------------------------------------------------------------------------------------------------

  constant C_WORD_SIZE : integer := 32;
  constant C_NUM_REGS : integer := 32;
  constant C_VEC_REG_ELEMENTS : integer := 4;

  constant C_CPU_HAS_MULDIV : boolean := false;
  constant C_CPU_HAS_FPU : boolean := false;
  constant C_CPU_HAS_VECTOR : boolean := false;


  ------------------------------------------------------------------------------------------------
  -- Operation identifiers
  ------------------------------------------------------------------------------------------------

  -- ALU operations.
  constant C_ALU_OP_SIZE : integer := 9;
  subtype alu_op_t is std_logic_vector(C_ALU_OP_SIZE-1 downto 0);

  constant OP_CPUID  : alu_op_t := "000000000";

  constant OP_LDHI   : alu_op_t := "000000001";
  constant OP_LDHIO  : alu_op_t := "000000010";

  constant OP_OR     : alu_op_t := "000010000";
  constant OP_NOR    : alu_op_t := "000010001";
  constant OP_AND    : alu_op_t := "000010010";
  constant OP_BIC    : alu_op_t := "000010011";
  constant OP_XOR    : alu_op_t := "000010100";
  constant OP_ADD    : alu_op_t := "000010101";
  constant OP_SUB    : alu_op_t := "000010110";
  constant OP_SLT    : alu_op_t := "000010111";
  constant OP_SLTU   : alu_op_t := "000011000";
  constant OP_CEQ    : alu_op_t := "000011001";
  constant OP_CLT    : alu_op_t := "000011010";
  constant OP_CLTU   : alu_op_t := "000011011";
  constant OP_CLE    : alu_op_t := "000011100";
  constant OP_CLEU   : alu_op_t := "000011101";

  constant OP_LSR    : alu_op_t := "000011110";
  constant OP_ASR    : alu_op_t := "000011111";
  constant OP_LSL    : alu_op_t := "000100000";
  
  constant OP_SHUF   : alu_op_t := "000100001";

  constant OP_SEL    : alu_op_t := "001000000";
  constant OP_CLZ    : alu_op_t := "001000001";
  constant OP_REV    : alu_op_t := "001000010";
  constant OP_EXTB   : alu_op_t := "001000011";
  constant OP_EXTH   : alu_op_t := "001000100";

  -- MUL/DIV operations.
  constant C_MULDIV_OP_SIZE : integer := 9;
  subtype muldiv_op_t is std_logic_vector(C_MULDIV_OP_SIZE-1 downto 0);

  constant OP_MUL    : muldiv_op_t := "000110000";
  constant OP_MULHI  : muldiv_op_t := "000110010";
  constant OP_MULHIU : muldiv_op_t := "000110011";
  constant OP_DIV    : muldiv_op_t := "000110100";
  constant OP_DIVU   : muldiv_op_t := "000110101";
  constant OP_REM    : muldiv_op_t := "000110110";
  constant OP_REMU   : muldiv_op_t := "000110111";

  -- FPU operations.
  constant C_FPU_OP_SIZE : integer := 9;
  subtype fpu_op_t is std_logic_vector(C_FPU_OP_SIZE-1 downto 0);

  constant OP_ITOF   : fpu_op_t := "000111000";
  constant OP_FTOI   : fpu_op_t := "000111001";
  constant OP_FADD   : fpu_op_t := "000111010";
  constant OP_FSUB   : fpu_op_t := "000111011";
  constant OP_FMUL   : fpu_op_t := "000111100";
  constant OP_FDIV   : fpu_op_t := "000111101";


  ------------------------------------------------------------------------------------------------
  -- Helper functions
  ------------------------------------------------------------------------------------------------

  function to_word(x: integer) return std_logic_vector;
  function to_std_logic(x: boolean) return std_logic;
  function to_string(x: std_logic_vector) return string;

end package;

package body consts is
  function to_word(x: integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(x, C_WORD_SIZE));
  end function;

  function to_std_logic(x: boolean) return std_logic is
  begin
    if x then
      return '1';
    else
      return '0';
    end if;
  end function;

  function to_string(x: std_logic_vector) return string is
    variable v_b : string (1 to x'length) := (others => NUL);
    variable v_stri : integer := 1;
  begin
    for i in x'range loop
      v_b(v_stri) := std_logic'image(x((i)))(2);
      v_stri := v_stri+1;
    end loop;
    return v_b;
  end function;

end package body;

