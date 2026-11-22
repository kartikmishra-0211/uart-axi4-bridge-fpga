## nexys4ddr.xdc  -  constraints for top.v on the Digilent Nexys 4 DDR (xc7a100tcsg324-1)
## Pins taken from Digilent's Nexys 4 DDR master XDC.
## (The clkA <-> clkB exception is in cdc.xdc, which must be "Used In: Implementation" only.)

## ---------------- 100 MHz clock ----------------
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## ---------------- Reset button (BTNC, centre) ----------------
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports btnC]

## ---------------- USB-UART: the FPGA RECEIVES on C4 (named UART_TXD_IN by Digilent) ----------------
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS33} [get_ports RsRx]

## ---------------- Switches ----------------
## NOTE: sw[8] and sw[9] are in a 1.8 V bank on this board -> LVCMOS18 (as in Digilent's master XDC)
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]
set_property -dict {PACKAGE_PIN R15 IOSTANDARD LVCMOS33} [get_ports {sw[3]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {sw[4]}]
set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports {sw[5]}]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports {sw[6]}]
set_property -dict {PACKAGE_PIN R13 IOSTANDARD LVCMOS33} [get_ports {sw[7]}]
set_property -dict {PACKAGE_PIN T8  IOSTANDARD LVCMOS18} [get_ports {sw[8]}]
set_property -dict {PACKAGE_PIN U8  IOSTANDARD LVCMOS18} [get_ports {sw[9]}]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {sw[10]}]
set_property -dict {PACKAGE_PIN T13 IOSTANDARD LVCMOS33} [get_ports {sw[11]}]
set_property -dict {PACKAGE_PIN H6  IOSTANDARD LVCMOS33} [get_ports {sw[12]}]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {sw[13]}]
set_property -dict {PACKAGE_PIN U11 IOSTANDARD LVCMOS33} [get_ports {sw[14]}]
set_property -dict {PACKAGE_PIN V10 IOSTANDARD LVCMOS33} [get_ports {sw[15]}]

## ---------------- LEDs ----------------
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {led[7]}]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {led[8]}]
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {led[9]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {led[10]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {led[11]}]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports {led[12]}]
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {led[13]}]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {led[14]}]
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS33} [get_ports {led[15]}]

## ---------------- Seven-segment display (8 digits, active low) ----------------
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {seg[0]}]
set_property -dict {PACKAGE_PIN R10 IOSTANDARD LVCMOS33} [get_ports {seg[1]}]
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports {seg[2]}]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS33} [get_ports {seg[3]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {seg[4]}]
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports {seg[5]}]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports {seg[6]}]
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports dp]
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports {an[0]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports {an[1]}]
set_property -dict {PACKAGE_PIN T9  IOSTANDARD LVCMOS33} [get_ports {an[2]}]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports {an[3]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {an[4]}]
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports {an[5]}]
set_property -dict {PACKAGE_PIN K2  IOSTANDARD LVCMOS33} [get_ports {an[6]}]
set_property -dict {PACKAGE_PIN U13 IOSTANDARD LVCMOS33} [get_ports {an[7]}]

## ---------------- Configuration ----------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## ---------------- Asynchronous human I/O ----------------
set_false_path -from [get_ports {btnC RsRx sw[*]}]
set_false_path -to   [get_ports {led[*] seg[*] an[*] dp}]

## ---------------- clkA <-> clkB clock-domain-crossing exception ----------------
## Lives in THIS file, after create_clock, so it can never be read before the clocks exist.
## clkA (100 MHz) and clkB (62.5 MHz) come from one MMCM, so Vivado would otherwise time the
## Gray-pointer synchronisers and the FIFO read against a 2 ns window. Those crossings are
## designed to be asynchronous. The block is guarded: during synthesis the MMCM pins are not
## visible (clk_wiz_0 is a black box) so it is skipped; in implementation it MUST print
## "CDC-XDC: applied" in the Tcl Console / log.
## Selected by NAME with a wildcard so the duplicate "_1" clocks (TIMING-4) are covered too.
set _cA [get_clocks -quiet {clk_out1_clk_wiz_0*}]
set _cB [get_clocks -quiet {clk_out2_clk_wiz_0*}]
if {[llength $_cA] && [llength $_cB]} {
    set_clock_groups -asynchronous -group $_cA -group $_cB
    puts "CDC-XDC: applied, $_cA <-> $_cB declared asynchronous"
} else {
    puts "CDC-XDC: skipped - MMCM clocks not defined yet (normal in synthesis, a problem in implementation)"
}
