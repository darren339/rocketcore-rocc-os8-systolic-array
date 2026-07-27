module os8_final_cpa #(
    parameter int W_ACC = 32
)(
    input  logic [W_ACC-1:0]        sum_in,
    input  logic [W_ACC-1:0]        carry_in,

    output logic signed [W_ACC-1:0] result_out
);

    assign result_out = $signed(sum_in + carry_in);

endmodule




