module jtag_user_reg_tangnano9k_top (
    input  logic       clk,
    output logic [5:0] led
);

    logic        jtck;
    logic        jtdi;
    logic        jreset;
    logic        jidle_er1;
    logic        jidle_er2;
    logic        jshift_capture;
    logic        jupdate;
    logic [31:0] shreg;
    logic        jtdo;

    initial begin
        shreg = 32'h0;
    end

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
        .jtdo_er2       (jtdo)
    );
    /* verilator lint_on PINCONNECTEMPTY */

    always_ff @(posedge jtck) begin
        if (jshift_capture) begin
            shreg <= {jtdi, shreg[31:1]};
        end
    end

    assign jtdo = shreg[0];
    assign led  = ~shreg[5:0];

    logic unused_clk;
    assign unused_clk = clk;

    logic [1:0] unused_idle;
    assign unused_idle = {jidle_er1, jidle_er2};

    logic [1:0] unused_jtag_ctrl;
    assign unused_jtag_ctrl = {jreset, jupdate};

endmodule
