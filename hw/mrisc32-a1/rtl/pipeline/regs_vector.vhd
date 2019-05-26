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
use work.types.all;
use work.config.all;

---------------------------------------------------------------------------------------------------
-- This implements the vector register file, with the following properties:
--
--  * There are two read ports.
--  * There is a single write port.
--  * Reading the VZ register always returns zero (0).
--  * Writing to the VZ register has no effect (no operation).
--  * Register content is undefined after reset.
---------------------------------------------------------------------------------------------------

entity regs_vector is
  port (
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall_read_ports : in std_logic;

    -- Asynchronous read requestes.
    i_sel_a : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
    i_element_a : in std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
    i_sel_b : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
    i_element_b : in std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);

    -- Output read data.
    o_data_a : out std_logic_vector(C_WORD_SIZE-1 downto 0);
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

  -- Selected read addresses.
  signal s_read_sel_a : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_read_element_a : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
  signal s_read_sel_b : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_read_element_b : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);

  -- Clocked version of the asynchronous inputs.
  signal s_sel_a : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_element_a : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);
  signal s_sel_b : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_element_b : std_logic_vector(C_LOG2_VEC_REG_ELEMENTS-1 downto 0);

  signal s_data_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_data_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  -- Handle stall:
  -- Use inputs or latched inputs from the previous cycle.
  s_read_sel_a <= i_sel_a when i_stall_read_ports = '0' else s_sel_a;
  s_read_element_a <= i_element_a when i_stall_read_ports = '0' else s_element_a;
  s_read_sel_b <= i_sel_b when i_stall_read_ports = '0' else s_sel_b;
  s_read_element_b <= i_element_b when i_stall_read_ports = '0' else s_element_b;

  -- Generate read & write addresses for the next clock cycle.
  s_read_a_addr <= s_read_sel_a & s_read_element_a;
  s_read_b_addr <= s_read_sel_b & s_read_element_b;
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

  -- Latch the read addresses.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_sel_a <= (others => '0');
      s_element_a <= (others => '0');
      s_sel_b <= (others => '0');
      s_element_b <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall_read_ports = '0' then
        s_sel_a <= s_read_sel_a;
        s_element_a <= s_read_element_a;
        s_sel_b <= s_read_sel_b;
        s_element_b <= s_read_element_b;
      end if;
    end if;
  end process;

  -- Read ports.
  -- TODO(m): Handle register lengths (return zeros for i_element_* >= RL).
  o_data_a <= s_data_a when s_sel_a /= to_vector(0, C_LOG2_NUM_REGS) else (others => '0');
  o_data_b <= s_data_b when s_sel_b /= to_vector(0, C_LOG2_NUM_REGS) else (others => '0');
end rtl;
