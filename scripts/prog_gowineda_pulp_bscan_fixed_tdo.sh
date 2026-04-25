#!/usr/bin/env bash
# prog_gowineda_pulp_bscan_fixed_tdo.sh — Write the Gowin EDA-generated
# PULP-style fixed TDO probe bitstream to a Tang Nano 9K via openFPGALoader.

set -euo pipefail
cd "$(dirname "$0")/.."

openFPGALoader -b tangnano9k gowin/impl/pnr/pulp_bscan_fixed_tdo_tangnano9k_top.fs
