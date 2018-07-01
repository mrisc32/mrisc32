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
use work.common.all;

entity alu is
  port(
      i_op : in T_ALU_OP;                                      -- Operation
      i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);   -- Source operand A
      i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);   -- Source operand B
      o_result : out std_logic_vector(C_WORD_SIZE-1 downto 0)  -- ALU result
    );
end;
 
architecture rtl of alu is
  -- Intermediate (concurrent) operation results.
  signal s_cpuid_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_or_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_nor_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_and_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_bic_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_xor_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_minmax_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_slt_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_cmp_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_shuf_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_rev_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ldhi_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_clz_res : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Signals for the adder.
  signal s_adder_subtract : std_logic;
  signal s_adder_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_adder_carry_out : std_logic;

  -- Signals for the comparator.
  signal s_compare_eq : std_logic;
  signal s_compare_ne : std_logic;
  signal s_compare_lt : std_logic;
  signal s_compare_le : std_logic;
  signal s_compare_ltu : std_logic;
  signal s_compare_leu : std_logic;
  signal s_cmp_bit : std_logic;
  signal s_is_max_op : std_logic;

  -- Signals for the shifter.
  signal s_shifter_res : std_logic_vector(C_WORD_SIZE-1 downto 0);

begin
  ------------------------------------------------------------------------------------------------
  -- CPUID
  ------------------------------------------------------------------------------------------------

  process(i_src_a, i_src_b)
  begin
    if (i_src_a = to_word(0)) and (i_src_b = to_word(0)) then
      s_cpuid_res <= to_word(C_VEC_REG_ELEMENTS);
    elsif (i_src_a = to_word(1)) and (i_src_b = to_word(0)) then
      s_cpuid_res(0) <= to_std_logic(C_CPU_HAS_MULDIV);
      s_cpuid_res(1) <= to_std_logic(C_CPU_HAS_FPU);
      s_cpuid_res(2) <= to_std_logic(C_CPU_HAS_VECTOR);
      s_cpuid_res(C_WORD_SIZE-1 downto 3) <= (others => '0');
    else
      s_cpuid_res <= (others => '0');
    end if;
  end process;


  ------------------------------------------------------------------------------------------------
  -- Bitwise operations
  ------------------------------------------------------------------------------------------------

  -- C_ALU_OR
  s_or_res <= i_src_a or i_src_b;

  -- C_ALU_NOR
  s_nor_res <= not s_or_res;

  -- C_ALU_AND
  s_and_res <= i_src_a and i_src_b;

  -- C_ALU_BIC
  s_bic_res <= i_src_a and (not i_src_b);

  -- C_ALU_XOR
  s_xor_res <= i_src_a xor i_src_b;


  ------------------------------------------------------------------------------------------------
  -- Bit, byte and word shuffling
  ------------------------------------------------------------------------------------------------

  -- C_ALU_SHUF
  AluSHUF32: entity work.shuf32
    port map (
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      o_result => s_shuf_res
    );

  -- C_ALU_REV
  RevGen: for k in 0 to C_WORD_SIZE-1 generate
    s_rev_res(k) <= i_src_a(C_WORD_SIZE-1-k);
  end generate;

  -- C_ALU_LDHI, C_ALU_LDHIO
  s_ldhi_res(C_WORD_SIZE-1 downto C_WORD_SIZE-19) <= i_src_a(18 downto 0);
  s_ldhi_res(C_WORD_SIZE-20 downto 0) <= (others => i_op(1));  -- C_ALU_LDHI="000001", C_ALU_LDHIO="000010"

  -- C_ALU_CLZ
  AluCLZ32: entity work.clz32
    port map (
      i_src => i_src_a,
      o_cnt => s_clz_res(5 downto 0)
    );
  s_clz_res(31 downto 6) <= (others => '0');


  ------------------------------------------------------------------------------------------------
  -- Arithmetic operations
  ------------------------------------------------------------------------------------------------

  AluAdder: entity work.adder
    generic map (
      WIDTH => C_WORD_SIZE
    )
    port map (
      i_subtract => s_adder_subtract,
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      o_result => s_adder_result,
      o_c_out => s_adder_carry_out
    );

  -- Select if we're doing addition or subtraction.
  NegAdderAMux: with i_op select
    s_adder_subtract <=
      '1' when C_ALU_SUB | C_ALU_SLT | C_ALU_SLTU | C_ALU_CLT | C_ALU_CLTU | C_ALU_CLE | C_ALU_CLEU | C_ALU_MIN | C_ALU_MAX,
      '0' when others;

  -- Camparison results.
  s_compare_eq <= '1' when i_src_a = i_src_b else '0';
  s_compare_ne <= not s_compare_eq;
  s_compare_lt <= s_adder_result(C_WORD_SIZE-1);
  s_compare_le <= s_compare_eq or s_compare_lt;
  s_compare_ltu <= not s_adder_carry_out;
  s_compare_leu <= s_compare_eq or s_compare_ltu;

  -- Set operations.
  s_slt_res(C_WORD_SIZE-1 downto 1) <= (others => '0');
  s_slt_res(0) <= s_compare_ltu when i_op = C_ALU_SLTU else s_compare_lt;

  -- Min/Max operations.
  s_is_max_op <= '1' when i_op = C_ALU_MAX else '0';
  s_minmax_res <= i_src_a when s_compare_lt = s_is_max_op else i_src_b;


  -- Compare operations.
  CmpMux: with i_op select
    s_cmp_bit <=
      s_compare_eq when C_ALU_CEQ,
      s_compare_ne when C_ALU_CNE,
      s_compare_lt when C_ALU_CLT,
      s_compare_ltu when C_ALU_CLTU,
      s_compare_le when C_ALU_CLE,
      s_compare_leu when C_ALU_CLEU,
      '0' when others;
  s_cmp_res <= (others => s_cmp_bit);


  ------------------------------------------------------------------------------------------------
  -- Shift operations
  ------------------------------------------------------------------------------------------------

  AluShifter: entity work.shift32
    port map (
      i_right => i_op(0),       -- '1' for C_ALU_LSR and C_ALU_ASR, '0' for C_ALU_LSL
      i_arithmetic => i_op(1),  -- '1' for C_ALU_ASR, '0' for C_ALU_LSR and C_ALU_LSL
      i_src => i_src_a,
      i_shift => i_src_b(4 downto 0),
      o_result => s_shifter_res
    );


  ------------------------------------------------------------------------------------------------
  -- Select the output.
  ------------------------------------------------------------------------------------------------

  AluMux: with i_op select
    o_result <=
        s_cpuid_res when C_ALU_CPUID,
        s_or_res when C_ALU_OR,
        s_nor_res when C_ALU_NOR,
        s_and_res when C_ALU_AND,
        s_bic_res when C_ALU_BIC,
        s_xor_res when C_ALU_XOR,
        s_minmax_res when C_ALU_MIN | C_ALU_MAX,
        s_adder_result when C_ALU_ADD | C_ALU_SUB,
        s_slt_res when C_ALU_SLT | C_ALU_SLTU,
        s_cmp_res when C_ALU_CEQ | C_ALU_CNE | C_ALU_CLT | C_ALU_CLTU | C_ALU_CLE | C_ALU_CLEU,
        s_shifter_res when C_ALU_LSR | C_ALU_ASR | C_ALU_LSL,
        s_shuf_res when C_ALU_SHUF,
        s_clz_res when C_ALU_CLZ,
        s_rev_res when C_ALU_REV,
        s_ldhi_res when C_ALU_LDHI | C_ALU_LDHIO,
        (others => '0') when others;

end rtl;

