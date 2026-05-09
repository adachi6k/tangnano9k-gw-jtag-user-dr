module pulp_bscan_signal_tdo_primer_top (
    output logic [1:0] probe_o
);

    logic jtck;
    logic jtdi;
    logic jreset;
    logic jidle_er1;
    logic jidle_er2;
    logic jshift_capture;
    logic jupdate;
    logic jen_er1;
    logic jen_er2;

    gowin_jtag_shim u_jtag (
        .jtck           (jtck),
        .jtdi           (jtdi),
        .jreset         (jreset),
        .jidle_er1      (jidle_er1),
        .jidle_er2      (jidle_er2),
        .jshift_capture (jshift_capture),
        .jupdate        (jupdate),
        .jen_er1        (jen_er1),
        .jen_er2        (jen_er2),
        .jtdo_er1       (jshift_capture),
        .jtdo_er2       (jtdi)
    );

    assign probe_o = {jen_er2 | jidle_er2, jen_er1 | jidle_er1};

    logic unused_jtag;
    assign unused_jtag = jtck ^ jreset ^ jupdate;

endmodule
