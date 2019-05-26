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
-- This implements the scalar register file, with the following properties:
--
--  * There are three generic read ports.
--  * There is a single write port.
--  * Reading the Z register always returns zero (0).
--  * Reading the PC register returns the current PC (from the input i_pc).
--  * Writing to the Z or PC registers has no effect (no operation).
--  * Register content is undefined after reset.
---------------------------------------------------------------------------------------------------

entity regs_scalar is
  port (
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall_read_ports : in std_logic;

    -- Asynchronous read requestes (three read ports).
    i_sel_a : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
    i_sel_b : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
    i_sel_c : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);

    -- Output read data.
    o_data_a : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_data_b : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_data_c : out std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- We have one write port.
    i_we : in std_logic;
    i_data_w : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_sel_w : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);

    -- The PC register always returns the current PC.
    i_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0)
  );
end regs_scalar;

architecture rtl of regs_scalar is
  signal s_next_sel_a : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_next_sel_b : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_next_sel_c : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);

  signal s_sel_a : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_sel_b : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
  signal s_sel_c : std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);

  signal s_data_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_data_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_data_c : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  -- Latch the read addresses.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_sel_a <= (others => '0');
      s_sel_b <= (others => '0');
      s_sel_c <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_stall_read_ports = '0' then
        s_sel_a <= s_next_sel_a;
        s_sel_b <= s_next_sel_b;
        s_sel_c <= s_next_sel_c;
      end if;
    end if;
  end process;

  -- Handle stall:
  -- Use inputs or latched inputs from the previous cycle.
  s_next_sel_a <= i_sel_a when i_stall_read_ports = '0' else s_sel_a;
  s_next_sel_b <= i_sel_b when i_stall_read_ports = '0' else s_sel_b;
  s_next_sel_c <= i_sel_c when i_stall_read_ports = '0' else s_sel_c;

  -- One RAM for the A read port.
  ram_a: entity work.ram_dual_port
    generic map (
      WIDTH => C_WORD_SIZE,
      ADDR_BITS => C_LOG2_NUM_REGS
    )
    port map (
      i_clk => i_clk,
      i_write_data => i_data_w,
      i_write_addr => i_sel_w,
      i_we => i_we,
      i_read_addr => s_next_sel_a,
      o_read_data => s_data_a
    );

  -- One RAM for the B read port.
  ram_b: entity work.ram_dual_port
    generic map (
      WIDTH => C_WORD_SIZE,
      ADDR_BITS => C_LOG2_NUM_REGS
    )
    port map (
      i_clk => i_clk,
      i_write_data => i_data_w,
      i_write_addr => i_sel_w,
      i_we => i_we,
      i_read_addr => s_next_sel_b,
      o_read_data => s_data_b
    );

  -- One RAM for the C read port.
  ram_c: entity work.ram_dual_port
    generic map (
      WIDTH => C_WORD_SIZE,
      ADDR_BITS => C_LOG2_NUM_REGS
    )
    port map (
      i_clk => i_clk,
      i_write_data => i_data_w,
      i_write_addr => i_sel_w,
      i_we => i_we,
      i_read_addr => s_next_sel_c,
      o_read_data => s_data_c
    );

  -- Read ports.
  o_data_a <=
      (others => '0') when s_sel_a = to_vector(C_Z_REG, C_LOG2_NUM_REGS) else
      i_pc when s_sel_a = to_vector(C_PC_REG, C_LOG2_NUM_REGS) else
      s_data_a;
  o_data_b <=
      (others => '0') when s_sel_b = to_vector(C_Z_REG, C_LOG2_NUM_REGS) else
      i_pc when s_sel_b = to_vector(C_PC_REG, C_LOG2_NUM_REGS) else
      s_data_b;
  o_data_c <=
      (others => '0') when s_sel_c = to_vector(C_Z_REG, C_LOG2_NUM_REGS) else
      i_pc when s_sel_c = to_vector(C_PC_REG, C_LOG2_NUM_REGS) else
      s_data_c;
end rtl;
