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

---------------------------------------------------------------------------------------------------
-- This implements the vector register file, with the following properties:
--
--  * There are two read ports.
--  * There is a single write port.
--  * TODO: Reading the VZ register always returns zero (0).
--  * TODO: Writing to the VZ register has no effect (no operation).
---------------------------------------------------------------------------------------------------

entity regs_vector is
  port (
    i_clk : in std_logic;
    i_rst : in std_logic;

    -- We have two read ports.
    i_sel_a : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
    i_element_a : in std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
    o_data_a : out std_logic_vector(C_WORD_SIZE-1 downto 0);

    i_sel_b : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
    i_element_b : in std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
    o_data_b : out std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- We have one write port.
    i_we : in std_logic;
    i_data_w : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_sel_w : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
    i_element_w : in std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0)
  );
end regs_vector;

architecture rtl of regs_vector is
  constant C_ADDR_BITS : integer := C_LOG2_NUM_REGS + C_LOG2_VEC_REG_ELEMENTS;
  signal s_read_a_addr : std_logic_vector(C_ADDR_BITS-1 downto 0);
  signal s_read_b_addr : std_logic_vector(C_ADDR_BITS-1 downto 0);
  signal s_write_addr : std_logic_vector(C_ADDR_BITS-1 downto 0);

  signal s_data_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_data_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  s_read_a_addr <= i_sel_a & i_element_a;
  s_read_b_addr <= i_sel_b & i_element_b;
  s_write_addr <= i_sel_w & i_element_w;

  -- One RAM for the A read port.
  ram_a: entity work.ram_dual_port
    generic map (
      WIDTH => C_WORD_SIZE,
      ADDR_BITS => C_ADDR_BITS
    )
    port map (
      i_clk => i_clk,
      i_write_data => i_data_w,
      i_write_addr => s_write_addr,
      i_we => i_we,
      i_read_addr => s_read_a_addr,
      o_read_data => s_data_a
    );

  -- One RAM for the B read port.
  ram_b: entity work.ram_dual_port
    generic map (
      WIDTH => C_WORD_SIZE,
      ADDR_BITS => C_ADDR_BITS
    )
    port map (
      i_clk => i_clk,
      i_write_data => i_data_w,
      i_write_addr => s_write_addr,
      i_we => i_we,
      i_read_addr => s_read_b_addr,
      o_read_data => s_data_b
    );

  -- Read ports.
  -- TODO(m): Handle register lengths (return zeros for i_element_* >= RL).
  -- TODO(m): Return zero when i_sel_* is zero (either explicitly or by hardwiring RL
  -- of VZ to zero).
  o_data_a <= s_data_a;
  o_data_b <= s_data_b;
end rtl;
