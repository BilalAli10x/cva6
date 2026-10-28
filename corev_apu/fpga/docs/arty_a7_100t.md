# CVA6 on the Digilent Arty A7-100T

Board: Digilent Arty A7-100T, Xilinx Artix-7 `xc7a100tcsg324-1`.

```
export BOARD=arty_a7_100t
source corev_apu/fpga/sourceme.sh
make fpga target=cv32a6_imac_sv32
```

The build needs the Digilent board files installed in Vivado (part and board
part are selected in `sourceme.sh`).

## Memory map

| Region | Address |
|---|---|
| Boot ROM | `0x0001_0000` |
| UART | `0x1000_0000` |
| Ethernet (PLIC source 3) | `0x3000_0000` |
| GPIO: LD4-LD7, SW0-SW3 | `0x4000_0000` |
| DDR3 (256 MB) | `0x8000_0000` |

The boot ROM prints `Hello World!` on the FT2232 channel B UART at 57600 baud
and then waits for a boot image. Its stack is in DDR (`sp = 0x8400_0000`), so
DDR must calibrate before any code runs.

USB-UART pins: `tx = D10` (FPGA TX), `rx = A9` (FPGA RX).

## Clocking and reset

- E3 100 MHz -> BUFG -> MIG `sys_clk_i` and the clocking wizard.
- Clocking wizard: 25 MHz core clock, 200 MHz MIG `clk_ref_i` (IDELAYCTRL).
- MIG `sys_rst` is held until the reference clock locks; BTN0 (D9, active
  high) is the board reset.
- The MIG uses `SystemClock`/`ReferenceClock = No Buffer` and the BUFG input
  to avoid an LVCMOS25 constraint on E3 (see `mig_arty_a7_100t.prj`).

## Ethernet

The board's TI DP83848J is a 10/100 MII PHY, which the lowRISC
`ariane-ethernet` MAC (RGMII, Genesys2) does not support. The Arty build uses
`src/arty-ethernet/` instead, added to the sources only for
`BOARD=arty_a7_100t`:

- `framing_top_mii.sv`: lowRISC's `framing_top` with the RGMII MAC replaced by
  an MII one, in the spirit of lowRISC's `framing_top_rmii`. The register map
  and buffers are unchanged, so the lowRISC Linux driver (`lowrisc-eth`) works
  as is.
- `mii_soc.sv`: glue to verilog-ethernet's `eth_mac_mii_fifo`. Adapts
  `framing_top`'s TX handshake to an AXI-Stream FIFO, adds an inter-frame gap
  on RX and uses 4 KB store-and-forward FIFOs (full 1518-byte frames).
- `eth_mac_mii*.sv`, `mii_phy_if.sv`, `ssio_sdr_in.sv`, `axis_*.sv`: unmodified
  verilog-ethernet (Alex Forencich, MIT). The shared MAC core
  (`eth_mac_1g.sv`, `axis_gmii_*.sv`) comes from `ariane-ethernet`.

`ariane_peripherals` selects it with `UseMii = 1`; other boards keep
`framing_top`. Everything runs on the 25 MHz SoC clock; the FIFOs cross into the
PHY's `eth_txck`/`eth_rxck`. The FPGA drives the PHY's 25 MHz reference clock
(`eth_ref_clk`, G18) from an ODDR. Tested at 100 Mb/s full duplex.

| Signal | Pin | Signal | Pin |
|---|---|---|---|
| `eth_ref_clk` | G18 | `eth_rst_n` | C16 |
| `eth_txck` | H16 | `eth_rxck` | F15 |
| `eth_txctl` (TX_EN) | H15 | `eth_rxctl` (RX_DV) | G16 |
| `eth_txd[3:0]` | H17 J13 J14 H14 | `eth_rxd[3:0]` | G17 E18 E17 D18 |
| `eth_mdc` | F16 | `eth_mdio` | K13 (pull-up) |
| `eth_rxer` | C17 | | |

## DDR3

Micron MT41K128M16 (2 Gb, x16, 1.35 V), MIG configuration: tCK 3077 ps, CAS 5,
chip select enabled (U8), SSTL135 I/O.

## Debug

There are no external JTAG user pins, so the debug TAP uses the FPGA's BSCANE2
primitives (`dmi_bscane_tap.sv`, selected in place of `dmi_jtag_tap.sv`).

| Chain | IR | Use |
|---|---|---|
| USER3 | `0x22` | DTM control/status |
| USER4 | `0x23` | DMI |

IDCODE: `0x13631093`, IR length 6.

## Flash

```
openFPGALoader -b arty_a7_100t corev_apu/fpga/work-fpga/ariane_xilinx.bit
```
