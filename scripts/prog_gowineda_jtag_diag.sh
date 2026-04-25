#!/usr/bin/env bash
# prog_gowineda_jtag_diag.sh — Write the Gowin EDA-generated GW_JTAG sticky-
# signal diagnostic bitstream to a Tang Nano 9K via openFPGALoader.
#
# Usage:  ./scripts/prog_gowineda_jtag_diag.sh

set -euo pipefail
cd "$(dirname "$0")/.."

openFPGALoader -b tangnano9k gowin/impl/pnr/jtag_diag_tangnano9k_top.fs
