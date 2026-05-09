module pulp_bscan_constant_tdo_primer_top #(
    parameter logic ER1_TDO = 1'b0,
    parameter logic ER2_TDO = 1'b1
) (
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
        .jtdo_er1       (ER1_TDO),
        .jtdo_er2       (ER2_TDO)
    );

    assign probe_o = {jen_er2 | jidle_er2, jen_er1 | jidle_er1};

    logic unused_jtag;
    assign unused_jtag = jtck ^ jtdi ^ jreset ^ jshift_capture ^ jupdate;

endmodule
