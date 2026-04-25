# Tang Nano 9K PULP DMI BSCAN

Gowin `GW_JTAG` adapter experiments for using the Tang Nano 9K internal JTAG TAP
as a PULP `riscv-dbg` DMI transport.

The main artifact is `rtl/pulp/gowin_dmi_bscan_tap.sv`: a module named
`dmi_jtag_tap` with the same port shape as PULP's JTAG TAP replacement layer. It
maps Gowin native USER data registers to the two DMI JTAG data registers used by
PULP:

| PULP DMI JTAG register | Gowin USER path | Gowin IR |
|:-----------------------|:----------------|:---------|
| DTMCS | ER1 / USER1 | `0x42` |
| DMIACCESS | ER2 / USER2 | `0x43` |

This follows the same integration idea as PULP's Xilinx `BSCANE2` flow, but uses
Gowin `GW_JTAG` instead of Xilinx BSCAN primitives.

## Upstream PULP context

- PULP RISC-V debug repository: <https://github.com/pulp-platform/riscv-dbg>
- Normal soft TAP: [`src/dmi_jtag_tap.sv`](https://github.com/pulp-platform/riscv-dbg/blob/master/src/dmi_jtag_tap.sv)
- Xilinx BSCAN replacement: [`src/dmi_bscane_tap.sv`](https://github.com/pulp-platform/riscv-dbg/blob/master/src/dmi_bscane_tap.sv)

PULP's `dmi_bscane_tap.sv` is pin-compatible with `dmi_jtag_tap` and replaces
the full soft TAP with FPGA-native USER chains. This repository provides the
corresponding Gowin/Tang Nano 9K direction:

```text
Gowin GW_JTAG
  ER1 / IR 0x42 -> DTMCS
  ER2 / IR 0x43 -> DMIACCESS
        |
        v
gowin_dmi_bscan_tap  (module name: dmi_jtag_tap)
        |
        v
PULP dmi_jtag
        |
        v
PULP dm_top
        |
        v
RISC-V core
```

`GW_JTAG` already provides decoded USER DR scan signals. Do not connect it as if
it were raw external `TCK` / `TMS` / `TDI` / `TDO` pins into the normal soft TAP.

## Current hardware status

Verified on Tang Nano 9K:

| Item | Value |
|:-----|:------|
| FPGA | GW1NR-LV9QN88PC6/I5 |
| JTAG IDCODE | `0x1100481b` |
| JTAG IR length | `8` |
| USER1 / ER1 IR | `0x42` |
| USER2 / ER2 IR | `0x43` |
| ER1 raw TDO control | Passed |
| ER2 raw TDO control | Passed |
| PULP-style adapter mapping probe | Passed during bring-up |

The final `gowin_dmi_bscan_tap.sv` now uses PULP-compatible semantics:

- `capture_o` and `shift_o` are mutually exclusive.
- The first active `shift_dr_capture_dr_o` cycle asserts `capture_o`.
- Following active `shift_dr_capture_dr_o` cycles assert `shift_o`.
- `dmi_clear_o` follows Gowin `test_logic_reset_o`.
- ER1/ER2 selection tracking is reset by Gowin `test_logic_reset_o`.

The next validation step is integration with real PULP `dmi_jtag` / `dm_top`:

1. Read DTMCS through IR `0x42`.
2. Read/write DMIACCESS through IR `0x43`.
3. Write `dmcontrol.dmactive`.
4. Read `dmstatus`.

## Key files

| Path | Purpose |
|:-----|:--------|
| `rtl/pulp/gowin_dmi_bscan_tap.sv` | PULP `dmi_jtag_tap` pin-compatible Gowin BSCAN adapter |
| `rtl/gowin/GW_JTAG.sv` | Gowin `GW_JTAG` black-box declaration |
| `rtl/gowin/gowin_jtag_shim.sv` | Small wrapper exposing `GW_JTAG` signals |
| `experiments/adapter_probe/pulp_bscan_probe_tangnano9k_top.sv` | Adapter bring-up probe top |
| `experiments/isolation/pulp_bscan_fixed_tdo_tangnano9k_top.sv` | Direct fixed-pattern TDO isolation probe |
| `experiments/isolation/pulp_bscan_constant_tdo_tangnano9k_top.sv` | Direct constant-low/high TDO isolation probe |
| `experiments/user_dr/jtag_user_reg_er1_tangnano9k_top.sv` | ER1 / USER1 LED probe |
| `experiments/user_dr/jtag_user_reg_tangnano9k_top.sv` | ER2 / USER2 LED probe |
| `scripts/openocd_gowin_jtag_probe.sh` | OpenOCD script-only raw IR/DR helper |

The older LED and diagnostic probes are kept because they document the Tang Nano
9K `GW_JTAG` bring-up path and are useful when debugging USER DR behavior.

## Requirements

- Gowin EDA with `gw_sh`
- `openFPGALoader`
- OpenOCD with FTDI support
- Tang Nano 9K with the SIPEED JTAG Debugger attached to the host

If `gw_sh` is not in `PATH`, set `GW_SH`:

```bash
export GW_SH=/opt/gowin_edu/IDE/bin/gw_sh
```

## Build the PULP-style adapter probe

Build and program the adapter probe:

```bash
make gowin-pulp-bscan-probe
sudo make gowin-pulp-bscan-probe-prog
```

Read the DTMCS-like probe register on ER1:

```bash
sudo make openocd-bscan-dtmcs
```

Read the DMIACCESS-like probe register on ER2:

```bash
sudo make openocd-bscan-dmi
```

Bring-up probe patterns:

| Command | IR/DR operation | Pattern |
|:--------|:----------------|:--------|
| `sudo make openocd-bscan-dtmcs` | `irscan 0x42`, `drscan 32 0` | `00001071` |
| `sudo make openocd-bscan-dmi` | `irscan 0x43`, `drscan 41 0` | `0ab2bfaeaf8` |

## Isolation probes

Use these only when the adapter probe result is confusing.

Direct fixed-pattern TDO probe:

```bash
make gowin-pulp-bscan-fixed-tdo
sudo make gowin-pulp-bscan-fixed-tdo-prog
sudo make openocd-bscan-fixed-dtmcs
sudo make openocd-bscan-fixed-dmi
```

Expected readback:

| Command | Expected |
|:--------|:---------|
| `sudo make openocd-bscan-fixed-dtmcs` | `00001071` |
| `sudo make openocd-bscan-fixed-dmi` | `0ab2bfaeaf8` |

Direct constant TDO probe:

```bash
make gowin-pulp-bscan-constant-tdo
sudo make gowin-pulp-bscan-constant-tdo-prog
sudo make openocd-bscan-constant-er1
sudo make openocd-bscan-constant-er2
```

Expected readback:

| Command | Expected |
|:--------|:---------|
| `sudo make openocd-bscan-constant-er1` | `00000000` |
| `sudo make openocd-bscan-constant-er2` | `ffffffff` |

## Basic USER DR probes

The original USER DR LED probes are still available:

```bash
make gowin-jtag-probe
sudo make gowin-jtag-probe-prog
sudo make openocd-led-on-er2

make gowin-jtag-er1-probe
sudo make gowin-jtag-er1-probe-prog
sudo make openocd-led-on-er1
```

Equivalent raw OpenOCD operations:

```tcl
irscan gowin.fpga 0x42
drscan gowin.fpga 32 0x0000003f

irscan gowin.fpga 0x43
drscan gowin.fpga 32 0x0000003f
```

## License

MIT. See [`LICENSE`](LICENSE).
