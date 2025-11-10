create_clock -period 20.000 -name CLK_50 [get_ports CLK_50]
set_property IOSTANDARD LVCMOS33 [get_ports CLK_50]
set_property PACKAGE_PIN R2 [get_ports CLK_50]

set_property IOSTANDARD LVCMOS33 [get_ports reset_rtl_0]
set_property PACKAGE_PIN H17 [get_ports reset_rtl_0]

#
# UART signals
#
set_property IOSTANDARD LVTTL [get_ports uart_rtl_0_rxd]
set_property PACKAGE_PIN V7 [get_ports uart_rtl_0_rxd]
set_property IOSTANDARD LVTTL [get_ports uart_rtl_0_txd]
set_property PACKAGE_PIN V6 [get_ports uart_rtl_0_txd]

#
# user LEDs gpio_io_o_0
#
set_property IOSTANDARD LVTTL [get_ports {gpio_rtl_0_tri_o[0]}]
set_property PACKAGE_PIN C8 [get_ports {gpio_rtl_0_tri_o[0]}]
set_property IOSTANDARD LVTTL [get_ports {gpio_rtl_0_tri_o[1]}]
set_property PACKAGE_PIN D8 [get_ports {gpio_rtl_0_tri_o[1]}]

#
# SPI
#
# CS = dip pin 1
set_property IOSTANDARD LVCMOS33 [get_ports {spi_rtl_0_ss_io[0]}]
set_property PACKAGE_PIN F18 [get_ports {spi_rtl_0_ss_io[0]}]
# MISO = dip pin 2
set_property IOSTANDARD LVCMOS33 [get_ports spi_rtl_0_io1_io]
set_property PACKAGE_PIN E18 [get_ports spi_rtl_0_io1_io]
# MOSI = dip pin 5
set_property IOSTANDARD LVCMOS33 [get_ports spi_rtl_0_io0_io]
set_property PACKAGE_PIN D18 [get_ports spi_rtl_0_io0_io]
# SCK = dip pin 6
set_property IOSTANDARD LVCMOS33 [get_ports spi_rtl_0_sck_io]
set_property PACKAGE_PIN C17 [get_ports spi_rtl_0_sck_io]

#
# My rtl
#
set_property IOSTANDARD LVCMOS33 [get_ports led_0]
set_property PACKAGE_PIN M1 [get_ports led_0]
#
# busybeaver rtl
#
set_property IOSTANDARD LVCMOS33 [get_ports led_1]
set_property PACKAGE_PIN N2 [get_ports led_1]


