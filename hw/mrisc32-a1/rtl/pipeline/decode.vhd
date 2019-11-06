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
-- Pipeline Stage 3: Instruction Decode (ID)
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.types.all;
use work.config.all;

entity decode is
  port(
      -- Control signals.
      i_clk : in std_logic;
      i_rst : in std_logic;
      i_stall : in std_logic;
      o_stall : out std_logic;
      i_cancel : in std_logic;
      o_bubble : out std_logic;  -- Only informational: The decode stage will generate NOP:s for
                                 -- every bubble, so this signal is not strictly necessary.

      -- From the IF stage (sync).
      i_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_instr : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_bubble : in std_logic;  -- 1 if IF could not provide a new instruction.

      -- Information to the operand forwarding logic (async).
      o_vl_requested : out std_logic;

      -- Operand forwarding to the vector control unit.
      i_vl_fwd_value : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_vl_fwd_use_value : in std_logic;
      i_vl_fwd_value_ready : in std_logic;

      -- WB data from the EX3 stage (async).
      i_wb_data_w : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_wb_we : in std_logic;
      i_wb_sel_w : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      i_wb_is_vector : in std_logic;

      -- To the RF stage (async).
      o_next_sreg_a_reg : out std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      o_next_sreg_b_reg : out std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      o_next_sreg_c_reg : out std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      o_next_vreg_a_reg : out std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      o_next_vreg_a_element : out std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
      o_next_vreg_b_reg : out std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      o_next_vreg_b_element : out std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);

      -- To the RF stage (sync).
      o_branch_is_branch : out std_logic;
      o_branch_is_unconditional : out std_logic;
      o_branch_condition : out T_BRANCH_COND;
      o_branch_offset : out std_logic_vector(20 downto 0);

      o_reg_a_required : out std_logic;
      o_reg_b_required : out std_logic;
      o_reg_c_required : out std_logic;
      o_src_a_mode : out T_SRC_A_MODE;
      o_src_b_mode : out T_SRC_B_MODE;
      o_pc : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_imm : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_is_first_vector_op_cycle : out std_logic;
      o_address_offset_is_stride : out std_logic;
      o_src_reg_a : out T_SRC_REG;
      o_src_reg_b : out T_SRC_REG;
      o_src_reg_c : out T_SRC_REG;
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
end decode;

