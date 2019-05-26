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
-- Operand forwarding for the ID stage.
--
-- The VL (Vector Length) value may be forwarded from later pipeline stages.
--
-- This entity decides:
--
--   * Whether or not the pipeline needs to be stalled to wait for a value that is not yet ready.
--   * Whether or not to use a forwarded value.
--   * Which value to use (from which pipeline stage).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.types.all;
use work.config.all;

entity forward_to_vector_control is
  port(
      -- Do we need the VL value?
      i_vl_requested : in std_logic;

      -- Operand information from the different pipeline stages.
      i_dst_reg_from_id : in T_DST_REG;

      i_dst_reg_from_rf : in T_DST_REG;

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

      -- Operand selection for the ID stage.
      o_value : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_use_value : out std_logic;
      o_value_ready : out std_logic
    );
end forward_to_vector_control;

architecture rtl of forward_to_vector_control is
  signal s_reg_from_id : std_logic;
  signal s_reg_from_rf : std_logic;
  signal s_reg_from_ex1 : std_logic;
  signal s_reg_from_ex2 : std_logic;
  signal s_reg_from_ex3 : std_logic;
  signal s_reg_from_ex4 : std_logic;

  signal s_use_value : std_logic;
  signal s_value_ready : std_logic;
begin
  -- Determine which stages are writing to the VL register.
  -- Note: VL is a scalar register, so we only care about scalar registers and do not have
  -- to match against individual vector elements. This saves time since the register
  -- matching logic is a critical path.
  s_reg_from_id <= i_dst_reg_from_id.is_target when
      (i_dst_reg_from_id.reg = to_vector(C_VL_REG, C_LOG2_NUM_REGS)) and
      (i_dst_reg_from_id.is_vector = '0') else '0';
  s_reg_from_rf <= i_dst_reg_from_rf.is_target when
      (i_dst_reg_from_rf.reg = to_vector(C_VL_REG, C_LOG2_NUM_REGS)) and
      (i_dst_reg_from_rf.is_vector = '0') else '0';
  s_reg_from_ex1 <= i_dst_reg_from_ex1.is_target when
      (i_dst_reg_from_ex1.reg = to_vector(C_VL_REG, C_LOG2_NUM_REGS)) and
      (i_dst_reg_from_ex1.is_vector = '0') else '0';
  s_reg_from_ex2 <= i_dst_reg_from_ex2.is_target when
      (i_dst_reg_from_ex2.reg = to_vector(C_VL_REG, C_LOG2_NUM_REGS)) and
      (i_dst_reg_from_ex2.is_vector = '0') else '0';
  s_reg_from_ex3 <= i_dst_reg_from_ex3.is_target when
      (i_dst_reg_from_ex3.reg = to_vector(C_VL_REG, C_LOG2_NUM_REGS)) and
      (i_dst_reg_from_ex3.is_vector = '0') else '0';
  s_reg_from_ex4 <= i_dst_reg_from_ex4.is_target when
      (i_dst_reg_from_ex4.reg = to_vector(C_VL_REG, C_LOG2_NUM_REGS)) and
      (i_dst_reg_from_ex4.is_vector = '0') else '0';

  -- Which value to forward?
  o_value <= i_value_from_ex1 when (s_reg_from_ex1 and i_ready_from_ex1) = '1' else
             i_value_from_ex2 when (s_reg_from_ex2 and i_ready_from_ex2) = '1' else
             i_value_from_ex3 when (s_reg_from_ex3 and i_ready_from_ex3) = '1' else
             i_value_from_ex4;

  -- Should the forwarded pipeline value be used instead of register file value?
  s_use_value <= s_reg_from_id or s_reg_from_rf or s_reg_from_ex1 or s_reg_from_ex2 or s_reg_from_ex3 or s_reg_from_ex4;

  -- Is the value ready for use?
  s_value_ready <= '0' when (s_reg_from_id or s_reg_from_rf) = '1' else
                   i_ready_from_ex1 when s_reg_from_ex1 = '1' else
                   i_ready_from_ex2 when s_reg_from_ex2 = '1' else
                   i_ready_from_ex3 when s_reg_from_ex3 = '1' else
                   '1';

  -- Mask the outputs: We should only forward the value if VL is requested.
  o_use_value <= s_use_value and i_vl_requested;
  o_value_ready <= s_value_ready and i_vl_requested;
end rtl;

