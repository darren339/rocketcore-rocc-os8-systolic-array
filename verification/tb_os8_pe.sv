`timescale 1ns/1ps

module tb_os8_pe;
    logic clk;
    logic rst_n;
    logic en;
    logic clear;
    logic prop_sel;
    logic prop_shift;
    logic signed [7:0] a_in;
    logic signed [7:0] b_in;
    logic [31:0] prop_sum_in;
    logic [31:0] prop_carry_in;
    logic [31:0] prop_sum_out;
    logic [31:0] prop_carry_out;
    logic signed [31:0] output_total;
    int pass_count;
    int fail_count;

    os8_pe #(.W_IN(8), .W_ACC(32)) dut (
        .clk(clk), .rst_n(rst_n), .en(en), .clear(clear),
        .prop_sel(prop_sel), .prop_shift(prop_shift),
        .a_in(a_in), .b_in(b_in),
        .prop_sum_in(prop_sum_in), .prop_carry_in(prop_carry_in),
        .prop_sum_out(prop_sum_out), .prop_carry_out(prop_carry_out)
    );

    assign output_total = $signed(prop_sum_out + prop_carry_out);

    initial begin clk = 1'b0; forever #5 clk = ~clk; end
    initial begin $dumpfile("dumpvars.vcd"); $dumpvars(0, tb_os8_pe); end

    task check_total(input int tc, input signed [31:0] exp);
        begin
            #1;
            if (output_total !== exp) begin
                $display("TC%0d FAIL: output_total=%0d expected=%0d", tc, output_total, exp);
                fail_count++;
            end else begin
                $display("TC%0d PASS", tc);
                pass_count++;
            end
        end
    endtask

    task do_clear;
        begin
            @(negedge clk); clear = 1'b1; en = 1'b0; prop_shift = 1'b0;
            @(posedge clk);
            @(negedge clk); clear = 1'b0;
            @(posedge clk);
        end
    endtask

    task do_one_product(input signed [7:0] a, input signed [7:0] b, input signed [31:0] exp, input int tc);
        begin
            do_clear();
            @(negedge clk); prop_sel = 1'b0; prop_shift = 1'b0; a_in = a; b_in = b; en = 1'b0;
            @(posedge clk); // preload product_small_pipe
            @(negedge clk); en = 1'b1;
            repeat (2) @(posedge clk); // product reaches CSA once
            @(negedge clk); en = 1'b0; prop_sel = 1'b1;
            @(posedge clk);
            check_total(tc, exp);
        end
    endtask

    initial begin
        pass_count = 0; fail_count = 0;
        rst_n = 1'b0; en = 1'b0; clear = 1'b0; prop_sel = 1'b0; prop_shift = 1'b0;
        a_in = 0; b_in = 0; prop_sum_in = 0; prop_carry_in = 0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        do_clear();
        prop_sel = 1'b1;
        check_total(1, 32'sd0);

        do_one_product(8'sd3, 8'sd4, 32'sd12, 2);
        do_one_product(-8'sd2, 8'sd5, -32'sd10, 3);

        do_clear();
        @(negedge clk); prop_sel = 1'b1; prop_sum_in = 32'd77; prop_carry_in = 32'd3; prop_shift = 1'b1;
        @(posedge clk);
        @(negedge clk); prop_shift = 1'b0;
        @(posedge clk);
        check_total(4, 32'sd80);

        $display("tb_os8_pe DONE: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $finish;
    end
endmodule
