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
-- Pipeline Stage 4: Memory (MEM)
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity memory is
  port(
      -- Control signals.
      i_clk : in std_logic;
      i_rst : in std_logic;
      o_stall : out std_logic;

      -- From EX stage (sync).
      i_mem_op : in T_MEM_OP;
      i_mem_enable : in std_logic;
      i_alu_result : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_store_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_dst_reg : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      i_writes_to_reg : in std_logic;

      -- DCache interface.
      o_dcache_req : out std_logic;  -- 1 = request, 0 = nop
      o_dcache_we : out std_logic;   -- 1 = write, 0 = read
      o_dcache_size : out std_logic_vector(1 downto 0);
      o_dcache_addr : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_dcache_write_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_dcache_read_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_dcache_read_data_ready : in std_logic;

      -- To WB stage (sync).
      -- NOTE: The WB stage is actually implemented in decode (where the
      -- register files are interfaced).
      o_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_dst_reg : out std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      o_writes_to_reg : out std_logic;

      -- To operand forward logic (async).
      o_next_data : out std_logic_vector(C_WORD_SIZE-1 downto 0)
    );
end memory;

architecture rtl of memory is
  signal s_dcache_we : std_logic;
  signal s_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  s_dcache_we <= i_mem_op(3);

  -- Outputs to the data cache.
  o_dcache_req <= i_mem_enable;
  o_dcache_we <= s_dcache_we;
  o_dcache_size <= i_mem_op(1 downto 0);
  o_dcache_addr <= i_alu_result;
  o_dcache_write_data <= i_store_data;

  -- Prepare signals for the WB stage.
  s_data <= i_dcache_read_data when i_mem_enable = '1' else i_alu_result;

  -- Outputs to the WB stage.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_data <= (others => '0');
      o_dst_reg <= (others => '0');
      o_writes_to_reg <= '0';
    elsif rising_edge(i_clk) then
      o_data <= s_data;
      o_dst_reg <= i_dst_reg;
      o_writes_to_reg <= i_writes_to_reg;
    end if;
  end process;

  -- Output the generated result to operand forwarding logic (async).
  o_next_data <= s_data;

  -- Do we need to stall the pipeline (async)?
  o_stall <= i_mem_enable and (not s_dcache_we) and (not i_dcache_read_data_ready);
end rtl;

