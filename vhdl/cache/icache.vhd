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

entity icache is
  generic(
      -- The total cache size is 2**(LOG2_NUM_LINES+LOG2_LINE_SIZE).
      LOG2_NUM_LINES : integer := 8;  -- log2(number of cache lines)
      LOG2_LINE_SIZE : integer := 4   -- log2(line size in bytes))
    );
  port(
      i_clk : in std_logic;
      i_rst : in std_logic;

      -- CPU interface.
      i_cpu_read : in std_logic;
      i_cpu_addr : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_cpu_data : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      o_cpu_data_ready : out std_logic;

      -- Memory interface.
      o_mem_read : out std_logic;
      o_mem_addr : out std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_mem_data : in std_logic_vector(C_WORD_SIZE-1 downto 0);
      i_mem_ready : in std_logic
    );
end icache;

architecture behavioural of icache is
  -- Calculate the actual cache size parameters.
  constant C_NUM_LINES : integer := 2**LOG2_NUM_LINES;
  constant C_LINE_SIZE : integer := 2**LOG2_LINE_SIZE;

  -- Number of machine words per cache line.
  constant C_WORDS_PER_LINE : integer := C_LINE_SIZE / (C_WORD_SIZE / 8);

  -- The number of tag bits is the part of the memory address that exeeds the cache size.
  constant C_TAG_BITS : integer := C_WORD_SIZE - (LOG2_NUM_LINES + LOG2_LINE_SIZE);

  -- Cache line data array.
  type T_LINE is array (0 to C_WORDS_PER_LINE-1) of std_logic_vector(C_WORD_SIZE-1 downto 0);
  type T_LINE_ARRAY is array (0 to C_NUM_LINES-1) of T_LINE;
  signal s_lines : T_LINE_ARRAY;

  -- Tag array.
  subtype T_TAG is std_logic_vector(C_TAG_BITS-1 downto 0);
  type T_TAG_ARRAY is array (0 to C_NUM_LINES-1) of T_TAG;
  signal s_tags : T_TAG_ARRAY;

  -- Line status array ('1' = valid, '0' = invalid).
  subtype T_LINE_STATUS is std_logic;
  type T_LINE_STATUS_ARRAY is array (0 to C_NUM_LINES-1) of T_LINE_STATUS;
  signal s_line_statuses : T_LINE_STATUS_ARRAY;

  -- Internal state.
  type T_CACHE_STATE is record
    cpu_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
    cpu_data_ready : std_logic;
    mem_read : std_logic;
    mem_addr : std_logic_vector(C_WORD_SIZE-1 downto 0);
  end record;

  signal s_state, s_next_state : T_CACHE_STATE;
begin
  -- Cache logic.
  process(i_cpu_read, i_cpu_addr, i_mem_data, i_mem_ready)
    variable v_cache_state : T_CACHE_STATE;
    variable v_line_no : std_logic_vector(LOG2_NUM_LINES-1 downto 0);
    variable v_tag : T_TAG;
    variable v_word_idx : std_logic_vector(LOG2_LINE_SIZE-1 downto 0);
    variable v_cache_miss : std_logic;
  begin
    v_cache_state := s_state;

    v_cache_state.cpu_data_ready := '0';  
    v_cache_miss := '0';
    if i_cpu_read = '1' then
      -- CPU read request.
      v_line_no := i_cpu_addr(LOG2_NUM_LINES+LOG2_LINE_SIZE-1 downto LOG2_LINE_SIZE);
      v_tag := i_cpu_addr(C_WORD_SIZE-1 downto C_TAG_BITS);
      if s_line_statuses(to_integer(unsigned(v_line_no))) = '1' and
         s_tags(to_integer(unsigned(v_line_no))) = v_tag then
        -- Cache hit.
        v_word_idx := i_cpu_addr(LOG2_LINE_SIZE-1 downto 0);
        v_cache_state.cpu_data := s_lines(to_integer(unsigned(v_line_no)))(to_integer(unsigned(v_word_idx)));
        v_cache_state.cpu_data_ready := '1';  
        v_cache_state.mem_read := '0';
      else
        -- Cache miss.
        v_cache_miss := '1';
      end if;
    end if;

    -- TODO(m): This is not even close to the truth. We need more elaborate memory interface logic.
    -- E.g:
    --   * Only initiate a memory request if there is no current pending request.
    --   * Do consecutive requests if necessary to fill up a complete cache line.
    --   * Fill out the cache line with the response from the memory sub system.
    --   * Etc.

    -- Do we need to initiate a memory request?
    if v_cache_miss = '1' then
      v_cache_state.mem_read := '1';
      v_cache_state.mem_addr(C_WORD_SIZE-1 downto LOG2_LINE_SIZE) := i_cpu_addr(C_WORD_SIZE-1 downto LOG2_LINE_SIZE);
      v_cache_state.mem_addr(LOG2_LINE_SIZE-1 downto 0) := (others => '0');
    end if;

    -- Update the register input signal.
    s_next_state <= v_cache_state;
  end process;

  -- Clocked registers.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      -- On reset: Set all lines to "invalid".
      for i in s_line_statuses'range loop
        s_line_statuses(i) <= '0';
      end loop;

      -- Clear the internal state.
      s_state.cpu_data_ready <= '0';
    elsif rising_edge(i_clk) then
      -- Update the state from the register inputs.
      o_cpu_data <= s_next_state.cpu_data;
      o_cpu_data_ready <= s_next_state.cpu_data_ready;
      o_mem_read <= s_next_state.mem_read;
      o_mem_addr <= s_next_state.mem_addr;
      s_state <= s_next_state;
    end if;
  end process;
end behavioural;
