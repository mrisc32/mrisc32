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
use work.types.all;
use work.config.all;

entity alu is
  port(
      i_op : in T_ALU_OP;                                      -- Operation
      i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);   -- Source operand A
      i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);   -- Source operand B
      i_packed_mode : in T_PACKED_MODE;                        -- Packed mode
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
  signal s_bitwise_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_set_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_min_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_max_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_minu_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_maxu_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_shuf_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_rev_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_pack_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ldi_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ldhi_fill_bit : std_logic;
  signal s_ldhi_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_addhi_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_clz_res : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Signals for the adder.
  signal s_add_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_sub_res : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Signals for packb/packh.
  signal s_packb_res : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_packh_res : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Signals for the shifter.
  signal s_shift_is_right : std_logic;
  signal s_shift_is_arithmetic : std_logic;
  signal s_shifter_res : std_logic_vector(C_WORD_SIZE-1 downto 0);

begin
  ------------------------------------------------------------------------------------------------
  -- CPUID
  ------------------------------------------------------------------------------------------------

  CPUID: entity work.cpuid
    port map (
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      o_result => s_cpuid_res
    );


  ------------------------------------------------------------------------------------------------
  -- Bitwise operations
  ------------------------------------------------------------------------------------------------

  -- C_ALU_OR
  s_or_res <= i_src_a or i_src_b;

  -- C_ALU_NOR
  s_nor_res <= not (i_src_a or i_src_b);

  -- C_ALU_AND
  s_and_res <= i_src_a and i_src_b;

  -- C_ALU_BIC
  s_bic_res <= i_src_a and (not i_src_b);

  -- C_ALU_XOR
  s_xor_res <= i_src_a xor i_src_b;

  -- We mux the bitwise operations together first (rather than adding them all to AluMux) since
  -- they have a very low complexity, thus giving us a better balance with the rest of the ALU.
  BitwiseMux: with i_op select
    s_bitwise_res <=
        s_or_res  when C_ALU_OR,
        s_nor_res when C_ALU_NOR,
        s_and_res when C_ALU_AND,
        s_bic_res when C_ALU_BIC,
        s_xor_res when C_ALU_XOR,
        (others => '-') when others;


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
  Rev: entity work.rev32
    port map (
      i_src => i_src_a,
      i_packed_mode => i_packed_mode,
      o_result => s_rev_res
    );

  -- C_ALU_PACKB, C_ALU_PACKH
  s_packb_res <= i_src_a(23 downto 16) & i_src_a(7 downto 0) & i_src_b(23 downto 16) & i_src_b(7 downto 0);
  s_packh_res <= i_src_a(15 downto 0) & i_src_b(15 downto 0);
  s_pack_res <= s_packb_res when i_op(0) = '0' else s_packh_res;

  -- C_ALU_LDI, C_ALU_LDHI, C_ALU_LDHIO
  -- Note: This MUX should be optimized by the synthesis tool to only depend on a single
  -- bit of i_op.
  LdhiFillBitMux: with i_op select
    s_ldhi_fill_bit <=
        '0' when C_ALU_LDHI,
        '1' when C_ALU_LDHIO,
        '-' when others;

  s_ldhi_res(C_WORD_SIZE-1 downto C_WORD_SIZE-21) <= i_src_b(20 downto 0);
  s_ldhi_res(C_WORD_SIZE-22 downto 0) <= (others => s_ldhi_fill_bit);

  s_ldi_res <= i_src_b when i_op = C_ALU_LDI else s_ldhi_res;

  -- C_ALU_CLZ
  AluCLZ32: entity work.clz32
    port map (
      i_src => i_src_a,
      i_packed_mode => i_packed_mode,
      o_result => s_clz_res
    );


  ------------------------------------------------------------------------------------------------
  -- Arithmetic operations
  ------------------------------------------------------------------------------------------------

  -- Add/sub.
  Adder: entity work.add32
    port map (
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      i_packed_mode => i_packed_mode,
      o_result => s_add_res
    );

  Subber: entity work.sub32
    port map (
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      i_packed_mode => i_packed_mode,
      o_result => s_sub_res
    );

  -- Comparison operations.
  Compare: entity work.cmp32
    port map (
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      i_op => i_op,
      i_packed_mode => i_packed_mode,
      o_set_res => s_set_res,
      o_min_res => s_min_res,
      o_max_res => s_max_res,
      o_minu_res => s_minu_res,
      o_maxu_res => s_maxu_res
    );

  -- Add high immediate (C_ALU_ADDHI): Add lower 21 bits of src_b to upper 21 bits of src_a.
  s_addhi_res(C_WORD_SIZE-1 downto C_WORD_SIZE-21) <=
      std_logic_vector(
          unsigned(i_src_b(20 downto 0)) + unsigned(i_src_a(C_WORD_SIZE-1 downto C_WORD_SIZE-21))
      );
  s_addhi_res(C_WORD_SIZE-22 downto 0) <= i_src_a(C_WORD_SIZE-22 downto 0);


  ------------------------------------------------------------------------------------------------
  -- Shift operations
  ------------------------------------------------------------------------------------------------

  -- Note: These MUX:es should be optimized by the synthesis tool to only depend on a single
  -- bit of i_op.
  ShiftIsRightMux: with i_op select
    s_shift_is_right <=
        '1' when C_ALU_LSR | C_ALU_ASR,
        '0' when C_ALU_LSL,
        '-' when others;

  ShiftIsArithmeticMux: with i_op select
    s_shift_is_arithmetic <=
        '1' when C_ALU_ASR,
        '0' when C_ALU_LSL | C_ALU_LSR,
        '-' when others;

  AluShifter: entity work.shift32
    port map (
      i_right => s_shift_is_right,
      i_arithmetic => s_shift_is_arithmetic,
      i_src => i_src_a,
      i_shift => i_src_b,
      i_packed_mode => i_packed_mode,
      o_result => s_shifter_res
    );


  ------------------------------------------------------------------------------------------------
  -- Select the output.
  ------------------------------------------------------------------------------------------------

  AluMux: with i_op select
    o_result <=
        s_cpuid_res when C_ALU_CPUID,
        s_bitwise_res when C_ALU_OR | C_ALU_NOR | C_ALU_AND | C_ALU_BIC | C_ALU_XOR,
        s_add_res when C_ALU_ADD,
        s_sub_res when C_ALU_SUB,
        s_set_res when C_ALU_SEQ | C_ALU_SNE | C_ALU_SLT | C_ALU_SLTU | C_ALU_SLE | C_ALU_SLEU,
        s_min_res when C_ALU_MIN,
        s_max_res when C_ALU_MAX,
        s_minu_res when C_ALU_MINU,
        s_maxu_res when C_ALU_MAXU,
        s_shifter_res when C_ALU_LSR | C_ALU_ASR | C_ALU_LSL,
        s_shuf_res when C_ALU_SHUF,
        s_clz_res when C_ALU_CLZ,
        s_rev_res when C_ALU_REV,
        s_pack_res when C_ALU_PACKB | C_ALU_PACKH,
        s_ldi_res when C_ALU_LDI | C_ALU_LDHI | C_ALU_LDHIO,
        s_addhi_res when C_ALU_ADDHI,
        (others => '-') when others;

end rtl;

