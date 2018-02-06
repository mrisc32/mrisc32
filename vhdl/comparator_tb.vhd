library ieee;
use ieee.std_logic_1164.all;

entity comparator_tb is
end comparator_tb;

architecture behavioral of comparator_tb is
  component comparator
    generic(WIDTH : positive);
    port(
        i_src : in  std_logic_vector(WIDTH-1 downto 0);
        o_eq  : out std_logic;
        o_lt  : out std_logic;
        o_le  : out std_logic
      );
  end component;

  signal s_src : std_logic_vector(7 downto 0);
  signal s_eq  : std_logic;
  signal s_lt  : std_logic;
  signal s_le  : std_logic;
begin
  comparator_0: entity work.comparator
    generic map (
      WIDTH => 8
    )
    port map (
      i_src => s_src,
      o_eq => s_eq,
      o_lt => s_lt,
      o_le => s_le
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      src : std_logic_vector(7 downto 0);

      -- Expected outputs
      eq : std_logic;
      lt : std_logic;
      le : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        ("00000000", '1', '0', '1'),
        ("00000001", '0', '0', '0'),
        ("01111111", '0', '0', '0'),
        ("11000000", '0', '1', '1'),
        ("11111111", '0', '1', '1')
      );
  begin
    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_src <= patterns(i).src;

      --  Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_eq = patterns(i).eq
        report "Bad EQ value" severity error;
      assert s_lt = patterns(i).lt
        report "Bad LT value" severity error;
      assert s_le = patterns(i).le
        report "Bad LE value" severity error;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

