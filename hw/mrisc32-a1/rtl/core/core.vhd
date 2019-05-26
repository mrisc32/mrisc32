----------------------------------------------------------------------------------------------------
-- Copyright (c) 2019 Marcus Geelnard
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
-- This is a single CPU core, including the pipeline and caches.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.config.all;
use work.debug.all;

entity core is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;

    -- Memory interface to the outside world (Wishbone B4 pipelined master).
    o_wb_cyc : out std_logic;
    o_wb_stb : out std_logic;
    o_wb_adr : out std_logic_vector(C_WORD_SIZE-1 downto 2);
    o_wb_dat : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_wb_we : out std_logic;
    o_wb_sel : out std_logic_vector(C_WORD_SIZE/8-1 downto 0);
    i_wb_dat : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_wb_ack : in std_logic;
    i_wb_stall : in std_logic;
    i_wb_err : in std_logic;

    -- Debug trace interface.
    o_debug_trace : out T_DEBUG_TRACE
  );
end core;

architecture rtl of core is
  -- Pipeline instruction bus master signals.
  signal s_instr_cyc : std_logic;
  signal s_instr_stb : std_logic;
  signal s_instr_adr : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_instr_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_instr_ack : std_logic;
  signal s_instr_stall : std_logic;
  signal s_instr_err : std_logic;

  -- Pipeline data bus master signals.
  signal s_data_cyc : std_logic;
  signal s_data_stb : std_logic;
  signal s_data_adr : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_data_dat_w : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_data_we : std_logic;
  signal s_data_sel : std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_data_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_data_ack : std_logic;
  signal s_data_stall : std_logic;
  signal s_data_err : std_logic;

  -- ICache bus master signals.
  signal s_icache_cyc : std_logic;
  signal s_icache_stb : std_logic;
  signal s_icache_adr : std_logic_vector(C_WORD_SIZE-1 downto 2);
  signal s_icache_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_icache_ack : std_logic;
  signal s_icache_stall : std_logic;
  signal s_icache_err : std_logic;
begin
  --------------------------------------------------------------------------------------------------
  -- Pipeline.
  --------------------------------------------------------------------------------------------------

  pipeline_1: entity work.pipeline
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      -- Instruction interface.
      o_instr_cyc => s_instr_cyc,
      o_instr_stb => s_instr_stb,
      o_instr_adr => s_instr_adr,
      i_instr_dat => s_instr_dat,
      i_instr_ack => s_instr_ack,
      i_instr_stall => s_instr_stall,
      i_instr_err => s_instr_err,

      -- Data interface.
      o_data_cyc => s_data_cyc,
      o_data_stb => s_data_stb,
      o_data_adr => s_data_adr,
      o_data_dat => s_data_dat_w,
      o_data_we => s_data_we,
      o_data_sel => s_data_sel,
      i_data_dat => s_data_dat,
      i_data_ack => s_data_ack,
      i_data_stall => s_data_stall,
      i_data_err => s_data_err,

      -- Debug trace interface.
      o_debug_trace => o_debug_trace
    );


  --------------------------------------------------------------------------------------------------
  -- Caches and memory interface.
  --------------------------------------------------------------------------------------------------

  icache_1: entity work.icache
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_instr_cyc => s_instr_cyc,
      i_instr_stb => s_instr_stb,
      i_instr_adr => s_instr_adr,
      o_instr_dat => s_instr_dat,
      o_instr_ack => s_instr_ack,
      o_instr_stall => s_instr_stall,
      o_instr_err => s_instr_err,

      o_mem_cyc => s_icache_cyc,
      o_mem_stb => s_icache_stb,
      o_mem_adr => s_icache_adr,
      i_mem_dat => s_icache_dat,
      i_mem_ack => s_icache_ack,
      i_mem_stall => s_icache_stall,
      i_mem_err => s_icache_err
    );

  mem_arbiter_1: entity work.mem_arbiter
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      i_instr_cyc => s_icache_cyc,
      i_instr_stb => s_icache_stb,
      i_instr_adr => s_icache_adr,
      o_instr_dat => s_icache_dat,
      o_instr_ack => s_icache_ack,
      o_instr_stall => s_icache_stall,
      o_instr_err => s_icache_err,

      i_data_cyc => s_data_cyc,
      i_data_stb => s_data_stb,
      i_data_we => s_data_we,
      i_data_sel => s_data_sel,
      i_data_adr => s_data_adr,
      i_data_dat_w => s_data_dat_w,
      o_data_dat => s_data_dat,
      o_data_ack => s_data_ack,
      o_data_stall => s_data_stall,
      o_data_err => s_data_err,

      o_mem_cyc => o_wb_cyc,
      o_mem_stb => o_wb_stb,
      o_mem_we => o_wb_we,
      o_mem_sel => o_wb_sel,
      o_mem_adr => o_wb_adr,
      o_mem_dat_w => o_wb_dat,
      i_mem_dat => i_wb_dat,
      i_mem_ack => i_wb_ack,
      i_mem_stall => i_wb_stall,
      i_mem_err => i_wb_err
    );
end rtl;
