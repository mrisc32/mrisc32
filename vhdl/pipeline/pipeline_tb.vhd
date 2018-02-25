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

entity pipeline_tb is
end pipeline_tb;

architecture behavioral of pipeline_tb is
  component fetch
    port(
        -- Control signals.
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_stall : in std_logic;

        -- Branch results from the ID stage (async).
        i_id_branch_reg_addr : in std_logic_vector(C_WORD_SIZE-1 downto 0);
        i_id_branch_offset_addr : in std_logic_vector(C_WORD_SIZE-1 downto 0);
        i_id_branch_is_branch : in std_logic;
        i_id_branch_is_reg : in std_logic;  -- 1 for register branches, 0 for all other instructions.
        i_id_branch_is_taken : in std_logic;

        -- ICache interface.
        o_icache_read : out std_logic;
        o_icache_addr : out std_logic_vector(C_WORD_SIZE-1 downto 0);
        i_icache_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
        i_icache_data_ready : in std_logic;

        -- To ID stage (sync).
        o_id_pc : out std_logic_vector(C_WORD_SIZE-1 downto 0);
        o_id_instr : out std_logic_vector(C_WORD_SIZE-1 downto 0);
        o_id_bubble : out std_logic  -- 1 if IF could not provide a new instruction.
      );
  end component;

  component decode
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
  end component;

  component execute
    port(
        -- Control signals.
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_stall : in std_logic;

        -- From ID stage (sync).
        i_id_alu_op : in T_ALU_OP;
        i_id_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);
        i_id_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);
        i_id_src_c : in std_logic_vector(C_WORD_SIZE-1 downto 0);
        i_id_mem_op : in T_MEM_OP;
        i_id_dst_reg : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);

        -- To MEM stage (sync).
        o_mem_op : out T_MEM_OP;
        o_mem_alu_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
        o_mem_store_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
        o_mem_dst_reg : out std_logic_vector(C_LOG2_NUM_REGS-1 downto 0)
      );
  end component;

  component memory
    port(
        -- Control signals.
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_stall : in std_logic;

        -- From EX stage (sync).
        i_ex_op : in T_MEM_OP;
        i_ex_alu_result : in std_logic_vector(C_WORD_SIZE-1 downto 0);
        i_ex_store_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
        i_ex_dst_reg : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);

        -- DCache interface.
        o_dcache_enable : out std_logic;  -- 1 = enable, 0 = nop
        o_dcache_write : out std_logic;   -- 1 = write, 0 = read
        o_dcache_size : out std_logic_vector(1 downto 0);
        o_dcache_addr : out std_logic_vector(C_WORD_SIZE-1 downto 0);
        i_dcache_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
        i_dcache_data_ready : in std_logic;

        -- To WB stage (sync).
        -- NOTE: The WB stage is actually implemented in decode (where the
        -- register files are interfaced).
        o_wb_we : out std_logic;
        o_wb_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
        o_wb_dst_reg : out std_logic_vector(C_LOG2_NUM_REGS-1 downto 0)
      );
  end component;

  signal s_clk : std_logic;
  signal s_rst : std_logic;
begin
  fetch_0: entity work.fetch
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- TODO(m): Complete this...
      i_stall => '0',
      i_id_branch_reg_addr => (others => '0'),
      i_id_branch_offset_addr => (others => '0'),
      i_id_branch_is_branch => '0',
      i_id_branch_is_reg => '0',
      i_id_branch_is_taken => '0',
      i_icache_data => (others => '0'),
      i_icache_data_ready => '0'
    );

  decode_0: entity work.decode
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- TODO(m): Complete this...
      i_stall => '0',
      i_if_pc => (others => '0'),
      i_if_instr => (others => '0'),
      i_if_bubble => '0',
      i_wb_we => '0',
      i_wb_data_w => (others => '0'),
      i_wb_sel_w => (others => '0')
    );

  execute_0: entity work.execute
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- TODO(m): Complete this...
      i_stall => '0',
      i_id_alu_op => (others => '0'),
      i_id_src_a => (others => '0'),
      i_id_src_b => (others => '0'),
      i_id_src_c => (others => '0'),
      i_id_mem_op => (others => '0'),
      i_id_dst_reg => (others => '0')
    );

  memory_0: entity work.memory
    port map (
      i_clk => s_clk,
      i_rst => s_rst,

      -- TODO(m): Complete this...
      i_stall => '0',
      i_ex_op => (others => '0'),
      i_ex_alu_result => (others => '0'),
      i_ex_store_data => (others => '0'),
      i_ex_dst_reg => (others => '0'),
      i_dcache_data => (others => '0'),
      i_dcache_data_ready => '0'
    );

  process
  begin
    -- Start by resetting the pipeline (to have defined signals).
    s_rst <= '1';
    s_clk <= '0';

    wait for 1 ns;
    s_rst <= '0';

    --  Wait forever; this will finish the simulation.
    assert false report "End of test" severity note;
    wait;
  end process;
end behavioral;

