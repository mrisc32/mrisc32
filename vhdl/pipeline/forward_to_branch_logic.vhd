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
-- The operand for branches (conditinal branches and register branches) may be forwarded from later
-- pipeline stages.
--
-- This entity decides:
--
--   * Whether or not the pipeline needs to be stalled to wait for a value that is not yet ready.
--   * Whether or not to use a forwarded value.
--   * Which value to use (from which pipeline stage).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity forward_to_branch_logic is
  port(
      -- What register is required in the ID stage (if any)?
      i_src_reg : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);

      -- Operand information from the different pipeline stages.
      i_id_writes_to_reg : in std_logic;
      i_dst_reg_from_id : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);

      i_ex_writes_to_reg : in std_logic;
      i_dst_reg_from_ex : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      i_value_from_ex : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_ready_from_ex : in std_logic;

      i_mem_writes_to_reg : in std_logic;
      i_dst_reg_from_mem : in std_logic_vector(C_LOG2_NUM_REGS-1 downto 0);
      i_value_from_mem : in std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- Operand selection for the ID stage.
      o_value : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_use_value : out std_logic;
      o_value_ready : out std_logic
    );
end forward_to_branch_logic;

architecture rtl of forward_to_branch_logic is
  signal s_reg_from_id : std_logic;
  signal s_reg_from_ex : std_logic;
  signal s_reg_from_mem : std_logic;
begin
  -- Determine which stages are writing to the requested source register.
  s_reg_from_id <= i_id_writes_to_reg when i_src_reg = i_dst_reg_from_id else '0';
  s_reg_from_ex <= i_ex_writes_to_reg when i_src_reg = i_dst_reg_from_ex else '0';
  s_reg_from_mem <= i_mem_writes_to_reg when i_src_reg = i_dst_reg_from_mem else '0';

  -- Which value to forward?
  o_value <= i_value_from_ex when (s_reg_from_ex and i_ready_from_ex) = '1' else i_value_from_mem;

  -- Should the forwarded pipeline value be used instead of register file value?
  o_use_value <= s_reg_from_id or s_reg_from_ex or s_reg_from_mem;

  -- Is the value ready for use?
  o_value_ready <= not (s_reg_from_id or (s_reg_from_ex and not i_ready_from_ex));
end rtl;

