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
-- Pipeline Stage 3: Execute (EX)
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity execute is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;
    o_stall : out std_logic;

    -- From ID stage (sync).
    i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_src_c : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_dst_reg : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
    i_writes_to_reg : in std_logic;
    i_alu_op : in T_ALU_OP;
    i_muldiv_op : in T_MULDIV_OP;
    i_mem_op : in T_MEM_OP;
    i_alu_en : in std_logic;
    i_muldiv_en : in std_logic;
    i_mem_en : in std_logic;

    -- To MEM stage (sync).
    o_mem_op : out T_MEM_OP;
    o_mem_enable : out std_logic;
    o_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_store_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_dst_reg : out std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
    o_writes_to_reg : out std_logic;

    -- To operand forward logic (async).
    o_next_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_next_result_ready : out std_logic
  );
end execute;

architecture rtl of execute is
  signal s_alu_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_muldiv_result : std_logic_vector(C_WORD_SIZE-1 downto 0);

  signal s_stall_for_mulu : std_logic;
  signal s_mulu_result : std_logic_vector(C_WORD_SIZE*2-1 downto 0);
  signal s_mulu_result_ready : std_logic;

  -- Multicycle operation handling.
  signal s_start_multicycle_op : std_logic;
  signal s_start_mulu_op : std_logic;
  signal s_stall_for_multicycle_op : std_logic;
  signal s_multicycle_op_finished : std_logic;
  signal s_prev_stall_for_multicycle_op : std_logic;

  signal s_mem_data : std_logic_vector(C_WORD_SIZE-1 downto 0);

  signal s_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_next_result_ready : std_logic;

  constant C_MULDIV_ZERO : T_MULDIV_OP := (others => '0');
begin
  -- Instantiate the ALU.
  alu_1: entity work.alu
    port map (
      i_op => i_alu_op,
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      i_src_c => i_src_c,
      o_result => s_alu_result
    );

  -- Instantiate a multiply unit.
  -- TODO(m): Support more operations. Right now we just have a mulu entity.
  mulu_1: entity work.mulu
    generic map (
      WIDTH => 32
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => i_stall,
      o_stall => s_stall_for_mulu,
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      i_start_op => s_start_mulu_op,
      o_result => s_mulu_result,
      o_result_ready => s_mulu_result_ready
    );

  MuldivMux: with i_muldiv_op select
    s_muldiv_result <=
      -- TODO(m): Move this into a dedicated muldiv entity and support more ops.
      s_mulu_result(C_WORD_SIZE-1 downto 0) when OP_MUL,
      s_mulu_result(C_WORD_SIZE*2-1 downto C_WORD_SIZE) when OP_MULHIU,
      (others => '0') when others;

  -- Multicycle operation.
  s_start_multicycle_op <= i_muldiv_en and not s_prev_stall_for_multicycle_op;
  s_start_mulu_op <= s_start_multicycle_op and i_muldiv_en;
  s_stall_for_multicycle_op <= s_stall_for_mulu;
  s_multicycle_op_finished <= s_mulu_result_ready;

  -- TODO(m): Prepare halfword and byte operations (mask, shift, ...) for the MEM stage.

  -- Select the output.
  s_next_result <=
      s_alu_result when i_alu_en = '1' else
      s_muldiv_result when i_muldiv_en = '1' else
      (others => '0');

  s_next_result_ready <= (i_alu_en and (not i_mem_en)) or s_multicycle_op_finished;

  -- Internal state.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_prev_stall_for_multicycle_op <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_prev_stall_for_multicycle_op <= s_stall_for_multicycle_op;
      end if;
    end if;
  end process;

  -- Outputs to the MEM stage (sync).
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_mem_op <= (others => '0');
      o_mem_enable <= '0';
      o_result <= (others => '0');
      o_store_data <= (others => '0');
      o_dst_reg <= (others => '0');
      o_writes_to_reg <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        o_mem_op <= i_mem_op;
        o_mem_enable <= i_mem_en;
        o_result <= s_alu_result;
        o_store_data <= i_src_c;
        o_dst_reg <= i_dst_reg;
        o_writes_to_reg <= i_writes_to_reg;
      end if;
    end if;
  end process;

  -- Output the generated result to operand forwarding logic (async).
  o_next_result <= s_next_result;
  o_next_result_ready <= s_next_result_ready;

  -- Do we need to stall the pipeline (async)?
  o_stall <= s_stall_for_multicycle_op;
end rtl;

