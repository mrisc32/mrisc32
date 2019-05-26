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
-- Pipeline stages 1 & 2: IF1 (Program Counter) and IF2 (Instruction Fetch)
--
-- * The PC is updated as follows (highers prio first):
--   - C_RESET_PC when i_rst = '1'.
--   - Corrected PC from EX.
--   - Predicted PC from branch predictor (based on PC from the previous cycle).
--   - PC + 4 when no other information is known.
-- * Rules:
--   - Handling of i_cancel.
--     - Treat current i_wb_ack or pending memory request as invalid when i_cancel is high.
--   - Handling of i_stall.
--     - i_wb_dat needs to be latched if i_stall = '1' (latch when i_wb_ack = '1').
--     - o_bubble must be '1' as long as i_stall = '0' but no instruction can be served.
--     - Do not initiate a new memory request if i_stall is high.
--   - Handling of the WB interface (i_wb_stall & i_wb_ack in particular).
--     - The pending WB cycle must be finished before changes to the data flow (i.e. i_pccorr_*
--       and i_cancel) can be applied. Thus, i_pccorr_adjust and i_pccorr_adjusted_pc must be
--       latched until i_wb_ack or i_wb_err has arrived (correction can be applied immediately if
--       i_wb_stall is high).
--   - Handling of i_pccorr signals.
--     - PC corrections must be latched if the IF1 stage is stalled.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config.all;

entity fetch is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;
    i_cancel : in std_logic;

    -- Results from the branch/PC correction unit in the EX stage (async).
    i_pccorr_source : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_pccorr_target : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_pccorr_is_branch : in std_logic;
    i_pccorr_is_taken : in std_logic;
    i_pccorr_adjust : in std_logic;  -- 1 if the PC correction needs to be applied.
    i_pccorr_adjusted_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- Wishbone master interface.
    o_wb_cyc : out std_logic;
    o_wb_stb : out std_logic;
    o_wb_adr : out std_logic_vector(C_WORD_SIZE-1 downto 2);
    i_wb_dat : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_wb_ack : in std_logic;
    i_wb_stall : in std_logic;
    i_wb_err : in std_logic;

    -- To ID stage (sync).
    o_pc : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_instr : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_bubble : out std_logic  -- 1 if IF could not provide a new instruction.
  );
end fetch;

architecture rtl of fetch is
  signal s_stall_if1 : std_logic;

  signal s_if1_active : std_logic;
  signal s_if1_latched_pccorr_adjusted_pc : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_if1_latched_pccorr_adjust : std_logic;
  signal s_if1_latched_btb_target : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_if1_latched_btb_taken : std_logic;
  signal s_if1_btb_read_en : std_logic;
  signal s_if1_btb_read_pc : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_if1_btb_taken : std_logic;
  signal s_if1_btb_target : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_if1_next_pc : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_if1_pc : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_if1_next_request_is_active : std_logic;
  signal s_if1_request_is_active : std_logic;

  signal s_if2_latched_cancel : std_logic;
  signal s_if2_latched_wb_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_if2_latched_wb_ack : std_logic;
  signal s_if2_has_ack : std_logic;
  signal s_if2_pending_ack : std_logic;

  signal s_if2_next_pc : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_if2_next_instr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_if2_next_bubble : std_logic;
