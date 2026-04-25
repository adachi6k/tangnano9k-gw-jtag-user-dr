module pulp_bscan_constant_tdo_tangnano9k_top (
    input  logic       clk,
    output logic [5:0] led
);

    logic jtck;
    logic jtdi;
    logic jreset;
    logic jidle_er1;
    logic jidle_er2;
    logic jshift_capture;
    logic jupdate;

    logic seen_tck;
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
        .jtdo_er1       (1'b0),
        .jtdo_er2       (1'b1)
    );

    initial begin
        seen_tck      = 1'b0;
        seen_shift    = 1'b0;
        seen_update   = 1'b0;
        seen_tdi_high = 1'b0;
    end

    always_ff @(posedge jtck or posedge jreset) begin
        if (jreset) begin
            seen_tck      <= 1'b0;
            seen_shift    <= 1'b0;
            seen_update   <= 1'b0;
            seen_tdi_high <= 1'b0;
        end else begin
            seen_tck <= 1'b1;
            if (jshift_capture) begin
                seen_shift <= 1'b1;
                if (jtdi) begin
                    seen_tdi_high <= 1'b1;
                end
            end
            if (jupdate) begin
                seen_update <= 1'b1;
            end
        end
    end

    assign led[0] = ~seen_tck;
    assign led[1] = ~seen_shift;
    assign led[2] = ~seen_update;
    assign led[3] = ~seen_tdi_high;
    assign led[4] = ~jidle_er1;
    assign led[5] = ~jidle_er2;

    logic unused_clk;
    assign unused_clk = clk;

endmodule
