# Constrain clock port i_clk with a 10 ns requirement (100 MHz).
create_clock -period 12.5 [get_ports i_clk]

# Automatically apply a generate clock on the output of phase-locked loops (PLLs).
# This command can be safely left in the SDC even if no PLLs exist in the design.
derive_pll_clocks

# Constrain the input I/O path.
set_input_delay -clock i_clk -max 2 [all_inputs]
set_input_delay -clock i_clk -min 1 [all_inputs]

