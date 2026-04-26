// SPDX-License-Identifier: SHL-0.51
// Copyright (c) 2026 adachi6k
//
// Gowin GW_JTAG-backed replacement for PULP riscv-dbg dmi_jtag.
//
// This module keeps the PULP dmi_jtag pin shape, reuses PULP dmi_cdc, and
// implements DTMCS/DMIACCESS directly on Tang Nano 9K GW_JTAG USER chains:
//
//   ER1 / USER1 / IR 0x42 -> DTMCS
//   ER2 / USER2 / IR 0x43 -> DMIACCESS
//
// The separate dmi_jtag_tap adapter (experiments/adapter_probe/gowin_dmi_bscan_tap.sv)
// is useful for probes, but Tang Nano 9K hardware does not expose enough
// BSCANE2-like phase information for a fully transparent PULP TAP replacement.
// In particular, ER2 update/enable behavior
// is not reliable for DMIACCESS, so this full bridge treats completion of a
// 41-bit USER DR shift as the DMI update point.

module dmi_jtag #(
    parameter logic [31:0] IdcodeValue = 32'h0000_0DB3
) (
    input  logic         clk_i,
    input  logic         rst_ni,
    input  logic         testmode_i,

    output logic         dmi_rst_no,
    output dm::dmi_req_t dmi_req_o,
    output logic         dmi_req_valid_o,
    input  logic         dmi_req_ready_i,

    input  dm::dmi_resp_t dmi_resp_i,
    output logic          dmi_resp_ready_o,
    input  logic          dmi_resp_valid_i,

    input  logic         tck_i,
    input  logic         tms_i,
    input  logic         trst_ni,
    input  logic         td_i,
    output logic         td_o,
    output logic         tdo_oe_o
);

    typedef enum logic [1:0] {
        DMINoError = 2'h0,
        DMIReservedError = 2'h1,
        DMIOPFailed = 2'h2,
        DMIBusy = 2'h3
    } dmi_error_e;

    typedef enum logic [2:0] {
        Idle,
        Read,
        WaitReadValid,
        Write,
        WaitWriteValid
    } state_e;

    localparam int unsigned DmiOpStatusWidth = 2;
    localparam int unsigned DmiDataWidth = 32;
    localparam int unsigned DmiAddressWidth = 7;
    localparam int unsigned DmiOpStatusLsb = 0;
    localparam int unsigned DmiOpStatusMsb =
        DmiOpStatusLsb + DmiOpStatusWidth - 1;
    localparam int unsigned DmiDataLsb = DmiOpStatusMsb + 1;
    localparam int unsigned DmiDataMsb = DmiDataLsb + DmiDataWidth - 1;
    localparam int unsigned DmiAddressLsb = DmiDataMsb + 1;
    localparam int unsigned DmiAddressMsb =
        DmiAddressLsb + DmiAddressWidth - 1;
    localparam int unsigned DmiWidth = DmiAddressMsb + 1;

    logic jtck;
    logic jtdi;
    logic jreset;
    logic jidle_er1;
    logic jidle_er2;
    logic jshift_capture;
    logic jshift_capture_q;
    logic jshift_done;
    logic jupdate;
    logic jtag_update;
    logic jen_er1;
    logic jen_er2;
    logic dtmcs_tdo;
    logic dmi_tdo;

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
        .jtdo_er1       (dtmcs_tdo),
        .jtdo_er2       (dmi_tdo)
    );

    logic dtmcs_selected;
    logic dmi_selected;
    logic er1_active;
    logic er2_active;
    logic dtmcs_select;
    logic dmi_select;

    assign jshift_done = ~jshift_capture & jshift_capture_q;
    assign jtag_update = jupdate | jshift_done;
    assign er1_active = jen_er1 | jidle_er1;
    assign er2_active = jen_er2 | jidle_er2;
    assign dtmcs_select = er1_active | (dtmcs_selected & ~er2_active);
    assign dmi_select = er2_active | (dmi_selected & ~er1_active);

    logic [31:0] dtmcs_dr_q;
    dmi_error_e error_q;
    dmi_error_e next_error;
    logic [31:0] dtmcs_read;
    logic dtmcs_hard_reset_req;
    logic dtmcs_error_reset_req;
    logic dmi_clear;

    assign dtmcs_read = {
        14'b0,
        1'b0,
        1'b0,
        1'b0,
        3'd1,
        error_q,
        6'd7,
        4'd1
    };

    assign dtmcs_tdo = dtmcs_dr_q[0];
    assign dtmcs_hard_reset_req = dtmcs_select & jtag_update & dtmcs_dr_q[17];
    assign dtmcs_error_reset_req = dtmcs_select & jtag_update & dtmcs_dr_q[16];
    assign dmi_clear = dtmcs_hard_reset_req;

    always_ff @(posedge jtck or negedge trst_ni) begin
        if (!trst_ni) begin
            jshift_capture_q <= 1'b0;
            dtmcs_selected <= 1'b0;
            dmi_selected <= 1'b0;
        end else begin
            jshift_capture_q <= jshift_capture;
            if (er1_active) begin
                dtmcs_selected <= 1'b1;
                dmi_selected <= 1'b0;
            end else if (er2_active) begin
                dtmcs_selected <= 1'b0;
                dmi_selected <= 1'b1;
            end
        end
    end

    always_ff @(posedge jtck or negedge trst_ni) begin
        if (!trst_ni) begin
            dtmcs_dr_q <= '0;
        end else if (dmi_clear) begin
            dtmcs_dr_q <= '0;
        end else if (dtmcs_select & ~jshift_capture & ~jupdate) begin
            dtmcs_dr_q <= dtmcs_read;
        end else if (dtmcs_select & jshift_capture) begin
            dtmcs_dr_q <= {jtdi, dtmcs_dr_q[31:1]};
        end
    end

    state_e state_q;
    state_e next_state;
    logic [DmiWidth-1:0] dmi_dr_q;
    logic [DmiAddressWidth-1:0] address_q;
    logic [DmiAddressWidth-1:0] next_address;
    logic [DmiDataWidth-1:0] data_q;
    logic [DmiDataWidth-1:0] next_data;
    dmi_error_e capture_status;
    dm::dmi_req_t jtag_dmi_req;
    dm::dmi_resp_t jtag_dmi_resp;
    logic jtag_dmi_req_valid;
    logic jtag_dmi_req_ready;
    logic jtag_dmi_resp_valid;
    logic jtag_dmi_resp_ready;
    logic [31:0] response_data;
    dmi_error_e response_status;
    logic [5:0] dmi_shift_count_q;
    logic dmi_update;
    logic dmi_resp_pending_q;
    dm::dtm_op_e dmi_update_op;

    assign capture_status = (state_q == Idle) ? error_q : DMIBusy;
    assign dmi_tdo = dmi_dr_q[0];
    assign dmi_update = jtag_update & (dmi_shift_count_q >= 6'(DmiWidth));
    assign dmi_update_op =
        dm::dtm_op_e'(dmi_dr_q[DmiOpStatusMsb:DmiOpStatusLsb]);

    always_comb begin
        response_data = data_q;
        response_status = DMINoError;
        unique case (jtag_dmi_resp.resp)
            dm::DTM_SUCCESS: begin
                if (state_q == WaitReadValid) begin
                    response_data = jtag_dmi_resp.data;
                end
            end
            dm::DTM_ERR: begin
                response_data = 32'hDEAD_BEEF;
                response_status = DMIOPFailed;
            end
            dm::DTM_BUSY: begin
                response_data = 32'hB051_B051;
                response_status = DMIBusy;
            end
            default: begin
                response_data = 32'hBAAD_C0DE;
                response_status = DMIOPFailed;
            end
        endcase
    end

    always_ff @(posedge jtck or negedge trst_ni) begin
        if (!trst_ni) begin
            dmi_shift_count_q <= '0;
        end else if (dmi_clear | jtag_update) begin
            dmi_shift_count_q <= '0;
        end else if (jshift_capture &&
                     (dmi_shift_count_q < 6'(DmiWidth))) begin
            dmi_shift_count_q <= dmi_shift_count_q + 6'd1;
        end
    end

    always_ff @(posedge jtck or negedge trst_ni) begin
        if (!trst_ni) begin
            dmi_dr_q <= '0;
        end else if (dmi_clear) begin
            dmi_dr_q <= '0;
        end else if (dmi_update) begin
            dmi_dr_q <= {
                dmi_dr_q[DmiAddressMsb:DmiAddressLsb],
                dmi_dr_q[DmiDataMsb:DmiDataLsb],
                DMINoError
            };
        end else if (jshift_capture) begin
            dmi_dr_q <= {jtdi, dmi_dr_q[DmiWidth-1:1]};
        end else if (dmi_resp_pending_q & jtag_dmi_resp_valid) begin
            dmi_dr_q <= {address_q, response_data, response_status};
        end else if (~jtag_update) begin
            dmi_dr_q <= {address_q, data_q, capture_status};
        end
    end

    always_ff @(posedge jtck or negedge trst_ni) begin
        if (!trst_ni) begin
            dmi_resp_pending_q <= 1'b0;
        end else if (dmi_clear) begin
            dmi_resp_pending_q <= 1'b0;
        end else if (dmi_update & (state_q == Idle) &
                     (error_q == DMINoError)) begin
            dmi_resp_pending_q <= (dmi_update_op == dm::DTM_READ) |
                                  (dmi_update_op == dm::DTM_WRITE);
        end else if (dmi_resp_pending_q & jtag_dmi_resp_valid) begin
            dmi_resp_pending_q <= 1'b0;
        end
    end

    always_comb begin
        next_state = state_q;
        next_address = address_q;
        next_data = data_q;
        next_error = error_q;
        jtag_dmi_req_valid = 1'b0;

        if (dmi_clear) begin
            next_state = Idle;
            next_address = '0;
            next_data = '0;
            next_error = DMINoError;
        end else begin
            unique case (state_q)
                Idle: begin
                    if (dmi_update & (error_q == DMINoError)) begin
                        next_address =
                            dmi_dr_q[DmiAddressMsb:DmiAddressLsb];
                        next_data = dmi_dr_q[DmiDataMsb:DmiDataLsb];
                        unique case (dmi_update_op)
                            dm::DTM_READ: next_state = Read;
                            dm::DTM_WRITE: next_state = Write;
                            default: next_state = Idle;
                        endcase
                    end
                end

                Read: begin
                    jtag_dmi_req_valid = 1'b1;
                    if (jtag_dmi_req_ready) begin
                        next_state = WaitReadValid;
                    end
                end

                WaitReadValid: begin
                    if (jtag_dmi_resp_valid) begin
                        unique case (jtag_dmi_resp.resp)
                            dm::DTM_SUCCESS: begin
                                next_data = jtag_dmi_resp.data;
                            end
                            dm::DTM_ERR: begin
                                next_data = 32'hDEAD_BEEF;
                                if (error_q == DMINoError) begin
                                    next_error = DMIOPFailed;
                                end
                            end
                            dm::DTM_BUSY: begin
                                next_data = 32'hB051_B051;
                                if (error_q == DMINoError) begin
                                    next_error = DMIBusy;
                                end
                            end
                            default: begin
                                next_data = 32'hBAAD_C0DE;
                            end
                        endcase
                        next_state = Idle;
                    end
                end

                Write: begin
                    jtag_dmi_req_valid = 1'b1;
                    if (jtag_dmi_req_ready) begin
                        next_state = WaitWriteValid;
                    end
                end

                WaitWriteValid: begin
                    if (jtag_dmi_resp_valid) begin
                        unique case (jtag_dmi_resp.resp)
                            dm::DTM_ERR: begin
                                if (error_q == DMINoError) begin
                                    next_error = DMIOPFailed;
                                end
                            end
                            dm::DTM_BUSY: begin
                                if (error_q == DMINoError) begin
                                    next_error = DMIBusy;
                                end
                            end
                            default: begin
                            end
                        endcase
                        next_state = Idle;
                    end
                end

                default: begin
                    next_state = Idle;
                end
            endcase

            if (dmi_update & (state_q != Idle) &
                (error_q == DMINoError)) begin
                next_error = DMIBusy;
            end

            if (dtmcs_error_reset_req) begin
                next_error = DMINoError;
            end

        end
    end

    always_ff @(posedge jtck or negedge trst_ni) begin
        if (!trst_ni) begin
            state_q <= Idle;
            address_q <= '0;
            data_q <= '0;
            error_q <= DMINoError;
        end else if (dmi_clear) begin
            state_q <= Idle;
            address_q <= '0;
            data_q <= '0;
            error_q <= DMINoError;
        end else begin
            state_q <= next_state;
            address_q <= next_address;
            data_q <= next_data;
            error_q <= next_error;
        end
    end

    assign jtag_dmi_req.addr = address_q;
    assign jtag_dmi_req.data = data_q;
    assign jtag_dmi_req.op = (state_q == Write) ? dm::DTM_WRITE : dm::DTM_READ;
    assign jtag_dmi_resp_ready = 1'b1;

    dmi_cdc i_dmi_cdc (
        .tck_i                (jtck),
        .trst_ni              (trst_ni),
        .jtag_dmi_req_i       (jtag_dmi_req),
        .jtag_dmi_ready_o     (jtag_dmi_req_ready),
        .jtag_dmi_valid_i     (jtag_dmi_req_valid),
        .jtag_dmi_cdc_clear_i (dmi_clear),
        .jtag_dmi_resp_o      (jtag_dmi_resp),
        .jtag_dmi_valid_o     (jtag_dmi_resp_valid),
        .jtag_dmi_ready_i     (jtag_dmi_resp_ready),
        .clk_i                (clk_i),
        .rst_ni               (rst_ni),
        .core_dmi_rst_no      (dmi_rst_no),
        .core_dmi_req_o       (dmi_req_o),
        .core_dmi_valid_o     (dmi_req_valid_o),
        .core_dmi_ready_i     (dmi_req_ready_i),
        .core_dmi_resp_i      (dmi_resp_i),
        .core_dmi_ready_o     (dmi_resp_ready_o),
        .core_dmi_valid_i     (dmi_resp_valid_i)
    );

    assign td_o = 1'b0;
    assign tdo_oe_o = 1'b0;

    logic [6:0] unused_compat;
    assign unused_compat = {
        tck_i,
        tms_i,
        td_i,
        testmode_i,
        jreset,
        jidle_er1 ^ jidle_er2,
        ^IdcodeValue
    };

endmodule
