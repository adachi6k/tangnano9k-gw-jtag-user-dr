# Tang Nano 9K GW_JTAG USER DR Bring-up

This note records the Tang Nano 9K `GW_JTAG` USER data register bring-up result.

## Result

Tang Nano 9K can access user logic through the Gowin internal `GW_JTAG` primitive.
The working USER data register path is:

| Item | Value |
|:-----|:------|
| Board | Tang Nano 9K |
| FPGA | GW1NR-LV9QN88PC6/I5 |
| JTAG IDCODE | `0x1100481b` |
| JTAG IR length | `8` |
| Working USER path | ER2 / USER2 |
| Working USER IR | `0x43` |
| Confirmed DR width | `32` bits |

The ER1 / USER1 path (`0x42`) did not produce a usable LED update in this
experiment. ER2 / USER2 (`0x43`) did.

## Reproduction

Build and program the ER2 USER DR probe bitstream:

```bash
GW_SH=/opt/gowin_edu/IDE/bin/gw_sh make gowin-jtag-probe
sudo make gowin-jtag-probe-prog
```

Shift `0x0000003f` into the USER DR:

```bash
cd scripts
sudo ./openocd_gowin_jtag_probe.sh led-on
```

Equivalent OpenOCD operations:

```tcl
irscan gowin.fpga 0x43
drscan gowin.fpga 32 0x0000003f
```

Expected result: all six on-board LEDs are lit.

The first `drscan` response can be `00000000`. That is expected for the probe
top because `tdo_er2_i` returns the previous shift-register contents; the LED
state after the scan is the important observation.

## Diagnostic observations

The sticky diagnostic top confirmed the following:

- `scan` alone observes the TAP and JTAG reset/clock behavior.
- `drscan-ir 0x43 0x0000003f` reaches ER2 and observes shift/update activity.
- With `tdo_er2_i` tied high in the diagnostic top, OpenOCD reads back
  `ffffffff`, confirming the ER2 TDO path.
- With `0x0000003f` shifted in, the diagnostic top observes `tdi_o=1` during
  `shift_dr_capture_dr_o`, confirming the ER2 TDI path.

## Implementation notes

The final LED probe intentionally drives LEDs from the shift register directly
instead of waiting for a separate `update_dr_o`-latched display register. This
avoids losing the visible result to TAP reset/update timing when OpenOCD exits.

The probe also does not gate shifting with `enable_er2_o`; the observed useful
control signals for this minimal test are `shift_dr_capture_dr_o` and the ER2
instruction selected by OpenOCD (`0x43`).

## Useful commands

Detect the TAP:

```bash
cd scripts
sudo ./openocd_gowin_jtag_probe.sh scan
```

Shift a custom 32-bit value through ER2:

```bash
cd scripts
sudo ./openocd_gowin_jtag_probe.sh drscan 0x00000015
```

Run the sticky diagnostic bitstream:

```bash
GW_SH=/opt/gowin_edu/IDE/bin/gw_sh make gowin-jtag-diag
sudo make gowin-jtag-diag-prog
```
