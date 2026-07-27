`timescale 1ns/1ps

module tb_os8_controller;
    localparam int XLEN = 64;
    localparam int N = 2;
    localparam int W = 8;
    localparam int ACCW = 32;

    logic clk;
    logic rst_n;
    logic start_pulse;
    logic [2:0] opMode;
    logic [XLEN-1:0] aPtr;
    logic [XLEN-1:0] bPtr;
    logic [XLEN-1:0] cPtr;
    logic [4:0] rdReg;
    logic reluEnable;
    logic [4:0] shiftAmount;
    logic resp_valid;
    logic resp_ready;
    logic [4:0] resp_rd;
    logic [XLEN-1:0] resp_data;
    logic mem_req_valid;
    logic mem_req_ready;
    logic [XLEN-1:0] mem_req_addr;
    logic [7:0] mem_req_tag;
    logic [4:0] mem_req_cmd;
    logic [2:0] mem_req_size;
    logic [XLEN-1:0] mem_req_data;
    logic mem_resp_valid;
    logic [7:0] mem_resp_tag;
    logic [XLEN-1:0] mem_resp_data;
    logic core_start;
    logic core_done;
    logic signed [W-1:0] A [0:N-1][0:N-1];
    logic signed [W-1:0] B [0:N-1][0:N-1];
    logic signed [ACCW-1:0] C [0:N-1][0:N-1];
    logic busy;

    // Scalar mirror signals for GTKWave display only.
    logic signed [W-1:0] observe_A00, observe_A01, observe_A10, observe_A11;
    logic signed [W-1:0] observe_B00, observe_B01, observe_B10, observe_B11;
    logic signed [ACCW-1:0] observe_C00, observe_C01, observe_C10, observe_C11;

    logic [63:0] mem [0:1023];
    logic signed [31:0] mem300, mem304, mem308, mem312;
    int pass_count;
    int fail_count;

    os8_controller #(.XLEN(XLEN), .N(N), .W(W), .ACCW(ACCW)) dut (
        .clk(clk), .rst_n(rst_n), .start_pulse(start_pulse), .opMode(opMode),
        .aPtr(aPtr), .bPtr(bPtr), .cPtr(cPtr), .rdReg(rdReg),
        .reluEnable(reluEnable), .shiftAmount(shiftAmount),
        .resp_valid(resp_valid), .resp_ready(resp_ready), .resp_rd(resp_rd), .resp_data(resp_data),
        .mem_req_valid(mem_req_valid), .mem_req_ready(mem_req_ready), .mem_req_addr(mem_req_addr),
        .mem_req_tag(mem_req_tag), .mem_req_cmd(mem_req_cmd), .mem_req_size(mem_req_size), .mem_req_data(mem_req_data),
        .mem_resp_valid(mem_resp_valid), .mem_resp_tag(mem_resp_tag), .mem_resp_data(mem_resp_data),
        .core_start(core_start), .core_done(core_done), .A(A), .B(B), .C(C), .busy(busy)
    );

    assign observe_A00 = A[0][0]; assign observe_A01 = A[0][1];
    assign observe_A10 = A[1][0]; assign observe_A11 = A[1][1];
    assign observe_B00 = B[0][0]; assign observe_B01 = B[0][1];
    assign observe_B10 = B[1][0]; assign observe_B11 = B[1][1];
    assign observe_C00 = C[0][0]; assign observe_C01 = C[0][1];
    assign observe_C10 = C[1][0]; assign observe_C11 = C[1][1];

    assign mem300 = $signed(mem[300][31:0]);
    assign mem304 = $signed(mem[304][31:0]);
    assign mem308 = $signed(mem[308][31:0]);
    assign mem312 = $signed(mem[312][31:0]);

    initial begin clk = 1'b0; forever #5 clk = ~clk; end
    initial begin $dumpfile("dumpvars.vcd"); $dumpvars(0, tb_os8_controller); end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_resp_valid <= 1'b0;
            mem_resp_tag <= '0;
            mem_resp_data <= '0;
        end else begin
            mem_resp_valid <= 1'b0;
            if (mem_req_valid && mem_req_ready) begin
                mem_resp_valid <= 1'b1;
                mem_resp_tag <= mem_req_tag;
                if (mem_req_cmd == 5'd0)
                    mem_resp_data <= mem[mem_req_addr[9:0]];
                else begin
                    mem[mem_req_addr[9:0]] <= mem_req_data;
                    mem_resp_data <= 64'd0;
                end
            end
        end
    end

    task check(input int tc, input bit pass);
        begin
            #1;
            if (!pass) begin $display("TC%0d FAIL", tc); fail_count++; end
            else begin $display("TC%0d PASS", tc); pass_count++; end
        end
    endtask

    task pulse_start(input [2:0] mode);
        begin
            @(negedge clk); opMode = mode; start_pulse = 1'b1;
            @(posedge clk);
            @(negedge clk); start_pulse = 1'b0;
        end
    endtask

    task wait_resp;
        begin
            wait(resp_valid === 1'b1);
            @(negedge clk); resp_ready = 1'b1;
            @(posedge clk);
            @(negedge clk); resp_ready = 1'b0;
            @(posedge clk);
        end
    endtask

    initial begin
        pass_count = 0; fail_count = 0;
        rst_n = 0; start_pulse = 0; opMode = 0; aPtr = 64'd100; bPtr = 64'd200; cPtr = 64'd300;
        rdReg = 5'd3; reluEnable = 0; shiftAmount = 0; resp_ready = 0; mem_req_ready = 1; core_done = 0;

        C[0][0] = 32'sd10; C[0][1] = -32'sd20; C[1][0] = 32'sd30; C[1][1] = -32'sd40;
        mem[100] = 64'd1; mem[101] = 64'd2; mem[102] = 64'd3; mem[103] = 64'd4;
        mem[200] = 64'hFF; mem[201] = 64'hFE; mem[202] = 64'hFD; mem[203] = 64'hFC;

        repeat (3) @(posedge clk); rst_n = 1; @(posedge clk);
        check(1, busy == 0 && resp_valid == 0);

        pulse_start(3'd1); wait_resp();
        check(2, A[0][0] == 1 && A[0][1] == 2 && A[1][0] == 3 && A[1][1] == 4);

        pulse_start(3'd2); wait_resp();
        check(3, B[0][0] == -1 && B[0][1] == -2 && B[1][0] == -3 && B[1][1] == -4);

        pulse_start(3'd4); wait_resp();
        check(4, mem300 == 10 && mem304 == -20 && mem308 == 30 && mem312 == -40);

        $display("tb_os8_controller DONE: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $finish;
    end
endmodule
