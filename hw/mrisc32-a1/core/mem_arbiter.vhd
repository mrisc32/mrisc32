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
use work.common.all;


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
      i_instr_adr : in std_logic_vector(C_WORD_SIZE-1 downto 2);
      o_instr_dat : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_instr_ack : out std_logic;
      -- o_instr_stall : out std_logic;
      -- o_instr_err : out std_logic;

      -- Data interface.
      i_data_cyc : in std_logic;
      i_data_we : in std_logic;
      i_data_sel : in std_logic_vector(C_WORD_SIZE/8-1 downto 0);
      i_data_adr : in std_logic_vector(C_WORD_SIZE-1 downto 2);
      i_data_dat_w : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_data_dat : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_data_ack : out std_logic;
      -- o_data_stall : out std_logic;
      -- o_data_err : out std_logic;

      -- Memory interface.
      o_mem_cyc : out std_logic;
      o_mem_we : out std_logic;
      o_mem_sel : out std_logic_vector(C_WORD_SIZE/8-1 downto 0);
      o_mem_adr : out std_logic_vector(C_WORD_SIZE-1 downto 2);
      o_mem_dat_w : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_mem_dat : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_mem_ack : in std_logic
      -- i_mem_stall : in std_logic;
      -- i_mem_err : in std_logic
    );
end mem_arbiter;

architecture behavioural of mem_arbiter is
  signal s_service_data : std_logic;
begin
  -- The data port has priority over the instruction port.
  s_service_data <= i_data_cyc;

  -- Send the request to the memory bus from either the instruction or data ports
  -- of the pipeline.
  o_mem_cyc <= i_instr_cyc or i_data_cyc;
  o_mem_we <= i_data_we and s_service_data;
  o_mem_sel <= i_data_sel when s_service_data = '1' else (others => '1');
  o_mem_adr <= i_data_adr when s_service_data = '1' else i_instr_adr;
  o_mem_dat_w <= i_data_dat_w;

  -- Send the result to the relevant port, and optionally stall the interfaces when waiting for
  -- read data.
  o_instr_dat <= i_mem_dat;
  o_instr_ack <= i_mem_ack and i_instr_cyc and not s_service_data;
  o_data_dat <= i_mem_dat;
  o_data_ack <= i_mem_ack and i_data_cyc and (not i_data_we) and s_service_data;
end behavioural;

