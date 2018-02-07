library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.consts.all;

entity alu is
  port(
      i_op : in alu_op_t;                                      -- Operation
      i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);   -- Source operand A
      i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);   -- Source operand B
      i_src_c : in std_logic_vector(C_WORD_SIZE-1 downto 0);   -- Source operand C
      o_result : out std_logic_vector(C_WORD_SIZE-1 downto 0)  -- ALU result
    );
end;
 
architecture rtl of alu is
  -- We use an adder.
  component adder
    generic(WIDTH : positive);
    port(
        i_c_in   : in  std_logic;
        i_src_a  : in  std_logic_vector(WIDTH-1 downto 0);
        i_src_b  : in  std_logic_vector(WIDTH-1 downto 0);
        o_result : out std_logic_vector(WIDTH-1 downto 0);
        o_c_out  : out std_logic
      );
  end component;

  -- We use a comparator.
  component comparator
    generic(WIDTH : positive);
    port(
        i_src : in  std_logic_vector(WIDTH-1 downto 0);
        o_eq  : out std_logic;
        o_lt  : out std_logic;
        o_le  : out std_logic
      );
  end component;

  -- We use a leading-zero counter.
  component clz32
    port(
        i_src : in  std_logic_vector(31 downto 0);
        o_cnt : out std_logic_vector(5 downto 0)
      );
  end component;

  -- We use a shifter.
  component shift32
    port(
        i_right      : in  std_logic;
        i_arithmetic : in  std_logic;
        i_src        : in  std_logic_vector(31 downto 0);
        i_shift      : in  std_logic_vector(4 downto 0);
        o_result     : out std_logic_vector(31 downto 0)
      );
  end component;

  -- Intermediate (concurrent) operation results.
  signal s_cpuid_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_or_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_nor_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_and_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_bic_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_xor_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_sel_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_slt_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_cmp_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_shuf_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_rev_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_extb_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_exth_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ldhi_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_clz_res : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Signals for the adder.
  signal s_adder_subtract : std_logic;
  signal s_adder_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_adder_carry_out : std_logic;

  -- Signals for the comparator.
  signal s_comparator_eq : std_logic;
  signal s_comparator_lt : std_logic;
  signal s_comparator_le : std_logic;
  signal s_cmp_bit : std_logic;

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

  -- OP_OR
  s_or_res <= i_src_a or i_src_b;

  -- OP_NOR
  s_nor_res <= not s_or_res;

  -- OP_AND
  s_and_res <= i_src_a and i_src_b;

  -- OP_BIC
  s_bic_res <= i_src_a and (not i_src_b);

  -- OP_XOR
  s_xor_res <= i_src_a xor i_src_b;

  -- OP_SEL
  s_sel_res <= (i_src_a and i_src_c) or (i_src_b and (not i_src_c));


  ------------------------------------------------------------------------------------------------
  -- Bit, byte and word shuffling
  ------------------------------------------------------------------------------------------------

  -- OP_SHUF
  ShufMux1: with i_src_b(2 downto 0) select
    s_shuf_res(7 downto 0) <=
      i_src_a(7 downto 0) when "000",
      i_src_a(15 downto 8) when "001",
      i_src_a(23 downto 16) when "010",
      i_src_a(31 downto 24) when "011",
      (others => '0') when others;
  ShufMux2: with i_src_b(5 downto 3) select
    s_shuf_res(15 downto 8) <=
      i_src_a(7 downto 0) when "000",
      i_src_a(15 downto 8) when "001",
      i_src_a(23 downto 16) when "010",
      i_src_a(31 downto 24) when "011",
      (others => '0') when others;
  ShufMux3: with i_src_b(8 downto 6) select
    s_shuf_res(23 downto 16) <=
      i_src_a(7 downto 0) when "000",
      i_src_a(15 downto 8) when "001",
      i_src_a(23 downto 16) when "010",
      i_src_a(31 downto 24) when "011",
      (others => '0') when others;
  ShufMux4: with i_src_b(11 downto 9) select
    s_shuf_res(31 downto 24) <=
      i_src_a(7 downto 0) when "000",
      i_src_a(15 downto 8) when "001",
      i_src_a(23 downto 16) when "010",
      i_src_a(31 downto 24) when "011",
      (others => '0') when others;

  -- OP_REV
  RevGen: for k in 0 to C_WORD_SIZE-1 generate
    s_rev_res(k) <= i_src_a(C_WORD_SIZE-1-k);
  end generate;

  -- OP_EXTB
  s_extb_res(C_WORD_SIZE-1 downto 8) <= (others => i_src_a(7));
  s_extb_res(7 downto 0) <= i_src_a(7 downto 0);

  -- OP_EXTH
  s_exth_res(C_WORD_SIZE-1 downto 16) <= (others => i_src_a(15));
  s_exth_res(15 downto 0) <= i_src_a(15 downto 0);

  -- OP_LDHI, OP_LDHIO
  s_ldhi_res(C_WORD_SIZE-1 downto C_WORD_SIZE-19) <= i_src_a(18 downto 0);
  s_ldhi_res(C_WORD_SIZE-20 downto 0) <= (others => i_op(1));  -- OP_LDHI="000000001", OP_LDHIO="000000010"

  -- OP_CLZ
  AluCLZ32: entity work.clz32
    port map (
      i_src => i_src_a,
      o_cnt => s_clz_res(5 downto 0)
    );
  s_clz_res(31 downto 6) <= (others => '0');


  ------------------------------------------------------------------------------------------------
  -- Arithmetic operations
  ------------------------------------------------------------------------------------------------

  -- TODO(m): Handle unsigned compares (SLTU, CLTU, CLEU).

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

  AluComparator: entity work.comparator
    generic map (
      WIDTH => C_WORD_SIZE
    )
    port map (
      i_src => s_adder_result,
      o_eq => s_comparator_eq,
      o_lt => s_comparator_lt,
      o_le => s_comparator_le
    );

  -- Select if we're doing addition or subtraction.
  NegAdderAMux: with i_op select
    s_adder_subtract <=
      '1' when OP_SUB | OP_SLT | OP_SLTU | OP_CEQ | OP_CLT | OP_CLTU | OP_CLE | OP_CLEU,
      '0' when others;

  -- Set operations.
  s_slt_res(C_WORD_SIZE-1 downto 1) <= (others => '0');
  s_slt_res(0) <= s_comparator_lt;

  -- Compare operations.
  CmpMux: with i_op select
    s_cmp_bit <=
      s_comparator_eq when OP_CEQ,
      s_comparator_lt when OP_CLT | OP_CLTU,
      s_comparator_le when OP_CLE | OP_CLEU,
      '0' when others;
  s_cmp_res <= (others => s_cmp_bit);


  ------------------------------------------------------------------------------------------------
  -- Shift operations
  ------------------------------------------------------------------------------------------------

  AluShifter: entity work.shift32
    port map (
      i_right => i_op(1),       -- '1' for OP_LSR and OP_ASR, '0' for OP_LSL
      i_arithmetic => i_op(0),  -- '1' for OP_ASR, '0' for OP_LSR and OP_LSL
      i_src => i_src_a,
      i_shift => i_src_b(4 downto 0),
      o_result => s_shifter_res
    );


  ------------------------------------------------------------------------------------------------
  -- Select the output.
  ------------------------------------------------------------------------------------------------

  AluMux: with i_op select
    o_result <=
        s_cpuid_res when OP_CPUID,
        s_or_res when OP_OR,
        s_nor_res when OP_NOR,
        s_and_res when OP_AND,
        s_bic_res when OP_BIC,
        s_xor_res when OP_XOR,
        s_sel_res when OP_SEL,
        s_adder_result when OP_ADD | OP_SUB,
        s_slt_res when OP_SLT | OP_SLTU,
        s_cmp_res when OP_CEQ | OP_CLT | OP_CLTU | OP_CLE | OP_CLEU,
        s_shifter_res when OP_LSR | OP_ASR | OP_LSL,
        s_shuf_res when OP_SHUF,
        s_clz_res when OP_CLZ,
        s_rev_res when OP_REV,
        s_extb_res when OP_EXTB,
        s_exth_res when OP_EXTH,
        s_ldhi_res when OP_LDHI | OP_LDHIO,
        (others => '0') when others;

end rtl;

