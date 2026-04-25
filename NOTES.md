# Tang Nano 9K PULP DMI BSCAN Bring-up

This note records the Tang Nano 9K `GW_JTAG` USER data register bring-up result.

## Result

Tang Nano 9K can access user logic through the Gowin internal `GW_JTAG` primitive.
The verified USER data register paths are:

| Item | Value |
|:-----|:------|
| Board | Tang Nano 9K |
| FPGA | GW1NR-LV9QN88PC6/I5 |
| JTAG IDCODE | `0x1100481b` |
| JTAG IR length | `8` |
| Verified USER paths | ER1 / USER1 and ER2 / USER2 |
| Verified USER IRs | `0x42` and `0x43` |
| Confirmed DR width | `32` bits |

ER2 / USER2 (`0x43`) was confirmed first. ER1 / USER1 (`0x42`) was then
retested with the same direct-shift conditions and also worked.

This makes a PULP Xilinx `BSCANE2`-style migration plausible: use two Gowin
native USER DRs instead of creating a soft TAP. The current experimental mapping
is ER1 / `0x42` for DTMCS and ER2 / `0x43` for DMIACCESS.

The similarly named files are split by USER path:

| Path | USER path |
|:-----|:----------|
| `rtl_top/jtag_user_reg_er1_tangnano9k_top.sv` | ER1 / USER1 |
| `rtl_top/jtag_user_reg_tangnano9k_top.sv` | ER2 / USER2 |
| `rtl_top/jtag_diag_er1_tangnano9k_top.sv` | ER1 / USER1 diagnostic |
| `rtl_top/jtag_diag_tangnano9k_top.sv` | ER2 / USER2 diagnostic |
| `rtl_top/gowin_dmi_bscan_tap.sv` | PULP-style BSCAN adapter |
| `rtl_top/pulp_bscan_probe_tangnano9k_top.sv` | PULP-style BSCAN probe |

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

Build and program the ER1 USER DR probe bitstream:

```bash
GW_SH=/opt/gowin_edu/IDE/bin/gw_sh make gowin-jtag-er1-probe
sudo make gowin-jtag-er1-probe-prog
```

Shift `0x0000003f` into ER1:

```bash
cd scripts
sudo ./openocd_gowin_jtag_probe.sh led-on-er1
```

Equivalent OpenOCD operations:

```tcl
irscan gowin.fpga 0x42
drscan gowin.fpga 32 0x0000003f
```

Expected result: all six on-board LEDs are lit.

## Diagnostic observations

The sticky diagnostic top confirmed the following:

- `scan` alone observes the TAP and JTAG reset/clock behavior.
- `drscan-ir 0x43 0x0000003f` reaches ER2 and observes shift/update activity.
- With `tdo_er2_i` tied high in the diagnostic top, OpenOCD reads back
  `ffffffff`, confirming the ER2 TDO path.
- With `0x0000003f` shifted in, the diagnostic top observes `tdi_o=1` during
  `shift_dr_capture_dr_o`, confirming the ER2 TDI path.
- The ER1 diagnostic top, using the same direct-shift conditions, also observes
  ER1 shift activity and reads back `ffffffff` with `tdo_er1_i` tied high.

## Implementation notes

The final LED probe intentionally drives LEDs from the shift register directly
instead of waiting for a separate `update_dr_o`-latched display register. This
avoids losing the visible result to TAP reset/update timing when OpenOCD exits.

The probes also do not gate shifting with `enable_er1_o` or `enable_er2_o`; the
observed useful control signal for this minimal test is `shift_dr_capture_dr_o`,
with OpenOCD selecting ER1 (`0x42`) or ER2 (`0x43`) through IR scan.

## PULP-style BSCAN migration notes

PULP's Xilinx flow replaces the normal soft `dmi_jtag_tap` with a native-FPGA
BSCAN implementation. In that flow, separate `BSCANE2` USER chains provide:

| Function | Xilinx/PULP shape | Gowin experiment |
|:---------|:------------------|:-----------------|
| DTMCS DR | native USER chain selected by a USER IR | ER1 / USER1, IR `0x42` |
| DMIACCESS DR | another native USER chain selected by a USER IR | ER2 / USER2, IR `0x43` |
| TCK/TDI/UPDATE/RESET | native BSCAN outputs | `GW_JTAG` outputs |
| TDO mux | native BSCAN chain TDO input | `tdo_er1_i` / `tdo_er2_i` |

`rtl_top/gowin_dmi_bscan_tap.sv` is written with the same module name and port
shape as PULP `dmi_jtag_tap`. The intended integration experiment is to compile
this file instead of PULP's Xilinx `dmi_bscane_tap.sv`, while keeping OpenOCD as
a script/config-only user of the existing Gowin TAP.

The main timing caveat is capture. `GW_JTAG` exposes `shift_dr_capture_dr_o`
rather than separate `CAPTURE` and `SHIFT` outputs like Xilinx `BSCANE2`. For
PULP integration, the adapter derives `capture_o` from the first active cycle of
`shift_dr_capture_dr_o` and `shift_o` from following active cycles, so they are
not asserted in the same TCK cycle. `dmi_clear_o` follows `test_logic_reset_o`
from the Gowin primitive.

