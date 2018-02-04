library ieee;
use ieee.std_logic_1164.all;

entity alu is
  port (i_op : in std_logic_vector(8 downto 0);        -- Operation
        i_src_a : in std_logic_vector(31 downto 0);    -- Source operand A
        i_src_b : in std_logic_vector(31 downto 0);    -- Source operand B
        i_src_c : in std_logic_vector(31 downto 0);    -- Source operand C
        o_result : out std_logic_vector(31 downto 0)   -- ALU result
    );
end;
 
architecture rtl of alu is
  -- Supported ALU operations.
  constant OP_CPUID  : std_logic_vector(8 downto 0) := "000000000";

  constant OP_LDHI   : std_logic_vector(8 downto 0) := "000000001";
  constant OP_LDHIO  : std_logic_vector(8 downto 0) := "000000010";

  constant OP_OR     : std_logic_vector(8 downto 0) := "000010000";
  constant OP_NOR    : std_logic_vector(8 downto 0) := "000010001";
  constant OP_AND    : std_logic_vector(8 downto 0) := "000010010";
  constant OP_BIC    : std_logic_vector(8 downto 0) := "000010011";
  constant OP_XOR    : std_logic_vector(8 downto 0) := "000010100";
  constant OP_ADD    : std_logic_vector(8 downto 0) := "000010101";
  constant OP_SUB    : std_logic_vector(8 downto 0) := "000010110";
  constant OP_SLT    : std_logic_vector(8 downto 0) := "000010111";
  constant OP_SLTU   : std_logic_vector(8 downto 0) := "000011000";
  constant OP_CMPEQ  : std_logic_vector(8 downto 0) := "000011001";
  constant OP_CMPLT  : std_logic_vector(8 downto 0) := "000011010";
  constant OP_CMPLTU : std_logic_vector(8 downto 0) := "000011011";
  constant OP_CMPLE  : std_logic_vector(8 downto 0) := "000011100";
  constant OP_CMPLEU : std_logic_vector(8 downto 0) := "000011101";
  constant OP_LSR    : std_logic_vector(8 downto 0) := "000011110";
  constant OP_ASR    : std_logic_vector(8 downto 0) := "000011111";
  constant OP_LSL    : std_logic_vector(8 downto 0) := "000100000";
  constant OP_SHUF   : std_logic_vector(8 downto 0) := "000100001";

  -- TODO(m): Move to a MUL/DIV entity.
  constant OP_MUL    : std_logic_vector(8 downto 0) := "000110000";
  constant OP_MULHI  : std_logic_vector(8 downto 0) := "000110010";
  constant OP_MULHIU : std_logic_vector(8 downto 0) := "000110011";
  constant OP_DIV    : std_logic_vector(8 downto 0) := "000110100";
  constant OP_DIVU   : std_logic_vector(8 downto 0) := "000110101";
  constant OP_REM    : std_logic_vector(8 downto 0) := "000110110";
  constant OP_REMU   : std_logic_vector(8 downto 0) := "000110111";

  -- TODO(m): Move to an FPU entity.
  constant OP_ITOF   : std_logic_vector(8 downto 0) := "000111000";
  constant OP_FTOI   : std_logic_vector(8 downto 0) := "000111001";
  constant OP_FADD   : std_logic_vector(8 downto 0) := "000111010";
  constant OP_FSUB   : std_logic_vector(8 downto 0) := "000111011";
  constant OP_FMUL   : std_logic_vector(8 downto 0) := "000111100";
  constant OP_FDIV   : std_logic_vector(8 downto 0) := "000111101";

  constant OP_SEL    : std_logic_vector(8 downto 0) := "001000000";
  constant OP_CLZ    : std_logic_vector(8 downto 0) := "001000001";
  constant OP_REV    : std_logic_vector(8 downto 0) := "001000010";
  constant OP_EXTB   : std_logic_vector(8 downto 0) := "001000011";
  constant OP_EXTH   : std_logic_vector(8 downto 0) := "001000100";


  -- Intermediate (concurrent) operation results.
  signal s_or_res : std_logic_vector(31 downto 0);
  signal s_nor_res : std_logic_vector(31 downto 0);
  signal s_and_res : std_logic_vector(31 downto 0);
  signal s_bic_res : std_logic_vector(31 downto 0);
  -- ...

begin

  -- OP_OR
  s_or_res <= i_src_a or i_src_b;

  -- OP_NOR
  s_nor_res <= not s_or_res;

  -- OP_AND
  s_and_res <= i_src_a and i_src_b;

  -- OP_BIC
  s_bic_res <= i_src_a and (not i_src_b);

  -- ...

  -- Select the output.
  AluMux: with i_op select
    o_result <= s_or_res when OP_OR,
                s_nor_res when OP_NOR,
                s_and_res when OP_AND,
                s_bic_res when OP_BIC,
                -- ...
                "00000000000000000000000000000000" when others;

end rtl;

