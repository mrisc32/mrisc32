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
--  * There is a dedicated, fourth read port hard-wired to the VL register.
--  * There is a single write port.
--  * Data is forwarded from the write port to the read ports within the same cycle.
--  * Reading the Z register always returns zero (0).
--  * Reading the PC register returns the current PC (from the input i_pc).
--  * Writing to the Z or PC registers has no effect (no operation).
---------------------------------------------------------------------------------------------------

entity regs_scalar is
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
end regs_scalar;

architecture rtl of regs_scalar is
  constant C_Z_REG  : integer := 0;   -- Z  = S0
  constant C_VL_REG : integer := 29;  -- VL = S29
  constant C_PC_REG : integer := 31;  -- PC = S31

  -- There are 30 internal write-enable signals (one for each dynamic register).
  type T_WE_ARRAY is array (1 to 30) of std_logic;
  signal s_we : T_WE_ARRAY;

  -- There are 32 internal register data signals.
  type T_DATA_ARRAY is array (0 to 31) of std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_data : T_DATA_ARRAY;
begin
  -- Instantiate the registers.
  -- Note: We do not need any registers for S0 and S31, since they are read-only.
  RegGen: for k in 1 to 30 generate
    reg_x: entity work.reg
      generic map (
        WIDTH => C_WORD_SIZE
      )
      port map (
        i_clk => i_clk,
        i_rst => i_rst,
        i_we => s_we(k),
        i_data_w => i_data_w,
        o_data => s_data(k)
      );
  end generate;

  -- The write port of the register file is connected to all registers. Select which register to
  -- write to by setting at most one of the register write-enable signals to '1'.
  WEGen: for k in 1 to 30 generate
    s_we(k) <= i_we when i_sel_w = std_logic_vector(to_unsigned(k, i_sel_w'length)) else '0';
  end generate;

  -- We hard-wire the values of registers 0 and 31 to Z and PC respectively.
  s_data(C_Z_REG) <= (others => '0');
  s_data(C_PC_REG) <= i_pc;

  -- We hard-wire the VL read-port to the VL-register.
  o_vl <= s_data(C_VL_REG);

  -- Read ports.
  o_data_a <= s_data(to_integer(unsigned(i_sel_a)));
  o_data_b <= s_data(to_integer(unsigned(i_sel_b)));
  o_data_c <= s_data(to_integer(unsigned(i_sel_c)));
end rtl;
