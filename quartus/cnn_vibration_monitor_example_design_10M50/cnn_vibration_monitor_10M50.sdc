derive_clock_uncertainty

set_false_path -from [get_ports {button[0]}] -to [get_ports {led[0]}]
set_false_path -from [get_ports {button[1]}] -to [get_ports {led[1]}]
set_false_path -from [get_ports {button[2]}] -to [get_ports {led[2]}]
set_false_path -from [get_ports {button[3]}] -to [get_ports {led[3]}]


set_false_path -from {m10_cnn1d:cnn1d|cnn_condition} -to [get_ports {led[4]}]

create_clock -name clk50 -period 20.000 [get_ports {clk50}]

derive_pll_clocks