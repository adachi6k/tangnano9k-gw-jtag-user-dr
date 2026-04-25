module jtag_diag_tangnano9k_top (
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
    logic seen_reset;
    logic seen_idle_er2;
    logic seen_shift_capture;
    logic seen_update;
    logic seen_tdi_high;

    /* verilator lint_off PINCONNECTEMPTY */
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
    /* verilator lint_on PINCONNECTEMPTY */

    initial begin
        seen_tck           = 1'b0;
        seen_reset         = 1'b0;
        seen_idle_er2      = 1'b0;
        seen_shift_capture = 1'b0;
        seen_update        = 1'b0;
        seen_tdi_high      = 1'b0;
    end

    always_ff @(posedge jtck) begin
        seen_tck <= 1'b1;
        if (jidle_er2) begin
            seen_idle_er2 <= 1'b1;
        end
        if (jshift_capture) begin
            seen_shift_capture <= 1'b1;
            if (jtdi) begin
                seen_tdi_high <= 1'b1;
            end
        end
    end

    always_ff @(posedge jupdate) begin
        seen_update <= 1'b1;
    end

    always_ff @(posedge jreset) begin
        seen_reset <= 1'b1;
    end

    assign led[0] = ~seen_tck;
    assign led[1] = ~seen_reset;
    assign led[2] = ~seen_idle_er2;
    assign led[3] = ~seen_shift_capture;
    assign led[4] = ~seen_update;
    assign led[5] = ~seen_tdi_high;

    logic unused_clk;
    assign unused_clk = clk;

    logic unused_idle_er1;
    assign unused_idle_er1 = jidle_er1;

endmodule
