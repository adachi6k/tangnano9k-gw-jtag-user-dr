# build_jtag_diag.tcl — Batch synthesis and implementation for the
# GW_JTAG sticky-signal diagnostic top on Tang Nano 9K using Gowin EDA.

set_device GW1NR-LV9QN88PC6/I5 -device_version C

add_file -type verilog {synth_defines.vh}

set _fp [open {../rtl_jtag_diag.f} r]
foreach _line [split [read $_fp] "\n"] {
    set _line [string trim $_line]
    if {$_line eq "" || [string match "//*" $_line]} { continue }
    add_file -type verilog "../$_line"
}
close $_fp
unset _fp _line

add_file -type cst {../cst/jtag_user_reg_tangnano9k.cst}

set_option -synthesis_tool gowinsynthesis
set_option -top_module jtag_diag_tangnano9k_top
set_option -verilog_std sysv2017
set_option -multi_file_compilation_unit 1

run all

set _fs_src {impl/pnr/project.fs}
set _fs_dst {impl/pnr/jtag_diag_tangnano9k_top.fs}
if {[file exists $_fs_src]} {
    file rename -force $_fs_src $_fs_dst
    puts "Bitstream renamed: $_fs_dst"
}
unset _fs_src _fs_dst
