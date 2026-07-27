`timescale 1ns/1ps

module tb_os8_rocc_cmd_regs;
    logic clk;
    logic rst_n;
    logic cmd_valid;
    logic cmd_ready;
    logic [6:0] cmd_funct;
    logic [63:0] cmd_rs1;
    logic [4:0] cmd_rd;
    logic fsm_busy;
    logic [63:0] aPtr;
    logic [63:0] bPtr;
    logic [63:0] cPtr;
    logic [4:0] rdReg;
    logic reluEnable;
    logic [4:0] shiftAmount;
    logic [2:0] opMode;
    logic start_pulse;
    int pass_count;
    int fail_count;

    os8_rocc_cmd_regs #(.XLEN(64)) dut (
        .clk(clk), .rst_n(rst_n), .cmd_valid(cmd_valid), .cmd_ready(cmd_ready),
        .cmd_funct(cmd_funct), .cmd_rs1(cmd_rs1), .cmd_rd(cmd_rd), .fsm_busy(fsm_busy),
        .aPtr(aPtr), .bPtr(bPtr), .cPtr(cPtr), .rdReg(rdReg),
        .reluEnable(reluEnable), .shiftAmount(shiftAmount), .opMode(opMode), .start_pulse(start_pulse)
    );

    initial begin clk = 1'b0; forever #5 clk = ~clk; end
    initial begin $dumpfile("dumpvars.vcd"); $dumpvars(0, tb_os8_rocc_cmd_regs); end

    task check(input int tc, input bit pass);
        begin
            if (!pass) begin $display("TC%0d FAIL", tc); fail_count++; end
            else begin $display("TC%0d PASS", tc); pass_count++; end
        end
    endtask

    task send_cmd(input [6:0] funct, input [63:0] rs1, input [4:0] rd);
        begin
            @(negedge clk); cmd_funct = funct; cmd_rs1 = rs1; cmd_rd = rd; cmd_valid = 1'b1;
            @(posedge clk);
            @(negedge clk); cmd_valid = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        pass_count = 0; fail_count = 0;
        rst_n = 0; cmd_valid = 0; cmd_funct = 0; cmd_rs1 = 0; cmd_rd = 0; fsm_busy = 0;
        repeat (3) @(posedge clk); rst_n = 1; @(posedge clk);

        send_cmd(7'd0, 64'h1000, 5'd0); check(1, aPtr == 64'h1000 && cmd_ready == 1'b1);
        send_cmd(7'd1, 64'h2000, 5'd0); check(2, bPtr == 64'h2000 && cmd_ready == 1'b1);
        send_cmd(7'd7, 64'b101011, 5'd0); check(3, reluEnable == 1'b1 && shiftAmount == 5'd21);
        send_cmd(7'd13, 64'd0, 5'd5); check(4, start_pulse == 1'b0 && opMode == 3'd6 && rdReg == 5'd5);

        $display("tb_os8_rocc_cmd_regs DONE: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $finish;
    end
endmodule
