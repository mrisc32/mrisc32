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

----------------------------------------------------------------------------------------------------
-- Operand forwarding to the EX stage (sent to the ID/EX flip-flops to be consumed by EX during the
-- next cycle).
--
-- An operand for use in the EX stage during the next cycle may come from:
--
--   * The EX1 stage.
--   * The EX2 stage.
--   * The EX3 stage.
--   * The EX4 stage.
--   * The WB stage.
--
-- This entity decides:
--
--   * Whether or not the pipeline needs to be stalled to wait for a value that is not yet ready.
--   * Whether or not to use a forwarded value.
--   * Which value to use (from which pipeline stage).
--
-- This entity only deals with one target operand, but there are up to three input operands to the
-- EX stage, so there will typically be three copies of this forwarding logic.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.types.all;
use work.config.all;

entity forward_to_ex is
  port(
      -- What register is requested (if any)?
      i_src_reg : in T_SRC_REG;
      i_reg_required : in std_logic;

      -- Operand information from the different pipeline stages.
      i_dst_reg_from_ex1 : in T_DST_REG;
      i_value_from_ex1 : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_ready_from_ex1 : in std_logic;

      i_dst_reg_from_ex2 : in T_DST_REG;
      i_value_from_ex2 : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_ready_from_ex2 : in std_logic;

      i_dst_reg_from_ex3 : in T_DST_REG;
      i_value_from_ex3 : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_ready_from_ex3 : in std_logic;

      i_dst_reg_from_ex4 : in T_DST_REG;
      i_value_from_ex4 : in std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- TODO(m): Is this necessary, or are we already reading the same value
      -- from the register file in the ID stage?
      i_dst_reg_from_wb : in T_DST_REG;
      i_value_from_wb : in std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- Operand selection for the EX stage.
      o_value : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_use_value : out std_logic;
      o_value_ready : out std_logic
    );
end forward_to_ex;

architecture rtl of forward_to_ex is
  signal s_reg_from_ex1 : std_logic;
  signal s_reg_from_ex2 : std_logic;
  signal s_reg_from_ex3 : std_logic;
  signal s_reg_from_ex4 : std_logic;
  signal s_reg_from_wb : std_logic;
begin
  -- Determine which stages are writing to the requested source register.
  s_reg_from_ex1 <= i_dst_reg_from_ex1.is_target when
      (i_src_reg.reg = i_dst_reg_from_ex1.reg) and
      ((i_src_reg.element = i_dst_reg_from_ex1.element) or (i_src_reg.is_vector = '0')) and
      (i_src_reg.is_vector = i_dst_reg_from_ex1.is_vector) else '0';
  s_reg_from_ex2 <= i_dst_reg_from_ex2.is_target when
      (i_src_reg.reg = i_dst_reg_from_ex2.reg) and
      ((i_src_reg.element = i_dst_reg_from_ex2.element) or (i_src_reg.is_vector = '0')) and
      (i_src_reg.is_vector = i_dst_reg_from_ex2.is_vector) else '0';
  s_reg_from_ex3 <= i_dst_reg_from_ex3.is_target when
      (i_src_reg.reg = i_dst_reg_from_ex3.reg) and
      ((i_src_reg.element = i_dst_reg_from_ex3.element) or (i_src_reg.is_vector = '0')) and
      (i_src_reg.is_vector = i_dst_reg_from_ex3.is_vector) else '0';
  s_reg_from_ex4 <= i_dst_reg_from_ex4.is_target when
      (i_src_reg.reg = i_dst_reg_from_ex4.reg) and
      ((i_src_reg.element = i_dst_reg_from_ex4.element) or (i_src_reg.is_vector = '0')) and
      (i_src_reg.is_vector = i_dst_reg_from_ex4.is_vector) else '0';
  s_reg_from_wb <= i_dst_reg_from_wb.is_target when
      (i_src_reg.reg = i_dst_reg_from_wb.reg) and
      ((i_src_reg.element = i_dst_reg_from_wb.element) or (i_src_reg.is_vector = '0')) and
      (i_src_reg.is_vector = i_dst_reg_from_wb.is_vector) else '0';

  -- Which value to forward?
  o_value <= i_value_from_ex1 when (s_reg_from_ex1 and i_ready_from_ex1) = '1' else
             i_value_from_ex2 when (s_reg_from_ex2 and i_ready_from_ex2) = '1' else
             i_value_from_ex3 when (s_reg_from_ex3 and i_ready_from_ex3) = '1' else
             i_value_from_ex4 when s_reg_from_ex4 = '1' else
             i_value_from_wb;

  -- Should the forwarded pipeline value be used instead of register file value?
  o_use_value <= i_reg_required and (s_reg_from_ex1 or s_reg_from_ex2 or s_reg_from_ex3 or s_reg_from_ex4 or s_reg_from_wb);

  -- Is the value ready for use?
  o_value_ready <= i_ready_from_ex1 when s_reg_from_ex1 = '1' else
                   i_ready_from_ex2 when s_reg_from_ex2 = '1' else
                   i_ready_from_ex3 when s_reg_from_ex3 = '1' else
                   '1';
end rtl;

