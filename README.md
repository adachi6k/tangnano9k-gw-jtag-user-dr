# Tang Nano 9K GW_JTAG USER DR

Minimal Tang Nano 9K experiments for accessing user logic through the Gowin
internal `GW_JTAG` primitive.

## Result

The verified USER data register paths on Tang Nano 9K are:

| Item | Value |
|:-----|:------|
| FPGA | GW1NR-LV9QN88PC6/I5 |
| JTAG IDCODE | `0x1100481b` |
| JTAG IR length | `8` |
| Verified USER paths | ER1 / USER1 and ER2 / USER2 |
| Verified USER IRs | `0x42` and `0x43` |
| Confirmed DR width | `32` bits |

`drscan 32 0x0000003f` through either ER1 or ER2 lights all six on-board LEDs
in the matching probe top. ER1 / IR `0x42` is useful for BSCAN-like integration
experiments. See [`NOTES.md`](NOTES.md) for the bring-up notes and diagnostics.

## Requirements

- Gowin EDA with `gw_sh`
- `openFPGALoader`
- OpenOCD with FTDI support
- Tang Nano 9K with the SIPEED JTAG Debugger attached to the host

If `gw_sh` is not in `PATH`, set `GW_SH`:

```bash
export GW_SH=/opt/gowin_edu/IDE/bin/gw_sh
```

## Build and program

Build the USER DR LED probe:

```bash
make gowin-jtag-probe
```

Program it to SRAM:

```bash
sudo make gowin-jtag-probe-prog
```

Light all six LEDs through USER2 / ER2:

```bash
sudo make openocd-led-on
```

Build, program, and test the ER1 / USER1 probe:

```bash
make gowin-jtag-er1-probe
sudo make gowin-jtag-er1-probe-prog
sudo make openocd-led-on-er1
```

Equivalent OpenOCD sequence:

```tcl
irscan gowin.fpga 0x43
drscan gowin.fpga 32 0x0000003f
```

Equivalent ER1 sequence:

```tcl
irscan gowin.fpga 0x42
drscan gowin.fpga 32 0x0000003f
```

## Diagnostics

Build and program the sticky diagnostic top:

```bash
make gowin-jtag-diag
sudo make gowin-jtag-diag-prog
```

Run an ER2 scan:

```bash
cd scripts
sudo ./openocd_gowin_jtag_probe.sh drscan-ir 0x43 0x0000003f
```

The diagnostic top ties `tdo_er2_i` high, so a working ER2 TDO path reads back
`ffffffff`.

For ER1 diagnostics:

```bash
make gowin-jtag-er1-diag
sudo make gowin-jtag-er1-diag-prog
cd scripts
sudo ./openocd_gowin_jtag_probe.sh drscan-ir 0x42 0x0000003f
```

The ER1 diagnostic top ties `tdo_er1_i` high, so a working ER1 TDO path reads
back `ffffffff`.
