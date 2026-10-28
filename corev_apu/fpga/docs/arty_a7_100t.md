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
