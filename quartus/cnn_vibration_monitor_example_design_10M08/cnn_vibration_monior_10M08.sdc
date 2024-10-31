derive_clock_uncertainty

set_false_path -from {m10_cnn1d:cnn1d|cnn_condition} -to [get_ports {led}]

create_clock -name clk50 -period 20.000 [get_ports {clk50}]

derive_pll_clocks