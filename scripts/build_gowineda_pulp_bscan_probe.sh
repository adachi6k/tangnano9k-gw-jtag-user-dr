#!/usr/bin/env bash
# build_gowineda_pulp_bscan_probe.sh — Build the PULP-style GW_JTAG BSCAN
# probe bitstream for Tang Nano 9K with the Gowin EDA vendor flow.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TANGNANO9K_DIR="${SCRIPT_DIR}/.."

cd "${TANGNANO9K_DIR}/gowin"

GW_SH="${GW_SH:-gw_sh}"

echo "=== Gowin EDA: PULP-style GW_JTAG BSCAN probe build ==="
"${GW_SH}" build_pulp_bscan_probe.tcl

echo ""
echo "=== Done: impl/pnr/pulp_bscan_probe_tangnano9k_top.fs ==="
