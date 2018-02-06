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

  constant C_OP_SIZE : integer := 9;
  subtype opcode_t is std_logic_vector(C_OP_SIZE-1 downto 0);

  -- ALU operations.
  constant OP_CPUID  : opcode_t := "000000000";

  constant OP_LDHI   : opcode_t := "000000001";
  constant OP_LDHIO  : opcode_t := "000000010";

  constant OP_OR     : opcode_t := "000010000";
  constant OP_NOR    : opcode_t := "000010001";
  constant OP_AND    : opcode_t := "000010010";
  constant OP_BIC    : opcode_t := "000010011";
  constant OP_XOR    : opcode_t := "000010100";
  constant OP_ADD    : opcode_t := "000010101";
  constant OP_SUB    : opcode_t := "000010110";
  constant OP_SLT    : opcode_t := "000010111";
  constant OP_SLTU   : opcode_t := "000011000";
  constant OP_CEQ    : opcode_t := "000011001";
  constant OP_CLT    : opcode_t := "000011010";
  constant OP_CLTU   : opcode_t := "000011011";
  constant OP_CLE    : opcode_t := "000011100";
  constant OP_CLEU   : opcode_t := "000011101";

  constant OP_LSR    : opcode_t := "000011110";
  constant OP_ASR    : opcode_t := "000011111";
  constant OP_LSL    : opcode_t := "000100000";
  
  constant OP_SHUF   : opcode_t := "000100001";

  constant OP_SEL    : opcode_t := "001000000";
  constant OP_CLZ    : opcode_t := "001000001";
  constant OP_REV    : opcode_t := "001000010";
  constant OP_EXTB   : opcode_t := "001000011";
  constant OP_EXTH   : opcode_t := "001000100";

  -- MUL/DIV operations.
  constant OP_MUL    : opcode_t := "000110000";
  constant OP_MULHI  : opcode_t := "000110010";
  constant OP_MULHIU : opcode_t := "000110011";
  constant OP_DIV    : opcode_t := "000110100";
  constant OP_DIVU   : opcode_t := "000110101";
  constant OP_REM    : opcode_t := "000110110";
  constant OP_REMU   : opcode_t := "000110111";

  -- FPU operations.
  constant OP_ITOF   : opcode_t := "000111000";
  constant OP_FTOI   : opcode_t := "000111001";
  constant OP_FADD   : opcode_t := "000111010";
  constant OP_FSUB   : opcode_t := "000111011";
  constant OP_FMUL   : opcode_t := "000111100";
  constant OP_FDIV   : opcode_t := "000111101";


  ------------------------------------------------------------------------------------------------
  -- Helper functions
  ------------------------------------------------------------------------------------------------

  function to_word(x: integer) return std_logic_vector;
  function to_std_logic(x: boolean) return std_logic;

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
end package body;
