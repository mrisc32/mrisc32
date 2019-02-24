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
-- Pipeline Stages 5, 6, 7 & 8: Execute (EX1/EX2/EX3/EX3)
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity execute is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    o_stall : out std_logic;

    -- PC signal from ID (sync).
    i_id_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- From RF stage (sync).
    i_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_src_c : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_is_first_vector_op_cycle : in std_logic;
    i_address_offset_is_stride : in std_logic;
    i_dst_reg : in T_DST_REG;
    i_packed_mode : in T_PACKED_MODE;
    i_alu_op : in T_ALU_OP;
    i_mem_op : in T_MEM_OP;
    i_sau_op : in T_SAU_OP;
    i_mul_op : in T_MUL_OP;
    i_div_op : in T_DIV_OP;
    i_fpu_op : in T_FPU_OP;
    i_alu_en : in std_logic;
    i_sau_en : in std_logic;
    i_mem_en : in std_logic;
    i_mul_en : in std_logic;
    i_div_en : in std_logic;
    i_fpu_en : in std_logic;

    -- Branch signals from RF (sync).
    i_branch_is_branch : in std_logic;
    i_branch_is_unconditional : in std_logic;
    i_branch_condition : in T_BRANCH_COND;
    i_branch_offset : in std_logic_vector(20 downto 0);
    i_branch_base_expected : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_branch_pc_plus_4 : in std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- Branch signals to PC (async).
    o_pccorr_target : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_pccorr_source : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_pccorr_is_branch : out std_logic;
    o_pccorr_is_taken : out std_logic;
    o_pccorr_adjust : out std_logic;
    o_pccorr_adjusted_pc : out std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- DCache interface.
    o_dcache_req : out std_logic;  -- 1 = request, 0 = nop
    o_dcache_we : out std_logic;   -- 1 = write, 0 = read
    o_dcache_byte_mask : out std_logic_vector(C_WORD_SIZE/8-1 downto 0);
    o_dcache_addr : out std_logic_vector(C_WORD_SIZE-1 downto 2);
    o_dcache_write_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_dcache_read_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_dcache_read_data_ready : in std_logic;

    -- Outputs from the different pipeline stages (async).
    o_ex1_next_dst_reg : out T_DST_REG;
    o_ex1_next_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_ex1_next_result_ready : out std_logic;
    o_ex2_next_dst_reg : out T_DST_REG;
    o_ex2_next_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_ex2_next_result_ready : out std_logic;
    o_ex3_next_dst_reg : out T_DST_REG;
    o_ex3_next_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_ex3_next_result_ready : out std_logic;
    o_ex4_next_dst_reg : out T_DST_REG;
    o_ex4_next_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- Outputs from the different pipeline stages (sync).
    o_ex1_dst_reg : out T_DST_REG;
    o_ex1_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_ex1_result_ready : out std_logic;
    o_ex2_dst_reg : out T_DST_REG;
    o_ex2_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_ex2_result_ready : out std_logic;
    o_ex3_dst_reg : out T_DST_REG;
    o_ex3_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_ex3_result_ready : out std_logic;
    o_ex4_dst_reg : out T_DST_REG;
    o_ex4_result : out std_logic_vector(C_WORD_SIZE-1 downto 0)
  );
end execute;

