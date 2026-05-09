# Gowin GW_JTAG PULP DMI BSCAN

Gowin `GW_JTAG` adapter experiments for using FPGA-native USER JTAG data
registers as a PULP `riscv-dbg` DMI transport.

The main RTL artifact is `experiments/adapter_probe/gowin_dmi_bscan_tap.sv`: a module named
`dmi_jtag_tap` with the same port shape as PULP's JTAG TAP replacement layer.
It maps Gowin USER data registers to the two DMI JTAG registers used by PULP:

| PULP DMI JTAG register | Gowin USER path | Gowin IR |
|:-----------------------|:----------------|:---------|
| DTMCS | ER1 / USER1 | `0x42` |
| DMIACCESS | ER2 / USER2 | `0x43` |

This follows the same integration idea as PULP's Xilinx `BSCANE2` flow, but
uses Gowin `GW_JTAG` instead of Xilinx BSCAN primitives.

## Upstream PULP Context

- PULP RISC-V debug repository: <https://github.com/pulp-platform/riscv-dbg>
- Normal soft TAP: [`src/dmi_jtag_tap.sv`](https://github.com/pulp-platform/riscv-dbg/blob/master/src/dmi_jtag_tap.sv)
- Xilinx BSCAN replacement: [`src/dmi_bscane_tap.sv`](https://github.com/pulp-platform/riscv-dbg/blob/master/src/dmi_bscane_tap.sv)

`GW_JTAG` already provides decoded USER DR scan signals. Do not connect it as
if it were raw external `TCK` / `TMS` / `TDI` / `TDO` pins into the normal soft
TAP.

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

## Verified Hardware

The USER1/USER2 IR assignment has been verified with fixed-pattern and
constant-TDO probes on these boards:

| Board | FPGA family | JTAG IDCODE | USER1 / ER1 | USER2 / ER2 |
|:------|:------------|:------------|:------------|:------------|
| Tang Nano 9K | GW1NR-9C | `0x1100481b` | `0x42` | `0x43` |
| Tang Primer 20K | GW2A-18 | `0x0000081b` | `0x42` | `0x43` |
| Tang Primer 25K | GW5A-25 | `0x0001281b` | `0x42` | `0x43` |

Expected fixed-pattern readback:

| Operation | Expected |
|:----------|:---------|
| `IR 0x42`, `DR32` | `00001071` |
| `IR 0x43`, `DR41` | `00ab2bfaeaf8` in OpenOCD formatting |

The GW5A-25 test exposed one timing detail: `shift_dr_capture_dr_o` can make
the capture cycle visible as the first scanned bit. The portable fixed-pattern
probe therefore loads on the first active `shift_dr_capture_dr_o` cycle and
compensates that first bit explicitly.

## Adapter Semantics

`gowin_dmi_bscan_tap.sv` uses PULP-compatible semantics:

- `capture_o` and `shift_o` are mutually exclusive.
- The first active `shift_dr_capture_dr_o` cycle asserts `capture_o`.
- Following active `shift_dr_capture_dr_o` cycles assert `shift_o`.
- `dmi_clear_o` follows Gowin `test_logic_reset_o`.
- ER1/ER2 selection tracking is reset by Gowin `test_logic_reset_o`.

The next system-level validation step is integration with real PULP
`dmi_jtag` / `dm_top`:

1. Read DTMCS through IR `0x42`.
2. Read/write DMIACCESS through IR `0x43`.
3. Write `dmcontrol.dmactive`.
4. Read `dmstatus`.

## Key Files

| Path | Purpose |
|:-----|:--------|
| `experiments/adapter_probe/gowin_dmi_bscan_tap.sv` | PULP `dmi_jtag_tap` pin-compatible Gowin BSCAN adapter |
| `rtl/gowin/GW_JTAG.sv` | Gowin `GW_JTAG` black-box declaration |
| `rtl/gowin/gowin_jtag_shim.sv` | Small wrapper exposing `GW_JTAG` signals |
| `experiments/adapter_probe/pulp_bscan_probe_tangnano9k_top.sv` | Nano 9K adapter bring-up probe |
| `experiments/isolation/pulp_bscan_fixed_tdo_tangnano9k_top.sv` | Nano 9K fixed-pattern isolation probe |
| `experiments/isolation/pulp_bscan_fixed_tdo_portless_top.sv` | Portable fixed-pattern isolation probe for boards without LEDs |
| `experiments/isolation/pulp_bscan_constant_tdo_tangnano9k_top.sv` | Nano 9K constant-TDO isolation probe |
| `experiments/isolation/pulp_bscan_constant_tdo_primer_top.sv` | Primer constant-TDO isolation probe |
| `experiments/isolation/pulp_bscan_signal_tdo_primer_top.sv` | Primer signal-to-TDO diagnostic probe |
| `scripts/openocd_gowin_jtag_probe.sh` | OpenOCD raw IR/DR helper |

The older Nano 9K LED and diagnostic probes are retained because they document
the original `GW_JTAG` bring-up path and remain useful when debugging USER DR
behavior.

## Requirements

- Gowin EDA with `gw_sh`
- `openFPGALoader`
- OpenOCD with FTDI support
- A Gowin board with an FTDI JTAG interface, such as Tang Nano 9K, Tang Primer
  20K, or Tang Primer 25K

If `gw_sh` is not in `PATH`, set `GW_SH`:

```bash
export GW_SH=/opt/gowin_edu/IDE/bin/gw_sh
```

## Build Examples

Nano 9K PULP-style adapter probe:

```bash
make gowin-pulp-bscan-probe
sudo make gowin-pulp-bscan-probe-prog
sudo make openocd-bscan-dtmcs
sudo make openocd-bscan-dmi
```

Nano 9K fixed-pattern isolation probe:

```bash
make gowin-pulp-bscan-fixed-tdo
sudo make gowin-pulp-bscan-fixed-tdo-prog
sudo make openocd-bscan-fixed-dtmcs
sudo make openocd-bscan-fixed-dmi
```

Primer 20K fixed-pattern isolation probe:

```bash
make gowin-primer20k-fixed-tdo
openFPGALoader -b tangprimer20k gowin/impl/pnr/pulp_bscan_fixed_tdo_primer20k.fs
scripts/openocd_gowin_jtag_probe.sh bscan-fixed-dtmcs
scripts/openocd_gowin_jtag_probe.sh bscan-fixed-dmi
```

Primer 25K fixed-pattern isolation probe:

```bash
make gowin-primer25k-fixed-tdo
openFPGALoader -b tangprimer25k gowin/impl/pnr/pulp_bscan_fixed_tdo_primer25k.fs
scripts/openocd_gowin_jtag_probe.sh bscan-fixed-dtmcs
scripts/openocd_gowin_jtag_probe.sh bscan-fixed-dmi
```

## OpenOCD Helper

The OpenOCD helper defaults to FTDI VID/PID `0403:6010`, channel 0, and
`ftdi layout_init 0x0008 0x001b`, which works for the verified SIPEED FTDI
debuggers. Environment variables can override the interface, speed, expected
IDCODE, FTDI description, VID/PID, channel, and layout.

Useful commands:

```bash
scripts/openocd_gowin_jtag_probe.sh scan
scripts/openocd_gowin_jtag_probe.sh bscan-fixed-dtmcs
scripts/openocd_gowin_jtag_probe.sh bscan-fixed-dmi
scripts/openocd_gowin_jtag_probe.sh bscan-constant-er1
scripts/openocd_gowin_jtag_probe.sh bscan-constant-er2
scripts/openocd_gowin_jtag_probe.sh sweep-constant-tdo-ir
```

## License

Solderpad Hardware License v0.51 (`SHL-0.51`). See [`LICENSE`](LICENSE).
