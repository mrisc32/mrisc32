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
-- Pipeline Stage 4: Register Fetch (RF)
--
-- Note: This entity also implements the WB stage (stage 8), since the register files live here.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity register_fetch is
  port(
      -- Control signals.
      i_clk : in std_logic;
      i_rst : in std_logic;
      i_stall : in std_logic;
      i_stall_id : in std_logic;  -- The stall signal to ID (we need it for the register files).
      o_stall : out std_logic;
      i_cancel : in std_logic;

      -- From the ID stage (async).
      i_next_sreg_a_reg : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      i_next_sreg_b_reg : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      i_next_sreg_c_reg : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      i_next_vreg_a_reg : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      i_next_vreg_a_element : in std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
      i_next_vreg_b_reg : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      i_next_vreg_b_element : in std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);

      -- From the ID stage (sync).
      i_branch_is_branch : in std_logic;
      i_branch_is_unconditional : in std_logic;
      i_branch_is_reg : in std_logic;
      i_branch_condition : in T_BRANCH_COND;

      i_reg_a_required : in std_logic;
      i_reg_b_required : in std_logic;
      i_reg_c_required : in std_logic;
      i_src_a_mode : in T_SRC_A_MODE;
      i_src_b_mode : in T_SRC_B_MODE;
      i_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_imm : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_is_first_vector_op_cycle : in std_logic;
      i_address_offset_is_stride : in std_logic;
      i_src_reg_a : in T_SRC_REG;
      i_src_reg_b : in T_SRC_REG;
      i_src_reg_c : in T_SRC_REG;
      i_dst_reg : in T_DST_REG;
      i_packed_mode : in T_PACKED_MODE;
      i_alu_op : in T_ALU_OP;
      i_mem_op : in T_MEM_OP;
      i_sau_op : in T_SAU_OP;
      i_mul_op : in T_MUL_OP;
      i_div_op : in T_DIV_OP;
      i_fpu_op : in T_FPU_OP;
      i_alu_en : in std_logic;
      i_mem_en : in std_logic;
      i_sau_en : in std_logic;
      i_mul_en : in std_logic;
      i_div_en : in std_logic;
      i_fpu_en : in std_logic;

      -- Information to the operand forwarding logic (async).
      o_src_reg_a : out T_SRC_REG;
      o_reg_a_required : out std_logic;
      o_src_reg_b : out T_SRC_REG;
      o_reg_b_required : out std_logic;
      o_src_reg_c : out T_SRC_REG;
      o_reg_c_required : out std_logic;

      -- Operand forwarding to the branch logic (async).
      i_branch_fwd_value : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_branch_fwd_use_value : in std_logic;
      i_branch_fwd_value_ready : in std_logic;

      -- Operand forwarding to EX1 input (async).
      i_reg_a_fwd_value : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_reg_a_fwd_use_value : in std_logic;
      i_reg_a_fwd_value_ready : in std_logic;
      i_reg_b_fwd_value : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_reg_b_fwd_use_value : in std_logic;
      i_reg_b_fwd_value_ready : in std_logic;
      i_reg_c_fwd_value : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_reg_c_fwd_use_value : in std_logic;
      i_reg_c_fwd_value_ready : in std_logic;

      -- WB data from the EX3 stage (async).
      i_wb_data_w : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_wb_we : in std_logic;
      i_wb_sel_w : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      i_wb_element_w : in std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
      i_wb_is_vector : in std_logic;

      -- Branch results to the EX1 stage (sync).
      o_branch_is_branch : out std_logic;
      o_branch_is_reg : out std_logic;  -- 1 for register branches, 0 for all other instructions.
      o_branch_offset_addr : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_branch_reg_addr : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_branch_is_taken : out std_logic;

      -- To the EX1 stage (sync).
      o_pc : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_pc_plus_4 : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_src_a : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_src_b : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_src_c : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_is_first_vector_op_cycle : out std_logic;
      o_address_offset_is_stride : out std_logic;
      o_dst_reg : out T_DST_REG;
      o_packed_mode : out T_PACKED_MODE;
      o_alu_op : out T_ALU_OP;
      o_mem_op : out T_MEM_OP;
      o_sau_op : out T_SAU_OP;
      o_mul_op : out T_MUL_OP;
      o_div_op : out T_DIV_OP;
      o_fpu_op : out T_FPU_OP;
      o_alu_en : out std_logic;
      o_mem_en : out std_logic;
      o_sau_en : out std_logic;
      o_mul_en : out std_logic;
      o_div_en : out std_logic;
      o_fpu_en : out std_logic
    );
