`timescale 1ns/1ps

module tb_os8_pe_mesh;

    localparam int N = 1;
    localparam int W = 8;
    localparam int ACCW = 32;

    logic clk;
    logic rst_n;

    logic en;
    logic clear;
    logic prop_sel;
    logic prop_shift;

    logic signed [W-1:0] a_left [0:N-1];
    logic signed [W-1:0] b_top  [0:N-1];

    logic [ACCW-1:0] bottom_sum   [0:N-1];
    logic [ACCW-1:0] bottom_carry [0:N-1];

    logic signed [ACCW-1:0] observe_bottom_sum0;
    logic signed [ACCW-1:0] observe_bottom_carry0;
    logic signed [ACCW-1:0] observe_bottom0_total;

    int pass_count;
    int fail_count;

    assign observe_bottom_sum0   = $signed(bottom_sum[0]);
    assign observe_bottom_carry0 = $signed(bottom_carry[0]);
    assign observe_bottom0_total = $signed(bottom_sum[0] + bottom_carry[0]);

    os8_pe_mesh #(
        .N(N),
        .W(W),
        .ACCW(ACCW)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .clear(clear),
        .prop_sel(prop_sel),
        .prop_shift(prop_shift),
        .a_left(a_left),
        .b_top(b_top),
        .bottom_sum(bottom_sum),
        .bottom_carry(bottom_carry)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dumpvars.vcd");
        $dumpvars(0, tb_os8_pe_mesh);
    end

    task check_total(input int tc, input signed [ACCW-1:0] expected);
        begin
            #1;
            if (observe_bottom0_total !== expected) begin
                $display("TC%0d FAIL: observe_bottom0_total=%0d expected=%0d",
                    tc, observe_bottom0_total, expected);
                fail_count++;
            end else begin
                $display("TC%0d PASS", tc);
                pass_count++;
            end
        end
    endtask

    task reset_dut;
        begin
            rst_n = 1'b0;
            en = 1'b0;
            clear = 1'b0;
            prop_sel = 1'b1;
            prop_shift = 1'b0;
            a_left[0] = 8'sd0;
            b_top[0] = 8'sd0;

            repeat (3) @(posedge clk);

            rst_n = 1'b1;

            repeat (2) @(posedge clk);
        end
    endtask

    task clear_mesh;
        begin
            @(negedge clk);
            clear = 1'b1;
            en = 1'b0;
            prop_shift = 1'b0;
            a_left[0] = 8'sd0;
            b_top[0] = 8'sd0;

            repeat (3) @(posedge clk);

            @(negedge clk);
            clear = 1'b0;

            repeat (2) @(posedge clk);
        end
    endtask

    task run_accumulate_test(
        input signed [W-1:0] a_val,
        input signed [W-1:0] b_val
    );
        begin
            clear_mesh();

            @(negedge clk);
            prop_sel = 1'b0;
            prop_shift = 1'b0;
            a_left[0] = a_val;
            b_top[0] = b_val;
            en = 1'b1;

            repeat (5) @(posedge clk);

            @(negedge clk);
            en = 1'b0;
            a_left[0] = 8'sd0;
            b_top[0] = 8'sd0;

            repeat (2) @(posedge clk);

            @(negedge clk);
            prop_sel = 1'b1;

            repeat (1) @(posedge clk);
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        reset_dut();

        clear_mesh();
        prop_sel = 1'b1;
        check_total(1, 32'sd0);

        run_accumulate_test(8'sd2, 8'sd3);
        check_total(2, 32'sd12);

        run_accumulate_test(-8'sd4, 8'sd5);
        check_total(3, -32'sd40);

        clear_mesh();
        prop_sel = 1'b1;
        check_total(4, 32'sd0);

        $display("tb_os8_pe_mesh DONE: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $finish;
    end

endmodule
