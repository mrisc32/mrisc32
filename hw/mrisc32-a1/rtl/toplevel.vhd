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
-- This is the top level entity, mostly intended for simple FPGA synthesis & fitting tests. The
-- entity consists of a single CPU core and exposes a single 32-bit Wishbone memory interface.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.config.all;

entity toplevel is
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
    i_wb_err : in std_logic
  );
end toplevel;

architecture rtl of toplevel is
begin
  core_1: entity work.core
    port map (
      i_clk => i_clk,
      i_rst => i_rst,

      -- Data interface.
      o_wb_cyc => o_wb_cyc,
      o_wb_stb => o_wb_stb,
      o_wb_adr => o_wb_adr,
      o_wb_dat => o_wb_dat,
      o_wb_we => o_wb_we,
      o_wb_sel => o_wb_sel,
      i_wb_dat => i_wb_dat,
      i_wb_ack => i_wb_ack,
      i_wb_stall => i_wb_stall,
      i_wb_err => i_wb_err
    );
end rtl;
