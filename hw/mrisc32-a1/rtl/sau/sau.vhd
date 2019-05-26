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
-- This is the SAU.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use work.config.all;

entity sau is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;

    -- Inputs (async).
    i_enable : in std_logic;
    i_op : in T_SAU_OP;
    i_packed_mode : in T_PACKED_MODE;
    i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- Outputs (async).
    o_next_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_next_result_ready : out std_logic
  );
end sau;

architecture rtl of sau is
  signal s_sau32_enable : std_logic;
  signal s_next_sau32_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_next_sau32_result_ready : std_logic;

  signal s_sau16_enable : std_logic;
  signal s_next_sau16_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_next_sau16_result_ready : std_logic;

  signal s_sau8_enable : std_logic;
  signal s_next_sau8_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_next_sau8_result_ready : std_logic;
begin
  -- Select SAU width.
  s_sau32_enable <= i_enable when i_packed_mode = C_PACKED_NONE else '0';
  s_sau16_enable <= i_enable when i_packed_mode = C_PACKED_HALF_WORD else '0';
  s_sau8_enable <= i_enable when i_packed_mode = C_PACKED_BYTE else '0';

  -- 32-bit pipeline.
  SAU32_0: entity work.sau_impl
    generic map (
      WIDTH => 32
    )
    port map (
      i_clk => i_clk,
      i_rst => i_rst,
      i_stall => i_stall,
      i_enable => s_sau32_enable,
      i_op => i_op,
      i_src_a => i_src_a,
      i_src_b => i_src_b,
      o_next_result => s_next_sau32_result,
      o_next_result_ready => s_next_sau32_result_ready
    );

  PACKED_GEN: if C_CPU_HAS_PO generate
    -- 16-bit pipelines.
    SAU16Gen: for k in 1 to 2 generate
      signal s_next_result_ready : std_logic_vector(1 to 2);
    begin
      SAU16_1: entity work.sau_impl
        generic map (
          WIDTH => 16
        )
        port map (
          i_clk => i_clk,
          i_rst => i_rst,
          i_stall => i_stall,
          i_enable => s_sau16_enable,
          i_op => i_op,
          i_src_a => i_src_a((16*k)-1 downto 16*(k-1)),
          i_src_b => i_src_b((16*k)-1 downto 16*(k-1)),
          o_next_result => s_next_sau16_result((16*k)-1 downto 16*(k-1)),
          o_next_result_ready => s_next_result_ready(k)
        );

        -- Note: For some signals we only have to consider one of the parallel pipelines.
        SAU16ExtractSignals: if k=1 generate
          s_next_sau16_result_ready <= s_next_result_ready(1);
        end generate;
    end generate;

    -- 8-bit pipelines.
    SAU8Gen: for k in 1 to 4 generate
      signal s_next_result_ready : std_logic_vector(1 to 4);
    begin
      SAU8_x: entity work.sau_impl
        generic map (
          WIDTH => 8
        )
        port map (
          i_clk => i_clk,
          i_rst => i_rst,
          i_stall => i_stall,
          i_enable => s_sau8_enable,
          i_op => i_op,
          i_src_a => i_src_a((8*k)-1 downto 8*(k-1)),
          i_src_b => i_src_b((8*k)-1 downto 8*(k-1)),
          o_next_result => s_next_sau8_result((8*k)-1 downto 8*(k-1)),
          o_next_result_ready => s_next_result_ready(k)
        );

        -- Note: For some signals we only have to consider one of the parallel pipelines.
        SAU8ExtractSignals: if k=1 generate
          s_next_sau8_result_ready <= s_next_result_ready(1);
        end generate;
    end generate;

    -- Select the output signals from the first pipeline stage.
    o_next_result <=
        s_next_sau32_result when s_next_sau32_result_ready = '1' else
        s_next_sau16_result when s_next_sau16_result_ready = '1' else
        s_next_sau8_result when s_next_sau8_result_ready = '1' else
        (others => '-');
    o_next_result_ready <= s_next_sau32_result_ready or
                          s_next_sau16_result_ready or
                          s_next_sau8_result_ready;
  else generate
    -- In unpacked mode we only have to consider the 32-bit result.
    o_next_result <= s_next_sau32_result;
    o_next_result_ready <= s_next_sau32_result_ready;
  end generate;
end rtl;
