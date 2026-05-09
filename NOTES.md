# Gowin GW_JTAG PULP DMI BSCAN Notes

This note records the current `GW_JTAG` USER data register bring-up result for
using Gowin FPGA-native USER JTAG data registers as a PULP `riscv-dbg` DMI
transport.

## Summary

Verified boards:

| Board | FPGA family | JTAG IDCODE | USER1 / ER1 | USER2 / ER2 |
|:------|:------------|:------------|:------------|:------------|
| Tang Nano 9K | GW1NR-9C | `0x1100481b` | `0x42` | `0x43` |
| Tang Primer 20K | GW2A-18 | `0x0000081b` | `0x42` | `0x43` |
| Tang Primer 25K | GW5A-25 | `0x0001281b` | `0x42` | `0x43` |

The important result is that all three tested boards expose the same two USER
paths through `GW_JTAG`:

- ER1 / USER1 / IR `0x42`: maps to PULP DTMCS.
- ER2 / USER2 / IR `0x43`: maps to PULP DMIACCESS.

## Adapter Shape

The adapter under test is `experiments/adapter_probe/gowin_dmi_bscan_tap.sv`. It keeps the PULP
module name `dmi_jtag_tap` and maps Gowin USER DR scan signals into the
PULP-compatible TAP replacement interface.

`GW_JTAG` is not a raw external JTAG pin interface. It already provides decoded
USER-chain signals:

- `tck_o`
- `tdi_o`
- `test_logic_reset_o`
- `shift_dr_capture_dr_o`
- `update_dr_o`
- `enable_er1_o`
- `enable_er2_o`
- `tdo_er1_i`
- `tdo_er2_i`

The adapter treats the first active `shift_dr_capture_dr_o` cycle as capture
and subsequent active cycles as shift:

- `capture_o = jshift_capture & ~jshift_capture_q`
- `shift_o = jshift_capture & jshift_capture_q`
- `update_o = jupdate`
- `dmi_clear_o = test_logic_reset_o`

This preserves PULP-style semantics where `capture_o` and `shift_o` are
mutually exclusive.

## Fixed-Pattern Probe

The fixed-pattern isolation probe reads known values from the two USER paths:

| Operation | Expected |
|:----------|:---------|
| `IR 0x42`, `DR32` | `00001071` |
| `IR 0x43`, `DR41` | `00ab2bfaeaf8` in OpenOCD formatting |

The portable top is:

- `experiments/isolation/pulp_bscan_fixed_tdo_portless_top.sv`

Board-specific build scripts:

- `gowin/build_pulp_bscan_fixed_tdo_primer20k.tcl`
- `gowin/build_pulp_bscan_fixed_tdo_primer25k.tcl`

Nano 9K uses the older LED-capable top:

- `experiments/isolation/pulp_bscan_fixed_tdo_tangnano9k_top.sv`
- `gowin/build_pulp_bscan_fixed_tdo.tcl`

## Capture Timing Detail

GW5A-25 showed why the fixed-pattern probe must not rely only on FF initial
values or `Update-DR` reload.

On Primer 25K, a first version of the fixed-pattern probe returned:

- `IR 0x42`, `DR32`: `ffffffff`
- `IR 0x43`, `DR41`: `000000000000`

Constant-TDO testing still showed that IR `0x42` and `0x43` were connected to
`tdo_er1_i` and `tdo_er2_i`. A signal-to-TDO diagnostic then tied ER1 TDO to
`jshift_capture` and ER2 TDO to `jtdi`, confirming that:

- `shift_dr_capture_dr_o` is active during the scan.
- `tdi_o` follows the shifted DR input data.
- The capture cycle can be visible as the first scanned bit.

The fixed-pattern portless probe was corrected to load the pattern on the first
active `shift_dr_capture_dr_o` cycle and drive the first bit explicitly. After
that change, Primer 25K reads:

- `IR 0x42`, `DR32`: `00001071`
- `IR 0x43`, `DR41`: `00ab2bfaeaf8`

## Constant-TDO Probe

The constant-TDO probe is used to identify USER IRs without depending on shift
register timing.

Normal polarity:

- `tdo_er1_i = 1'b0`
- `tdo_er2_i = 1'b1`

Expected direct reads:

- `IR 0x42`: all-zero
- `IR 0x43`: all-one

Inverted polarity swaps those results.

Relevant tops:

- `experiments/isolation/pulp_bscan_constant_tdo_tangnano9k_top.sv`
- `experiments/isolation/pulp_bscan_constant_tdo_inverted_tangnano9k_top.sv`
- `experiments/isolation/pulp_bscan_constant_tdo_primer_top.sv`
- `experiments/isolation/pulp_bscan_constant_tdo_primer_inverted_top.sv`

## OpenOCD / FTDI Notes

The shared helper is:

- `scripts/openocd_gowin_jtag_probe.sh`
- `scripts/openocd_gowin_jtag_probe.cfg`

The default direct FTDI setup is:

- VID/PID: `0x0403:0x6010`
- channel: `0`
- `ftdi layout_init 0x0008 0x001b`
- adapter speed: `1000 kHz`
- JTAG IR length: `8`

This setup works for the verified SIPEED FTDI debug interfaces. The old layout
`0x0808 0x0a1b` worked in some Nano/20K cases but produced all-ones / IR
capture errors with the tested Primer 25K, so it is no longer the default.

Useful commands:

```bash
scripts/openocd_gowin_jtag_probe.sh scan
scripts/openocd_gowin_jtag_probe.sh bscan-fixed-dtmcs
scripts/openocd_gowin_jtag_probe.sh bscan-fixed-dmi
scripts/openocd_gowin_jtag_probe.sh bscan-constant-er1
scripts/openocd_gowin_jtag_probe.sh bscan-constant-er2
scripts/openocd_gowin_jtag_probe.sh sweep-constant-tdo-ir
```

## Current Validation Boundary

The raw `GW_JTAG` USER paths and fixed-pattern probes are verified. The next
validation step is to connect `gowin_dmi_bscan_tap.sv` to real PULP
`dmi_jtag` / `dm_top` logic and verify an actual debug-module transaction:

1. Read DTMCS.
2. Read/write DMIACCESS.
3. Write `dmcontrol.dmactive`.
4. Read `dmstatus`.
