#!/usr/bin/env bash
# build_gowineda_jtag_diag.sh — Build the GW_JTAG sticky-signal diagnostic
# top for Tang Nano 9K with the Gowin EDA vendor flow.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TANGNANO9K_DIR="${SCRIPT_DIR}/.."

cd "${TANGNANO9K_DIR}/gowin"

GW_SH="${GW_SH:-gw_sh}"

echo "=== Gowin EDA: GW_JTAG sticky-signal diagnostic build ==="
"${GW_SH}" build_jtag_diag.tcl

echo ""
echo "=== Done: impl/pnr/jtag_diag_tangnano9k_top.fs ==="
