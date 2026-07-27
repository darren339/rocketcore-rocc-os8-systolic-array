module os8_pe_mesh #(
    parameter int N    = 8,
    parameter int W    = 8,
    parameter int ACCW = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,

    input  logic                    en,
    input  logic                    clear,

    input  logic                    prop_sel,
    input  logic                    prop_shift,

    input  logic signed [W-1:0]     a_left [0:N-1],
    input  logic signed [W-1:0]     b_top  [0:N-1],

    output logic [ACCW-1:0]         bottom_sum   [0:N-1],
    output logic [ACCW-1:0]         bottom_carry [0:N-1]
);

    logic en_q;
    logic clear_q;

    logic signed [W-1:0] a_pipe [0:N-1][0:N-1];
    logic signed [W-1:0] b_pipe [0:N-1][0:N-1];

    logic [ACCW-1:0] prop_sum   [0:N-1][0:N-1];
    logic [ACCW-1:0] prop_carry [0:N-1][0:N-1];

    integer r;
    integer c;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_q    <= 1'b0;
            clear_q <= 1'b0;
        end else begin
            en_q    <= en;
            clear_q <= clear;
        end
    end

    genvar i;
    genvar j;

    generate
        for (i = 0; i < N; i = i + 1) begin : GEN_ROW
            for (j = 0; j < N; j = j + 1) begin : GEN_COL

                if (i == 0) begin : GEN_TOP_PE
                    os8_pe #(
                        .W_IN(W),
                        .W_ACC(ACCW)
                    ) u_pe (
                        .clk            (clk),
                        .rst_n          (rst_n),

                        .en             (en_q),
                        .clear          (clear_q),

                        .prop_sel       (prop_sel),
                        .prop_shift     (prop_shift),

                        .a_in           (a_pipe[i][j]),
                        .b_in           (b_pipe[i][j]),

                        .prop_sum_in    ('0),
                        .prop_carry_in  ('0),

                        .prop_sum_out   (prop_sum[i][j]),
                        .prop_carry_out (prop_carry[i][j])
                    );
                end else begin : GEN_NON_TOP_PE
                    os8_pe #(
                        .W_IN(W),
                        .W_ACC(ACCW)
                    ) u_pe (
                        .clk            (clk),
                        .rst_n          (rst_n),

                        .en             (en_q),
                        .clear          (clear_q),

                        .prop_sel       (prop_sel),
                        .prop_shift     (prop_shift),

                        .a_in           (a_pipe[i][j]),
                        .b_in           (b_pipe[i][j]),

                        .prop_sum_in    (prop_sum[i-1][j]),
                        .prop_carry_in  (prop_carry[i-1][j]),

                        .prop_sum_out   (prop_sum[i][j]),
                        .prop_carry_out (prop_carry[i][j])
                    );
                end

            end
        end

        for (j = 0; j < N; j = j + 1) begin : GEN_BOTTOM_OUT
            assign bottom_sum[j]   = prop_sum[N-1][j];
            assign bottom_carry[j] = prop_carry[N-1][j];
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (r = 0; r < N; r = r + 1) begin
                for (c = 0; c < N; c = c + 1) begin
                    a_pipe[r][c] <= '0;
                    b_pipe[r][c] <= '0;
                end
            end

        end else if (clear_q) begin
            for (r = 0; r < N; r = r + 1) begin
                for (c = 0; c < N; c = c + 1) begin
                    a_pipe[r][c] <= '0;
                    b_pipe[r][c] <= '0;
                end
            end

        end else if (en_q) begin
            for (r = 0; r < N; r = r + 1) begin
                for (c = 0; c < N; c = c + 1) begin

                    if (c == 0)
                        a_pipe[r][c] <= a_left[r];
                    else
                        a_pipe[r][c] <= a_pipe[r][c-1];

                    if (r == 0)
                        b_pipe[r][c] <= b_top[c];
                    else
                        b_pipe[r][c] <= b_pipe[r-1][c];

                end
            end
        end
    end

endmodule
