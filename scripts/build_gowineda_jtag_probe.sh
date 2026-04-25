#!/usr/bin/env bash
# build_gowineda_jtag_probe.sh — Build the GW_JTAG USER DR probe bitstream
# for Tang Nano 9K with the Gowin EDA vendor flow.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TANGNANO9K_DIR="${SCRIPT_DIR}/.."

cd "${TANGNANO9K_DIR}/gowin"

GW_SH="${GW_SH:-gw_sh}"

echo "=== Gowin EDA: GW_JTAG USER DR probe build ==="
"${GW_SH}" build_jtag_probe.tcl

echo ""
echo "=== Done: impl/pnr/jtag_user_reg_tangnano9k_top.fs ==="
