#!/usr/bin/env bash
# prog_gowineda_pulp_bscan_constant_tdo.sh — Write the Gowin EDA-generated
# constant TDO probe bitstream to a Tang Nano 9K via openFPGALoader.

set -euo pipefail
cd "$(dirname "$0")/.."

openFPGALoader -b tangnano9k gowin/impl/pnr/pulp_bscan_constant_tdo_tangnano9k_top.fs
