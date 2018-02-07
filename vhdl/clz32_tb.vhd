library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.consts.all;

entity clz32_tb is
end clz32_tb;

architecture behavioral of clz32_tb is
  component clz32
    port(
        i_src : in  std_logic_vector(31 downto 0);
        o_cnt : out std_logic_vector(5 downto 0)
      );
  end component;

  signal s_src : std_logic_vector(31 downto 0);
  signal s_cnt : std_logic_vector(5 downto 0);
begin
  clz32_0: entity work.clz32
    port map (
      i_src => s_src,
      o_cnt => s_cnt
    );

  process
    function refClz32(x: std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
      for i in 31 downto 0 loop
        if x(i) = '1' then
          return std_logic_vector(to_unsigned(31-i, 6));
        end if;
      end loop;
      return std_logic_vector(to_unsigned(32, 6));
    end function;
  begin
    -- Test some values from 0 to 2^32-1.
    -- TODO(m): Test more relevant values.
    for k in 0 to 10000 loop
      -- Set the inputs.
      s_src <= to_word(k);

      -- Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_cnt = refClz32(s_src)
        report "Bad count value:" & lf &
               "  src=" & to_string(s_src) & lf &
               "  cnt=" & to_string(s_cnt) & " (expected " & to_string(refClz32(s_src)) & ")"
          severity error;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