begin
  --------------------------------------------------------------------------------------------------
  -- Pipeline Stage 1: IF1 (Program Counter)
  --------------------------------------------------------------------------------------------------

  -- Instantiate the branch target buffer.
  s_if1_btb_read_en <= not s_stall_if1;
  s_if1_btb_read_pc <= s_if1_next_pc & "00";
  btb_0: entity work.branch_target_buffer
    port map (
      -- Control signals.
      i_clk => i_clk,
      i_rst => i_rst,
      i_invalidate => '0',

      -- Buffer lookup (sync).
      i_read_en => s_if1_btb_read_en,
      i_read_pc => s_if1_btb_read_pc,
      o_predict_taken => s_if1_btb_taken,
      o_predict_target => s_if1_btb_target,

      -- Buffer update (sync).
      i_write_pc => i_pccorr_source,
      i_write_is_branch => i_pccorr_is_branch,
      i_write_is_taken => i_pccorr_is_taken,
      i_write_target => i_pccorr_target
    );

  -- We need to latch PC corrections and BTB PC predictions when IF1 is stalled,
  -- so that they are not lost.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      -- We start with a forced jump to the reset PC.
      s_if1_latched_pccorr_adjusted_pc <= C_RESET_PC(C_WORD_SIZE-1 downto 2);
      s_if1_latched_pccorr_adjust <= '1';
      s_if1_latched_btb_target <= (others => '0');
      s_if1_latched_btb_taken <= '0';
    elsif rising_edge(i_clk) then
      if i_pccorr_adjust = '1' and s_stall_if1 = '1' then
        s_if1_latched_pccorr_adjust <= '1';
        s_if1_latched_pccorr_adjusted_pc <= i_pccorr_adjusted_pc(C_WORD_SIZE-1 downto 2);
      else
        s_if1_latched_pccorr_adjust <= '0';
      end if;
      if s_if1_btb_taken = '1' and (s_stall_if1 = '1' or s_if1_request_is_active = '0') then
        s_if1_latched_btb_taken <= '1';
        s_if1_latched_btb_target <= s_if1_btb_target(C_WORD_SIZE-1 downto 2);
      else
        s_if1_latched_btb_taken <= '0';
      end if;
    end if;
  end process;

  -- Determine the next PC, based on a few different information sources:
  s_if1_next_pc <=
      i_pccorr_adjusted_pc(C_WORD_SIZE-1 downto 2) when i_pccorr_adjust = '1' else
      s_if1_latched_pccorr_adjusted_pc when s_if1_latched_pccorr_adjust = '1' else
      s_if1_pc when s_if1_request_is_active = '0' else
      s_if1_btb_target(C_WORD_SIZE-1 downto 2) when s_if1_btb_taken = '1' else
      s_if1_latched_btb_target when s_if1_latched_btb_taken = '1' else
      std_logic_vector(unsigned(s_if1_pc) + to_unsigned(1, 1));

  -- Should we send a memory request?
  s_if1_next_request_is_active <= s_if1_active and not i_wb_stall;

  -- Should IF1 be stalled?
  s_stall_if1 <= i_stall or s_if2_pending_ack;

  -- Signals to the IF2 stage (sync).
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_if1_active <= '0';
      s_if1_pc <= (others => '0');
      s_if1_request_is_active <= '0';
    elsif rising_edge(i_clk) then
      s_if1_active <= '1';
      if s_stall_if1 = '0' then
        s_if1_pc <= s_if1_next_pc;
        s_if1_request_is_active <= s_if1_next_request_is_active;
      end if;
    end if;
  end process;

  -- Outputs to the instruction Wishbone bus (async).

  -- A cycle is almost always active. The only situation when CYC shall be low
  -- is when we're stalled and we're no longer waiting for any more ACK:s.
  o_wb_cyc <= s_if1_active and ((not s_if2_latched_wb_ack) or (not s_stall_if1));

  -- We try to initiate a new request on every cycle that we're not stalled.
  o_wb_stb <= s_if1_active and not s_stall_if1;

  -- The read address is the predicted or corrected PC.
  o_wb_adr <= s_if1_next_pc;


  --------------------------------------------------------------------------------------------------
  -- Pipeline Stage 2: IF2 (Instruction Fetch)
  --------------------------------------------------------------------------------------------------

  -- We need to latch memory read results and cancel requests when i_stall = '1', so that they are
  -- not lost.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_if2_latched_cancel <= '0';
      s_if2_latched_wb_dat <= (others => '0');
      s_if2_latched_wb_ack <= '0';
    elsif rising_edge(i_clk) then
      if i_stall = '1' then
        if i_cancel = '1' then
          s_if2_latched_cancel <= '1';
        end if;
        if i_wb_ack = '1' then
          s_if2_latched_wb_ack <= '1';
          s_if2_latched_wb_dat <= i_wb_dat;
        end if;
      else
        s_if2_latched_cancel <= '0';
        s_if2_latched_wb_ack <= '0';
      end if;
    end if;
  end process;

  -- Do we have any data from the memory interface?
  s_if2_has_ack <= i_wb_ack or s_if2_latched_wb_ack;
  s_if2_pending_ack <= s_if1_request_is_active and not s_if2_has_ack;

  -- Determine what to send to the ID stage.
  s_if2_next_pc <= s_if1_pc;
  s_if2_next_instr <= s_if2_latched_wb_dat when s_if2_latched_wb_ack = '1' else i_wb_dat;
  s_if2_next_bubble <= i_cancel or s_if2_latched_cancel or not s_if2_has_ack;

  -- Output to the ID stage (sync).
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_pc <= (others => '0');
      o_instr <= (others => '0');
      o_bubble <= '1';
    elsif rising_edge(i_clk) then
      if i_stall = '0' then
        o_pc <= s_if2_next_pc & "00";
        o_instr <= s_if2_next_instr;
        o_bubble <= s_if2_next_bubble;
      end if;
    end if;
  end process;

end rtl;