The probe readback shifters are intentionally not gated by `enable_er1_o` or
`enable_er2_o`. This mirrors the earlier minimal LED probes, where the robust
condition was the USER IR selected by OpenOCD plus `shift_dr_capture_dr_o`.
The LEDs still latch the derived DTMCS/DMI select observations so enable behavior
can be inspected independently from the TDO readback path.

Probe expectations:

| Command | IR/DR operation | Expected readback |
|:--------|:----------------|:------------------|
| `sudo make openocd-bscan-dtmcs` | `irscan 0x42`, `drscan 32 0` | `00001071` |
| `sudo make openocd-bscan-dmi` | `irscan 0x43`, `drscan 41 0` | `0ab2bfaeaf8` |

During bring-up, a standalone adapter probe using direct shift behavior passed
on hardware and confirmed the ER1/ER2 USER DR mapping:

| Command | Observed readback |
|:--------|:------------------|
| `sudo make openocd-bscan-dtmcs` | `00001071` |
| `sudo make openocd-bscan-dmi` | `0ab2bfaeaf8` |

If the PULP-style probe reads back `ffffffff`, use
`pulp_bscan_fixed_tdo_tangnano9k_top` to bypass the adapter and drive
`tdo_er1_i` / `tdo_er2_i` directly from known shift registers:

| Command | Purpose | Expected readback |
|:--------|:--------|:------------------|
| `sudo make openocd-bscan-fixed-dtmcs` | Direct ER1 fixed-pattern TDO | `00001071` |
| `sudo make openocd-bscan-fixed-dmi` | Direct ER2 fixed-pattern TDO | `0ab2bfaeaf8` |

After avoiding pattern reload from `test_logic_reset_o`, this fixed-pattern
probe passes on hardware:

| Command | Observed readback |
|:--------|:------------------|
| `sudo make openocd-bscan-fixed-dtmcs` | `00001071` |
| `sudo make openocd-bscan-fixed-dmi` | `0ab2bfaeaf8` |

This confirms the raw Gowin USER TDO paths are healthy. Any remaining failure in
`pulp_bscan_probe_tangnano9k_top` belongs in the adapter timing/select layer.

If the fixed-pattern probe still reads `ffffffff`, run the constant TDO probe:

| Command | Purpose | Expected readback |
|:--------|:--------|:------------------|
| `sudo make openocd-bscan-constant-er1` | ER1 TDO tied low | `00000000` |
| `sudo make openocd-bscan-constant-er2` | ER2 TDO tied high | `ffffffff` |

This is the minimal check that the programmed top is controlling the USER TDO
inputs.

The constant TDO probe passing while a pattern probe reads `ffffffff` points at
probe-side reset/loading behavior rather than the raw TDO path. In particular,
do not reload ER1 pattern registers from `test_logic_reset_o` during scans: the
DTMCS test pattern has LSB `1`, so repeated reset reloads appear as all-ones
TDO.

The first adapter-probe pass used direct-shift bring-up semantics to prove the
ER1/ER2 USER DR mapping. For the real PULP-compatible adapter, the final
integration semantics are stricter than that bring-up probe: `capture_o` and
`shift_o` are mutually exclusive, selection tracking resets on
`test_logic_reset_o`, and `dmi_clear_o` is connected to the Gowin JTAG reset.
The next validation step is a real PULP `dmi_jtag` / `dm_top` connection,
checking DTMCS read through IR `0x42`, DMIACCESS read/write through IR `0x43`,
`dmcontrol.dmactive` write, and `dmstatus` read.

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

Shift `0x0000003f` through ER1:

```bash
cd scripts
sudo ./openocd_gowin_jtag_probe.sh led-on-er1
```

Run the sticky diagnostic bitstream:

```bash
GW_SH=/opt/gowin_edu/IDE/bin/gw_sh make gowin-jtag-diag
sudo make gowin-jtag-diag-prog
```

Run the ER1 sticky diagnostic bitstream:

```bash
GW_SH=/opt/gowin_edu/IDE/bin/gw_sh make gowin-jtag-er1-diag
sudo make gowin-jtag-er1-diag-prog
cd scripts
sudo ./openocd_gowin_jtag_probe.sh drscan-ir 0x42 0x0000003f
```

Run the PULP-style BSCAN probe:

```bash
GW_SH=/opt/gowin_edu/IDE/bin/gw_sh make gowin-pulp-bscan-probe
sudo make gowin-pulp-bscan-probe-prog
sudo make openocd-bscan-dtmcs
sudo make openocd-bscan-dmi
```

Run the fixed-pattern TDO isolation probe:

```bash
GW_SH=/opt/gowin_edu/IDE/bin/gw_sh make gowin-pulp-bscan-fixed-tdo
sudo make gowin-pulp-bscan-fixed-tdo-prog
sudo make openocd-bscan-fixed-dtmcs
sudo make openocd-bscan-fixed-dmi
```

Run the constant TDO isolation probe:

```bash
GW_SH=/opt/gowin_edu/IDE/bin/gw_sh make gowin-pulp-bscan-constant-tdo
sudo make gowin-pulp-bscan-constant-tdo-prog
sudo make openocd-bscan-constant-er1
sudo make openocd-bscan-constant-er2
```
