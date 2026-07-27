module os8_delay_mem #(
    parameter int N = 8,
    parameter int W = 8
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   en,
    input  logic                   load,

    input  logic signed [W-1:0]    in_mat [0:N-1][0:N-1],
    output logic signed [W-1:0]    out_vec[0:N-1]
);

    // Delay depth creates the systolic wavefront.
    localparam int DEPTH = (2*N) - 1;

    logic signed [W-1:0] shift [0:N-1][0:DEPTH-1];

    integer lane;
    integer p;

    // Output is always the head of each lane shift register.
    always_comb begin
        for (lane = 0; lane < N; lane = lane + 1) begin
            out_vec[lane] = shift[lane][0];
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (lane = 0; lane < N; lane = lane + 1) begin
                for (p = 0; p < DEPTH; p = p + 1) begin
                    shift[lane][p] <= '0;
                end
            end

        end else if (load) begin
            // Load each row with a different starting delay.
            // Row 0 starts earliest, row 1 one cycle later, etc.
            for (lane = 0; lane < N; lane = lane + 1) begin
                for (p = 0; p < DEPTH; p = p + 1) begin
                    if ((p >= lane) && (p < lane + N)) begin
                        shift[lane][p] <= in_mat[lane][p-lane];
                    end else begin
                        shift[lane][p] <= '0;
                    end
                end
            end

        end else if (en) begin
            // Shift data toward the array boundary.
            for (lane = 0; lane < N; lane = lane + 1) begin
                for (p = 0; p < DEPTH-1; p = p + 1) begin
                    shift[lane][p] <= shift[lane][p+1];
                end
                shift[lane][DEPTH-1] <= '0;
            end
        end
    end

endmodule
