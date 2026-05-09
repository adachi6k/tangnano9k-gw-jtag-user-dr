module pulp_bscan_fixed_tdo_portless_top (
    output logic [1:0] probe_o
);

    localparam logic [31:0] DTMCS_PATTERN = 32'h00001071;
    localparam logic [40:0] DMI_PATTERN   = 41'h0ab2bfaeaf8;

    logic jtck;
    logic jtdi;
    logic jreset;
    logic jshift_capture;
    logic jupdate;
    logic dtmcs_tdo;
    logic dmi_tdo;
    logic jshift_capture_q;

    logic [31:0] dtmcs_shreg;
    logic [40:0] dmi_shreg;

    initial begin
        dtmcs_shreg = DTMCS_PATTERN;
        dmi_shreg   = DMI_PATTERN;
        jshift_capture_q = 1'b0;
    end

    gowin_jtag_shim u_jtag (
        .jtck           (jtck),
        .jtdi           (jtdi),
        .jreset         (jreset),
        .jidle_er1      (),
        .jidle_er2      (),
        .jshift_capture (jshift_capture),
        .jupdate        (jupdate),
        .jen_er1        (),
        .jen_er2        (),
        .jtdo_er1       (dtmcs_tdo),
        .jtdo_er2       (dmi_tdo)
    );

    always_ff @(posedge jtck) begin
        jshift_capture_q <= jshift_capture;

        if (jshift_capture && !jshift_capture_q) begin
            dtmcs_shreg <= {1'b0, DTMCS_PATTERN[31:1]};
            dmi_shreg   <= {1'b0, DMI_PATTERN[40:1]};
        end else if (jshift_capture) begin
            dtmcs_shreg <= {jtdi, dtmcs_shreg[31:1]};
            dmi_shreg   <= {jtdi, dmi_shreg[40:1]};
        end
        if (jupdate) begin
            jshift_capture_q <= 1'b0;
        end
    end

    assign dtmcs_tdo = (jshift_capture && !jshift_capture_q) ? DTMCS_PATTERN[0] : dtmcs_shreg[0];
    assign dmi_tdo   = (jshift_capture && !jshift_capture_q) ? DMI_PATTERN[0] : dmi_shreg[0];
    assign probe_o   = {dmi_shreg[0], dtmcs_shreg[0]};

    logic unused_jreset;
    assign unused_jreset = jreset;

endmodule
