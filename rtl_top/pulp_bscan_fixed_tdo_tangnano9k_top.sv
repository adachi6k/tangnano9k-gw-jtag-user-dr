module pulp_bscan_fixed_tdo_tangnano9k_top (
    input  logic       clk,
    output logic [5:0] led
);

    localparam logic [31:0] DTMCS_PATTERN = 32'h00001071;
    localparam logic [40:0] DMI_PATTERN   = {7'h2a, 32'hcafe_babe, 2'b00};

    logic        jtck;
    logic        jtdi;
    logic        jreset;
    logic        jidle_er1;
    logic        jidle_er2;
    logic        jshift_capture;
    logic        jupdate;
    logic [31:0] dtmcs_shreg;
    logic [40:0] dmi_shreg;
    logic        dtmcs_tdo;
    logic        dmi_tdo;

    logic seen_shift;
    logic seen_update;
    logic seen_tdi_high;

    gowin_jtag_shim u_jtag (
        .jtck           (jtck),
        .jtdi           (jtdi),
        .jreset         (jreset),
        .jidle_er1      (jidle_er1),
        .jidle_er2      (jidle_er2),
        .jshift_capture (jshift_capture),
        .jupdate        (jupdate),
        .jen_er1        (),
        .jen_er2        (),
        .jtdo_er1       (dtmcs_tdo),
        .jtdo_er2       (dmi_tdo)
    );

    initial begin
        dtmcs_shreg   = DTMCS_PATTERN;
        dmi_shreg     = DMI_PATTERN;
        seen_shift    = 1'b0;
        seen_update   = 1'b0;
        seen_tdi_high = 1'b0;
    end

    always_ff @(posedge jtck or posedge jreset) begin
        if (jreset) begin
            dtmcs_shreg   <= DTMCS_PATTERN;
            dmi_shreg     <= DMI_PATTERN;
            seen_shift    <= 1'b0;
            seen_update   <= 1'b0;
            seen_tdi_high <= 1'b0;
        end else begin
            if (jshift_capture) begin
                seen_shift <= 1'b1;
                if (jtdi) begin
                    seen_tdi_high <= 1'b1;
                end
                dtmcs_shreg <= {jtdi, dtmcs_shreg[31:1]};
                dmi_shreg   <= {jtdi, dmi_shreg[40:1]};
            end
            if (jupdate) begin
                seen_update <= 1'b1;
            end
        end
    end

    assign dtmcs_tdo = dtmcs_shreg[0];
    assign dmi_tdo   = dmi_shreg[0];

    assign led[0] = ~dtmcs_shreg[0];
    assign led[1] = ~dmi_shreg[0];
    assign led[2] = ~seen_shift;
    assign led[3] = ~seen_update;
    assign led[4] = ~seen_tdi_high;
    assign led[5] = ~(jidle_er1 | jidle_er2);

    logic unused_clk;
    assign unused_clk = clk;

endmodule
