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
use work.config.all;


----------------------------------------------------------------------------------------------------
-- This entity arbitrates memory access requests from the instruction and the data ports of the
-- pipeline.
----------------------------------------------------------------------------------------------------

entity mem_arbiter is
  port(
    -- (ignored)
    i_clk : in std_logic;
    i_rst : in std_logic;

    -- Instruction interface.
    i_instr_cyc : in std_logic;
    i_instr_stb : in std_logic;
    i_instr_adr : in std_logic_vector(C_WORD_SIZE-1 downto 2);
    o_instr_dat : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_instr_ack : out std_logic;
    o_instr_stall : out std_logic;
    o_instr_err : out std_logic;

    -- Data interface.
    i_data_cyc : in std_logic;
    i_data_stb : in std_logic;
    i_data_we : in std_logic;
    i_data_sel : in std_logic_vector(C_WORD_SIZE/8-1 downto 0);
    i_data_adr : in std_logic_vector(C_WORD_SIZE-1 downto 2);
    i_data_dat_w : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_data_dat : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_data_ack : out std_logic;
    o_data_stall : out std_logic;
    o_data_err : out std_logic;

    -- Memory interface.
    o_mem_cyc : out std_logic;
    o_mem_stb : out std_logic;
    o_mem_we : out std_logic;
    o_mem_sel : out std_logic_vector(C_WORD_SIZE/8-1 downto 0);
    o_mem_adr : out std_logic_vector(C_WORD_SIZE-1 downto 2);
    o_mem_dat_w : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_mem_dat : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_mem_ack : in std_logic;
    i_mem_stall : in std_logic;
    i_mem_err : in std_logic
  );
end mem_arbiter;

architecture rtl of mem_arbiter is
  signal s_next_serve_data : std_logic;
  signal s_next_serve_instr : std_logic;
  signal s_serve_data : std_logic;
  signal s_serve_instr : std_logic;

  signal s_pending_data_ack : std_logic;
  signal s_pending_instr_ack : std_logic;
  signal s_stall_inactive_data : std_logic;
  signal s_stall_inactive_instr : std_logic;
begin
  -- Determine if a memory request is being finished during this cycle.
  --
  -- NOTE: This assumes that the master will never have more than one outstanding
  -- request (which is currently true). For more advanced caches this may no longer hold.
  -- TODO(m): Properly solve this, e.g. in one of the following ways:
  --   - Respond with o_instr_stall/o_data_stall = '1' when multiple pipelined requests are
  --     detected (poor performance as it kills pipelining).
  --   - Keep a count of outstanding requests (with an upper limit, then stall). This
  --     keeps the instr pipeline running, but may starve the data port.
  --   - Implement a proper request pipeline/FIFO, to be able to match STB:s with ACK:s
  --     and send the result back to the correct master.
  s_pending_data_ack <= s_serve_data and not i_mem_ack;
  s_pending_instr_ack <= s_serve_instr and not i_mem_ack;

  -- The state machine decides whether we wait for instruction or data results from the
  -- memory bus.
  --
  -- The data port has priority over the instruction port.
  --
  -- Rationale: If the execute stage of the pipeline waits for a data access cycle, it will
  -- stall the instruction fetch stage of the pipeline anyway. I.e. better finish the data
  -- cycle before servicing the instruction fetch.

  s_next_serve_data <= (i_data_cyc and i_data_stb and not s_pending_instr_ack) or
                       s_pending_data_ack;
  s_next_serve_instr <= (i_instr_cyc and i_instr_stb and not s_next_serve_data) or
                        s_pending_instr_ack;

  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_serve_data <= '0';
      s_serve_instr <= '0';
    elsif rising_edge(i_clk) then
      s_serve_data <= s_next_serve_data;
      s_serve_instr <= s_next_serve_instr;
    end if;
  end process;

  -- Determine if we should stall one port because the other port is busy.
  s_stall_inactive_data <= (i_data_cyc and i_data_stb) when s_next_serve_data = '0' else '0';
  s_stall_inactive_instr <= (i_instr_cyc and i_instr_stb) when s_next_serve_instr = '0' else '0';

  -- Send the request to the memory bus from either the instruction or data ports
  -- of the pipeline.
  o_mem_cyc <= i_data_cyc or i_instr_cyc;
  o_mem_stb <= i_data_stb when s_next_serve_data = '1' else i_instr_stb;
  o_mem_we <= i_data_we when s_next_serve_data = '1' else '0';
  o_mem_sel <= i_data_sel when s_next_serve_data = '1' else (others => '1');
  o_mem_adr <= i_data_adr when s_next_serve_data = '1' else i_instr_adr;
  o_mem_dat_w <= i_data_dat_w;

  -- Send results to the data port.
  o_data_dat <= i_mem_dat;
  o_data_ack <= i_mem_ack and s_serve_data;
  o_data_stall <= i_mem_stall when s_next_serve_data = '1' else s_stall_inactive_data;
  o_data_err <= i_mem_err and s_serve_data;

  -- Send results to the instruction port.
  o_instr_dat <= i_mem_dat;
  o_instr_ack <= i_mem_ack and s_serve_instr;
  o_instr_stall <= i_mem_stall when s_next_serve_instr = '1' else s_stall_inactive_instr;
  o_instr_err <= i_mem_err and s_serve_instr;
end rtl;
