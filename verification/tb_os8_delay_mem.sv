`timescale 1ns/1ps

module tb_os8_delay_mem;
    localparam int N = 4;
    localparam int W = 8;

    logic clk;
    logic rst_n;
    logic en;
    logic load;

    logic signed [W-1:0] in_mat [0:N-1][0:N-1];
    logic signed [W-1:0] out_vec[0:N-1];

    // Scalar mirror signals for GTKWave display only.
    logic signed [W-1:0] observe_in00, observe_in01, observe_in02, observe_in03;
    logic signed [W-1:0] observe_in10, observe_in11, observe_in12, observe_in13;
    logic signed [W-1:0] observe_in20, observe_in21, observe_in22, observe_in23;
    logic signed [W-1:0] observe_in30, observe_in31, observe_in32, observe_in33;
    logic signed [W-1:0] observe_out0, observe_out1, observe_out2, observe_out3;

    int pass_count;
    int fail_count;

    os8_delay_mem #(.N(N), .W(W)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .load(load),
        .in_mat(in_mat),
        .out_vec(out_vec)
    );

    assign observe_in00 = in_mat[0][0]; assign observe_in01 = in_mat[0][1];
    assign observe_in02 = in_mat[0][2]; assign observe_in03 = in_mat[0][3];
    assign observe_in10 = in_mat[1][0]; assign observe_in11 = in_mat[1][1];
    assign observe_in12 = in_mat[1][2]; assign observe_in13 = in_mat[1][3];
    assign observe_in20 = in_mat[2][0]; assign observe_in21 = in_mat[2][1];
    assign observe_in22 = in_mat[2][2]; assign observe_in23 = in_mat[2][3];
    assign observe_in30 = in_mat[3][0]; assign observe_in31 = in_mat[3][1];
    assign observe_in32 = in_mat[3][2]; assign observe_in33 = in_mat[3][3];

    assign observe_out0 = out_vec[0]; assign observe_out1 = out_vec[1];
    assign observe_out2 = out_vec[2]; assign observe_out3 = out_vec[3];

    initial begin clk = 1'b0; forever #5 clk = ~clk; end
    initial begin $dumpfile("dumpvars.vcd"); $dumpvars(0, tb_os8_delay_mem); end

    task check_vec(input int tc, input int e0, input int e1, input int e2, input int e3);
        begin
            #1;
            if (out_vec[0] !== e0 || out_vec[1] !== e1 || out_vec[2] !== e2 || out_vec[3] !== e3) begin
                $display("TC%0d FAIL: out_vec={%0d,%0d,%0d,%0d}, expected={%0d,%0d,%0d,%0d}",
                    tc, out_vec[0], out_vec[1], out_vec[2], out_vec[3], e0, e1, e2, e3);
                fail_count++;
            end else begin
                $display("TC%0d PASS", tc);
                pass_count++;
            end
        end
    endtask

    initial begin
        pass_count = 0; fail_count = 0;
        rst_n = 1'b0; en = 1'b0; load = 1'b0;

        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin
                in_mat[r][c] = (r * 10) + c + 1;
            end
        end

        repeat (3) @(posedge clk);
        check_vec(1, 0, 0, 0, 0);

        @(negedge clk); rst_n = 1'b1;
        @(negedge clk); load = 1'b1; en = 1'b0;
        @(posedge clk); check_vec(2, 1, 0, 0, 0);

        @(negedge clk); load = 1'b0; en = 1'b1;
        @(posedge clk); check_vec(3, 2, 11, 0, 0);
        @(posedge clk); check_vec(4, 3, 12, 21, 0);

        @(negedge clk); en = 1'b0;
        $display("tb_os8_delay_mem DONE: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $finish;
    end
endmodule
