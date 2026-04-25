#!/usr/bin/env bash
# prog_gowineda_jtag_probe.sh — Write the Gowin EDA-generated GW_JTAG USER DR
#                               probe bitstream to a Tang Nano 9K via
#                               openFPGALoader.
#
# Build the bitstream first with build_gowineda_jtag_probe.sh.
#
# Usage:  ./scripts/prog_gowineda_jtag_probe.sh

set -euo pipefail
cd "$(dirname "$0")/.."

openFPGALoader -b tangnano9k gowin/impl/pnr/jtag_user_reg_tangnano9k_top.fs
