`timescale 1ns/1ps

module tb_os8_final_cpa;
    logic clk;
    logic [31:0] sum_in;
    logic [31:0] carry_in;
    logic signed [31:0] result_out;
    int pass_count;
    int fail_count;

    os8_final_cpa #(.W_ACC(32)) dut (
        .sum_in(sum_in),
        .carry_in(carry_in),
        .result_out(result_out)
    );

    initial begin clk = 1'b0; forever #5 clk = ~clk; end
    initial begin $dumpfile("dumpvars.vcd"); $dumpvars(0, tb_os8_final_cpa); end

    task check(input int tc, input signed [31:0] exp);
        begin
            #1;
            if (result_out !== exp) begin
                $display("TC%0d FAIL: result_out=%0d expected=%0d", tc, result_out, exp);
                fail_count++;
            end else begin
                $display("TC%0d PASS", tc);
                pass_count++;
            end
        end
    endtask

    initial begin
        pass_count = 0; fail_count = 0;
        sum_in = 32'd10;       carry_in = 32'd5; check(1, 32'sd15);
        sum_in = 32'd100;      carry_in = 32'd200; check(2, 32'sd300);
        sum_in = 32'hFFFFFFF0; carry_in = 32'd0; check(3, -32'sd16);
        sum_in = 32'hFFFFFFFF; carry_in = 32'd1; check(4, 32'sd0);
        $display("tb_os8_final_cpa DONE: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $finish;
    end
endmodule
