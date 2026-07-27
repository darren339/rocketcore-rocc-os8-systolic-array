module os8_activation_unit #(
    parameter int W = 32
)(
    input  logic signed [W-1:0] in_data,
    input  logic                relu_enable,
    input  logic [4:0]          shift_amount,
    output logic signed [W-1:0] out_data
);

    logic signed [W-1:0] shifted;

    always_comb begin
        shifted = in_data >>> shift_amount;

        if (relu_enable && shifted[W-1])
            out_data = '0;
        else
            out_data = shifted;
    end

endmodule





