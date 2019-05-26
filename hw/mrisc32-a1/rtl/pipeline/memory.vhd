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
-- Data memory pipeline (two stages). The interface to the memory is in the form of a Wishbone
-- master.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.types.all;
use work.config.all;

entity memory is
  port(
    -- Control signals.
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_stall : in std_logic;
    o_stall : out std_logic;

    -- Operation definition.
    i_mem_enable : in std_logic;
    i_mem_op : in T_MEM_OP;
    i_mem_adr : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_mem_dat : in std_logic_vector(C_WORD_SIZE-1 downto 0);

    -- Wishbone master interface.
    o_wb_cyc : out std_logic;
    o_wb_stb : out std_logic;
    o_wb_adr : out std_logic_vector(C_WORD_SIZE-1 downto 2);
    o_wb_we : out std_logic;   -- 1 = write, 0 = read
    o_wb_sel : out std_logic_vector(C_WORD_SIZE/8-1 downto 0);
    o_wb_dat : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_wb_dat : in std_logic_vector(C_WORD_SIZE-1 downto 0);
    i_wb_ack : in std_logic;
    i_wb_stall : in std_logic;
    i_wb_err : in std_logic;

    -- Outputs (async).
    o_result : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    o_result_ready : out std_logic
  );
end memory;

architecture rtl of memory is
  signal s_stall_m1 : std_logic;

  signal s_mem_byte_mask_unshifted : std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_mem_byte_mask : std_logic_vector(C_WORD_SIZE/8-1 downto 0);
  signal s_mem_store_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_mem_we : std_logic;

  signal s_mem_is_signed : std_logic;
  signal s_mem_size : std_logic_vector(1 downto 0);

  signal s_shifted_read_data : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_sign_bit : std_logic;
  signal s_extend_bit : std_logic;
  signal s_adjusted_read_data : std_logic_vector(C_WORD_SIZE-1 downto 0);

  signal s_repeat_request : std_logic;

  signal s_m1_enable : std_logic;
  signal s_m1_we : std_logic;
  signal s_m1_mem_op : T_MEM_OP;
  signal s_m1_shift : std_logic_vector(1 downto 0);

  signal s_m2_latched_wb_ack : std_logic;
  signal s_m2_latched_wb_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_m2_wb_ack : std_logic;
  signal s_m2_wb_dat : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_m2_pending_ack : std_logic;

  signal s_waiting_for_wb : std_logic;
