#!/usr/bin/env bash
# openocd_gowin_jtag_probe.sh — OpenOCD helper for Tang Nano 9K GW_JTAG USER
# DR probing.
#
# Usage:
#   ./scripts/openocd_gowin_jtag_probe.sh scan
#   ./scripts/openocd_gowin_jtag_probe.sh led-on
#   ./scripts/openocd_gowin_jtag_probe.sh led-on-er1
#   ./scripts/openocd_gowin_jtag_probe.sh led-on-er2
#   ./scripts/openocd_gowin_jtag_probe.sh drscan 0x0000003f
#   ./scripts/openocd_gowin_jtag_probe.sh drscan-ir 0x43 0x0000003f
#   ./scripts/openocd_gowin_jtag_probe.sh drscan-bits-ir 0x42 32 0x0
#   ./scripts/openocd_gowin_jtag_probe.sh bscan-dtmcs
#   ./scripts/openocd_gowin_jtag_probe.sh bscan-dmi
#   ./scripts/openocd_gowin_jtag_probe.sh bscan-fixed-dtmcs
#   ./scripts/openocd_gowin_jtag_probe.sh bscan-fixed-dmi
#   ./scripts/openocd_gowin_jtag_probe.sh bscan-constant-er1
#   ./scripts/openocd_gowin_jtag_probe.sh bscan-constant-er2
#   ./scripts/openocd_gowin_jtag_probe.sh server

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  openocd_gowin_jtag_probe.sh scan
  openocd_gowin_jtag_probe.sh led-on
  openocd_gowin_jtag_probe.sh led-on-er1
  openocd_gowin_jtag_probe.sh led-on-er2
  openocd_gowin_jtag_probe.sh drscan <32-bit-value>
  openocd_gowin_jtag_probe.sh drscan-ir <8-bit-ir> <32-bit-value>
  openocd_gowin_jtag_probe.sh drscan-bits-ir <8-bit-ir> <bit-count> <value>
  openocd_gowin_jtag_probe.sh bscan-dtmcs
  openocd_gowin_jtag_probe.sh bscan-dmi
  openocd_gowin_jtag_probe.sh bscan-fixed-dtmcs
  openocd_gowin_jtag_probe.sh bscan-fixed-dmi
  openocd_gowin_jtag_probe.sh bscan-constant-er1
  openocd_gowin_jtag_probe.sh bscan-constant-er2
  openocd_gowin_jtag_probe.sh server

Environment overrides:
  OPENOCD=/path/to/openocd
  OPENOCD_IFACE_CFG=/path/to/interface.cfg
  OPENOCD_ADAPTER_SPEED_KHZ=1000
  OPENOCD_EXPECTED_IDCODE=0x12345678

Notes:
  - Run with sudo if OpenOCD cannot open the FTDI device in WSL.
  - "led-on" and "led-on-er2" shift USER IR 0x43 then USER DR 0x0000003f.
  - "led-on-er1" shifts USER IR 0x42 then USER DR 0x0000003f.
  - "bscan-dtmcs" reads the PULP-style DTMCS DR on ER1 / IR 0x42.
  - "bscan-dmi" reads the PULP-style DMIACCESS DR on ER2 / IR 0x43.
  - "bscan-fixed-*" reads the direct GW_JTAG fixed-pattern TDO probe.
  - "bscan-constant-er1" expects all-zero readback; "bscan-constant-er2" expects all-one readback.
EOF
}

