# CVA6 — Digilent Arty A7-100T constraints (xc7a100tcsg324-1)
#
# Port names follow ariane_xilinx.sv / the nexys_video.xdc convention.
# Pin assignments come from:
#   - Digilent Arty-A7-100T Master XDC
#   - ibex-demo-system/data/pins_artya7.xdc (same part, same FT2232 JTAG)
#
# Ethernet is a TI DP83848J 10/100 MII PHY; pins follow the Digilent
# Arty-A7-100T master XDC / LiteX digilent_arty platform.

## Single-ended 100 MHz clock (E3), CMOS33
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { sys_clk_i }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { sys_clk_i }];

## Reset button: BTN0 (D9). Arty user buttons are active HIGH (low at rest);
## the design inverts it for the MIG's active-low sys_rst. (The dedicated RESET
## button on C2 is not usable here: C2 is in bank 35, shared with the clock and
## the DDR IO bank group.)
set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { cpu_resetn }];

## JTAG: on the Arty the debug TAP lives inside the FPGA (dmi_bscane_tap.sv +
## BSCANE2), tapped from the FT2232 configuration chain. The common
## tck/tms/tdi/tdo ports are unused on this board (the BSCANE2 TAP ignores
## them) and stay unconstrained; trst_n is tied high in the RTL.

## LEDs (H5, J5, T9, T10) + RGB LEDs spare
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

## Switches (A8, C11, C10, A10)
set_property -dict { PACKAGE_PIN A8    IOSTANDARD LVCMOS33 } [get_ports { sw[0] }];
set_property -dict { PACKAGE_PIN C11   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }];
set_property -dict { PACKAGE_PIN C10   IOSTANDARD LVCMOS33 } [get_ports { sw[2] }];
set_property -dict { PACKAGE_PIN A10   IOSTANDARD LVCMOS33 } [get_ports { sw[3] }];

## USB-UART (FT2232H channel B): D10 uart_rxd_out (FPGA tx), A9 uart_txd_in (FPGA rx)
set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { tx }];
set_property -dict { PACKAGE_PIN A9    IOSTANDARD LVCMOS33 } [get_ports { rx }];

## Ethernet MII (TI DP83848J)
set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { eth_ref_clk }];
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { eth_txck }];
set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { eth_rxck }];
set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports { eth_rst_n }];
set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS33 } [get_ports { eth_mdio }];
set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { eth_mdc }];
set_property -dict { PACKAGE_PIN G16   IOSTANDARD LVCMOS33 } [get_ports { eth_rxctl }];
set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { eth_rxer }];
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[0] }];
set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[1] }];
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[2] }];
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[3] }];
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { eth_txctl }];
set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[0] }];
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[1] }];
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[2] }];
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[3] }];

set_property PULLUP true [get_ports { eth_mdio }];

# MII TX/RX clocks are supplied by the PHY (25 MHz).
create_clock -add -name eth_txck -period 40.000 [get_ports { eth_txck }];
create_clock -add -name eth_rxck -period 40.000 [get_ports { eth_rxck }];
# Both cross into the SoC clock only through the MAC's async FIFOs.
set_clock_groups -asynchronous -group [get_clocks eth_rxck]
set_clock_groups -asynchronous -group [get_clocks eth_txck]

# DP83848J @100 Mb/s: RXD/RX_DV/RX_ER valid 10..30 ns after RX_CLK rises;
# TXD/TX_EN need 10 ns setup / 0 ns hold to TX_CLK.
set_input_delay  -clock eth_rxck -max 30.000 [get_ports { eth_rxd[*] eth_rxctl eth_rxer }]
set_input_delay  -clock eth_rxck -min 10.000 [get_ports { eth_rxd[*] eth_rxctl eth_rxer }]
set_output_delay -clock eth_txck -max 10.000 [get_ports { eth_txd[*] eth_txctl }]
set_output_delay -clock eth_txck -min  0.000 [get_ports { eth_txd[*] eth_txctl }]

## DDR3: all DDR3 pin locations come from the MIG project (mig_arty_a7_100t.prj)

## Park the unused Genesys2 programming/DTPI and SPI ports on Pmod pins.
## They have no function on Arty, but leaving them unconstrained makes the
## placer try to fit them into 1.8 V banks.
set_property -dict { PACKAGE_PIN G13 IOSTANDARD LVCMOS33 } [get_ports { prog_d[0] }];
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports { prog_d[1] }];
set_property -dict { PACKAGE_PIN A11 IOSTANDARD LVCMOS33 } [get_ports { prog_d[2] }];
set_property -dict { PACKAGE_PIN D12 IOSTANDARD LVCMOS33 } [get_ports { prog_d[3] }];
set_property -dict { PACKAGE_PIN D13 IOSTANDARD LVCMOS33 } [get_ports { prog_d[4] }];
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports { prog_d[5] }];
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports { prog_d[6] }];
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports { prog_d[7] }];
set_property -dict { PACKAGE_PIN E15 IOSTANDARD LVCMOS33 } [get_ports { prog_clko }];
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports { prog_rxen }];
set_property -dict { PACKAGE_PIN D15 IOSTANDARD LVCMOS33 } [get_ports { prog_txen }];
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports { prog_spien }];
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports { prog_rdn }];
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports { prog_wrn }];
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports { prog_oen }];
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports { prog_siwun }];
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports { spi_clk_o }];
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }];
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports { spi_ss }];
set_property -dict { PACKAGE_PIN V11 IOSTANDARD LVCMOS33 } [get_ports { spi_miso }];
# Unused external-JTAG pins; the Arty uses the internal BSCANE2 TAP.
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports { tdo }];
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports { tck }];
set_property -dict { PACKAGE_PIN T13 IOSTANDARD LVCMOS33 } [get_ports { tms }];
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports { tdi }];

## DPTI/trace clocks are asynchronous and the trace port is unused on Arty.
set_false_path -from [get_clocks clk_pll_i] -to [get_clocks {prog_clko_pin clk_out1_xlnx_dpti_clk_1 clk_out2_xlnx_dpti_clk_1}]
set_false_path -from [get_clocks {prog_clko_pin clk_out1_xlnx_dpti_clk_1 clk_out2_xlnx_dpti_clk_1}] -to [get_clocks clk_pll_i]

## MIG ui_clk reset fans out into the SoC clock domain (same as Genesys2).
set_false_path -from [get_pins i_ddr/u_xlnx_mig_7_ddr3_mig/u_ddr3_infrastructure/rstdiv0_sync_r1_reg_rep/C]

## Configuration: 3.3 V bank 0, QSPI x4
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
