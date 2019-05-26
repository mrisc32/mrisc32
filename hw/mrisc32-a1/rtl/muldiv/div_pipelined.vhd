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
-- This is a pipelined divider for signed or unsigned integers.
--
--  * One division operation can start each clock cycle.
--  * An N-bit division operation takes N clock cycles to complete.
--
-- TODO:
--  * Add support for blocking/stalling mode.
--    - Non-blocking mode shall be used when the next instruction is a division (to enable single
--      cycle divisions for vector instructions).
--    - Otherwise blocking mode shall be used (to ensure proper EX pipeline scheduling).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity div_pipelined is
  generic(
    WIDTH : positive
  );
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;

    -- Inputs (async).
    i_enable : in std_logic;
    i_op : in T_DIV_OP;                                  -- Operation
    i_src_a : in std_logic_vector(WIDTH-1 downto 0);     -- Source operand A
    i_src_b : in std_logic_vector(WIDTH-1 downto 0);     -- Source operand B
    i_dst_reg : in T_DST_REG;

    -- Outputs (async).
    o_result : out std_logic_vector(WIDTH-1 downto 0);
    o_result_dst_reg : out T_DST_REG;
    o_result_ready : out std_logic
  );
end div_pipelined;

architecture rtl of div_pipelined is
  constant NUM_STEPS : integer := WIDTH;

  type T_DIV_STATE is record
    n : std_logic_vector(WIDTH-1 downto 0);
    d : std_logic_vector(WIDTH-1 downto 0);
    q : std_logic_vector(WIDTH-1 downto 0);
    r : std_logic_vector(WIDTH-1 downto 0);
    op : T_DIV_OP;
    dst_reg : T_DST_REG;
  end record;

  type T_DIV_PIPELINE_REGS is array (0 to NUM_STEPS) of T_DIV_STATE;
  signal s_next_div_state : T_DIV_PIPELINE_REGS;
  signal s_div_state : T_DIV_PIPELINE_REGS;
  signal s_first_state : T_DIV_STATE;
  signal s_final_state : T_DIV_STATE;
begin
  -- Prepare inputs.
  -- TODO(m): Handle sign.
  s_first_state.n <= i_src_a when i_enable = '1' else (others => '0');
  s_first_state.d <= i_src_b when i_enable = '1' else (0 => '1', others => '0');
  s_first_state.q <= (others => '0');
  s_first_state.r <= (others => '0');

  s_first_state.op <= i_op;

  s_first_state.dst_reg.is_target <= i_dst_reg.is_target and i_enable;
  s_first_state.dst_reg.reg <= i_dst_reg.reg;
  s_first_state.dst_reg.element <= i_dst_reg.element;
  s_first_state.dst_reg.is_vector <= i_dst_reg.is_vector;

  s_div_state(0) <= s_first_state;

  DivPipeGen: for k in 1 to NUM_STEPS generate
    -- Divider stage.
    div_stage_x: entity work.div_stage
      generic map (
        WIDTH => WIDTH
      )
      port map (
        i_n => s_div_state(k-1).n,
        i_d => s_div_state(k-1).d,
        i_q => s_div_state(k-1).q,
        i_r => s_div_state(k-1).r,
        o_n => s_next_div_state(k).n,
        o_d => s_next_div_state(k).d,
        o_q => s_next_div_state(k).q,
        o_r => s_next_div_state(k).r
      );

    -- Forward the operation information from the previous pipeline stage.
    s_next_div_state(k).dst_reg <= s_div_state(k-1).dst_reg;
    s_next_div_state(k).op <= s_div_state(k-1).op;

    -- Pipeline flops.
    process(i_clk, i_rst)
    begin
      if i_rst = '1' then
        s_div_state(k).n <= (others => '0');
        s_div_state(k).d <= (others => '0');
        s_div_state(k).q <= (others => '0');
        s_div_state(k).r <= (others => '0');
        s_div_state(k).dst_reg.is_target <= '0';
        s_div_state(k).dst_reg.reg <= (others => '0');
        s_div_state(k).dst_reg.element <= (others => '0');
        s_div_state(k).dst_reg.is_vector <= '0';
      elsif rising_edge(i_clk) then
        s_div_state(k) <= s_next_div_state(k);
      end if;
    end process;
  end generate;

  s_final_state <= s_div_state(NUM_STEPS);

  -- Outputs.
  -- TODO(m): Handle sign.
  ResultMux: with s_final_state.op select
  o_result <=
    s_final_state.q when C_DIV_DIV | C_DIV_DIVU,
    s_final_state.r when C_DIV_REM | C_DIV_REMU,
    (others => '0') when others;

  o_result_dst_reg <= s_final_state.dst_reg;
  o_result_ready <= s_final_state.dst_reg.is_target;
end rtl;
