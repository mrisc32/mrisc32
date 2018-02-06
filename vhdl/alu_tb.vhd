library ieee;
use ieee.std_logic_1164.all;
use work.consts.all;

--  A testbench has no ports.
entity alu_tb is
end alu_tb;
 
architecture behav of alu_tb is
  --  Declaration of the component that will be instantiated.
  component alu
    port(
        i_op : in alu_op_t;                                      -- Operation
        i_src_a : in std_logic_vector(C_WORD_SIZE-1 downto 0);   -- Source operand A
        i_src_b : in std_logic_vector(C_WORD_SIZE-1 downto 0);   -- Source operand B
        i_src_c : in std_logic_vector(C_WORD_SIZE-1 downto 0);   -- Source operand C
        o_result : out std_logic_vector(C_WORD_SIZE-1 downto 0)  -- ALU result
      );
  end component;

  signal s_op : alu_op_t;
  signal s_src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_src_c : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal s_result : std_logic_vector(C_WORD_SIZE-1 downto 0);
begin
  --  Component instantiation.
  alu_0: entity work.alu
    port map (
      i_op => s_op,
      i_src_a => s_src_a,
      i_src_b => s_src_b,
      i_src_c => s_src_c,
      o_result => s_result
    );

  process
    --  The patterns to apply.
    type pattern_type is record
      -- Inputs
      op : alu_op_t;
      src_a : std_logic_vector(C_WORD_SIZE-1 downto 0);
      src_b : std_logic_vector(C_WORD_SIZE-1 downto 0);
      src_c : std_logic_vector(C_WORD_SIZE-1 downto 0);

      -- Expected outputs
      result : std_logic_vector(C_WORD_SIZE-1 downto 0);
    end record;
    type pattern_array is array (natural range <>) of pattern_type;
    constant patterns : pattern_array := (
        (OP_OR,
          "00000000000000000000000000000000",
          "00000000000000000000000000000000",
          "00000000000000000000000000000000",
          "00000000000000000000000000000000"),
        (OP_OR,
          "10101010101010101000000000000000",
          "01010101010111111000000000000000",
          "00000000000000000111111111111111",
          "11111111111111111000000000000000")
      );
  begin
    -- Test all the patterns in the pattern array.
    for i in patterns'range loop
      --  Set the inputs.
      s_op <= patterns(i).op;
      s_src_a <= patterns(i).src_a;
      s_src_b <= patterns(i).src_b;
      s_src_c <= patterns(i).src_c;

      --  Wait for the results.
      wait for 1 ns;

      --  Check the outputs.
      assert s_result = patterns(i).result
        report "Bad ALU result" severity error;
    end loop;
    assert false report "End of test" severity note;
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behav;
