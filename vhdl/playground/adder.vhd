entity adder is
  port (i0, i1 : in bit;  -- Inputs
        ci : in bit;      -- Carry in
        s : out bit;      -- Output sum
        co : out bit);    -- Carry out
end adder;
 
architecture rtl of adder is
begin
  --  Compute the sum and carry.
  s <= i0 xor i1 xor ci;
  co <= (i0 and i1) or (i0 and ci) or (i1 and ci);
end rtl;

