#!/usr/bin/env bash
# prog_gowineda_jtag_er1_diag.sh — Write the Gowin EDA-generated GW_JTAG
# ER1 diagnostic bitstream to a Tang Nano 9K via openFPGALoader.

set -euo pipefail
cd "$(dirname "$0")/.."

openFPGALoader -b tangnano9k gowin/impl/pnr/jtag_diag_er1_tangnano9k_top.fs
