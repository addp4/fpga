
set_property PACKAGE_PIN T23 [get_ports led]
set_property PACKAGE_PIN U22 [get_ports clk]
set_property PACKAGE_PIN A3 [get_ports din0]
set_property PACKAGE_PIN B4 [get_ports ce_0]
set_property PACKAGE_PIN B5 [get_ports clk0]
set_property PACKAGE_PIN E5 [get_ports din1]
set_property PACKAGE_PIN C2 [get_ports ce_1]
set_property PACKAGE_PIN D4 [get_ports clk1]
set_property PACKAGE_PIN P4 [get_ports rst_n]

set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports din0]
set_property IOSTANDARD LVCMOS33 [get_ports ce_0]
set_property IOSTANDARD LVCMOS33 [get_ports clk0]
set_property IOSTANDARD LVCMOS33 [get_ports din1]
set_property IOSTANDARD LVCMOS33 [get_ports ce_1]
set_property IOSTANDARD LVCMOS33 [get_ports clk1]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]



create_clock -period 20.000 -name clk -waveform {0.000 10.000} [get_ports -filter { NAME =~  "*" && DIRECTION == "IN" }]
set_max_delay -from [get_pins {bb3/count_d_reg[23]/C}] -to [get_pins {display_value_reg[23]/D}] 100.000
set_max_delay -from [get_pins {bb3/count_d_reg[39]/C}] -to [get_pins {display_value_reg[39]/D}] 100.000
set_max_delay -from [get_pins {bb3/count_d_reg[51]/C}] -to [get_pins {display_value_reg[51]/D}] 100.000
