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
-- Branch Target Buffer
--
-- This is a simple direct mapped, single bit state (taken/not taken) branch target buffer. The PC
-- provided by i_read_pc represents the PC that will be used during the next cycle in the IF stage,
-- and the predicted target (and whether it should be taken) is provided during the next cycle.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.config.all;

entity branch_target_buffer is
  port(
      -- Control signals.
      i_clk : in std_logic;
      i_rst : in std_logic;
      i_invalidate : in std_logic;

      -- Buffer lookup (sync).
      i_read_en : in std_logic;
      i_read_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_predict_taken : out std_logic;
      o_predict_target : out std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- Buffer update (sync).
      i_write_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_write_is_branch : in std_logic;
      i_write_is_taken : in std_logic;
      i_write_target : in std_logic_vector(C_WORD_SIZE-1 downto 0)
    );
end branch_target_buffer;

architecture rtl of branch_target_buffer is
  constant C_LOG2_ENTRIES : integer := 9;  -- 512 entries.
  constant C_TAG_SIZE : integer := C_WORD_SIZE - C_LOG2_ENTRIES;
  constant C_TARGET_SIZE : integer := C_WORD_SIZE + 2;  -- is_valid  & is_taken & target_address

  signal s_prev_read_en : std_logic;
  signal s_prev_read_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_got_match : std_logic;
  signal s_got_branch : std_logic;
  signal s_got_taken : std_logic;

  signal s_read_addr : std_logic_vector(C_LOG2_ENTRIES-1 downto 0);
  signal s_tag_read_data : std_logic_vector(C_TAG_SIZE-1 downto 0);
  signal s_target_read_data : std_logic_vector(C_TARGET_SIZE-1 downto 0);

  signal s_write_addr : std_logic_vector(C_LOG2_ENTRIES-1 downto 0);
  signal s_we : std_logic;
  signal s_tag_write_data : std_logic_vector(C_TAG_SIZE-1 downto 0);
  signal s_target_write_data : std_logic_vector(C_TARGET_SIZE-1 downto 0);
begin
  -- Instantiate the tag RAM.
  tag_ram_0: entity work.ram_dual_port
    generic map (
      WIDTH => C_TAG_SIZE,
      ADDR_BITS => C_LOG2_ENTRIES
    )
    port map (
      i_clk => i_clk,
      i_write_addr => s_write_addr,
      i_write_data => s_tag_write_data,
      i_we => s_we,
      i_read_addr => s_read_addr,
      o_read_data => s_tag_read_data
    );

  -- Instantiate the branch target RAM.
  -- TODO(m): Split out the meta data (is_valid & is_taken) into a separate RAM
  -- with more flexible properties (clear on reset/invalidate and possibility
  -- to use two-bit saturating increment/decrement operations instead of one-bit
  -- write).
  target_ram_0: entity work.ram_dual_port
    generic map (
      WIDTH => C_TARGET_SIZE,
      ADDR_BITS => C_LOG2_ENTRIES
    )
    port map (
      i_clk => i_clk,
      i_write_addr => s_write_addr,
      i_write_data => s_target_write_data,
      i_we => s_we,
      i_read_addr => s_read_addr,
      o_read_data => s_target_read_data
    );

  -- Internal state.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_prev_read_en <= '0';
      s_prev_read_pc <= (others => '0');
    elsif rising_edge(i_clk) then
      s_prev_read_en <= i_read_en;
      s_prev_read_pc <= i_read_pc;
    end if;
  end process;


  --------------------------------------------------------------------------------------------------
  -- Buffer lookup.
  --------------------------------------------------------------------------------------------------

  s_read_addr <= i_read_pc(C_LOG2_ENTRIES-1 downto 0);

  -- Decode the target and tag information.
  o_predict_target <= s_target_read_data(C_WORD_SIZE-1 downto 0);
  s_got_branch <= s_target_read_data(C_WORD_SIZE);
  s_got_taken <= s_target_read_data(C_WORD_SIZE + 1);
  s_got_match <= '1' when s_prev_read_pc(C_WORD_SIZE-1 downto C_LOG2_ENTRIES) = s_tag_read_data else '0';

  -- Determine if we should take the branch.
  o_predict_taken <= s_prev_read_en and s_got_match and s_got_branch and s_got_taken;


  --------------------------------------------------------------------------------------------------
  -- Buffer update.
  --------------------------------------------------------------------------------------------------

  s_we <= i_write_is_branch;
  s_write_addr <= i_write_pc(C_LOG2_ENTRIES-1 downto 0);
  s_tag_write_data <= i_write_pc(C_WORD_SIZE-1 downto C_LOG2_ENTRIES);
  s_target_write_data <= i_write_is_branch & i_write_is_taken & i_write_target;
end rtl;

