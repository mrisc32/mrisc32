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
use work.consts.all;

---------------------------------------------------------------------------------------------------
-- This implements the 32-entry scalar register file, with the following properties:
--
--  * There are three generic read ports.
--  * There is a dedicated, fourth read port for the VL register.
--  * There is a single write port.
--  * Data is forwarded from the write port to the read ports within the same cycle.
--  * Reading the Z register always returns zero ("00000000000000000000000000000000").
--  * Reading the PC register returns the current PC (from the input i_pc).
---------------------------------------------------------------------------------------------------

entity reg32x32 is
  port (
    i_clk : in std_logic;
    i_rst : in std_logic;

    -- We have three generic read ports.
    i_sel_a : in std_logic_vector(4 downto 0);
    i_sel_b : in std_logic_vector(4 downto 0);
    i_sel_c : in std_logic_vector(4 downto 0);
    o_data_a : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_data_b : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_data_c : out std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- One read port is hard-wired to the VL register.
    o_vl : out std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- We have one write port.
    i_we : in std_logic;
    i_data_w : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_sel_w : in std_logic_vector(4 downto 0);

    -- The PC register always returns the current PC.
    i_pc : in std_logic_vector(C_WORD_SIZE-1 downto 0)
  );
end reg32x32;

architecture behavioural of reg32x32 is
  type registerFile is array(0 to C_NUM_REGS-1) of std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal regs : registerFile;

  constant C_Z_REG  : integer := 0;   -- Z  = S0
  constant C_VL_REG : integer := 29;  -- VL = S29
  constant C_PC_REG : integer := 31;  -- PC = S31

begin
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      for i in regs'range loop
        regs(i) <= (others => '0');
      end loop;
    elsif rising_edge(i_clk) then
      -- Read.
      o_data_a <= regs(to_integer(unsigned(i_sel_a)));
      o_data_b <= regs(to_integer(unsigned(i_sel_b)));
      o_data_c <= regs(to_integer(unsigned(i_sel_c)));

      -- Always read the VL register (S29).
      o_vl <= regs(C_VL_REG);

      -- Write.
      if (i_we = '1') then
        regs(to_integer(unsigned(i_sel_w))) <= i_data_w;

        -- Bypass for read ports (overrides reads from the register file).
        if i_sel_a = i_sel_w then
          o_data_a <= i_data_w;
        end if;
        if i_sel_b = i_sel_w then
          o_data_b <= i_data_w;
        end if;
        if i_sel_c = i_sel_w then
          o_data_c <= i_data_w;
        end if;
        if i_sel_w = std_logic_vector(to_unsigned(C_VL_REG, 5)) then
          o_vl <= i_data_w;
        end if;
      end if;

      -- Read-only register reads trump other reads.
      if i_sel_a = std_logic_vector(to_unsigned(C_Z_REG, 5)) then
        o_data_a <= (others => '0');
      elsif i_sel_a = std_logic_vector(to_unsigned(C_PC_REG, 5)) then
        o_data_a <= i_pc;
      end if;
      if i_sel_b = std_logic_vector(to_unsigned(C_Z_REG, 5)) then
        o_data_b <= (others => '0');
      elsif i_sel_b = std_logic_vector(to_unsigned(C_PC_REG, 5)) then
        o_data_b <= i_pc;
      end if;
      if i_sel_c = std_logic_vector(to_unsigned(C_Z_REG, 5)) then
        o_data_c <= (others => '0');
      elsif i_sel_c = std_logic_vector(to_unsigned(C_PC_REG, 5)) then
        o_data_c <= i_pc;
      end if;
    end if;
  end process;
end behavioural;

