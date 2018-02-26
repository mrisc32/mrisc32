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
-- Pipeline Stage 2: Instruction Decode (ID)
--
-- Note: This entity also implements the WB stage (stage 5), since the register files live here.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity decode is
  port(
      -- Control signals.
      i_clk : in std_logic;
      i_rst : in std_logic;
      i_stall : in std_logic;

      -- From the IF stage (sync).
      i_if_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_if_instr : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_if_bubble : in std_logic;  -- 1 if IF could not provide a new instruction.

      -- WB data from the MEM stage (sync).
      i_wb_we : in std_logic;
      i_wb_data_w : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_wb_sel_w : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);

      -- Branch results to the IF stage (async).
      o_if_branch_reg_addr : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_if_branch_offset_addr : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_if_branch_is_branch : out std_logic;
      o_if_branch_is_reg : out std_logic;  -- 1 for register branches, 0 for all other instructions.
      o_if_branch_is_taken : out std_logic;

      -- To the EX stage (sync).
      o_ex_alu_op : out T_ALU_OP;
      o_ex_src_a : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_ex_src_b : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_ex_src_c : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_ex_mem_op : out T_MEM_OP;
      o_ex_dst_reg : out std_logic_vector(C_LOG2_NUM_REGS-1 downto 0)
    );
end decode;

architecture rtl of decode is
  -- Instruction decode signals.
  signal s_op_high : std_logic_vector(5 downto 0);
  signal s_op_low : std_logic_vector(8 downto 0);
  signal s_reg_a : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_reg_b : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_reg_c : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_imm : std_logic_vector(C_WORD_SIZE-1 downto 0);

  signal s_is_type_a : std_logic;
  signal s_is_type_b : std_logic;
  signal s_is_type_c : std_logic;

  -- Register read signals.
  signal s_reg_a_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_reg_b_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_reg_c_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_vl_data : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Signals to the EX stage.
  signal s_ex_alu_op : T_ALU_OP;
  signal s_ex_src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex_src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex_src_c : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_ex_mem_op : T_MEM_OP;
  signal s_ex_dst_reg : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
begin
  -- Extract operation codes.
  s_op_high <= i_if_instr(29 downto 24);
  s_op_low <= i_if_instr(8 downto 0);

  -- Determine encoding type.
  s_is_type_a <= '1' when s_op_high = "000000" else '0';
  s_is_type_c <= '1' when s_op_high(5 downto 4) = "11" else '0';
  s_is_type_b <= not (s_is_type_a or s_is_type_c);

  -- Extract immediate.
  s_imm(13 downto 0) <= i_if_instr(13 downto 0);
  s_imm(18 downto 14) <= i_if_instr(18 downto 14) when s_is_type_c = '1' else (others => i_if_instr(13));
  s_imm(31 downto 19) <= (others => s_imm(18));

  -- Extract register numbers.
  s_reg_a <= i_if_instr(18 downto 14);
  s_reg_b <= i_if_instr(13 downto 9);
  s_reg_c <= i_if_instr(23 downto 19);  -- Usually destination, somtimes source.

  -- Read from the register file.
  regs_scalar_1: entity work.regs_scalar
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_sel_a => s_reg_a,
      i_sel_b => s_reg_b,
      i_sel_c => s_reg_c,
      o_data_a => s_reg_a_data,
      o_data_b => s_reg_b_data,
      o_data_c => s_reg_c_data,
      o_vl => s_vl_data,
      i_we => i_wb_we,
      i_data_w => i_wb_data_w,
      i_sel_w => i_wb_sel_w,
      i_pc => i_if_pc
    );

  -- Select source data for the EX stage.
  s_ex_src_a <= s_reg_a_data when s_is_type_c = '0' else s_imm;
  s_ex_src_b <= s_reg_b_data when s_is_type_a = '1' else s_imm;
  s_ex_src_c <= s_reg_c_data;

  -- Select destination register.
  -- TODO(m): There are more things to consider (e.g. branches, stores, ...).
  s_ex_dst_reg <= s_reg_c;

  -- Select ALU operation.
  -- TODO(m): There are more things to consider (e.g. branches, LDHI, ...).
  s_ex_alu_op <= s_op_low when s_is_type_a = '1' else ("000" & s_op_high);

  -- Select MEM operation.
  -- TODO(m): Implement me!
  s_ex_mem_op <= (others => '0');

  -- Async outputs to the IF stage (branch logic).
  -- TODO(m): Implement me!
  o_if_branch_reg_addr <= (others => '0');
  o_if_branch_offset_addr <= (others => '0');
  o_if_branch_is_branch <= '0';
  o_if_branch_is_reg <= '0';
  o_if_branch_is_taken <= '0';

  -- Outputs to the EX stage.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_ex_alu_op <= (others => '0');
      o_ex_src_a <= (others => '0');
      o_ex_src_b <= (others => '0');
      o_ex_src_c <= (others => '0');
      o_ex_mem_op <= (others => '0');
      o_ex_dst_reg <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        o_ex_alu_op <= s_ex_alu_op;
        o_ex_src_a <= s_ex_src_a;
        o_ex_src_b <= s_ex_src_b;
        o_ex_src_c <= s_ex_src_c;
        o_ex_mem_op <= s_ex_mem_op;
        o_ex_dst_reg <= s_ex_dst_reg;
      end if;
    end if;
  end process;
end rtl;