architecture rtl of execute is
  signal s_alu_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_agu_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_agu_address_is_result : std_logic;
  signal s_sau_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_sau_result_ready : std_logic;
  signal s_mul_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_mul_result_ready : std_logic;
  signal s_div_d3_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_div_d3_result_ready : std_logic;
  signal s_div_d4_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_div_d4_result_ready : std_logic;
  signal s_div_stall : std_logic;
  signal s_fpu_stall : std_logic;
  signal s_fpu_f1_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_fpu_f1_result_ready : std_logic;
  signal s_fpu_f3_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_fpu_f3_result_ready : std_logic;
  signal s_fpu_f4_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_fpu_f4_result_ready : std_logic;

  -- Should the EX pipeline be stalled?
  signal s_stall_ex : std_logic;
  signal s_stall_div : std_logic;
  signal s_stall_fpu : std_logic;

  -- Signals related to memory I/O.
  signal s_mem_byte_mask_unshifted : std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_mem_byte_mask : std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_mem_store_data : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Branch condition signals.
  signal s_branch_cond_z : std_logic;
  signal s_branch_cond_nz : std_logic;
  signal s_branch_cond_s : std_logic;
  signal s_branch_cond_ns : std_logic;
  signal s_branch_cond_lt : std_logic;
  signal s_branch_cond_ge : std_logic;
  signal s_branch_cond_le : std_logic;
  signal s_branch_cond_gt : std_logic;

  signal s_branch_cond_true : std_logic;

  -- Branch/PC correction signals.
  signal s_branch_is_taken : std_logic;
  signal s_branch_base : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_branch_target : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_next_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_mispredicted_pc : std_logic;

  -- Signals from the EX1 to the EX2 stage (async).
  signal s_ex1_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex1_next_result_ready : std_logic;
  signal s_ex1_next_mem_enable : std_logic;

  -- Signals from the EX1 to the EX2 stage (sync).
  signal s_ex1_mem_op : T_MEM_OP;
  signal s_ex1_mem_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex1_mem_enable : std_logic;
  signal s_ex1_mem_we : std_logic;
  signal s_ex1_mem_byte_mask : std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_ex1_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex1_result_ready : std_logic;
  signal s_ex1_store_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex1_dst_reg : T_DST_REG;

  -- Signals from the memory interface (async).
  signal s_mem_stall : std_logic;
  signal s_mem_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_mem_data_ready : std_logic;

  -- Signals from the EX2 to the EX3 stage (async).
  signal s_ex2_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex2_next_result_ready : std_logic;
  signal s_ex2_next_dst_reg : T_DST_REG;

  -- Signals from the EX2 to the EX3 stage (sync).
  signal s_ex2_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex2_result_ready : std_logic;
  signal s_ex2_dst_reg : T_DST_REG;

  -- Signals from the EX3 to the EX4 stage (async).
  signal s_ex3_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex3_next_result_ready : std_logic;
  signal s_ex3_next_dst_reg : T_DST_REG;

  -- Signals from the EX3 to the EX4 stage (sync).
  signal s_ex3_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex3_result_ready : std_logic;
  signal s_ex3_dst_reg : T_DST_REG;

  -- Signals from the EX4 stage (async).
  signal s_ex4_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  --------------------------------------------------------------------------------------------------
  -- Branch logic.
  --------------------------------------------------------------------------------------------------

  -- Calculate the branch target.
  s_branch_base <= i_src_c when i_branch_is_unconditional = '1' else i_pc;
  pc_plus_offset_0: entity work.pc_plus_offset
    generic map (OFFSET_SIZE => 21)
    port map (
      i_pc => s_branch_base,
      i_offset => i_branch_offset,
      o_result => s_branch_target
    );

  -- Determine if a conditional branch is taken?
  branch_comparator_0: entity work.comparator
    generic map (WIDTH => C_WORD_SIZE)
    port map (
      i_src => i_src_c,
      o_z  => s_branch_cond_z,
      o_nz => s_branch_cond_nz,
      o_s  => s_branch_cond_s,
      o_ns => s_branch_cond_ns,
      o_lt => s_branch_cond_lt,
      o_ge => s_branch_cond_ge,
      o_le => s_branch_cond_le,
      o_gt => s_branch_cond_gt
    );

  BranchCondMux: with i_branch_condition select
    s_branch_cond_true <=
        s_branch_cond_z  when C_BRANCH_BZ,
        s_branch_cond_nz when C_BRANCH_NZ,
        s_branch_cond_s  when C_BRANCH_S,
        s_branch_cond_ns when C_BRANCH_NS,
        s_branch_cond_lt when C_BRANCH_LT,
        s_branch_cond_ge when C_BRANCH_GE,
        s_branch_cond_le when C_BRANCH_LE,
        s_branch_cond_gt when C_BRANCH_GT,
        '0' when others;

  -- A branch is taken if it's either:
  --   a) an unconditional branch, or
  --   b) a conditional branch and the branch condition is true
  s_branch_is_taken <= i_branch_is_unconditional or (i_branch_is_branch and s_branch_cond_true);

  -- Determine the next PC address.
  s_next_pc <= s_branch_target when s_branch_is_taken = '1' else
               i_branch_pc_plus_4;

  -- A branch was correctly predicted if it's either:
  --   a) a taken branch and the branch base was the expected base, or
  --   b) an untaken branch and the next PC equals this PC + 4, or
  --   c) not a branch at all
  s_mispredicted_pc <= '0' when
      (s_branch_is_taken = '1' and i_branch_base_expected = s_branch_base) or
      (s_branch_is_taken = '0' and i_branch_pc_plus_4 = i_id_pc) or
      (i_branch_is_branch = '0')
      else '1';

  -- Branch/PC correction signals to the PC stage.
  o_pccorr_target <= s_branch_target;
  o_pccorr_source <= i_pc;
  o_pccorr_is_branch <= i_branch_is_branch;
  o_pccorr_is_taken <= s_branch_is_taken;
  o_pccorr_adjust <= s_mispredicted_pc;
  o_pccorr_adjusted_pc <= s_next_pc;


  --------------------------------------------------------------------------------------------------
  -- Multi cycle units: SAU (2 cycles), MUL (3 cycles), DIV (3+ cycles), FPU (1/4 cycles).
  --------------------------------------------------------------------------------------------------

  -- Instantiate the saturating arithmetic unit.
  SAU_GEN: if C_CPU_HAS_SA generate
    sau_1: entity work.sau
      port map (
        i_clk => i_clk,
        i_rst => i_rst,
        i_stall => s_stall_ex,
        i_enable => i_sau_en,
        i_op => i_sau_op,
        i_packed_mode => i_packed_mode,
        i_src_a => i_src_a,
        i_src_b => i_src_b,
        o_next_result => s_sau_result,
        o_next_result_ready => s_sau_result_ready
      );
  else generate
    s_sau_result <= (others => '0');
    s_sau_result_ready <= '0';
  end generate;

  -- Instantiate the multiply unit.
  MUL_GEN: if C_CPU_HAS_MUL generate
    mul_1: entity work.mul
      port map (
        i_clk => i_clk,
        i_rst => i_rst,
        i_stall => s_stall_ex,
        i_enable => i_mul_en,
        i_op => i_mul_op,
        i_packed_mode => i_packed_mode,
        i_src_a => i_src_a,
        i_src_b => i_src_b,
        o_result => s_mul_result,
        o_result_ready => s_mul_result_ready
      );
  else generate
    s_mul_result <= (others => '0');
    s_mul_result_ready <= '0';
  end generate;

  -- Instantiate the division unit.
  DIV_GEN: if C_CPU_HAS_DIV generate
    div_1: entity work.div
      port map (
        i_clk => i_clk,
        i_rst => i_rst,
        i_stall => s_stall_div,
        o_stall => s_div_stall,
        i_enable => i_div_en,
        i_op => i_div_op,
        i_packed_mode => i_packed_mode,
        i_src_a => i_src_a,
        i_src_b => i_src_b,
        o_d3_next_result => s_div_d3_result,
        o_d3_next_result_ready => s_div_d3_result_ready,
        o_d4_next_result => s_div_d4_result,
        o_d4_next_result_ready => s_div_d4_result_ready
      );
  else generate
    s_div_stall <= '0';
    s_div_d3_result <= (others => '0');
    s_div_d3_result_ready <= '0';
    s_div_d4_result <= (others => '0');
    s_div_d4_result_ready <= '0';
  end generate;

  -- Instantiate the floating point unit.
  FPU_GEN: if C_CPU_HAS_FP generate
    fpu_1: entity work.fpu
      port map (
        i_clk => i_clk,
        i_rst => i_rst,
        i_stall => s_stall_fpu,
        o_stall => s_fpu_stall,
        i_enable => i_fpu_en,
        i_op => i_fpu_op,
        i_packed_mode => i_packed_mode,
        i_src_a => i_src_a,
        i_src_b => i_src_b,
        o_f1_next_result => s_fpu_f1_result,
        o_f1_next_result_ready => s_fpu_f1_result_ready,
        o_f3_next_result => s_fpu_f3_result,
        o_f3_next_result_ready => s_fpu_f3_result_ready,
        o_f4_next_result => s_fpu_f4_result,
        o_f4_next_result_ready => s_fpu_f4_result_ready
      );
  else generate
    s_fpu_stall <= '0';
    s_fpu_f1_result <= (others => '0');
    s_fpu_f1_result_ready <= '0';
    s_fpu_f3_result <= (others => '0');
    s_fpu_f3_result_ready <= '0';
    s_fpu_f4_result <= (others => '0');
    s_fpu_f4_result_ready <= '0';
  end generate;


  --------------------------------------------------------------------------------------------------
  -- EX1: ALU, FPU (single cycle operations), AGU, memory store preparation.
  --------------------------------------------------------------------------------------------------

  -- Instantiate the ALU (arithmetic logic unit).
  alu_1: entity work.alu
    port map (
      i_op => i_alu_op,
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      i_packed_mode => i_packed_mode,
      o_result => s_alu_result
    );

  -- Instantiate the AGU (address generation unit).
  agu_1: entity work.agu
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => s_stall_ex,

      i_is_first_vector_op_cycle => i_is_first_vector_op_cycle,
      i_address_offset_is_stride => i_address_offset_is_stride,
      i_base => i_src_a,
      i_offset => i_src_b,
      i_offset_shift => i_packed_mode,
      o_result => s_agu_result
    );

  -- Should the AGU result be used for the memory unit or directly?
  s_agu_address_is_result <= i_mem_en when i_mem_op = C_MEM_OP_LDSTRD else '0';
  s_ex1_next_mem_enable <= i_mem_en and not s_agu_address_is_result;

  -- Prepare the byte mask for the MEM stage.
  ByteMaskMux: with i_mem_op(1 downto 0) select
    s_mem_byte_mask_unshifted <=
      "0001" when "01",    -- byte
      "0011" when "10",    -- halfword
      "1111" when others;  -- word (11) and undefined (00)

  ByteMaskShiftMux: with s_agu_result(1 downto 0) select
    s_mem_byte_mask <=
      s_mem_byte_mask_unshifted(3 downto 0)         when "00",
      s_mem_byte_mask_unshifted(2 downto 0) & "0"   when "01",
      s_mem_byte_mask_unshifted(1 downto 0) & "00"  when "10",
      s_mem_byte_mask_unshifted(0 downto 0) & "000" when others;  -- "11"

  -- Prepare the store data for the MEM stage (shift it into position).
  StoreDataShiftMux: with s_agu_result(1 downto 0) select
    s_mem_store_data <=
      i_src_c(31 downto 0)             when "00",
      i_src_c(23 downto 0) & X"00"     when "01",
      i_src_c(15 downto 0) & X"0000"   when "10",
      i_src_c(7 downto 0)  & X"000000" when others;  -- "11"

  -- Select the result from the EX1 stage.
  s_ex1_next_result <= s_fpu_f1_result when s_fpu_f1_result_ready = '1' else
                       s_agu_result when s_agu_address_is_result = '1' else
                       s_alu_result;
  s_ex1_next_result_ready <= s_fpu_f1_result_ready or s_agu_address_is_result or i_alu_en;

  -- Outputs to the EX2 stage (sync).
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_ex1_mem_op <= (others => '0');
      s_ex1_mem_addr <= (others => '0');
      s_ex1_mem_enable <= '0';
      s_ex1_mem_we <= '0';
      s_ex1_mem_byte_mask <= (others => '0');
      s_ex1_result <= (others => '0');
      s_ex1_result_ready <= '0';
      s_ex1_store_data <= (others => '0');
      s_ex1_dst_reg.is_target <= '0';
      s_ex1_dst_reg.reg <= (others => '0');
      s_ex1_dst_reg.element <= (others => '0');
      s_ex1_dst_reg.is_vector <= '0';
    elsif rising_edge(i_clk) then
      if s_stall_ex = '0' then
        s_ex1_mem_op <= i_mem_op;
        s_ex1_mem_addr <= s_agu_result;
        s_ex1_mem_enable <= s_ex1_next_mem_enable;
        s_ex1_mem_we <= i_mem_op(3);
        s_ex1_mem_byte_mask <= s_mem_byte_mask;
        s_ex1_result <= s_ex1_next_result;
        s_ex1_result_ready <= s_ex1_next_result_ready;
        s_ex1_store_data <= s_mem_store_data;
        s_ex1_dst_reg <= i_dst_reg;
      end if;
    end if;
  end process;

  -- Output the EX1 result to operand forwarding logic.
  -- Async:
  o_ex1_next_dst_reg <= i_dst_reg;
  o_ex1_next_result <= s_ex1_next_result;
  o_ex1_next_result_ready <= s_ex1_next_result_ready;

  -- Sync:
  o_ex1_dst_reg <= s_ex1_dst_reg;
  o_ex1_result <= s_ex1_result;
  o_ex1_result_ready <= s_ex1_result_ready;


  --------------------------------------------------------------------------------------------------
  -- EX2: Memory.
  --------------------------------------------------------------------------------------------------

  memory_0: entity work.memory
    port map (
      o_stall => s_mem_stall,

      -- From EX1 stage (sync).
      i_mem_op => s_ex1_mem_op,
      i_mem_enable => s_ex1_mem_enable,
      i_mem_we => s_ex1_mem_we,
      i_mem_byte_mask => s_ex1_mem_byte_mask,
      i_mem_addr => s_ex1_mem_addr,
      i_store_data => s_ex1_store_data,

      -- DCache interface.
      o_dcache_req => o_dcache_req,
      o_dcache_we => o_dcache_we,
      o_dcache_byte_mask => o_dcache_byte_mask,
      o_dcache_addr => o_dcache_addr,
      o_dcache_write_data => o_dcache_write_data,
      i_dcache_read_data => i_dcache_read_data,
      i_dcache_read_data_ready => i_dcache_read_data_ready,

      -- Memory read data (async).
      o_data => s_mem_data,
      o_data_ready => s_mem_data_ready
    );

  -- Select the result from the EX2 stage.
  s_ex2_next_result <= s_mem_data when s_mem_data_ready = '1' else
                       s_sau_result when s_sau_result_ready = '1' else
                       s_ex1_result;
  s_ex2_next_result_ready <= s_mem_data_ready or
                             s_sau_result_ready or
                             s_ex1_result_ready;

  -- Outputs to the EX3 stage (sync).
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_ex2_result <= (others => '0');
      s_ex2_result_ready <= '0';
      s_ex2_dst_reg.is_target <= '0';
      s_ex2_dst_reg.reg <= (others => '0');
      s_ex2_dst_reg.element <= (others => '0');
      s_ex2_dst_reg.is_vector <= '0';
    elsif rising_edge(i_clk) then
      if s_stall_ex = '0' then
        s_ex2_result <= s_ex2_next_result;
        s_ex2_result_ready <= s_ex2_next_result_ready;
        s_ex2_dst_reg <= s_ex1_dst_reg;
      end if;
    end if;
  end process;

  -- Output the EX2 result to operand forwarding logic.
  -- Async:
  o_ex2_next_dst_reg <= s_ex1_dst_reg;
  o_ex2_next_result <= s_ex2_next_result;
  o_ex2_next_result_ready <= s_ex2_next_result_ready;

  -- Sync:
  o_ex2_dst_reg <= s_ex2_dst_reg;
  o_ex2_result <= s_ex2_result;
  o_ex2_result_ready <= s_ex2_result_ready;


  --------------------------------------------------------------------------------------------------
  -- EX3: MUL, DIV & FPU (3-cycle operations).
  --------------------------------------------------------------------------------------------------

  -- Select the EX2, MUL or DIV result.
  s_ex3_next_result <= s_div_d3_result when s_div_d3_result_ready = '1' else
                       s_mul_result when s_mul_result_ready = '1' else
                       s_fpu_f3_result when s_fpu_f3_result_ready = '1' else
                       s_ex2_result;
  s_ex3_next_result_ready <= s_div_d3_result_ready or
                             s_mul_result_ready or
                             s_fpu_f3_result_ready or
                             s_ex2_result_ready;

  -- Outputs from the EX3 stage (sync).
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_ex3_result <= (others => '0');
      s_ex3_result_ready <= '0';
      s_ex3_dst_reg.is_target <= '0';
      s_ex3_dst_reg.reg <= (others => '0');
      s_ex3_dst_reg.element <= (others => '0');
      s_ex3_dst_reg.is_vector <= '0';
    elsif rising_edge(i_clk) then
      if s_stall_ex = '0' then
        s_ex3_result <= s_ex3_next_result;
        s_ex3_result_ready <= s_ex3_next_result_ready;
        s_ex3_dst_reg <= s_ex2_dst_reg;
      end if;
    end if;
  end process;

  -- Output the EX3 result to operand forwarding logic.
  -- Async:
  o_ex3_next_dst_reg <= s_ex2_dst_reg;
  o_ex3_next_result <= s_ex3_next_result;
  o_ex3_next_result_ready <= s_ex3_next_result_ready;

  -- Sync:
  o_ex3_dst_reg <= s_ex3_dst_reg;
  o_ex3_result <= s_ex3_result;
  o_ex3_result_ready <= s_ex3_result_ready;


  --------------------------------------------------------------------------------------------------
  -- EX4: FPU & FDIV (4-cycle operations).
  --------------------------------------------------------------------------------------------------

  -- Select the EX3 or FPU result.
  s_ex4_next_result <= s_fpu_f4_result when s_fpu_f4_result_ready = '1' else
                       s_div_d4_result when s_div_d4_result_ready = '1' else
                       s_ex3_result;

  -- Outputs from the EX4 stage (sync).
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_ex4_result <= (others => '0');
      o_ex4_dst_reg.is_target <= '0';
      o_ex4_dst_reg.reg <= (others => '0');
      o_ex4_dst_reg.element <= (others => '0');
      o_ex4_dst_reg.is_vector <= '0';
    elsif rising_edge(i_clk) then
      if s_stall_ex = '0' then
        o_ex4_result <= s_ex4_next_result;
        o_ex4_dst_reg <= s_ex3_dst_reg;
      end if;
    end if;
  end process;

  -- Output the EX4 result to operand forwarding logic (async).
  o_ex4_next_dst_reg <= s_ex3_dst_reg;
  o_ex4_next_result <= s_ex4_next_result;

  -- Stall logic (async).
  s_stall_ex <= s_mem_stall or s_div_stall or s_fpu_stall;
  s_stall_div <= s_mem_stall or s_fpu_stall;
  s_stall_fpu <= s_mem_stall or s_div_stall;
  o_stall <= s_stall_ex;
end rtl;
