module dmi_jtag_tap #(
    parameter int unsigned IrLength = 8,
    parameter logic [31:0] IdcodeValue = 32'h1100481b
) (
    input  logic tck_i,
    input  logic tms_i,
    input  logic trst_ni,
    input  logic td_i,
    output logic td_o,
    output logic tdo_oe_o,
    input  logic testmode_i,

    output logic tck_o,
    output logic dmi_clear_o,
    output logic update_o,
    output logic capture_o,
    output logic shift_o,
    output logic tdi_o,
    output logic dtmcs_select_o,
    input  logic dtmcs_tdo_i,
    output logic dmi_select_o,
    input  logic dmi_tdo_i
);

    logic jtck;
    logic jtdi;
    logic jreset;
    logic jidle_er1;
    logic jidle_er2;
    logic jshift_capture;
    logic jshift_capture_q;
    logic jupdate;
    logic jen_er1;
    logic jen_er2;
    logic dtmcs_selected;
    logic dmi_selected;

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
        .jtdo_er1       (dtmcs_tdo_i),
        .jtdo_er2       (dmi_tdo_i)
    );

    always_ff @(posedge jtck or posedge jreset) begin
        if (jreset) begin
            jshift_capture_q <= 1'b0;
            dtmcs_selected   <= 1'b0;
            dmi_selected     <= 1'b0;
        end else begin
            jshift_capture_q <= jshift_capture;
            if (jen_er1) begin
                dtmcs_selected <= 1'b1;
                dmi_selected   <= 1'b0;
            end else if (jen_er2) begin
                dtmcs_selected <= 1'b0;
                dmi_selected   <= 1'b1;
            end
        end
    end

    assign tck_o          = jtck;
    assign dmi_clear_o    = jreset;
    assign update_o       = jupdate;
    assign capture_o      = jshift_capture & ~jshift_capture_q;
    assign shift_o        = jshift_capture & jshift_capture_q;
    assign tdi_o          = jtdi;
    assign dtmcs_select_o = jen_er1 | (dtmcs_selected & ~jen_er2);
    assign dmi_select_o   = jen_er2 | (dmi_selected & ~jen_er1);

    assign td_o      = 1'b0;
    assign tdo_oe_o  = 1'b0;

    logic [5:0] unused_compat;
    assign unused_compat = {
        tck_i,
        tms_i,
        trst_ni,
        td_i,
        testmode_i,
        jidle_er1 ^ jidle_er2
    };

    logic unused_idcode;
    assign unused_idcode = ^IdcodeValue;

    logic unused_irlength;
    assign unused_irlength = |IrLength;

endmodule
