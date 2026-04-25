# Tang Nano 9K GW_JTAG USER DR experiments

.PHONY: gowin-jtag-probe gowin-jtag-probe-prog
.PHONY: gowin-jtag-diag gowin-jtag-diag-prog
.PHONY: gowin-jtag-er1-probe gowin-jtag-er1-probe-prog
.PHONY: gowin-jtag-er1-diag gowin-jtag-er1-diag-prog
.PHONY: gowin-pulp-bscan-probe gowin-pulp-bscan-probe-prog
.PHONY: gowin-pulp-bscan-fixed-tdo gowin-pulp-bscan-fixed-tdo-prog
.PHONY: openocd-scan openocd-led-on openocd-led-on-er1 openocd-led-on-er2
.PHONY: openocd-bscan-dtmcs openocd-bscan-dmi openocd-bscan-fixed-dtmcs
.PHONY: openocd-bscan-fixed-dmi

gowin-jtag-probe:
	scripts/build_gowineda_jtag_probe.sh

gowin-jtag-probe-prog:
	scripts/prog_gowineda_jtag_probe.sh

gowin-jtag-diag:
	scripts/build_gowineda_jtag_diag.sh

gowin-jtag-diag-prog:
	scripts/prog_gowineda_jtag_diag.sh

gowin-jtag-er1-probe:
	scripts/build_gowineda_jtag_er1_probe.sh

gowin-jtag-er1-probe-prog:
	scripts/prog_gowineda_jtag_er1_probe.sh

gowin-jtag-er1-diag:
	scripts/build_gowineda_jtag_er1_diag.sh

gowin-jtag-er1-diag-prog:
	scripts/prog_gowineda_jtag_er1_diag.sh

gowin-pulp-bscan-probe:
	scripts/build_gowineda_pulp_bscan_probe.sh

gowin-pulp-bscan-probe-prog:
	scripts/prog_gowineda_pulp_bscan_probe.sh

gowin-pulp-bscan-fixed-tdo:
	scripts/build_gowineda_pulp_bscan_fixed_tdo.sh

gowin-pulp-bscan-fixed-tdo-prog:
	scripts/prog_gowineda_pulp_bscan_fixed_tdo.sh

openocd-scan:
	scripts/openocd_gowin_jtag_probe.sh scan

openocd-led-on:
	scripts/openocd_gowin_jtag_probe.sh led-on

openocd-led-on-er1:
	scripts/openocd_gowin_jtag_probe.sh led-on-er1

openocd-led-on-er2:
	scripts/openocd_gowin_jtag_probe.sh led-on-er2

openocd-bscan-dtmcs:
	scripts/openocd_gowin_jtag_probe.sh bscan-dtmcs

openocd-bscan-dmi:
	scripts/openocd_gowin_jtag_probe.sh bscan-dmi

openocd-bscan-fixed-dtmcs:
	scripts/openocd_gowin_jtag_probe.sh bscan-fixed-dtmcs

openocd-bscan-fixed-dmi:
	scripts/openocd_gowin_jtag_probe.sh bscan-fixed-dmi
