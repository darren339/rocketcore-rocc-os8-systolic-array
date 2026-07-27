`timescale 1ns/1ps

module tb_os8_sa;
    localparam int N = 2;
    localparam int W = 8;
    localparam int ACCW = 32;

    logic clk;
    logic rst_n;
    logic start;
    logic signed [W-1:0] A [0:N-1][0:N-1];
    logic signed [W-1:0] B [0:N-1][0:N-1];
    logic signed [ACCW-1:0] C [0:N-1][0:N-1];
    logic busy;
    logic done;

    // Scalar mirror signals for GTKWave display only.
    logic signed [W-1:0] observe_A00, observe_A01, observe_A10, observe_A11;
    logic signed [W-1:0] observe_B00, observe_B01, observe_B10, observe_B11;
    logic signed [ACCW-1:0] observe_C00, observe_C01, observe_C10, observe_C11;

    int pass_count;
    int fail_count;

    os8_sa #(.N(N), .W(W), .ACCW(ACCW)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .A(A), .B(B), .C(C), .busy(busy), .done(done)
    );

    assign observe_A00 = A[0][0]; assign observe_A01 = A[0][1];
    assign observe_A10 = A[1][0]; assign observe_A11 = A[1][1];
    assign observe_B00 = B[0][0]; assign observe_B01 = B[0][1];
    assign observe_B10 = B[1][0]; assign observe_B11 = B[1][1];
    assign observe_C00 = C[0][0]; assign observe_C01 = C[0][1];
    assign observe_C10 = C[1][0]; assign observe_C11 = C[1][1];

    initial begin clk = 1'b0; forever #5 clk = ~clk; end
    initial begin $dumpfile("dumpvars.vcd"); $dumpvars(0, tb_os8_sa); end

    task run_start;
        begin
            @(negedge clk); start = 1'b1;
            @(posedge clk);
            @(negedge clk); start = 1'b0;
            wait(done === 1'b1 || $time > 5000);
            @(posedge clk);
        end
    endtask

    task check_mat(input int tc, input signed [31:0] e00, input signed [31:0] e01, input signed [31:0] e10, input signed [31:0] e11);
        begin
            #1;
            if (C[0][0] !== e00 || C[0][1] !== e01 || C[1][0] !== e10 || C[1][1] !== e11) begin
                $display("TC%0d FAIL: C={{%0d,%0d},{%0d,%0d}}, expected={{%0d,%0d},{%0d,%0d}}",
                    tc, C[0][0], C[0][1], C[1][0], C[1][1], e00, e01, e10, e11);
                fail_count++;
            end else begin
                $display("TC%0d PASS", tc);
                pass_count++;
            end
        end
    endtask

    initial begin
        pass_count = 0; fail_count = 0;
        rst_n = 0; start = 0;
        repeat (3) @(posedge clk); rst_n = 1; @(posedge clk);

        A[0][0]=1; A[0][1]=0; A[1][0]=0; A[1][1]=1;
        B[0][0]=5; B[0][1]=6; B[1][0]=7; B[1][1]=8;
        run_start(); check_mat(1,5,6,7,8);

        A[0][0]=1; A[0][1]=2; A[1][0]=3; A[1][1]=4;
        B[0][0]=5; B[0][1]=6; B[1][0]=7; B[1][1]=8;
        run_start(); check_mat(2,19,22,43,50);

        A[0][0]=-1; A[0][1]=2; A[1][0]=3; A[1][1]=-4;
        B[0][0]=5; B[0][1]=-6; B[1][0]=-7; B[1][1]=8;
        run_start(); check_mat(3,-19,22,43,-50);

        A[0][0]=0; A[0][1]=0; A[1][0]=0; A[1][1]=0;
        B[0][0]=1; B[0][1]=2; B[1][0]=3; B[1][1]=4;
        run_start(); check_mat(4,0,0,0,0);

        $display("tb_os8_sa DONE: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $finish;
    end
endmodule
