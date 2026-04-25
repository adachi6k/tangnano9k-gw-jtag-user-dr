module pulp_bscan_probe_tangnano9k_top (
    input  logic       clk,
    output logic [5:0] led
);

    localparam logic [31:0] DTMCS_CAPTURE_VALUE = 32'h00001071;
    localparam logic [40:0] DMI_CAPTURE_VALUE   = {7'h2a, 32'hcafe_babe, 2'b00};

    logic        jtck;
    logic        jreset;
    logic        jupdate;
    logic        jcapture;
    logic        jshift;
    logic        jtdi;
    logic        dtmcs_select;
    logic        dmi_select;
    logic [31:0] dtmcs_shreg;
    logic [40:0] dmi_shreg;
    logic        dtmcs_tdo;
    logic        dmi_tdo;

    logic seen_dtmcs_select;
    logic seen_dmi_select;
    logic seen_capture;
    logic seen_shift;
    logic seen_update;
    logic seen_tdi_high;

    dmi_jtag_tap u_gowin_bscan (
        .tck_i          (1'b0),
        .tms_i          (1'b0),
        .trst_ni        (1'b1),
        .td_i           (1'b0),
        .td_o           (),
        .tdo_oe_o       (),
        .testmode_i     (1'b0),
        .tck_o          (jtck),
        .dmi_clear_o    (jreset),
        .update_o       (jupdate),
        .capture_o      (jcapture),
        .shift_o        (jshift),
        .tdi_o          (jtdi),
        .dtmcs_select_o (dtmcs_select),
        .dtmcs_tdo_i    (dtmcs_tdo),
        .dmi_select_o   (dmi_select),
        .dmi_tdo_i      (dmi_tdo)
    );

    initial begin
        dtmcs_shreg       = DTMCS_CAPTURE_VALUE;
        dmi_shreg         = DMI_CAPTURE_VALUE;
        seen_dtmcs_select = 1'b0;
        seen_dmi_select   = 1'b0;
        seen_capture      = 1'b0;
        seen_shift        = 1'b0;
        seen_update       = 1'b0;
        seen_tdi_high     = 1'b0;
    end

    always_ff @(posedge jtck) begin
        if (dtmcs_select) begin
            seen_dtmcs_select <= 1'b1;
        end
        if (dmi_select) begin
            seen_dmi_select <= 1'b1;
        end
        if (jcapture) begin
            seen_capture <= 1'b1;
            dtmcs_shreg <= DTMCS_CAPTURE_VALUE;
            dmi_shreg   <= DMI_CAPTURE_VALUE;
        end
        if (jshift) begin
            seen_shift <= 1'b1;
            if (jtdi) begin
                seen_tdi_high <= 1'b1;
            end
            dtmcs_shreg <= {jtdi, dtmcs_shreg[31:1]};
            dmi_shreg   <= {jtdi, dmi_shreg[40:1]};
        end
        if (jupdate) begin
            dtmcs_shreg <= DTMCS_CAPTURE_VALUE;
            dmi_shreg   <= DMI_CAPTURE_VALUE;
            seen_update <= 1'b1;
        end
    end

    assign dtmcs_tdo = dtmcs_shreg[0];
    assign dmi_tdo   = dmi_shreg[0];

    assign led[0] = ~seen_dtmcs_select;
    assign led[1] = ~seen_dmi_select;
    assign led[2] = ~seen_capture;
    assign led[3] = ~seen_shift;
    assign led[4] = ~seen_update;
    assign led[5] = ~seen_tdi_high;

    logic unused_clk;
    assign unused_clk = clk;

endmodule
