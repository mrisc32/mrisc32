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
-- This is the combined integer and floating point division unit.
--
-- The division units for different data sizes are configured as follows:
--   32 bits: 2 division stages per cycle -> 15 cycles stall.
--   16 bits: 2 division stages per cycle -> 7 cycles stall.
--    8 bits: 2 division stages per cycle -> 3 cycles stall.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity div is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;
    o_stall : out std_logic;

    -- Inputs (async).
    i_enable : in std_logic;
    i_op : in T_DIV_OP;
    i_packed_mode : in T_PACKED_MODE;
    i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- Outputs (async).
    o_d3_next_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_d3_next_result_ready : out std_logic;
    o_d4_next_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_d4_next_result_ready : out std_logic
  );
end div;

architecture rtl of div is
  signal s_div32_enable : std_logic;
  signal s_d3_next_div32_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_d3_next_div32_result_ready : std_logic;
  signal s_d4_next_div32_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_d4_next_div32_result_ready : std_logic;
  signal s_div32_stall : std_logic;

  signal s_div16_enable : std_logic;
  signal s_d3_next_div16_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_d3_next_div16_result_ready : std_logic;
  signal s_d4_next_div16_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_d4_next_div16_result_ready : std_logic;
  signal s_div16_stall : std_logic;

  signal s_div8_enable : std_logic;
  signal s_d3_next_div8_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_d3_next_div8_result_ready : std_logic;
  signal s_d4_next_div8_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_d4_next_div8_result_ready : std_logic;
  signal s_div8_stall : std_logic;

  signal s_stall_div32 : std_logic;
  signal s_stall_div16 : std_logic;
  signal s_stall_div8 : std_logic;
