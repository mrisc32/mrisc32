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
  -- Internal write-enable signals (one for each dynamic register, which excludes VZ).
  type T_WE_MATRIX is array (1 to C_NUM_REGS-1, 0 to C_VEC_REG_ELEMENTS-1) of std_logic;
  signal s_we : T_WE_MATRIX;

  -- Internal register data signals for all registers.
  type T_DATA_MATRIX is array (0 to C_NUM_REGS-1, 0 to C_VEC_REG_ELEMENTS-1) of std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_data : T_DATA_MATRIX;
begin
  -- Instantiate the registers.
  -- Note: We only need registers that can be written (read-only registers are handled separately).
  RegGen: for r in 1 to C_NUM_REGS-1 generate
    ElementGen: for e in 0 to C_VEC_REG_ELEMENTS-1 generate
      reg_x: entity work.reg
        generic map (
          WIDTH => C_WORD_SIZE
        )
        port map (
          i_clk => i_clk,
          i_rst => i_rst,
          i_we => s_we(r, e),
          i_data_w => i_data_w,
          o_data => s_data(r, e)
        );
    end generate;
  end generate;

  -- The write port of the register file is connected to all registers. Select which register to
  -- write to by setting at most one of the register write-enable signals to '1'.
  WEGen1: for r in 1 to C_NUM_REGS-1 generate
    WEGen2: for e in 0 to C_VEC_REG_ELEMENTS-1 generate
      s_we(r, e) <= i_we when
          i_sel_w = std_logic_vector(to_unsigned(r, i_sel_w'length)) and
          i_element_w = std_logic_vector(to_unsigned(e, i_element_w'length))
          else '0';
    end generate;
  end generate;

  -- We hard-wire the values of the VZ register to zero.
  VZGen: for e in 0 to C_VEC_REG_ELEMENTS-1 generate
    s_data(C_Z_REG, e) <= (others => '0');
  end generate;

  -- Read ports.
  o_data_a <= s_data(to_integer(unsigned(i_sel_a)), to_integer(unsigned(i_element_a)));
  o_data_b <= s_data(to_integer(unsigned(i_sel_b)), to_integer(unsigned(i_element_b)));
end rtl;
