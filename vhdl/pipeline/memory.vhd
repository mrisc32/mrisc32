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
-- Pipeline Stage 5: Memory (MEM)
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
      i_mem_we : in std_logic;
      i_mem_byte_mask : in std_logic_vector(C_WORD_SIZE/8-1 downto 0);
      i_ex_result : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_store_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_dst_reg : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      i_writes_to_reg : in std_logic;

      -- DCache interface.
      o_dcache_req : out std_logic;  -- 1 = request, 0 = nop
      o_dcache_we : out std_logic;   -- 1 = write, 0 = read
      o_dcache_byte_mask : out std_logic_vector(C_WORD_SIZE/8-1 downto 0);
      o_dcache_addr : out std_logic_vector(C_WORD_SIZE-1 downto 2);
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
  signal s_mem_is_signed : std_logic;
  signal s_mem_size : std_logic_vector(1 downto 0);

  signal s_shifted_read_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_sign_bit : std_logic;
  signal s_extend_bit : std_logic;
  signal s_adjusted_read_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  ------------------------------------------------------------------------------
  -- Outputs to the data cache.
  ------------------------------------------------------------------------------

  o_dcache_req <= i_mem_enable;
  o_dcache_we <= i_mem_we;
  o_dcache_byte_mask <= i_mem_byte_mask;
  o_dcache_addr <= i_ex_result(C_WORD_SIZE-1 downto 2);
  o_dcache_write_data <= i_store_data;

  ------------------------------------------------------------------------------
  -- Handle data type transformations (shifting and sign extension).
  ------------------------------------------------------------------------------

  -- Decode the memory operation.
  s_mem_is_signed <= not i_mem_op(2);
  s_mem_size <= i_mem_op(1 downto 0);

  -- Shift the read data according to the memory address LSBs.
  ShiftMux: with i_ex_result(1 downto 0) select
    s_shifted_read_data <=
      X"00" & i_dcache_read_data(31 downto 8) when "01",
      X"0000" & i_dcache_read_data(31 downto 16) when "10",
      X"000000" & i_dcache_read_data(31 downto 24) when "11",
      i_dcache_read_data when others;

  -- Determine the sign extension bit.
  SignMux: with s_mem_size select
    s_sign_bit <=
      s_shifted_read_data(7) when "01",   -- byte
      s_shifted_read_data(15) when "10",  -- halfword
      '0' when others;

  s_extend_bit <= s_sign_bit and s_mem_is_signed;

  -- Perform the sign extension.
  s_adjusted_read_data(31 downto 16) <=
    (others => s_extend_bit) when s_mem_size(1) /= s_mem_size(0)
    else s_shifted_read_data(31 downto 16);

  s_adjusted_read_data(15 downto 8) <=
    (others => s_extend_bit) when s_mem_size = "01"
    else s_shifted_read_data(15 downto 8);

  ------------------------------------------------------------------------------
  -- Outputs to the WB stage.
  ------------------------------------------------------------------------------

  -- Prepare signals for the WB stage.
  s_data <= s_adjusted_read_data when i_mem_enable = '1' else i_ex_result;

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
  o_stall <= i_mem_enable and (not i_mem_we) and (not i_dcache_read_data_ready);
end rtl;

