`timescale 1ns/1ps

module tb_os8_activation_unit;
    logic clk;
    logic signed [31:0] in_data;
    logic relu_enable;
    logic [4:0] shift_amount;
    logic signed [31:0] out_data;
    int pass_count;
    int fail_count;

    os8_activation_unit #(.W(32)) dut (
        .in_data(in_data),
        .relu_enable(relu_enable),
        .shift_amount(shift_amount),
        .out_data(out_data)
    );

    initial begin clk = 1'b0; forever #5 clk = ~clk; end
    initial begin $dumpfile("dumpvars.vcd"); $dumpvars(0, tb_os8_activation_unit); end

    task check(input int tc, input signed [31:0] exp);
        begin
            #1;
            if (out_data !== exp) begin
                $display("TC%0d FAIL: out_data=%0d expected=%0d", tc, out_data, exp);
                fail_count++;
            end else begin
                $display("TC%0d PASS", tc);
                pass_count++;
            end
        end
    endtask

    initial begin
        pass_count = 0; fail_count = 0;
        in_data = 32'sd64;  relu_enable = 1'b0; shift_amount = 5'd0; check(1, 32'sd64);
        in_data = 32'sd64;  relu_enable = 1'b0; shift_amount = 5'd2; check(2, 32'sd16);
        in_data = -32'sd32; relu_enable = 1'b0; shift_amount = 5'd1; check(3, -32'sd16);
        in_data = -32'sd32; relu_enable = 1'b1; shift_amount = 5'd1; check(4, 32'sd0);
        $display("tb_os8_activation_unit DONE: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $finish;
    end
endmodule