architecture rtl of decode is
  -- Instruction decode signals.
  signal s_op_high : std_logic_vector(5 downto 0);
  signal s_op_low : std_logic_vector(6 downto 0);
  signal s_reg_a : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_reg_b : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_reg_c : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_imm_from_instr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_imm : std_logic_vector(C_WORD_SIZE-1 downto 0);

  signal s_is_type_a : std_logic;
  signal s_is_type_b : std_logic;
  signal s_is_type_c : std_logic;
  signal s_is_type_d : std_logic;

  signal s_vector_mode : std_logic_vector(1 downto 0);
  signal s_is_vector_op : std_logic;
  signal s_reg_a_is_vector : std_logic;
  signal s_reg_b_is_vector : std_logic;
  signal s_reg_c_is_vector : std_logic;
  signal s_is_folding_vector_op : std_logic;
  signal s_is_vector_stride_mem_op : std_logic;
  signal s_stall_vector_control : std_logic;
  signal s_element_a : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
  signal s_element_b : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
  signal s_element_c : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
  signal s_is_vector_op_busy : std_logic;
  signal s_is_first_vector_op_cycle : std_logic;
  signal s_address_offset_is_stride : std_logic;
  signal s_bubble_from_vector_op : std_logic;

  signal s_packed_mode : T_PACKED_MODE;

  signal s_is_unconditional_branch : std_logic;
  signal s_is_conditional_branch : std_logic;
  signal s_is_branch : std_logic;
  signal s_is_link_branch : std_logic;
  signal s_branch_condition : T_BRANCH_COND;
  signal s_branch_offset : std_logic_vector(20 downto 0);

  signal s_mem_op_type : std_logic_vector(1 downto 0);
  signal s_is_mem_op : std_logic;
  signal s_is_mem_store : std_logic;

  signal s_is_fdiv : std_logic;
  signal s_is_sau_op : std_logic;
  signal s_is_mul_op : std_logic;
  signal s_is_div_op : std_logic;
  signal s_is_fpu_op : std_logic;

  signal s_is_ldi : std_logic;
  signal s_is_ldhi : std_logic;
  signal s_is_ldhio : std_logic;
  signal s_is_addpchi : std_logic;

  signal s_is_type_b_alu : std_logic;
  signal s_func : std_logic_vector(5 downto 0);

  -- VL register signals.
  signal s_vl_we : std_logic;
  signal s_vl_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_vl_data_or_fwd : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_missing_fwd_operand : std_logic;

  -- Signals to the RF stage.
  signal s_reg_a_required : std_logic;
  signal s_reg_b_required : std_logic;
  signal s_reg_c_required : std_logic;
  signal s_src_a_mode : T_SRC_A_MODE;
  signal s_src_b_mode : T_SRC_B_MODE;
  signal s_dst_reg : T_DST_REG;
  signal s_alu_op : T_ALU_OP;
  signal s_mem_op : T_MEM_OP;
  signal s_sau_op : T_SAU_OP;
  signal s_mul_op : T_MUL_OP;
  signal s_div_op : T_DIV_OP;
  signal s_fpu_op : T_FPU_OP;
  signal s_alu_en : std_logic;
  signal s_mem_en : std_logic;
  signal s_sau_en : std_logic;
  signal s_mul_en : std_logic;
  signal s_div_en : std_logic;
  signal s_fpu_en : std_logic;

  -- Signals for handling discarding of the current operation (i.e. bubble).
  signal s_bubble : std_logic;
  signal s_reg_a_required_masked : std_logic;
  signal s_reg_b_required_masked : std_logic;
  signal s_reg_c_required_masked : std_logic;
  signal s_dst_reg_masked : T_DST_REG;
  signal s_alu_op_masked : T_ALU_OP;
  signal s_mem_op_masked : T_MEM_OP;
  signal s_alu_en_masked : std_logic;
  signal s_mem_en_masked : std_logic;
  signal s_sau_en_masked : std_logic;
  signal s_mul_en_masked : std_logic;
  signal s_div_en_masked : std_logic;
  signal s_fpu_en_masked : std_logic;
  signal s_is_branch_masked : std_logic;
