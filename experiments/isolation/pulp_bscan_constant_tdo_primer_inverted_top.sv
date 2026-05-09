module pulp_bscan_constant_tdo_primer_inverted_top (
    output logic [1:0] probe_o
);

    pulp_bscan_constant_tdo_primer_top #(
        .ER1_TDO (1'b1),
        .ER2_TDO (1'b0)
    ) u_top (
        .probe_o (probe_o)
    );

endmodule
