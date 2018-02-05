library ieee;
use ieee.std_logic_1164.all;

entity adder_tb is
end adder_tb;
 
architecture behavioral of adder_tb is
  component adder
    generic(WIDTH : positive);
    port(i_c_in   : in  std_logic;
         i_src_a  : in  std_logic_vector(WIDTH-1 downto 0);
         i_src_b  : in  std_logic_vector(WIDTH-1 downto 0);
         o_result : out std_logic_vector(WIDTH-1 downto 0);
         o_c_out  : out std_logic
      );
  end component;

  signal s_c_in   : std_logic;
  signal s_src_a  : std_logic_vector(7 downto 0);
  signal s_src_b  : std_logic_vector(7 downto 0);
  signal s_result : std_logic_vector(7 downto 0);
  signal s_c_out  : std_logic;
begin
  adder_0: entity work.adder
    generic map (
      WIDTH => 8
    )
    port map (
      i_c_in => s_c_in,
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      o_result => s_result,
      o_c_out => s_c_out
    );
   
  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      c_in  : std_logic;
      src_a : std_logic_vector(7 downto 0);
      src_b : std_logic_vector(7 downto 0);

      -- Expected outputs
      result : std_logic_vector(7 downto 0);
      c_out  : std_logic;
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        ('0', "00000001", "00000001", "00000010", '0'),
        ('1', "00000001", "00000001", "00000011", '0'),
        ('0', "11111111", "00000001", "00000000", '1'),
        ('1', "11111110", "00000001", "00000000", '1')
      );
  begin
    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_c_in <= patterns(i).c_in;
      s_src_a <= patterns(i).src_a;
      s_src_b <= patterns(i).src_b;

      --  Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_result = patterns(i).result
        report "Bad sum value" severity error;
      assert s_c_out = patterns(i).c_out
        report "Bad carray out value" severity error;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behavioral;