begin
  ------------------------------------------------------------------------------
  -- M1: First pipeline stage.
  ------------------------------------------------------------------------------

  -- Prepare the byte mask.
  ByteMaskMux: with i_mem_op(1 downto 0) select
    s_mem_byte_mask_unshifted <=
      "0001" when "01",    -- byte
      "0011" when "10",    -- halfword
      "1111" when others;  -- word (11) and undefined (00)

  ByteMaskShiftMux: with i_mem_adr(1 downto 0) select
    s_mem_byte_mask <=
      s_mem_byte_mask_unshifted(3 downto 0)         when "00",
      s_mem_byte_mask_unshifted(2 downto 0) & "0"   when "01",
      s_mem_byte_mask_unshifted(1 downto 0) & "00"  when "10",
      s_mem_byte_mask_unshifted(0 downto 0) & "000" when others;  -- "11"

  -- Prepare the data to store (shift it into position).
  StoreDataShiftMux: with i_mem_adr(1 downto 0) select
    s_mem_store_data <=
      i_mem_dat(31 downto 0)             when "00",
      i_mem_dat(23 downto 0) & X"00"     when "01",
      i_mem_dat(15 downto 0) & X"0000"   when "10",
      i_mem_dat(7 downto 0)  & X"000000" when others;  -- "11"

  -- Is this a write opration?
  s_mem_we <= i_mem_op(3);

  -- Outputs to the Wishbone interface (async).
  o_wb_cyc <= (i_mem_enable or s_m1_enable) and ((not i_stall) or s_m2_pending_ack or i_wb_ack);
  o_wb_stb <= i_mem_enable and (s_repeat_request or not (i_stall or s_m2_pending_ack));
  o_wb_adr <= i_mem_adr(C_WORD_SIZE-1 downto 2);
  o_wb_we <= s_mem_we;
  o_wb_sel <= s_mem_byte_mask;
  o_wb_dat <= s_mem_store_data;

  -- Should M1 be stalled?
  s_stall_m1 <= i_stall or s_m2_pending_ack or i_wb_stall;

  -- Did we get a stall (i.e. repeat) request from the Wishbone interface?
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_repeat_request <= '0';
    elsif rising_edge(i_clk) then
      s_repeat_request <= i_wb_stall;
    end if;
  end process;

  -- Signals from the M1 stage to the M2 stage (sync).
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_m1_enable <= '0';
      s_m1_we <= '0';
      s_m1_mem_op <= (others => '0');
      s_m1_shift <= (others => '0');
    elsif rising_edge(i_clk) then
      if s_stall_m1 = '0' then
        s_m1_enable <= i_mem_enable;
        s_m1_we <= s_mem_we;
        s_m1_mem_op <= i_mem_op;
        s_m1_shift <= i_mem_adr(1 downto 0);
      end if;
    end if;
  end process;


  ------------------------------------------------------------------------------
  -- M2: Second pipeline stage.
  -- Handle data type transformations (shifting and sign extension).
  ------------------------------------------------------------------------------

  -- We need to latch memory read results when we are stalled, so that they are
  -- not lost.
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_m2_latched_wb_dat <= (others => '0');
      s_m2_latched_wb_ack <= '0';
    elsif rising_edge(i_clk) then
      if s_stall_m1 = '1' then
        if i_wb_ack = '1' then
          s_m2_latched_wb_ack <= '1';
          s_m2_latched_wb_dat <= i_wb_dat;
        end if;
      else
        s_m2_latched_wb_ack <= '0';
      end if;
    end if;
  end process;

  -- Do we have any data from the memory interface?
  s_m2_wb_ack <= i_wb_ack or s_m2_latched_wb_ack;
  s_m2_wb_dat <= s_m2_latched_wb_dat when s_m2_latched_wb_ack = '1' else i_wb_dat;
  s_m2_pending_ack <= s_m1_enable and not s_m2_wb_ack;

  -- Decode the memory operation.
  s_mem_is_signed <= not s_m1_mem_op(2);
  s_mem_size <= s_m1_mem_op(1 downto 0);

  -- Shift the read data according to the memory address LSBs.
  ShiftMux: with s_m1_shift select
    s_shifted_read_data <=
      X"00" & s_m2_wb_dat(31 downto 8) when "01",
      X"0000" & s_m2_wb_dat(31 downto 16) when "10",
      X"000000" & s_m2_wb_dat(31 downto 24) when "11",
      s_m2_wb_dat when others;

  -- Determine the sign extension bit.
  SignMux: with s_mem_size select
    s_sign_bit <=
      s_shifted_read_data(7) when "01",   -- byte
      s_shifted_read_data(15) when "10",  -- halfword
      '0' when others;

  s_extend_bit <= s_sign_bit and s_mem_is_signed;

  -- Perform the sign extension.
  s_adjusted_read_data(31 downto 16) <=
    (others => s_extend_bit) when s_mem_size(1) /= s_mem_size(0)
    else s_shifted_read_data(31 downto 16);

  s_adjusted_read_data(15 downto 8) <=
    (others => s_extend_bit) when s_mem_size = "01"
    else s_shifted_read_data(15 downto 8);

  s_adjusted_read_data(7 downto 0) <= s_shifted_read_data(7 downto 0);


  ------------------------------------------------------------------------------
  -- Outputs.
  ------------------------------------------------------------------------------

  -- Output result signal (async).
  o_result <= s_adjusted_read_data;
  o_result_ready <= s_m1_enable and s_m2_wb_ack and (not s_m1_we);

  -- Do we need to stall the pipeline (async)?
  -- Note: We do not want to send out a stall request if we're being stalled by
  -- an external request.
  o_stall <= (s_m2_pending_ack or i_wb_stall) and not i_stall;
end rtl;

