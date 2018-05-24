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

package common is
  ------------------------------------------------------------------------------------------------
  -- Machine configuration
  ------------------------------------------------------------------------------------------------

  constant C_WORD_SIZE : integer := 32;
  constant C_NUM_REGS : integer := 32;
  constant C_LOG2_NUM_REGS : integer := 5;
  constant C_VEC_REG_ELEMENTS : integer := 4;

  constant C_CPU_HAS_MULDIV : boolean := false;
  constant C_CPU_HAS_FPU : boolean := false;
  constant C_CPU_HAS_VECTOR : boolean := false;

  -- The start PC after reset.
  constant C_RESET_PC : std_logic_vector(C_WORD_SIZE-1 downto 0) := X"00000200";


  ------------------------------------------------------------------------------------------------
  -- Registers
  ------------------------------------------------------------------------------------------------

  constant C_Z_REG  : integer := 0;   -- Z  = S0
  constant C_VL_REG : integer := 29;  -- VL = S29
  constant C_LR_REG : integer := 30;  -- LR = S30
  constant C_PC_REG : integer := 31;  -- PC = S31


  ------------------------------------------------------------------------------------------------
  -- Operation identifiers
  ------------------------------------------------------------------------------------------------

  -- ALU operations.
  constant C_ALU_OP_SIZE : integer := 6;
  subtype T_ALU_OP is std_logic_vector(C_ALU_OP_SIZE-1 downto 0);

  constant C_ALU_CPUID : T_ALU_OP := "000000";

  constant C_ALU_LDHI  : T_ALU_OP := "000001";
  constant C_ALU_LDHIO : T_ALU_OP := "000010";

  constant C_ALU_OR    : T_ALU_OP := "010000";
  constant C_ALU_NOR   : T_ALU_OP := "010001";
  constant C_ALU_AND   : T_ALU_OP := "010010";
  constant C_ALU_BIC   : T_ALU_OP := "010011";
  constant C_ALU_XOR   : T_ALU_OP := "010100";
  constant C_ALU_ADD   : T_ALU_OP := "010101";
  constant C_ALU_SUB   : T_ALU_OP := "010110";
  constant C_ALU_SLT   : T_ALU_OP := "010111";
  constant C_ALU_SLTU  : T_ALU_OP := "011000";
  constant C_ALU_CEQ   : T_ALU_OP := "011001";
  constant C_ALU_CLT   : T_ALU_OP := "011010";
  constant C_ALU_CLTU  : T_ALU_OP := "011011";
  constant C_ALU_CLE   : T_ALU_OP := "011100";
  constant C_ALU_CLEU  : T_ALU_OP := "011101";
  constant C_ALU_LSR   : T_ALU_OP := "011110";
  constant C_ALU_ASR   : T_ALU_OP := "011111";
  constant C_ALU_LSL   : T_ALU_OP := "100000";
  constant C_ALU_SHUF  : T_ALU_OP := "100001";
  constant C_ALU_MIN   : T_ALU_OP := "100010";
  constant C_ALU_MAX   : T_ALU_OP := "100011";

  constant C_ALU_CLZ   : T_ALU_OP := "110001";
  constant C_ALU_REV   : T_ALU_OP := "110010";
  constant C_ALU_EXTB  : T_ALU_OP := "110011";
  constant C_ALU_EXTH  : T_ALU_OP := "110100";

  -- MUL operations.
  constant C_MUL_OP_SIZE : integer := 3;
  subtype T_MUL_OP is std_logic_vector(C_MUL_OP_SIZE-1 downto 0);

  constant C_MUL_MUL    : T_MUL_OP := "000";
  constant C_MUL_MULHI  : T_MUL_OP := "010";
  constant C_MUL_MULHIU : T_MUL_OP := "011";
  constant C_MUL_FMUL   : T_MUL_OP := "100";

  -- DIV operations.
  constant C_DIV_OP_SIZE : integer := 3;
  subtype T_DIV_OP is std_logic_vector(C_DIV_OP_SIZE-1 downto 0);

  constant C_DIV_DIV    : T_DIV_OP := "000";
  constant C_DIV_DIVU   : T_DIV_OP := "001";
  constant C_DIV_REM    : T_DIV_OP := "010";
  constant C_DIV_REMU   : T_DIV_OP := "011";
  constant C_DIV_FDIV   : T_DIV_OP := "100";

  -- FPU operations.
  constant C_FPU_OP_SIZE : integer := 4;
  subtype T_FPU_OP is std_logic_vector(C_FPU_OP_SIZE-1 downto 0);

  constant C_FPU_ITOF : T_FPU_OP := "0000";
  constant C_FPU_FTOI : T_FPU_OP := "0001";
  constant C_FPU_FADD : T_FPU_OP := "0010";
  constant C_FPU_FSUB : T_FPU_OP := "0011";
  constant C_FPU_FCEQ : T_FPU_OP := "0100";
  constant C_FPU_FCLT : T_FPU_OP := "0101";
  constant C_FPU_FCLE : T_FPU_OP := "0110";
  constant C_FPU_FMIN : T_FPU_OP := "0111";
  constant C_FPU_FMAX : T_FPU_OP := "1000";

  -- MEM operations.
  constant C_MEM_OP_SIZE : integer := 4;
  subtype T_MEM_OP is std_logic_vector(C_MEM_OP_SIZE-1 downto 0);

  -- The memory operation is encoded as follows: "SUWW", where:
  --   S  = Store    (1 = store, 0 = load).
  --   U  = Unsigned (1 = unsigned, 0 = signed)
  --   WW = Width    (01 = byte, 10 = halfword, 11 = word)
  constant C_MEM_OP_NONE    : T_MEM_OP := "0000";
  constant C_MEM_OP_LOAD8   : T_MEM_OP := "0001";
  constant C_MEM_OP_LOAD16  : T_MEM_OP := "0010";
  constant C_MEM_OP_LOAD32  : T_MEM_OP := "0011";
  constant C_MEM_OP_LOADU8  : T_MEM_OP := "0101";
  constant C_MEM_OP_LOADU16 : T_MEM_OP := "0110";
  constant C_MEM_OP_STORE8  : T_MEM_OP := "1001";
  constant C_MEM_OP_STORE16 : T_MEM_OP := "1010";
  constant C_MEM_OP_STORE32 : T_MEM_OP := "1011";


  ------------------------------------------------------------------------------------------------
  -- Helper functions
  ------------------------------------------------------------------------------------------------

  function to_vector(x: integer; size: integer) return std_logic_vector;
  function to_word(x: integer) return std_logic_vector;
  function to_std_logic(x: boolean) return std_logic;
  function to_string(x: std_logic_vector) return string;
  function to_string(x: std_logic) return string;

end package;

package body common is
  function to_vector(x: integer; size: integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(x, size));
  end function;

  function to_word(x: integer) return std_logic_vector is
  begin
    return to_vector(x, C_WORD_SIZE);
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

  function to_string(x: std_logic) return string is
  begin
    return std_logic'image(x);
  end function;

end package body;

