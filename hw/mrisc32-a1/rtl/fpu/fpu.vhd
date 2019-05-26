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
-- This is the FPU (a fairly big chunk of logic).
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use work.config.all;

entity fpu is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;

    -- Inputs (async).
    i_enable : in std_logic;
    i_op : in T_FPU_OP;
    i_packed_mode : in T_PACKED_MODE;
    i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- Outputs (async).
    o_f1_next_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_f1_next_result_ready : out std_logic;
    o_f3_next_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_f3_next_result_ready : out std_logic;
    o_f4_next_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_f4_next_result_ready : out std_logic
  );
end fpu;

architecture rtl of fpu is
  signal s_fpu32_enable : std_logic;
  signal s_f1_next_fpu32_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f1_next_fpu32_result_ready : std_logic;
  signal s_f3_next_fpu32_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f3_next_fpu32_result_ready : std_logic;
  signal s_f4_next_fpu32_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f4_next_fpu32_result_ready : std_logic;

  signal s_fpu16_enable : std_logic;
  signal s_f1_next_fpu16_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f1_next_fpu16_result_ready : std_logic;
  signal s_f3_next_fpu16_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f3_next_fpu16_result_ready : std_logic;
  signal s_f4_next_fpu16_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f4_next_fpu16_result_ready : std_logic;

  signal s_fpu8_enable : std_logic;
  signal s_f1_next_fpu8_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f1_next_fpu8_result_ready : std_logic;
  signal s_f3_next_fpu8_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f3_next_fpu8_result_ready : std_logic;
  signal s_f4_next_fpu8_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_f4_next_fpu8_result_ready : std_logic;
