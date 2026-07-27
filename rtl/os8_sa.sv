module os8_sa #(
    parameter int N    = 8,
    parameter int W    = 8,
    parameter int ACCW = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    start,

    input  logic signed [W-1:0]     A [0:N-1][0:N-1],
    input  logic signed [W-1:0]     B [0:N-1][0:N-1],

    output logic signed [ACCW-1:0]  C [0:N-1][0:N-1],
    output logic                    busy,
    output logic                    done
);

    // Conservative exact-control version.
    // Compute cycles include:
    // - systolic fill
    // - N multiply-accumulate cycles
    // - product_reg flush
    // - boundary/delay alignment margin
    localparam int COMPUTE_CYCLES = (4*N) + 8;

    typedef enum logic [2:0] {
        S_IDLE,
        S_CLEAR,
        S_COMPUTE,
        S_SWAP_PROP,
        S_STORE_ROW,
        S_DONE
    } state_t;

    state_t state;

    logic [7:0] compute_ctr;
    logic [7:0] row_out_ctr;

    logic load;
    logic en;
    logic clear;

    logic prop_sel;
    logic prop_shift;

    logic signed [W-1:0] B_T [0:N-1][0:N-1];

    logic signed [W-1:0] a_stream   [0:N-1];
    logic signed [W-1:0] b_stream   [0:N-1];
    logic signed [W-1:0] a_boundary [0:N-1];
    logic signed [W-1:0] b_boundary [0:N-1];

    logic [ACCW-1:0] bottom_sum   [0:N-1];
    logic [ACCW-1:0] bottom_carry [0:N-1];

    logic signed [ACCW-1:0] cpa_result [0:N-1];

    assign busy = (state != S_IDLE);
    assign done = (state == S_DONE);

    assign load       = (state == S_CLEAR);
    assign clear      = (state == S_CLEAR);
    assign en         = (state == S_COMPUTE);

    // During S_STORE_ROW, current bottom row is captured first.
    // Then the selected propagation buffer shifts downward for the next row.
    assign prop_shift = (state == S_STORE_ROW) && (row_out_ctr < N-1);

    genvar r;
    genvar c;

    generate
        // Transpose B so original B columns become stream lanes.
        for (r = 0; r < N; r = r + 1) begin : GEN_BT_ROW
            for (c = 0; c < N; c = c + 1) begin : GEN_BT_COL
                assign B_T[c][r] = B[r][c];
            end
        end

        // One final CPA per output column only.
        for (c = 0; c < N; c = c + 1) begin : GEN_BOTTOM_CPA
            os8_final_cpa #(
                .W_ACC(ACCW)
            ) u_final_cpa (
                .sum_in     (bottom_sum[c]),
                .carry_in   (bottom_carry[c]),
                .result_out (cpa_result[c])
            );
        end
    endgenerate

    os8_delay_mem #(
        .N(N),
        .W(W)
    ) u_a_delay (
        .clk     (clk),
        .rst_n   (rst_n),
        .en      (en),
        .load    (load),
        .in_mat  (A),
        .out_vec (a_stream)
    );

    os8_delay_mem #(
        .N(N),
        .W(W)
    ) u_b_delay (
        .clk     (clk),
        .rst_n   (rst_n),
        .en      (en),
        .load    (load),
        .in_mat  (B_T),
        .out_vec (b_stream)
    );

    os8_pe_mesh #(
        .N(N),
        .W(W),
        .ACCW(ACCW)
    ) u_mesh (
        .clk          (clk),
        .rst_n        (rst_n),

        .en           (en),
        .clear        (clear),

        .prop_sel     (prop_sel),
        .prop_shift   (prop_shift),

        .a_left       (a_boundary),
        .b_top        (b_boundary),

        .bottom_sum   (bottom_sum),
        .bottom_carry (bottom_carry)
    );

    integer i;
    integer j;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            compute_ctr <= '0;
            row_out_ctr <= '0;
            prop_sel    <= 1'b0;

            for (i = 0; i < N; i = i + 1) begin
                a_boundary[i] <= '0;
                b_boundary[i] <= '0;
            end

            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    C[i][j] <= '0;
                end
            end

        end else begin
            case (state)

                S_IDLE: begin
                    compute_ctr <= '0;
                    row_out_ctr <= '0;

                    if (start) begin
                        state <= S_CLEAR;
                    end
                end

                S_CLEAR: begin
                    compute_ctr <= '0;
                    row_out_ctr <= '0;

                    for (i = 0; i < N; i = i + 1) begin
                        a_boundary[i] <= '0;
                        b_boundary[i] <= '0;
                    end

                    for (i = 0; i < N; i = i + 1) begin
                        for (j = 0; j < N; j = j + 1) begin
                            C[i][j] <= '0;
                        end
                    end

                    state <= S_COMPUTE;
                end

                S_COMPUTE: begin
                    for (i = 0; i < N; i = i + 1) begin
                        a_boundary[i] <= a_stream[i];
                        b_boundary[i] <= b_stream[i];
                    end

                    if (compute_ctr == COMPUTE_CYCLES-1) begin
                        compute_ctr <= '0;
                        state       <= S_SWAP_PROP;
                    end else begin
                        compute_ctr <= compute_ctr + 1'b1;
                    end
                end

                // Swap buffer roles.
                // The buffer that was used for compute now becomes the propagation buffer.
                S_SWAP_PROP: begin
                    prop_sel    <= ~prop_sel;
                    row_out_ctr <= '0;
                    state       <= S_STORE_ROW;
                end

                S_STORE_ROW: begin
                    for (j = 0; j < N; j = j + 1) begin
                        C[(N-1)-row_out_ctr][j] <= cpa_result[j];
                    end

                    if (row_out_ctr == N-1) begin
                        row_out_ctr <= '0;
                        state       <= S_DONE;
                    end else begin
                        row_out_ctr <= row_out_ctr + 1'b1;
                    end
                end

                S_DONE: begin
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule
