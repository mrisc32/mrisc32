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
-- Pipeline Stage 4: Execute (EX)
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
    o_mem_we : out std_logic;
    o_mem_byte_mask : out std_logic_vector(C_WORD_SIZE/8-1 downto 0);
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
  signal s_muldiv_result_ready : std_logic;
  signal s_stall_for_muldiv : std_logic;

  -- Multicycle operation handling.
  signal s_start_multicycle_op : std_logic;
  signal s_start_muldiv_op : std_logic;
  signal s_stall_for_multicycle_op : std_logic;
  signal s_multicycle_op_finished : std_logic;
  signal s_prev_stall_for_multicycle_op : std_logic;

  signal s_next_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_next_result_ready : std_logic;

  -- Signals related to memory I/O.
  signal s_mem_byte_mask_unshifted : std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_mem_byte_mask : std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_mem_store_data : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Signals for handling bubbling.
  signal s_bubble : std_logic;
  signal s_mem_op_masked : T_MEM_OP;
  signal s_mem_en_masked : std_logic;
  signal s_dst_reg_masked : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_writes_to_reg_masked : std_logic;

  constant C_MULDIV_ZERO : T_MULDIV_OP := (others => '0');
begin
  -- Instantiate the ALU.
  alu_1: entity work.alu
    port map (
      i_op => i_alu_op,
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      o_result => s_alu_result
    );

  -- Instantiate a multiply unit.
  muldiv_1: entity work.muldiv
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => i_stall,
      o_stall => s_stall_for_muldiv,
      i_enable => i_muldiv_en,
      i_op => i_muldiv_op,
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      i_start_op => s_start_muldiv_op,
      o_result => s_muldiv_result,
      o_result_ready => s_muldiv_result_ready
    );

  -- Multicycle operation.
  s_start_multicycle_op <= i_muldiv_en and not s_prev_stall_for_multicycle_op;
  s_start_muldiv_op <= s_start_multicycle_op and i_muldiv_en;
  s_stall_for_multicycle_op <= s_stall_for_muldiv;
  s_multicycle_op_finished <= s_muldiv_result_ready;

  -- Prepare the byte mask for the MEM stage.
  ByteMaskMux: with i_mem_op(1 downto 0) select
    s_mem_byte_mask_unshifted <=
      "0001" when "01",    -- byte
      "0011" when "10",    -- halfword
      "1111" when others;  -- word (11) and undefined (00)

  ByteMaskShiftMux: with s_alu_result(1 downto 0) select
    s_mem_byte_mask <=
      s_mem_byte_mask_unshifted(3 downto 0)         when "00",
      s_mem_byte_mask_unshifted(2 downto 0) & "0"   when "01",
      s_mem_byte_mask_unshifted(1 downto 0) & "00"  when "10",
      s_mem_byte_mask_unshifted(0 downto 0) & "000" when others;  -- "11"

  -- Prepare the store data for the MEM stage (shift it into position).
  StoreDataShiftMux: with s_alu_result(1 downto 0) select
    s_mem_store_data <=
      i_src_c(31 downto 0)             when "00",
      i_src_c(23 downto 0) & X"00"     when "01",
      i_src_c(15 downto 0) & X"0000"   when "10",
      i_src_c(7 downto 0)  & X"000000" when others;  -- "11"

  -- Select the output.
  s_next_result <=
      s_alu_result when i_alu_en = '1' else
      s_muldiv_result when i_muldiv_en = '1' else
      (others => '0');

  s_next_result_ready <= (i_alu_en and (not i_mem_en)) or s_multicycle_op_finished;

  -- Should we send a bubble down the pipeline?
  s_bubble <= s_stall_for_multicycle_op;
  s_mem_op_masked <= i_mem_op when s_bubble = '0' else (others => '0');
  s_mem_en_masked <= i_mem_en and not s_bubble;
  s_dst_reg_masked <= i_dst_reg when s_bubble = '0' else (others => '0');
  s_writes_to_reg_masked <= i_writes_to_reg and not s_bubble;

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
      o_mem_we <= '0';
      o_mem_byte_mask <= (others => '0');
      o_result <= (others => '0');
      o_store_data <= (others => '0');
      o_dst_reg <= (others => '0');
      o_writes_to_reg <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        o_mem_op <= s_mem_op_masked;
        o_mem_enable <= s_mem_en_masked;
        o_mem_we <= s_mem_op_masked(3);
        o_mem_byte_mask <= s_mem_byte_mask;
        o_result <= s_next_result;
        o_store_data <= s_mem_store_data;
        o_dst_reg <= s_dst_reg_masked;
        o_writes_to_reg <= s_writes_to_reg_masked;
      end if;
    end if;
  end process;

  -- Output the generated result to operand forwarding logic (async).
  o_next_result <= s_next_result;
  o_next_result_ready <= s_next_result_ready;

  -- Do we need to stall the pipeline (async)?
  o_stall <= s_stall_for_multicycle_op;
end rtl;