begin
  -- Select FPU width.
  s_fpu32_enable <= i_enable when i_packed_mode = C_PACKED_NONE else '0';
  s_fpu16_enable <= i_enable when i_packed_mode = C_PACKED_HALF_WORD else '0';
  s_fpu8_enable <= i_enable when i_packed_mode = C_PACKED_BYTE else '0';

  -- 32-bit floating point pipeline.
  FPU32_0: entity work.fpu_impl
    generic map (
      WIDTH => F32_WIDTH,
      EXP_BITS => F32_EXP_BITS,
      EXP_BIAS => F32_EXP_BIAS,
      FRACT_BITS => F32_FRACT_BITS
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => i_stall,
      i_enable => s_fpu32_enable,
      i_op => i_op,
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      o_f1_next_result => s_f1_next_fpu32_result,
      o_f1_next_result_ready => s_f1_next_fpu32_result_ready,
      o_f3_next_result => s_f3_next_fpu32_result,
      o_f3_next_result_ready => s_f3_next_fpu32_result_ready,
      o_f4_next_result => s_f4_next_fpu32_result,
      o_f4_next_result_ready => s_f4_next_fpu32_result_ready
    );

  PACKED_GEN: if C_CPU_HAS_PO generate
    -- 16-bit floating point pipelines.
    FPU16Gen: for k in 1 to 2 generate
      signal s_f1_next_result_ready : std_logic_vector(1 to 2);
      signal s_f3_next_result_ready : std_logic_vector(1 to 2);
      signal s_f4_next_result_ready : std_logic_vector(1 to 2);
    begin
      FPU16_1: entity work.fpu_impl
        generic map (
          WIDTH => F16_WIDTH,
          EXP_BITS => F16_EXP_BITS,
          EXP_BIAS => F16_EXP_BIAS,
          FRACT_BITS => F16_FRACT_BITS
        )
        port map (
          i_clk => i_clk,
          i_rst => i_rst,
          i_stall => i_stall,
          i_enable => s_fpu16_enable,
          i_op => i_op,
          i_src_a => i_src_a((16*k)-1 downto 16*(k-1)),
          i_src_b => i_src_b((16*k)-1 downto 16*(k-1)),
          o_f1_next_result => s_f1_next_fpu16_result((16*k)-1 downto 16*(k-1)),
          o_f1_next_result_ready => s_f1_next_result_ready(k),
          o_f3_next_result => s_f3_next_fpu16_result((16*k)-1 downto 16*(k-1)),
          o_f3_next_result_ready => s_f3_next_result_ready(k),
          o_f4_next_result => s_f4_next_fpu16_result((16*k)-1 downto 16*(k-1)),
          o_f4_next_result_ready => s_f4_next_result_ready(k)
        );

        -- Note: For some signals we only have to consider one of the parallel pipelines.
        FPU16ExtractSignals: if k=1 generate
          s_f1_next_fpu16_result_ready <= s_f1_next_result_ready(1);
          s_f3_next_fpu16_result_ready <= s_f3_next_result_ready(1);
          s_f4_next_fpu16_result_ready <= s_f4_next_result_ready(1);
        end generate;
    end generate;

    -- 8-bit floating point pipelines.
    FPU8Gen: for k in 1 to 4 generate
      signal s_f1_next_result_ready : std_logic_vector(1 to 4);
      signal s_f3_next_result_ready : std_logic_vector(1 to 4);
      signal s_f4_next_result_ready : std_logic_vector(1 to 4);
    begin
      FPU8_x: entity work.fpu_impl
        generic map (
          WIDTH => F8_WIDTH,
          EXP_BITS => F8_EXP_BITS,
          EXP_BIAS => F8_EXP_BIAS,
          FRACT_BITS => F8_FRACT_BITS
        )
        port map (
          i_clk => i_clk,
          i_rst => i_rst,
          i_stall => i_stall,
          i_enable => s_fpu8_enable,
          i_op => i_op,
          i_src_a => i_src_a((8*k)-1 downto 8*(k-1)),
          i_src_b => i_src_b((8*k)-1 downto 8*(k-1)),
          o_f1_next_result => s_f1_next_fpu8_result((8*k)-1 downto 8*(k-1)),
          o_f1_next_result_ready => s_f1_next_result_ready(k),
          o_f3_next_result => s_f3_next_fpu8_result((8*k)-1 downto 8*(k-1)),
          o_f3_next_result_ready => s_f3_next_result_ready(k),
          o_f4_next_result => s_f4_next_fpu8_result((8*k)-1 downto 8*(k-1)),
          o_f4_next_result_ready => s_f4_next_result_ready(k)
        );

        -- Note: For some signals we only have to consider one of the parallel pipelines.
        FPU8ExtractSignals: if k=1 generate
          s_f1_next_fpu8_result_ready <= s_f1_next_result_ready(1);
          s_f3_next_fpu8_result_ready <= s_f3_next_result_ready(1);
          s_f4_next_fpu8_result_ready <= s_f4_next_result_ready(1);
        end generate;
    end generate;

    -- Select the output signals from the first pipeline stage.
    o_f1_next_result <=
        s_f1_next_fpu32_result when s_f1_next_fpu32_result_ready = '1' else
        s_f1_next_fpu16_result when s_f1_next_fpu16_result_ready = '1' else
        s_f1_next_fpu8_result when s_f1_next_fpu8_result_ready = '1' else
        (others => '-');
    o_f1_next_result_ready <= s_f1_next_fpu32_result_ready or
                              s_f1_next_fpu16_result_ready or
                              s_f1_next_fpu8_result_ready;

    -- Select the output signals from the second pipeline stage.
    o_f3_next_result <=
        s_f3_next_fpu32_result when s_f3_next_fpu32_result_ready = '1' else
        s_f3_next_fpu16_result when s_f3_next_fpu16_result_ready = '1' else
        s_f3_next_fpu8_result when s_f3_next_fpu8_result_ready = '1' else
        (others => '-');
    o_f3_next_result_ready <= s_f3_next_fpu32_result_ready or
                              s_f3_next_fpu16_result_ready or
                              s_f3_next_fpu8_result_ready;

    -- Select the output signals from the final pipeline stage.
    o_f4_next_result <=
        s_f4_next_fpu32_result when s_f4_next_fpu32_result_ready = '1' else
        s_f4_next_fpu16_result when s_f4_next_fpu16_result_ready = '1' else
        s_f4_next_fpu8_result when s_f4_next_fpu8_result_ready = '1' else
        (others => '-');
    o_f4_next_result_ready <= s_f4_next_fpu32_result_ready or
                              s_f4_next_fpu16_result_ready or
                              s_f4_next_fpu8_result_ready;
  else generate
    -- In unpacked mode we only have to consider the 32-bit results.
    o_f1_next_result <= s_f1_next_fpu32_result;
    o_f1_next_result_ready <= s_f1_next_fpu32_result_ready;
    o_f3_next_result <= s_f3_next_fpu32_result;
    o_f3_next_result_ready <= s_f3_next_fpu32_result_ready;
    o_f4_next_result <= s_f4_next_fpu32_result;
    o_f4_next_result_ready <= s_f4_next_fpu32_result_ready;
  end generate;
end rtl;
