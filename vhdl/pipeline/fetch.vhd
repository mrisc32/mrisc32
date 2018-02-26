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
-- Pipeline Stage 1: Instruction Fetch (IF)
--
-- A major part of this stage is the branch logic (PC prediction and correction). This relies on
-- a few different concepts:
--   * A branch target cache provides information about historical branch events.
--   * A simple predictor (PC + 4) is used when no branch was predicted taken.
--   * Information from the ID stage (which evaluates branch instructions) is used for detecting
--     mispredictions and correcting the PC.
--     - An unconditional register-target branch is considered mispredicted if the register content
--       and the predicted PC for the next instruction differ.
--     - A conditional PC-offset branch is considered mispredicted if the predicted taken signal
--       differs from the actual branch taken result (based on condition evaluation in the ID
--       stage).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity fetch is
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
end fetch;

architecture rtl of fetch is
  -- Internal PC.
  signal s_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);       -- Current PC.
  signal s_next_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);  -- Next IF PC.
  signal s_id_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);    -- Current ID PC.

  -- Branch target cache signals.
  signal s_btc_taken : std_logic;
  signal s_btc_target : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_prev_btc_taken : std_logic;

  -- Branch prediction signals.
  signal s_pc_plus_4 : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_predicted_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Branch calculation signals.
  signal s_branch_target : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_reg_branch_mispredicted : std_logic;
  signal s_offset_branch_mispredicted : std_logic;
  signal s_branch_mispredicted : std_logic;
  signal s_id_bubble : std_logic;

  -- Internal stall handling signals.
  signal s_stall : std_logic;
begin
  -- Instruction fetch from the ICache.
  o_icache_read <= '1';  -- We always read from the cache.
  o_icache_addr <= s_pc;

  -- Branch target cache.
  BTC: entity work.branch_target_cache
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_invalidate => '0',
      i_read_pc => s_pc,
      o_predict_taken => s_btc_taken,
      o_predict_target => s_btc_target,
      i_write_pc => s_id_pc,
      i_write_is_branch => i_id_branch_is_branch,
      i_write_is_taken => i_id_branch_is_taken,
      i_write_target => s_branch_target
    );

  -- Predict the next PC.
  pc_plus_4_0: entity work.pc_plus_4
    port map (
      i_pc => s_pc,
      o_pc_plus_4 => s_pc_plus_4
    );
  s_predicted_pc <= s_btc_target when s_btc_taken = '1' else s_pc_plus_4;

  -- Select the corrected PC for the current cycle (based on the decoded branch
  -- info from the ID stage), if the previous instruction was a branch.
  s_branch_target <= i_id_branch_reg_addr when i_id_branch_is_reg = '1' else i_id_branch_offset_addr;

  -- Determine if we had a branch misprediction in the previous cycle.
  s_reg_branch_mispredicted <= to_std_logic(s_pc /= i_id_branch_reg_addr) and i_id_branch_is_reg;
  s_offset_branch_mispredicted <= i_id_branch_is_branch and (not i_id_branch_is_reg) and
                                  (not (s_prev_btc_taken xor i_id_branch_is_taken));
  s_branch_mispredicted <= s_reg_branch_mispredicted or s_offset_branch_mispredicted;

  -- Select the corrected or the predicted PC for the next IF cycle.
  s_next_pc <= s_branch_target when s_branch_mispredicted = '1' else s_predicted_pc;

  -- Determine if we need to send a bubble down the pipeline.
  s_id_bubble <= s_branch_mispredicted or not i_icache_data_ready;

  -- Determine if we need to stall the fetch stage.
  s_stall <= i_stall or not i_icache_data_ready;

  -- Internal registered signals.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_pc <= C_RESET_PC;
      s_id_pc <= (others => '0');
      s_prev_btc_taken <= '0';
    elsif rising_edge(i_clk) then
      if s_stall = '0' then
        s_pc <= s_next_pc;
        s_id_pc <= s_pc;
        s_prev_btc_taken <= s_btc_taken;
      end if;
    end if;
  end process;

  -- Outputs to the ID stage.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_id_pc <= (others => '0');
      o_id_instr <= (others => '0');
      o_id_bubble <= '1';
    elsif rising_edge(i_clk) then
      if s_stall = '0' then
        o_id_pc <= s_pc;
        o_id_instr <= i_icache_data;
      end if;

      -- If we're idling this cycle, we need to let ID know since it will continue running anyway.
      -- I.e. don't let ID use the PC or instruction signals since they are not valid.
      o_id_bubble <= s_id_bubble;
    end if;
  end process;
end rtl;