if [[ $# -lt 1 ]]; then
    usage >&2
    exit 1
fi

if [[ -n "${OPENOCD:-}" ]]; then
    OPENOCD_BIN="${OPENOCD}"
elif command -v openocd >/dev/null 2>&1; then
    OPENOCD_BIN="$(command -v openocd)"
elif [[ -x /opt/riscv/bin/openocd ]]; then
    OPENOCD_BIN=/opt/riscv/bin/openocd
else
    echo "error: openocd not found; set OPENOCD=/path/to/openocd" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENOCD_CFG="${SCRIPT_DIR}/openocd_gowin_jtag_probe.cfg"

mode="$1"
shift || true

openocd_args=(
    -f "${OPENOCD_CFG}"
)

case "${mode}" in
    scan)
        openocd_args+=(
            -c "init"
            -c "scan_chain"
            -c "exit"
        )
        ;;
    led-on|led-on-er2)
        openocd_args+=(
            -c "init"
            -c "scan_chain"
            -c "irscan gowin.fpga 0x43"
            -c "drscan gowin.fpga 32 0x0000003f"
            -c "exit"
        )
        ;;
    led-on-er1)
        openocd_args+=(
            -c "init"
            -c "scan_chain"
            -c "irscan gowin.fpga 0x42"
            -c "drscan gowin.fpga 32 0x0000003f"
            -c "exit"
        )
        ;;
    drscan)
        if [[ $# -ne 1 ]]; then
            echo "error: drscan requires one 32-bit value" >&2
            usage >&2
            exit 1
        fi
        openocd_args+=(
            -c "init"
            -c "scan_chain"
            -c "irscan gowin.fpga 0x43"
            -c "drscan gowin.fpga 32 $1"
            -c "exit"
        )
        ;;
    drscan-ir)
        if [[ $# -ne 2 ]]; then
            echo "error: drscan-ir requires an IR value and one 32-bit DR value" >&2
            usage >&2
            exit 1
        fi
        openocd_args+=(
            -c "init"
            -c "scan_chain"
            -c "irscan gowin.fpga $1"
            -c "drscan gowin.fpga 32 $2"
            -c "exit"
        )
        ;;
    drscan-bits-ir)
        if [[ $# -ne 3 ]]; then
            echo "error: drscan-bits-ir requires an IR value, bit count, and DR value" >&2
            usage >&2
            exit 1
        fi
        openocd_args+=(
            -c "init"
            -c "scan_chain"
            -c "irscan gowin.fpga $1"
            -c "drscan gowin.fpga $2 $3"
            -c "exit"
        )
        ;;
    bscan-dtmcs)
        openocd_args+=(
            -c "init"
            -c "scan_chain"
            -c "irscan gowin.fpga 0x42"
            -c "drscan gowin.fpga 32 0x00000000"
            -c "exit"
        )
        ;;
    bscan-dmi)
        openocd_args+=(
            -c "init"
            -c "scan_chain"
            -c "irscan gowin.fpga 0x43"
            -c "drscan gowin.fpga 41 0x00000000000"
            -c "exit"
        )
        ;;
    bscan-fixed-dtmcs)
        openocd_args+=(
            -c "init"
            -c "scan_chain"
            -c "irscan gowin.fpga 0x42"
            -c "drscan gowin.fpga 32 0x00000000"
            -c "exit"
        )
        ;;
    bscan-fixed-dmi)
        openocd_args+=(
            -c "init"
            -c "scan_chain"
            -c "irscan gowin.fpga 0x43"
            -c "drscan gowin.fpga 41 0x00000000000"
            -c "exit"
        )
        ;;
    bscan-constant-er1)
        openocd_args+=(
            -c "init"
            -c "scan_chain"
            -c "irscan gowin.fpga 0x42"
            -c "drscan gowin.fpga 32 0x00000000"
            -c "exit"
        )
        ;;
    bscan-constant-er2)
        openocd_args+=(
            -c "init"
            -c "scan_chain"
            -c "irscan gowin.fpga 0x43"
            -c "drscan gowin.fpga 32 0x00000000"
            -c "exit"
        )
        ;;
    server)
        openocd_args+=(
            -c "init"
        )
        ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        echo "error: unknown mode: ${mode}" >&2
        usage >&2
        exit 1
        ;;
esac

exec "${OPENOCD_BIN}" "${openocd_args[@]}"
