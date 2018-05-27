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
--  * Reading the VZ register always returns zero (0).
--  * Writing to the VZ register has no effect (no operation).
--
-- The registers are implemented as dual port RAMs (two identical copies of the reigsters: one for
-- each read port). Both RAMs are written to, so both RAMs contain identical data.
---------------------------------------------------------------------------------------------------

entity regs_vector is
  port (
    i_clk : in std_logic;
    i_rst : in std_logic;

    -- We have two generic read ports.
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
  constant C_RAM_ADDR_BITS : positive := C_LOG2_NUM_REGS + C_LOG2_VEC_REG_ELEMENTS;
  constant C_SEL_VZ : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0) := (others => '0');

  signal s_data_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_next_read_a_is_vz : std_logic;
  signal s_read_a_is_vz : std_logic;
  signal s_data_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_next_read_b_is_vz : std_logic;
  signal s_read_b_is_vz : std_logic;

  signal s_addr_a : std_logic_vector(C_RAM_ADDR_BITS-1 downto 0);
  signal s_addr_b : std_logic_vector(C_RAM_ADDR_BITS-1 downto 0);
  signal s_addr_w : std_logic_vector(C_RAM_ADDR_BITS-1 downto 0);
begin
  -- Logic for filtering reads of the VZ register.
  s_next_read_a_is_vz <= '1' when i_sel_a = C_SEL_VZ else '0';
  s_next_read_b_is_vz <= '1' when i_sel_b = C_SEL_VZ else '0';
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_read_a_is_vz <= '0';
      s_read_b_is_vz <= '0';
    elsif rising_edge(i_clk) then
      s_read_a_is_vz <= s_next_read_a_is_vz;
      s_read_b_is_vz <= s_next_read_b_is_vz;
    end if;
  end process;

  s_addr_a <= i_sel_a & i_element_a;
  s_addr_b <= i_sel_b & i_element_b;
  s_addr_w <= i_sel_w & i_element_w;

  -- ram_a is connected to the A read port.
  ram_a : entity work.ram_dual_port
    generic map (
      WIDTH => C_WORD_SIZE,
      ADDR_BITS => C_RAM_ADDR_BITS
    )
    port map (
      i_clk => i_clk,
      i_write_data => i_data_w,
      i_write_addr => s_addr_w,
      i_we => i_we,
      i_read_addr => s_addr_a,
      o_read_data => s_data_a
    );
  o_data_a <= s_data_a when s_read_a_is_vz = '0' else (others => '0');

  -- ram_b is connected to the B read port.
  ram_b : entity work.ram_dual_port
    generic map (
      WIDTH => C_WORD_SIZE,
      ADDR_BITS => C_RAM_ADDR_BITS
    )
    port map (
      i_clk => i_clk,
      i_write_data => i_data_w,
      i_write_addr => s_addr_w,
      i_we => i_we,
      i_read_addr => s_addr_b,
      o_read_data => s_data_b
    );
  o_data_b <= s_data_b when s_read_b_is_vz = '0' else (others => '0');
end rtl;
