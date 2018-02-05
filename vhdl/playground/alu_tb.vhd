library ieee;
use ieee.std_logic_1164.all;

--  A testbench has no ports.
entity alu_tb is
end alu_tb;
 
architecture behav of alu_tb is
  --  Declaration of the component that will be instantiated.
  component alu
    port (i_op : in std_logic_vector(8 downto 0);        -- Operation
          i_src_a : in std_logic_vector(31 downto 0);    -- Source operand A
          i_src_b : in std_logic_vector(31 downto 0);    -- Source operand B
          i_src_c : in std_logic_vector(31 downto 0);    -- Source operand C
          o_result : out std_logic_vector(31 downto 0)   -- ALU result
      );
  end component;
  --  Specifies which entity is bound with the component.
  signal op : std_logic_vector(8 downto 0);
  signal src_a : std_logic_vector(31 downto 0);
  signal src_b : std_logic_vector(31 downto 0);
  signal src_c : std_logic_vector(31 downto 0);
  signal result : std_logic_vector(31 downto 0);
begin
  --  Component instantiation.
  alu_0: entity work.alu
    port map (
      i_op => op,
      i_src_a => src_a,
      i_src_b => src_b,
      i_src_c => src_c,
      o_result => result
    );
   
  --  This process does the real job.
  process
  begin
    --  Wait forever; this will finish the simulation.
    wait;
  end process;
end behav;
