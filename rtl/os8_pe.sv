module os8_pe #(
    parameter int W_IN  = 8,
    parameter int W_ACC = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,

    input  logic                    en,
    input  logic                    clear,
    input  logic                    prop_sel,

    input  logic                    prop_shift,

    input  logic signed [W_IN-1:0]  a_in,
    input  logic signed [W_IN-1:0]  b_in,

    input  logic [W_ACC-1:0]        prop_sum_in,
    input  logic [W_ACC-1:0]        prop_carry_in,

    output logic [W_ACC-1:0]        prop_sum_out,
    output logic [W_ACC-1:0]        prop_carry_out
);

    logic signed [(2*W_IN)-1:0] product_small;
    logic signed [W_ACC-1:0]    product_ext;
    logic signed [W_ACC-1:0]    product_reg;

    logic signed [(2*W_IN)-1:0] product_small_pipe;

    logic [W_ACC-1:0] c1_sum_reg;
    logic [W_ACC-1:0] c1_carry_reg;

    logic [W_ACC-1:0] c2_sum_reg;
    logic [W_ACC-1:0] c2_carry_reg;

    logic [W_ACC-1:0] c1_next_sum;
    logic [W_ACC-1:0] c1_next_carry;

    logic [W_ACC-1:0] c2_next_sum;
    logic [W_ACC-1:0] c2_next_carry;

    assign product_small = a_in * b_in;
    assign product_ext = {
        {(W_ACC-(2*W_IN)){product_small_pipe[(2*W_IN)-1]}},
        product_small_pipe
    };
    always_comb begin
        c1_next_sum   = c1_sum_reg ^ c1_carry_reg ^ product_reg;
        c1_next_carry = ((c1_sum_reg   & c1_carry_reg) |
                         (c1_sum_reg   & product_reg)  |
                         (c1_carry_reg & product_reg)) << 1;
    end
    always_comb begin
        c2_next_sum   = c2_sum_reg ^ c2_carry_reg ^ product_reg;
        c2_next_carry = ((c2_sum_reg   & c2_carry_reg) |
                         (c2_sum_reg   & product_reg)  |
                         (c2_carry_reg & product_reg)) << 1;
    end
    always_comb begin
        if (prop_sel) begin
            prop_sum_out   = c1_sum_reg;
            prop_carry_out = c1_carry_reg;
        end else begin
            prop_sum_out   = c2_sum_reg;
            prop_carry_out = c2_carry_reg;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_small_pipe <= '0;
            product_reg        <= '0;
            c1_sum_reg         <= '0;
            c1_carry_reg       <= '0;
            c2_sum_reg         <= '0;
            c2_carry_reg       <= '0;
        end else if (clear) begin
            product_small_pipe <= '0;
            product_reg        <= '0;
            c1_sum_reg         <= '0;
            c1_carry_reg       <= '0;
            c2_sum_reg         <= '0;
            c2_carry_reg       <= '0;
        end else begin
            product_small_pipe <= product_small;
            if (en) begin
                 product_reg <= product_ext;

                if (!prop_sel) begin
                    c1_sum_reg   <= c1_next_sum;
                    c1_carry_reg <= c1_next_carry;
                end else begin
                    c2_sum_reg   <= c2_next_sum;
                    c2_carry_reg <= c2_next_carry;
                end
            end
            if (prop_shift) begin
                if (prop_sel) begin
                    c1_sum_reg   <= prop_sum_in;
                    c1_carry_reg <= prop_carry_in;
                end else begin
                    c2_sum_reg   <= prop_sum_in;
                    c2_carry_reg <= prop_carry_in;
                end
            end
        end
    end

endmodule
