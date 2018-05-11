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
-- Pipeline Stage 1: Program Counter (PC)
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity program_counter is
  port(
      -- Control signals.
      i_clk : in std_logic;
      i_rst : in std_logic;
      i_stall : in std_logic;

      -- Results from the branch/PC correction unit in the EX stage (async).
      i_pccorr_source : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_pccorr_target : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_pccorr_is_branch : in std_logic;
      i_pccorr_is_taken : in std_logic;
      i_pccorr_adjust : in std_logic;  -- 1 if the PC correction needs to be applied.
      i_pccorr_adjusted_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- To IF stage (sync).
      o_pc : out std_logic_vector(C_WORD_SIZE-1 downto 0)
    );
end program_counter;

architecture rtl of program_counter is
  -- Internal PC signals.
  signal s_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);  -- Next PC.
  signal s_prev_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);  -- Previous PC.
  signal s_btb_read_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Branch target buffer signals.
  signal s_btb_taken : std_logic;
  signal s_btb_target : std_logic_vector(C_WORD_SIZE-1 downto 0);

  -- Branch prediction signals.
  signal s_pc_plus_4 : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_predicted_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);

  constant C_RESET_PC_MINUS_4 : std_logic_vector(C_WORD_SIZE-1 downto 0) :=
      std_logic_vector(unsigned(C_RESET_PC) - 4);
begin
  -- Branch target buffer.
  BTB: entity work.branch_target_buffer
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_invalidate => '0',
      i_read_pc => s_btb_read_pc,
      o_predict_taken => s_btb_taken,
      o_predict_target => s_btb_target,
      i_write_pc => i_pccorr_source,
      i_write_is_branch => i_pccorr_is_branch,
      i_write_is_taken => i_pccorr_is_taken,
      i_write_target => i_pccorr_target
    );

  -- Predict the next PC.
  pc_plus_4_0: entity work.pc_plus_4
    port map (
      i_pc => s_prev_pc,
      o_result => s_pc_plus_4
    );
  s_predicted_pc <= s_btb_target when s_btb_taken = '1' else s_pc_plus_4;

  -- Select the corrected or the predicted PC for the next IF cycle.
  s_pc <= i_pccorr_adjusted_pc when i_pccorr_adjust = '1' else s_predicted_pc;

  -- Select the corrected or the predicted PC for the next IF cycle.
  s_btb_read_pc <= s_prev_pc when i_stall = '1' else s_pc;

  -- Internal registered signals.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_prev_pc <= C_RESET_PC_MINUS_4;
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        s_prev_pc <= s_pc;
      end if;
    end if;
  end process;

  -- Outputs to the IF stage.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_pc <= C_RESET_PC;
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        o_pc <= s_pc;
      end if;
    end if;
  end process;
end rtl;
