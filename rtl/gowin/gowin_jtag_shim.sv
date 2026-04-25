module gowin_jtag_shim (
    output wire jtck,
    output wire jtdi,
    output wire jreset,
    output wire jidle_er1,
    output wire jidle_er2,
    output wire jshift_capture,
    output wire jupdate,
    output wire jen_er1,
    output wire jen_er2,
    input  wire jtdo_er1,
    input  wire jtdo_er2
);

    /* verilator lint_off PINCONNECTEMPTY */
    GW_JTAG u_gw_jtag (
        .tck_pad_i             (),
        .tms_pad_i             (),
        .tdi_pad_i             (),
        .tdo_pad_o             (),
        .tck_o                 (jtck),
        .tdi_o                 (jtdi),
        .test_logic_reset_o    (jreset),
        .run_test_idle_er1_o   (jidle_er1),
        .run_test_idle_er2_o   (jidle_er2),
        .shift_dr_capture_dr_o (jshift_capture),
        .pause_dr_o            (),
        .update_dr_o           (jupdate),
        .enable_er1_o          (jen_er1),
        .enable_er2_o          (jen_er2),
        .tdo_er1_i             (jtdo_er1),
        .tdo_er2_i             (jtdo_er2)
    );
    /* verilator lint_on PINCONNECTEMPTY */

endmodule