end register_fetch;

architecture rtl of register_fetch is
  -- Branch condition signals.
  signal s_branch_is_conditional : std_logic;
  signal s_branch_cond_z : std_logic;
  signal s_branch_cond_nz : std_logic;
  signal s_branch_cond_s : std_logic;
  signal s_branch_cond_ns : std_logic;
  signal s_branch_cond_lt : std_logic;
  signal s_branch_cond_ge : std_logic;
  signal s_branch_cond_le : std_logic;
  signal s_branch_cond_gt : std_logic;

  signal s_branch_cond_true : std_logic;

  -- Branch target signals.
  signal s_branch_offset_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_branch_reg_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_branch_is_taken : std_logic;
  signal s_pc_plus_4 : std_logic_vector(C_WORD_SIZE-1 downto 0);

  signal s_stall_register_files : std_logic;

  -- Scalar register signals.
  signal s_scalar_we : std_logic;
  signal s_sreg_a_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_sreg_b_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_sreg_c_data : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Vector register signals.
  signal s_vector_we : std_logic;
  signal s_vreg_a_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_vreg_b_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_vreg_c_data : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Selected register values (scalar or vector).
  signal s_reg_a_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_reg_b_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_reg_c_data : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Signals to the EX stage.
  signal s_src_a_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_src_b_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_src_c_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_src_c : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Operand forwarding signals.
  signal s_missing_fwd_operand : std_logic;

  -- Signals for handling discarding of the current operation (i.e. bubble).
  signal s_bubble : std_logic;
  signal s_dst_reg_masked : T_DST_REG;
  signal s_alu_op_masked : T_ALU_OP;
  signal s_mem_op_masked : T_MEM_OP;
  signal s_alu_en_masked : std_logic;
  signal s_mem_en_masked : std_logic;
  signal s_sau_en_masked : std_logic;
  signal s_mul_en_masked : std_logic;
  signal s_div_en_masked : std_logic;
  signal s_fpu_en_masked : std_logic;
  signal s_branch_is_branch_masked : std_logic;
