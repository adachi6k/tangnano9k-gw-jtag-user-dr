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
| Confirmed raw USER probe DR width | `32` bits |
| Verified DMIACCESS width | `41` bits (`abits=7`, `data=32`, `op/status=2`) |

ER2 / USER2 (`0x43`) was confirmed first. ER1 / USER1 (`0x42`) was then
retested with the same direct-shift conditions and also worked.

This makes a PULP Xilinx `BSCANE2`-style migration plausible: use two Gowin
native USER DRs instead of creating a soft TAP. The current experimental mapping
is ER1 / `0x42` for DTMCS and ER2 / `0x43` for DMIACCESS.

The similarly named files are split by USER path:

| Path | USER path |
|:-----|:----------|
| `experiments/user_dr/jtag_user_reg_er1_tangnano9k_top.sv` | ER1 / USER1 |
| `experiments/user_dr/jtag_user_reg_tangnano9k_top.sv` | ER2 / USER2 |
| `experiments/user_dr/jtag_diag_er1_tangnano9k_top.sv` | ER1 / USER1 diagnostic |
| `experiments/user_dr/jtag_diag_tangnano9k_top.sv` | ER2 / USER2 diagnostic |
| `experiments/adapter_probe/gowin_dmi_bscan_tap.sv` | PULP-style BSCAN adapter |
| `experiments/adapter_probe/pulp_bscan_probe_tangnano9k_top.sv` | PULP-style BSCAN probe |

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

`experiments/adapter_probe/gowin_dmi_bscan_tap.sv` is written with the same module name and port
shape as PULP `dmi_jtag_tap`. It remains useful for adapter probes and for
documenting the attempted BSCANE2-style migration.

The hardware-validated integration path is now `rtl/pulp/gowin_dmi_jtag.sv`.
It replaces PULP `dmi_jtag.sv` as a whole, keeps the same external module port
shape, reuses PULP `dmi_cdc`, and implements DTMCS/DMIACCESS directly on
`GW_JTAG` USER chains.

The main timing caveat is capture/update. `GW_JTAG` exposes
`shift_dr_capture_dr_o` rather than separate `CAPTURE` and `SHIFT` outputs like
Xilinx `BSCANE2`, and ER2 DMIACCESS does not reliably provide a
PULP-compatible `enable_er2_o` / `update_dr_o` sequence. The working full bridge
therefore preloads DTMCS while ER1 is selected and idle, shifts throughout
`shift_dr_capture_dr_o`, counts 41 DMIACCESS bits, and treats the end of that
41-bit USER DR shift as the DMI update point. `test_logic_reset_o` is kept as an
observed diagnostic signal rather than being wired into the bridge reset path;
using it as `trst_ni` or DMI clear made DTMCS read back `00000000` in hardware.

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
ER1/ER2 USER DR mapping. The later real PULP `dmi_jtag` / `dm_top` connection
showed that a TAP-only adapter was not sufficient on Tang Nano 9K, so the
working integration moved the Gowin-specific behavior into a full `dmi_jtag`
replacement.

## Verified PULP Debug Module integration

The following stack was verified on hardware through the LM RV32 integration:

| Component | Version / value |
|:----------|:----------------|
| Board | Tang Nano 9K |
| FPGA | GW1NR-LV9QN88PC6/I5 |
| JTAG adapter | SIPEED JTAG Debugger |
| PULP riscv-dbg | `v0.10.0` / `1cd764a82d7d49c5e8679fbb70b540b2e274bab9` |
| PULP common_cells | `v1.39.0-5-gb74f0ad` / `b74f0ad63600762ef101cf1d3365d19dfbb3123b` |
| Debug wrapper | `dm_obi_top` + `dmi_cdc` + `gowin_dmi_jtag.sv` |
| OpenOCD | `0.12.0+dev-geb01c63` |

Confirmed operations:

| Operation | Result |
|:----------|:-------|
| Gowin TAP scan | IDCODE `0x1100481b`, IR length `8` |
| DTMCS read, ER1 / IR `0x42` | `00001071` |
| DMIACCESS NOP pattern loop, ER2 / IR `0x43` | second scan readback `00ab2bfaeaf8` |
| Write `dmcontrol.dmactive=1` | `addr=0x10 data=0x00000001 status=0` |
| Read `dmstatus` | `addr=0x11 data=0x000c0c82 status=0` |
| OpenOCD examine | `Target successfully examined`, `XLEN=32`, `misa=0x40001100` |
| OpenOCD halt smoke test | halted by debug-request, `pc=0x00000400` |

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
