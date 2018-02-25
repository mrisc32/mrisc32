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

entity pipeline_mem is
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
      -- NOTE: The WB stage is actually implemented in pipeline_id (where the
      -- register files are interfaced).
      o_wb_we : out std_logic;
      o_wb_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_wb_dst_reg : out std_logic_vector(C_LOG2_NUM_REGS-1 downto 0)
    );
end pipeline_mem;

architecture rtl of pipeline_mem is
  signal s_wb_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  -- TODO(m): Implement me!

  -- Right now we just forward the result from EX to WB.
  s_wb_data <= i_ex_alu_result;

  -- Write enabled?
  s_wb_we <= '1' when (i_ex_dst_reg /= "00000") and (i_ex_dst_reg /= "11111") else '0';

  -- Outputs to the WB stage.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_wb_we <= '0';
      o_wb_data <= (others => '0');
      o_wb_dst_reg <= (others => '0');
    elsif rising_edge(i_clk) then
      o_wb_we <= s_wb_we;
      o_wb_data <= s_wb_data;
      o_wb_dst_reg <= i_ex_dst_reg;
    end if;
  end process;
end rtl;