begin
  --------------------------------------------------------------------------------------------------
  -- Register files.
  --------------------------------------------------------------------------------------------------

  -- We need to stall the register files (latch the inputs) if the ID stage is being stalled. This
  -- is because the inputs to the register files coming from the ID stage come from *before* the ID
  -- pipeline stage output registers.
  s_stall_register_files <= i_stall_id;

  -- Instantiate the scalar register file.
  s_scalar_we <= i_wb_we and not i_wb_is_vector;
  regs_scalar_1: entity work.regs_scalar
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => s_stall_register_files,
      i_sel_a => i_next_sreg_a_reg,
      i_sel_b => i_next_sreg_b_reg,
      i_sel_c => i_next_sreg_c_reg,
      o_data_a => s_sreg_a_data,
      o_data_b => s_sreg_b_data,
      o_data_c => s_sreg_c_data,
      i_we => s_scalar_we,
      i_data_w => i_wb_data_w,
      i_sel_w => i_wb_sel_w,
      i_pc => i_pc
    );

  -- Instantiate the vector register file.
  s_vector_we <= i_wb_we and i_wb_is_vector;
  regs_vector_1: entity work.regs_vector
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => s_stall_register_files,
      i_sel_a => i_next_vreg_a_reg,
      i_element_a => i_next_vreg_a_element,
      i_sel_b => i_next_vreg_b_reg,
      i_element_b => i_next_vreg_b_element,
      o_data_a => s_vreg_a_data,
      o_data_b => s_vreg_b_data,
      i_we => s_vector_we,
      i_data_w => i_wb_data_w,
      i_sel_w => i_wb_sel_w,
      i_element_w => i_wb_element_w
    );

  -- Note: We reuse the A read port of the vector register file for the C register.
  s_vreg_c_data <= s_vreg_a_data;

  -- Select the register data to use (scalar vs vector).
  s_reg_a_data <= s_vreg_a_data when i_src_reg_a.is_vector = '1' else s_sreg_a_data;
  s_reg_b_data <= s_vreg_b_data when i_src_reg_b.is_vector = '1' else s_sreg_b_data;
  s_reg_c_data <= s_vreg_c_data when i_src_reg_c.is_vector = '1' else s_sreg_c_data;


  --------------------------------------------------------------------------------------------------
  -- Branch logic.
  --------------------------------------------------------------------------------------------------

  -- Conditional branch: B[cc]
  s_branch_is_conditional <= i_branch_is_branch and not i_branch_is_unconditional;

  -- Calculate the offset branch target.
  pc_plus_offset_0: entity work.pc_plus_offset
    generic map (OFFSET_SIZE => 21)
    port map (
      i_pc => i_pc,
      i_offset => i_imm(20 downto 0),
      o_result => s_branch_offset_addr
    );

  -- Calculate the expected PC if no branch is taken (i.e. PC + 4).
  -- This is used by the branch logic in the EX1 stage if the branch is not taken.
  pc_plus_4_0: entity work.pc_plus_4
    port map (
      i_pc => i_pc,
      o_result => s_pc_plus_4
    );

  -- Get the register content for branch logic (condition or target address).
  s_branch_reg_data <= i_branch_fwd_value when i_branch_fwd_use_value = '1' else s_sreg_c_data;

  -- Determine if a conditional (offset) branch is taken?
  branch_comparator_0: entity work.comparator
    generic map (WIDTH => C_WORD_SIZE)
    port map (
      i_src => s_branch_reg_data,
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

  s_branch_is_taken <= i_branch_is_unconditional or (s_branch_is_conditional and s_branch_cond_true);


  --------------------------------------------------------------------------------------------------
  -- Information for the operand forwarding logic.
  --------------------------------------------------------------------------------------------------

  o_src_reg_a <= i_src_reg_a;
  o_reg_a_required <= i_reg_a_required;
  o_src_reg_b <= i_src_reg_b;
  o_reg_b_required <= i_reg_b_required;
  o_src_reg_c <= i_src_reg_c;
  o_reg_c_required <= i_reg_c_required;


  --------------------------------------------------------------------------------------------------
  -- Prepare data for the EX stage.
  --------------------------------------------------------------------------------------------------

  -- Select source data for the EX stage.
  SrcAMux: with i_src_a_mode select
      s_src_a_data <= s_reg_a_data when C_SRC_A_REG,
                      i_imm        when C_SRC_A_IMM,
                      i_pc         when C_SRC_A_PC,
                      i_imm        when others;

  SrcBMux: with i_src_b_mode select
      s_src_b_data <= s_reg_b_data           when C_SRC_B_REG,
                      i_imm                  when C_SRC_B_IMM,
                      X"00000004"            when C_SRC_B_FOUR,
                      i_imm                  when others;

  s_src_c_data <= s_reg_c_data;

  -- Select data from decoding / register file or operand forwarding.
  s_src_a <= i_reg_a_fwd_value when i_reg_a_fwd_use_value = '1' else s_src_a_data;
  s_src_b <= i_reg_b_fwd_value when i_reg_b_fwd_use_value = '1' else s_src_b_data;
  s_src_c <= i_reg_c_fwd_value when i_reg_c_fwd_use_value = '1' else s_src_c_data;

  -- Are we missing any fwd operation that has not yet been produced by the pipeline?
  s_missing_fwd_operand <=
      (i_branch_is_branch and (i_branch_fwd_use_value and not i_branch_fwd_value_ready)) or
      (i_reg_a_required and (i_reg_a_fwd_use_value and not i_reg_a_fwd_value_ready)) or
      (i_reg_b_required and (i_reg_b_fwd_use_value and not i_reg_b_fwd_value_ready)) or
      (i_reg_c_required and (i_reg_c_fwd_use_value and not i_reg_c_fwd_value_ready));

  -- Should we discard the operation (i.e. send a bubble down the pipeline)?
  s_bubble <= i_cancel or s_missing_fwd_operand;
  s_dst_reg_masked.is_target <= i_dst_reg.is_target when s_bubble = '0' else '0';
  s_dst_reg_masked.reg <= i_dst_reg.reg when s_bubble = '0' else (others => '0');
  s_dst_reg_masked.element <= i_dst_reg.element when s_bubble = '0' else (others => '0');
  s_dst_reg_masked.is_vector <= i_dst_reg.is_vector when s_bubble = '0' else '0';
  s_alu_op_masked <= i_alu_op when s_bubble = '0' else (others => '0');
  s_mem_op_masked <= i_mem_op when s_bubble = '0' else (others => '0');
  s_alu_en_masked <= i_alu_en and not s_bubble;
  s_mem_en_masked <= i_mem_en and not s_bubble;
  s_sau_en_masked <= i_sau_en and not s_bubble;
  s_mul_en_masked <= i_mul_en and not s_bubble;
  s_div_en_masked <= i_div_en and not s_bubble;
  s_fpu_en_masked <= i_fpu_en and not s_bubble;
  s_branch_is_branch_masked <= i_branch_is_branch and not s_bubble;

  -- Outputs to the EX stage.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_pc <= (others => '0');
      o_pc_plus_4 <= (others => '0');
      o_src_a <= (others => '0');
      o_src_b <= (others => '0');
      o_src_c <= (others => '0');
      o_is_first_vector_op_cycle <= '0';
      o_address_offset_is_stride <= '0';
      o_dst_reg.is_target <= '0';
      o_dst_reg.reg <= (others => '0');
      o_dst_reg.element <= (others => '0');
      o_dst_reg.is_vector <= '0';
      o_packed_mode <= (others => '0');
      o_alu_op <= (others => '0');
      o_mem_op <= (others => '0');
      o_sau_op <= (others => '0');
      o_mul_op <= (others => '0');
      o_div_op <= (others => '0');
      o_fpu_op <= (others => '0');
      o_alu_en <= '0';
      o_mem_en <= '0';
      o_sau_en <= '0';
      o_mul_en <= '0';
      o_div_en <= '0';
      o_fpu_en <= '0';

      o_branch_reg_addr <= (others => '0');
      o_branch_offset_addr <= (others => '0');
      o_branch_is_branch <= '0';
      o_branch_is_reg <= '0';
      o_branch_is_taken <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        o_pc <= i_pc;
        o_pc_plus_4 <= s_pc_plus_4;
        o_src_a <= s_src_a;
        o_src_b <= s_src_b;
        o_src_c <= s_src_c;
        o_is_first_vector_op_cycle <= i_is_first_vector_op_cycle;
        o_address_offset_is_stride <= i_address_offset_is_stride;
        o_dst_reg <= s_dst_reg_masked;
        o_packed_mode <= i_packed_mode;
        o_alu_op <= s_alu_op_masked;
        o_mem_op <= s_mem_op_masked;
        o_sau_op <= i_sau_op;
        o_mul_op <= i_mul_op;
        o_div_op <= i_div_op;
        o_fpu_op <= i_fpu_op;
        o_alu_en <= s_alu_en_masked;
        o_mem_en <= s_mem_en_masked;
        o_sau_en <= s_sau_en_masked;
        o_mul_en <= s_mul_en_masked;
        o_div_en <= s_div_en_masked;
        o_fpu_en <= s_fpu_en_masked;

        o_branch_reg_addr <= s_branch_reg_data;
        o_branch_offset_addr <= s_branch_offset_addr;
        o_branch_is_branch <= s_branch_is_branch_masked;
        o_branch_is_reg <= i_branch_is_reg;
        o_branch_is_taken <= s_branch_is_taken;
      end if;
    end if;
  end process;

  -- Do we need to stall the pipeline (async)?
  o_stall <= s_missing_fwd_operand;
end rtl;
