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
use work.config.all;

entity icache is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;

    -- Instruction interface (WB slave).
    i_instr_cyc : in std_logic;
    i_instr_stb : in std_logic;
    i_instr_adr : in std_logic_vector(C_WORD_SIZE-1 downto 2);
    o_instr_dat : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_instr_ack : out std_logic;
    o_instr_stall : out std_logic;
    o_instr_err : out std_logic;

    -- Memory interface (WB master).
    o_mem_cyc : out std_logic;
    o_mem_stb : out std_logic;
    o_mem_adr : out std_logic_vector(C_WORD_SIZE-1 downto 2);
    i_mem_dat : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_mem_ack : in std_logic;
    i_mem_stall : in std_logic;
    i_mem_err : in std_logic
  );
end icache;

architecture rtl of icache is
begin
  -- We just forward all requests to the main memory interface.
  o_mem_cyc <= i_instr_cyc;
  o_mem_stb <= i_instr_stb;
  o_mem_adr <= i_instr_adr;

  -- ...and send the result right back.
  o_instr_dat <= i_mem_dat;
  o_instr_ack <= i_mem_ack;
  o_instr_stall <= i_mem_stall;
  o_instr_err <= i_mem_err;
end rtl;
