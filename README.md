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

The repository now also includes an experimental PULP-style BSCAN migration
layer. It maps Gowin ER1 / USER1 to DTMCS and ER2 / USER2 to DMIACCESS, matching
the two-native-USER-DR shape of PULP's Xilinx `BSCANE2` flow without modifying
OpenOCD itself.

## File map

| Path | Purpose |
|:-----|:--------|
| `rtl_top/jtag_user_reg_er1_tangnano9k_top.sv` | ER1 / USER1 LED probe (`tdo_er1_i`) |
| `rtl_top/jtag_user_reg_tangnano9k_top.sv` | ER2 / USER2 LED probe (`tdo_er2_i`) |
| `rtl_top/jtag_diag_er1_tangnano9k_top.sv` | ER1 sticky diagnostic; ties `tdo_er1_i` high |
| `rtl_top/jtag_diag_tangnano9k_top.sv` | ER2 sticky diagnostic; ties `tdo_er2_i` high |
| `rtl_top/gowin_dmi_bscan_tap.sv` | PULP `dmi_jtag_tap`-compatible Gowin BSCAN adapter |
| `rtl_top/pulp_bscan_probe_tangnano9k_top.sv` | Probe top for the PULP-style ER1/ER2 mapping |
| `rtl_top/pulp_bscan_fixed_tdo_tangnano9k_top.sv` | Direct GW_JTAG fixed-pattern TDO isolation probe |
| `rtl_top/pulp_bscan_constant_tdo_tangnano9k_top.sv` | Direct GW_JTAG constant-low/high TDO isolation probe |
| `rtl_jtag_er1_probe.f` | ER1 probe filelist |
| `rtl_jtag_probe.f` | ER2 probe filelist |
| `rtl_jtag_er1_diag.f` | ER1 diagnostic filelist |
| `rtl_jtag_diag.f` | ER2 diagnostic filelist |
| `rtl_pulp_bscan_probe.f` | PULP-style BSCAN probe filelist |
| `rtl_pulp_bscan_fixed_tdo.f` | Direct fixed-pattern TDO probe filelist |
| `rtl_pulp_bscan_constant_tdo.f` | Direct constant TDO probe filelist |

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
sudo make openocd-led-on-er2
```

`openocd-led-on` is kept as an alias for `openocd-led-on-er2`.

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

## PULP-style BSCAN probe

Build and program the PULP-style BSCAN probe:

```bash
make gowin-pulp-bscan-probe
sudo make gowin-pulp-bscan-probe-prog
```

The migration mapping is:

| PULP-style DR | Gowin USER path | IR | Probe DR width |
|:--------------|:----------------|:---|:---------------|
| DTMCS | ER1 / USER1 | `0x42` | `32` |
| DMIACCESS | ER2 / USER2 | `0x43` | `41` |

Read the probe DTMCS register:

```bash
sudo make openocd-bscan-dtmcs
```

Expected probe readback is `00001071` when the derived capture/shift timing
matches the Gowin primitive behavior.

Read the probe DMIACCESS register:

```bash
sudo make openocd-bscan-dmi
```

Expected probe readback is `0ab2bfaeaf8`.

These adapter probe readbacks have been confirmed on Tang Nano 9K hardware:

| Command | Observed readback |
|:--------|:------------------|
| `sudo make openocd-bscan-dtmcs` | `00001071` |
| `sudo make openocd-bscan-dmi` | `0ab2bfaeaf8` |

The probe readback registers intentionally capture and shift on GW_JTAG DR
activity without gating by `enable_er1_o` or `enable_er2_o`. The LED bits still
record whether those enable signals were observed, but readback validation only
depends on the USER DR TDO path and derived capture/shift timing.

`rtl_top/gowin_dmi_bscan_tap.sv` intentionally uses the same module name and
port shape as PULP `dmi_jtag_tap`, so it can be evaluated as a replacement for
PULP's Xilinx `dmi_bscane_tap.sv`. The next integration step is connecting this
adapter to a real PULP/RISC-V Debug Module.

If the PULP-style probe reads back `ffffffff`, program the direct fixed-pattern
TDO isolation probe:

```bash
make gowin-pulp-bscan-fixed-tdo
sudo make gowin-pulp-bscan-fixed-tdo-prog
sudo make openocd-bscan-fixed-dtmcs
sudo make openocd-bscan-fixed-dmi
```

This probe bypasses `gowin_dmi_bscan_tap.sv` and drives `tdo_er1_i` /
`tdo_er2_i` directly from known shift registers. It reads the same `00001071`
and `0ab2bfaeaf8` patterns on hardware after avoiding pattern reload from
`test_logic_reset_o`. That confirms the raw ER1/ER2 TDO paths are healthy.

If the fixed-pattern probe still reads back `ffffffff`, use the constant TDO
probe:

```bash
make gowin-pulp-bscan-constant-tdo
sudo make gowin-pulp-bscan-constant-tdo-prog
sudo make openocd-bscan-constant-er1
sudo make openocd-bscan-constant-er2
```

This ties ER1 TDO low and ER2 TDO high. Expected readback is `00000000` for ER1
and `ffffffff` for ER2. If ER1 still reads `ffffffff`, the issue is not the
shift-register pattern logic.

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
