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
-- Pipeline Stage 2: Instruction Fetch (IF)
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
      o_stall : out std_logic;
      i_cancel : in std_logic;

      -- Signals from the PC stage.
      i_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- ICache interface.
      o_icache_req : out std_logic;
      o_icache_addr : out std_logic_vector(C_WORD_SIZE-1 downto 2);
      i_icache_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_icache_data_ready : in std_logic;

      -- To ID stage (sync).
      o_pc : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_instr : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_bubble : out std_logic  -- 1 if IF could not provide a new instruction.
    );
end fetch;

architecture rtl of fetch is
  -- Branch calculation signals.
  signal s_bubble : std_logic;

  -- Internal stall handling signals.
  signal s_stall : std_logic;
begin
  -- Instruction fetch from the ICache.
  o_icache_req <= '1';  -- We always read from the cache.
  o_icache_addr <= i_pc(C_WORD_SIZE-1 downto 2);

  -- Determine if we need to send a bubble down the pipeline.
  s_bubble <= i_cancel or not i_icache_data_ready;

  -- Determine if we need to stall the fetch stage.
  s_stall <= i_stall or not i_icache_data_ready;

  -- Outputs to the ID stage.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      o_pc <= (others => '0');
      o_instr <= (others => '0');
      o_bubble <= '1';
    elsif rising_edge(i_clk) then
      if s_stall = '0' then
        o_pc <= i_pc;
        o_instr <= i_icache_data;
      end if;

      -- If we're idling this cycle, we need to let ID know since it will continue running anyway.
      -- I.e. don't let ID use the PC or instruction signals since they are not valid.
      o_bubble <= s_bubble;
    end if;
  end process;

  -- Should we stall previous stages in the pipeline?
  o_stall <= not i_icache_data_ready;
end rtl;