begin
  --------------------------------------------------------------------------------------------------
  -- Instruction decoding.
  --------------------------------------------------------------------------------------------------

  -- Extract operation codes.
  s_op_high <= i_instr(31 downto 26);
  s_op_low <= i_instr(6 downto 0);

  -- Determine encoding type.
  s_is_type_a <= '1' when s_op_high = "000000" and s_op_low(6 downto 2) /= "11111" else '0';
  s_is_type_b <= '1' when s_op_high = "000000" and s_op_low(6 downto 2) = "11111" else '0';
  s_is_type_c <= '1' when s_op_high /= "000000" and s_op_high(5 downto 4) /= "11" else '0';
  s_is_type_d <= '1' when s_op_high(5 downto 4) = "11" else '0';

  -- Extract immediate.
  s_imm_from_instr(14 downto 0) <= i_instr(14 downto 0);
  s_imm_from_instr(20 downto 15) <= i_instr(20 downto 15) when s_is_type_d = '1' else (others => i_instr(14));
  s_imm_from_instr(31 downto 21) <= (others => s_imm_from_instr(20));

  -- Extract register numbers.
  s_reg_a <= i_instr(20 downto 16);
  s_reg_b <= i_instr(13 downto 9);
  s_reg_c <= i_instr(25 downto 21);  -- Usually destination, somtimes source.

  -- Determine MEM operation.
  s_mem_op_type(0) <= s_is_type_a when (s_op_low(6 downto 4) = "000") and (s_op_low(3 downto 0) /= "0000") else '0';
  s_mem_op_type(1) <= s_is_type_c when (s_op_high(5 downto 4) = "00") else '0';
  MemOpMux: with s_mem_op_type select
    s_mem_op <=
        s_op_low(3 downto 0) when "01",    -- Addr = reg + reg
        s_op_high(3 downto 0) when "10",   -- Addr = reg + imm
        (others => '0') when others;
  s_is_mem_op <= s_mem_op_type(0) or s_mem_op_type(1);
  s_is_mem_store <= s_is_mem_op and s_mem_op(3);

  -- Is this an immediate load?
  s_is_ldi     <= '1' when s_op_high = 6X"3a" else '0';
  s_is_ldhi    <= '1' when s_op_high = 6X"3b" else '0';
  s_is_ldhio   <= '1' when s_op_high = 6X"3c" else '0';
  s_is_addpchi <= '1' when s_op_high = 6X"3d" else '0';

  -- Is this a two-operand operation?
  s_func <= i_instr(14 downto 9) when s_is_type_b = '1' else (others => '0');
  s_is_type_b_alu <= '1' when (s_is_type_b = '1' and s_op_low(1 downto 0) = "00") else '0';

  -- Is this FDIV?
  s_is_fdiv <= '1' when (s_is_type_a = '1' and s_op_low = "11" & C_FPU_FDIV) else '0';

  -- Is this a SAU, MUL, DIV or FPU op?
  s_is_sau_op <= '1' when s_is_type_a = '1' and s_op_low(6 downto 3) = "0111" else '0';
  s_is_mul_op <= '1' when s_is_type_a = '1' and s_op_low(6 downto 2) = "10000" else '0';
  s_is_div_op <= '1' when (s_is_type_a = '1' and s_op_low(6 downto 2) = "10001") or s_is_fdiv = '1' else '0';
  s_is_fpu_op <= '1' when s_is_type_a = '1' and s_op_low(6 downto 5) = "11" and s_is_fdiv = '0' else '0';

  -- Determine vector mode.
  s_vector_mode(1) <= i_instr(15) and not s_is_type_d;
  s_vector_mode(0) <= i_instr(14) and s_is_type_a;
  s_is_vector_op <= '1' when s_vector_mode /= "00" and (i_bubble or i_cancel) = '0' else '0';
  s_reg_a_is_vector <= s_is_vector_op and not s_is_mem_op;
  s_reg_b_is_vector <= s_vector_mode(0);
  s_reg_c_is_vector <= s_is_vector_op;
  s_is_folding_vector_op <= '1' when s_vector_mode = "01" else '0';
  s_is_vector_stride_mem_op <= s_is_mem_op and s_is_vector_op and (not s_reg_b_is_vector);

  -- Determine packed mode.
  -- Note: Only instructions that support packed operation will care about this value, so it is safe
  -- to just pick bits 7 and 8 from the instruction word without masking against instruction type,
  -- as long as this is a format A instruction.
  s_packed_mode <= i_instr(8 downto 7) when s_is_type_a = '1' or s_is_type_b = '1' else C_PACKED_NONE;

  -- What source registers are required for this operation?
  s_reg_a_required <= s_is_type_a or s_is_type_b or s_is_type_c;
  s_reg_b_required <= s_is_type_a;
  s_reg_c_required <= s_is_mem_store or s_is_branch;

  -- Is this a stride offset or regular offset memory addressing mode instruction?
  s_address_offset_is_stride <= s_is_vector_stride_mem_op;


  --------------------------------------------------------------------------------------------------
  -- Vector control logic.
  --------------------------------------------------------------------------------------------------

  -- Instantiate a register that holds the VL data (a mirror of the corresponding register in the
  -- scalar register file).
  s_vl_we <= (i_wb_we and not (i_stall or i_wb_is_vector)) when i_wb_sel_w = to_vector(C_VL_REG, C_LOG2_NUM_REGS) else '0';
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_vl_data <= (others => '0');
    elsif rising_edge(i_clk) then
      if s_vl_we = '1' then
        s_vl_data <= i_wb_data_w;
      end if;
    end if;
  end process;

  -- Operand forwarding of VL.
  s_vl_data_or_fwd <= i_vl_fwd_value when i_vl_fwd_use_value = '1' else s_vl_data;

  -- Instantiate the vector control unit.
  VCTRL_GEN: if C_CPU_HAS_VEC generate
    -- Stall the vector control unit?
    s_stall_vector_control <= i_stall or (i_vl_fwd_use_value and not i_vl_fwd_value_ready);

    vector_control_1: entity work.vector_control
      port map (
        i_clk => i_clk,
        i_rst => i_rst,
        i_stall => s_stall_vector_control,
        i_cancel => i_cancel,
        i_is_vector_op => s_is_vector_op,
        i_vl => s_vl_data_or_fwd,
        i_fold => s_is_folding_vector_op,
        o_element_a => s_element_a,
        o_element_b => s_element_b,
        o_is_vector_op_busy => s_is_vector_op_busy,
        o_is_first_vector_op_cycle => s_is_first_vector_op_cycle,
        o_bubble => s_bubble_from_vector_op
      );
  else generate
    s_element_a <= (others => '0');
    s_element_b <= (others => '0');
    s_is_vector_op_busy <= '0';
    s_is_first_vector_op_cycle <= '0';
    s_bubble_from_vector_op <= '0';
  end generate;

  -- The target (write) element index is always the same as the src A element index.
  s_element_c <= s_element_a;


  --------------------------------------------------------------------------------------------------
  -- Decode branch instructions.
  --------------------------------------------------------------------------------------------------

  -- Unconditional branch: J, JL
  s_is_unconditional_branch <= (not i_bubble) when s_op_high(5 downto 1) = "11100" else '0';
  s_is_link_branch <= s_is_unconditional_branch and s_op_high(0);

  -- Conditional branch: B[cc]
  s_is_conditional_branch <= (not i_bubble) when s_op_high(5 downto 3) = "110" else '0';
  s_branch_condition <= s_op_high(2 downto 0);

  s_is_branch <= s_is_unconditional_branch or s_is_conditional_branch;

  -- The branch offset is the lowest 21 bits of the instruction (i.e. the 21-bit immediate).
  s_branch_offset <= i_instr(20 downto 0);


  --------------------------------------------------------------------------------------------------
  -- Information for the operand forwarding logic.
  --------------------------------------------------------------------------------------------------

  -- Async.
  o_vl_requested <= s_is_vector_op;


  --------------------------------------------------------------------------------------------------
  -- Prepare data for the RF stage.
  --------------------------------------------------------------------------------------------------

  -- Select the immediate value.
  -- Note: For linking branches we use the ALU to calculate PC + 4.
  s_imm <= to_word(4) when s_is_link_branch = '1' else
           s_imm_from_instr;


  -- Select source data that the RF stage should pass to the EX stage.
  -- Note 1: For linking branches we use the ALU to calculate PC + 4.
  -- Note 2: For ADDPCHI we use the ALU to calculate PC + (imm21 << 11).
  s_src_a_mode <= C_SRC_A_PC when (s_is_link_branch or s_is_addpchi) = '1' else
                  C_SRC_A_REG;
  s_src_b_mode <= C_SRC_B_REG when s_is_type_a = '1' and s_is_link_branch = '0' else
                  C_SRC_B_IMM;

  -- Select destination register.
  -- Note: For linking branches we set the target register to LR.
  s_dst_reg.reg <= to_vector(C_LR_REG, C_LOG2_NUM_REGS) when s_is_link_branch = '1' else
                   s_reg_c when (s_is_mem_store or s_is_branch) = '0' else
                   (others => '0');

  -- Will this instruction write to a register?
  -- The following registers are the MRISC32 versions of /dev/null: z, vz and pc.
  s_dst_reg.is_target <= '1' when ((s_dst_reg.reg /= to_vector(C_Z_REG, C_LOG2_NUM_REGS)) and
                                   (s_dst_reg.reg /= to_vector(C_PC_REG, C_LOG2_NUM_REGS) or
                                    s_dst_reg.is_vector = '1')) else '0';

  -- Select target vector element.
  s_dst_reg.element <= s_element_c when s_reg_c_is_vector = '1' else (others => '0');
  s_dst_reg.is_vector <= s_reg_c_is_vector and not s_is_mem_store;

  -- What pipeline units should be enabled?
  s_alu_en <= not (s_is_mem_op or s_is_sau_op or s_is_mul_op or s_is_div_op or s_is_fpu_op);
  s_sau_en <= s_is_sau_op;
  s_mul_en <= s_is_mul_op;
  s_div_en <= s_is_div_op;
  s_mem_en <= s_is_mem_op;
  s_fpu_en <= s_is_fpu_op;

  -- Select ALU operation.
  s_alu_op <=
      -- Use the ALU to calculate the return address of linking branches.
      C_ALU_ADD when s_is_link_branch = '1' else

      -- LDI has a special ALU op.
      C_ALU_LDI when s_is_ldi = '1' else

      -- LDHI has a special ALU op.
      C_ALU_LDHI when s_is_ldhi = '1' else

      -- LDHIO has a special ALU op.
      C_ALU_LDHIO when s_is_ldhio = '1' else

      -- ADDPCHI has a special ALU op.
      C_ALU_ADDHI when s_is_addpchi = '1' else

      -- Use NOP for non-ALU ops and non-linking branches (they do not produce any result).
      C_ALU_CPUID when s_alu_en = '0' or (s_is_branch and not s_is_link_branch) = '1' else

      -- We map the two-operand FUNC ID into the opcode for such instructions.
      -- Note: This is a hack. We should really send the entire FUNC code to the ALU.
      "001" & s_func(2 downto 0) when s_is_type_b_alu = '1' else

      -- Map the low order bits of the low order opcode directly to the ALU.
      s_op_low(C_ALU_OP_SIZE-1 downto 0) when s_is_type_a = '1' else

      -- Map the high order opcode directly to the ALU.
      s_op_high;

  -- Select saturating arithmetic operation.
  -- Map the low order bits of the low order opcode directly to the saturating arithmetic unit.
  s_sau_op <= s_op_low(C_SAU_OP_SIZE-1 downto 0);

  -- Select multiply operation.
  -- Map the low order bits of the low order opcode directly to the multiply unit.
  s_mul_op <= s_op_low(C_MUL_OP_SIZE-1 downto 0);

  -- Select division operation.
  -- Map the low order bits of the low order opcode directly to the division unit, except for
  -- for FDIV, which is decoded separately.
  s_div_op <= C_DIV_FDIV when s_is_fdiv = '1' else
              "0" & s_op_low(C_DIV_OP_SIZE-2 downto 0);

  -- Select FPU operation.
  -- Map the low order bits of the low order opcode directly to the FPU.
  s_fpu_op <= s_op_low(C_FPU_OP_SIZE-1 downto 0);

  -- Are we missing any fwd operation that has not yet been produced by the pipeline?
  s_missing_fwd_operand <= s_is_vector_op and i_vl_fwd_use_value and not i_vl_fwd_value_ready;

  -- Should we discard the operation (i.e. send a bubble down the pipeline)?
  s_bubble <= i_bubble or i_cancel or s_missing_fwd_operand or s_bubble_from_vector_op;
  s_reg_a_required_masked <= s_reg_a_required when s_bubble = '0' else '0';
  s_reg_b_required_masked <= s_reg_b_required when s_bubble = '0' else '0';
  s_reg_c_required_masked <= s_reg_c_required when s_bubble = '0' else '0';
  s_dst_reg_masked.is_target <= s_dst_reg.is_target when s_bubble = '0' else '0';
  s_dst_reg_masked.reg <= s_dst_reg.reg when s_bubble = '0' else (others => '0');
  s_dst_reg_masked.element <= s_dst_reg.element when s_bubble = '0' else (others => '0');
  s_dst_reg_masked.is_vector <= s_dst_reg.is_vector when s_bubble = '0' else '0';
  s_alu_op_masked <= s_alu_op when s_bubble = '0' else (others => '0');
  s_mem_op_masked <= s_mem_op when s_bubble = '0' else (others => '0');
  s_alu_en_masked <= s_alu_en and not s_bubble;
  s_mem_en_masked <= s_mem_en and not s_bubble;
  s_sau_en_masked <= s_sau_en and not s_bubble;
  s_mul_en_masked <= s_mul_en and not s_bubble;
  s_div_en_masked <= s_div_en and not s_bubble;
  s_fpu_en_masked <= s_fpu_en and not s_bubble;
  s_is_branch_masked <= s_is_branch and not s_bubble;

  -- Select register numbers for the read ports (async signals to RF).
  o_next_sreg_a_reg <= s_reg_a;
  o_next_sreg_b_reg <= s_reg_b;
  o_next_sreg_c_reg <= s_reg_c;

  -- Note: We remap vector register ports for memory operations.
  o_next_vreg_a_reg <= s_reg_c when s_mem_en = '1' else s_reg_a;
  o_next_vreg_a_element <= s_element_c when s_mem_en = '1' else s_element_a;
  o_next_vreg_b_reg <= s_reg_b;
  o_next_vreg_b_element <= s_element_b;

  -- Outputs to the RF stage (sync).
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_branch_is_branch <= '0';
      o_branch_is_unconditional <= '0';
      o_branch_condition <= (others => '0');
      o_branch_offset <= (others => '0');

      o_reg_a_required <= '0';
      o_reg_b_required <= '0';
      o_reg_c_required <= '0';
      o_src_a_mode <= (others => '0');
      o_src_b_mode <= (others => '0');
      o_pc <= (others => '0');
      o_imm <= (others => '0');
      o_is_first_vector_op_cycle <= '0';
      o_address_offset_is_stride <= '0';
      o_src_reg_a.reg <= (others => '0');
      o_src_reg_a.element <= (others => '0');
      o_src_reg_a.is_vector <= '0';
      o_src_reg_b.reg <= (others => '0');
      o_src_reg_b.element <= (others => '0');
      o_src_reg_b.is_vector <= '0';
      o_src_reg_c.reg <= (others => '0');
      o_src_reg_c.element <= (others => '0');
      o_src_reg_c.is_vector <= '0';
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
      o_bubble <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        o_branch_is_branch <= s_is_branch_masked;
        o_branch_is_unconditional <= s_is_unconditional_branch;
        o_branch_condition <= s_branch_condition;
        o_branch_offset <= s_branch_offset;

        o_reg_a_required <= s_reg_a_required_masked;
        o_reg_b_required <= s_reg_b_required_masked;
        o_reg_c_required <= s_reg_c_required_masked;
        o_src_a_mode <= s_src_a_mode;
        o_src_b_mode <= s_src_b_mode;
        o_pc <= i_pc;
        o_imm <= s_imm;
        o_is_first_vector_op_cycle <= s_is_first_vector_op_cycle;
        o_address_offset_is_stride <= s_address_offset_is_stride;
        o_src_reg_a.reg <= s_reg_a;
        o_src_reg_a.element <= s_element_a;
        o_src_reg_a.is_vector <= s_reg_a_is_vector;
        o_src_reg_b.reg <= s_reg_b;
        o_src_reg_b.element <= s_element_b;
        o_src_reg_b.is_vector <= s_reg_b_is_vector;
        o_src_reg_c.reg <= s_reg_c;
        o_src_reg_c.element <= s_element_c;
        o_src_reg_c.is_vector <= s_reg_c_is_vector;
        o_dst_reg <= s_dst_reg_masked;
        o_packed_mode <= s_packed_mode;
        o_alu_op <= s_alu_op_masked;
        o_mem_op <= s_mem_op_masked;
        o_sau_op <= s_sau_op;
        o_mul_op <= s_mul_op;
        o_div_op <= s_div_op;
        o_fpu_op <= s_fpu_op;
        o_alu_en <= s_alu_en_masked;
        o_mem_en <= s_mem_en_masked;
        o_sau_en <= s_sau_en_masked;
        o_mul_en <= s_mul_en_masked;
        o_div_en <= s_div_en_masked;
        o_fpu_en <= s_fpu_en_masked;
        o_bubble <= s_bubble;
      end if;
    end if;
  end process;

  -- Do we need to stall the pipeline (async)?
  o_stall <= (not (i_bubble or i_cancel)) and (s_missing_fwd_operand or s_is_vector_op_busy);
end rtl;
