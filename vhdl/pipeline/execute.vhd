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
      i_alu_op : in T_ALU_OP;
      i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_src_c : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_mem_op : in T_MEM_OP;
      i_dst_reg : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      i_writes_to_reg : in std_logic;

      -- To MEM stage (sync).
      o_mem_op : out T_MEM_OP;
      o_mem_enable : out std_logic;
      o_alu_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_store_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_dst_reg : out std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      o_writes_to_reg : out std_logic;

      -- To operand forward logic (async).
      o_next_alu_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_next_result_ready : out std_logic
    );
end execute;

architecture rtl of execute is
  signal s_alu_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_mem_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_mem_enable : std_logic;
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

  -- Prepare signals for the MEM stage.
  s_mem_enable <= '1' when i_mem_op /= "0000" else '0';

  -- Outputs to the MEM stage.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_mem_op <= (others => '0');
      o_mem_enable <= '0';
      o_alu_result <= (others => '0');
      o_store_data <= (others => '0');
      o_dst_reg <= (others => '0');
      o_writes_to_reg <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        o_mem_op <= i_mem_op;
        o_mem_enable <= s_mem_enable;
        o_alu_result <= s_alu_result;
        o_store_data <= i_src_c;
        o_dst_reg <= i_dst_reg;
        o_writes_to_reg <= i_writes_to_reg;
      end if;
    end if;
  end process;

  -- Output the generated result to operand forwarding logic (async).
  o_next_alu_result <= s_alu_result;
  o_next_result_ready <= not s_mem_enable;

  -- Do we need to stall the pipeline (async)?
  o_stall <= '0';  -- TODO(m): Implement me (operand forwarding & multi-cycle instructions)!
end rtl;

