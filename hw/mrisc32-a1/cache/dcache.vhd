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

entity dcache is
  port(
      -- (ignored)
      i_clk : in std_logic;
      i_rst : in std_logic;

      -- CPU interface.
      i_cpu_req : in std_logic;
      i_cpu_we : in std_logic;
      i_cpu_byte_mask : in std_logic_vector(C_WORD_SIZE/8-1 downto 0);
      i_cpu_addr : in std_logic_vector(C_WORD_SIZE-1 downto 2);
      i_cpu_write_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_cpu_read_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_cpu_read_data_ready : out std_logic;

      -- Memory interface.
      o_mem_req : out std_logic;
      o_mem_we : out std_logic;
      o_mem_byte_mask : out std_logic_vector(C_WORD_SIZE/8-1 downto 0);
      o_mem_addr : out std_logic_vector(C_WORD_SIZE-1 downto 2);
      o_mem_write_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_mem_read_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_mem_read_data_ready : in std_logic
    );
end dcache;

architecture behavioural of dcache is
begin
  -- We just forward all requests to the main memory interface.
  o_mem_req <= i_cpu_req;
  o_mem_we <= i_cpu_we;
  o_mem_byte_mask <= i_cpu_byte_mask;
  o_mem_addr <= i_cpu_addr;
  o_mem_write_data <= i_cpu_write_data;

  -- ...and send the result right back.
  o_cpu_read_data <= i_mem_read_data;
  o_cpu_read_data_ready <= i_mem_read_data_ready;
end behavioural;