begin
  -- Select division width.
  s_div32_enable <= i_enable when i_packed_mode = C_PACKED_NONE else '0';
  s_div16_enable <= i_enable when i_packed_mode = C_PACKED_HALF_WORD else '0';
  s_div8_enable <= i_enable when i_packed_mode = C_PACKED_BYTE else '0';

  -- 32-bit pipeline.
  div32_0: entity work.div_impl
    generic map (
      WIDTH => 32,
      EXP_BITS => F32_EXP_BITS,
      EXP_BIAS => F32_EXP_BIAS,
      FRACT_BITS => F32_FRACT_BITS,
      CNT_BITS => 4,
      STEPS_PER_CYCLE => 2
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => s_stall_div32,
      o_stall => s_div32_stall,
      i_enable => s_div32_enable,
      i_op => i_op,
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      o_d3_next_result => s_d3_next_div32_result,
      o_d3_next_result_ready => s_d3_next_div32_result_ready,
      o_d4_next_result => s_d4_next_div32_result,
      o_d4_next_result_ready => s_d4_next_div32_result_ready
    );

  PACKED_GEN: if C_CPU_HAS_PO generate
    -- 16-bit pipelines.
    div16Gen: for k in 1 to 2 generate
      signal s_d3_next_result_ready : std_logic_vector(1 to 2);
      signal s_d4_next_result_ready : std_logic_vector(1 to 2);
      signal s_stall : std_logic_vector(1 to 2);
    begin
      div16_1: entity work.div_impl
        generic map (
          WIDTH => 16,
          EXP_BITS => F16_EXP_BITS,
          EXP_BIAS => F16_EXP_BIAS,
          FRACT_BITS => F16_FRACT_BITS,
          CNT_BITS => 3,
          STEPS_PER_CYCLE => 2
        )
        port map (
          i_clk => i_clk,
          i_rst => i_rst,
          i_stall => s_stall_div16,
          o_stall => s_stall(k),
          i_enable => s_div16_enable,
          i_op => i_op,
          i_src_a => i_src_a((16*k)-1 downto 16*(k-1)),
          i_src_b => i_src_b((16*k)-1 downto 16*(k-1)),
          o_d3_next_result => s_d3_next_div16_result((16*k)-1 downto 16*(k-1)),
          o_d3_next_result_ready => s_d3_next_result_ready(k),
          o_d4_next_result => s_d4_next_div16_result((16*k)-1 downto 16*(k-1)),
          o_d4_next_result_ready => s_d4_next_result_ready(k)
        );

        -- Note: For some signals we only have to consider one of the parallel pipelines.
        div16ExtractSignals: if k=1 generate
          s_d3_next_div16_result_ready <= s_d3_next_result_ready(1);
          s_d4_next_div16_result_ready <= s_d4_next_result_ready(1);
          s_div16_stall <= s_stall(1);
        end generate;
    end generate;

    -- 8-bit pipelines.
    div8Gen: for k in 1 to 4 generate
      signal s_d3_next_result_ready : std_logic_vector(1 to 4);
      signal s_d4_next_result_ready : std_logic_vector(1 to 4);
      signal s_stall : std_logic_vector(1 to 4);
    begin
      div8_x: entity work.div_impl
        generic map (
          WIDTH => 8,
          EXP_BITS => F8_EXP_BITS,
          EXP_BIAS => F8_EXP_BIAS,
          FRACT_BITS => F8_FRACT_BITS,
          CNT_BITS => 2,
          STEPS_PER_CYCLE => 2
        )
        port map (
          i_clk => i_clk,
          i_rst => i_rst,
          i_stall => s_stall_div8,
          o_stall => s_stall(k),
          i_enable => s_div8_enable,
          i_op => i_op,
          i_src_a => i_src_a((8*k)-1 downto 8*(k-1)),
          i_src_b => i_src_b((8*k)-1 downto 8*(k-1)),
          o_d3_next_result => s_d3_next_div8_result((8*k)-1 downto 8*(k-1)),
          o_d3_next_result_ready => s_d3_next_result_ready(k),
          o_d4_next_result => s_d4_next_div8_result((8*k)-1 downto 8*(k-1)),
          o_d4_next_result_ready => s_d4_next_result_ready(k)
        );

        -- Note: For some signals we only have to consider one of the parallel pipelines.
        div8ExtractSignals: if k=1 generate
          s_d3_next_div8_result_ready <= s_d3_next_result_ready(1);
          s_d4_next_div8_result_ready <= s_d4_next_result_ready(1);
          s_div8_stall <= s_stall(1);
        end generate;
    end generate;

    -- Internal stall logic. Only ONE division loop can be running at a time!
    s_stall_div32 <= i_stall or s_div16_stall or s_div8_stall;
    s_stall_div16 <= i_stall or s_div32_stall or s_div8_stall;
    s_stall_div8 <= i_stall or s_div32_stall or s_div16_stall;

    -- Select the D3 output signals.
    o_d3_next_result <=
        s_d3_next_div32_result when s_d3_next_div32_result_ready = '1' else
        s_d3_next_div16_result when s_d3_next_div16_result_ready = '1' else
        s_d3_next_div8_result when s_d3_next_div8_result_ready = '1' else
        (others => '-');
    o_d3_next_result_ready <= s_d3_next_div32_result_ready or
                              s_d3_next_div16_result_ready or
                              s_d3_next_div8_result_ready;

    -- Select the D4 output signals.
    o_d4_next_result <=
        s_d4_next_div32_result when s_d4_next_div32_result_ready = '1' else
        s_d4_next_div16_result when s_d4_next_div16_result_ready = '1' else
        s_d4_next_div8_result when s_d4_next_div8_result_ready = '1' else
        (others => '-');
    o_d4_next_result_ready <= s_d4_next_div32_result_ready or
                              s_d4_next_div16_result_ready or
                              s_d4_next_div8_result_ready;

    o_stall <= s_div32_stall or
               s_div16_stall or
               s_div8_stall;
  else generate
    -- In unpacked mode we only have to consider the 32-bit result.
    o_d3_next_result <= s_d3_next_div32_result;
    o_d3_next_result_ready <= s_d3_next_div32_result_ready;
    o_d4_next_result <= s_d4_next_div32_result;
    o_d4_next_result_ready <= s_d4_next_div32_result_ready;
    o_stall <= s_div32_stall;
  end generate;
end rtl;
