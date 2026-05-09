# build_pulp_bscan_fixed_tdo_primer25k.tcl

set_device -name GW5A-25A GW5A-LV25MG121NC1/I0

add_file -type verilog {synth_defines.vh}

set _fp [open {../filelists/rtl_pulp_bscan_fixed_tdo_portless.f} r]
foreach _line [split [read $_fp] "\n"] {
    set _line [string trim $_line]
    if {$_line eq "" || [string match "//*" $_line]} { continue }
    add_file -type verilog "../$_line"
}
close $_fp
unset _fp _line

add_file -type cst {../cst/pulp_bscan_fixed_tdo_primer25k.cst}

set_option -synthesis_tool gowinsynthesis
set_option -top_module pulp_bscan_fixed_tdo_portless_top
set_option -verilog_std sysv2017
set_option -multi_file_compilation_unit 1

run all

set _fs_src {impl/pnr/project.fs}
set _fs_dst {impl/pnr/pulp_bscan_fixed_tdo_primer25k.fs}
if {[file exists $_fs_src]} {
    file rename -force $_fs_src $_fs_dst
    puts "Bitstream renamed: $_fs_dst"
}
unset _fs_src _fs_dst
