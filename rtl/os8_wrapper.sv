module os8_wrapper #(
    parameter int XLEN = 64,
    parameter int N    = 8,
    parameter int W    = 8,
    parameter int ACCW = 32
)(
    input  logic                 clk,
    input  logic                 rst_n,

    input  logic                 cmd_valid,
    output logic                 cmd_ready,
    input  logic [6:0]           cmd_funct,
    input  logic [XLEN-1:0]      cmd_rs1,
    input  logic [4:0]           cmd_rd,

    output logic                 resp_valid,
    input  logic                 resp_ready,
    output logic [4:0]           resp_rd,
    output logic [XLEN-1:0]      resp_data,

    output logic                 mem_req_valid,
    input  logic                 mem_req_ready,
    output logic [XLEN-1:0]      mem_req_addr,
    output logic [7:0]           mem_req_tag,
    output logic [4:0]           mem_req_cmd,
    output logic [2:0]           mem_req_size,
    output logic [XLEN-1:0]      mem_req_data,

    input  logic                 mem_resp_valid,
    input  logic [7:0]           mem_resp_tag,
    input  logic [XLEN-1:0]      mem_resp_data,

    output logic                 busy
);

    logic [XLEN-1:0] aPtr;
    logic [XLEN-1:0] bPtr;
    logic [XLEN-1:0] cPtr;

    logic [4:0] rdReg;

    logic       reluEnable;
    logic [4:0] shiftAmount;

    logic [2:0] opMode;
    logic       start_pulse;

    logic signed [W-1:0]    A [0:N-1][0:N-1];
    logic signed [W-1:0]    B [0:N-1][0:N-1];
    logic signed [ACCW-1:0] C [0:N-1][0:N-1];

    logic core_start;
    logic core_busy;
    logic core_done;
    logic fsm_busy;

    assign busy = core_busy || fsm_busy;

    os8_rocc_cmd_regs #(
        .XLEN(XLEN)
    ) u_cmd_regs (
        .clk(clk),
        .rst_n(rst_n),

        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_funct(cmd_funct),
        .cmd_rs1(cmd_rs1),
        .cmd_rd(cmd_rd),

        .fsm_busy(fsm_busy),

        .aPtr(aPtr),
        .bPtr(bPtr),
        .cPtr(cPtr),

        .rdReg(rdReg),

        .reluEnable(reluEnable),
        .shiftAmount(shiftAmount),

        .opMode(opMode),
        .start_pulse(start_pulse)
    );

    os8_controller #(
        .XLEN(XLEN),
        .N(N),
        .W(W),
        .ACCW(ACCW)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),

        .start_pulse(start_pulse),
        .opMode(opMode),

        .aPtr(aPtr),
        .bPtr(bPtr),
        .cPtr(cPtr),

        .rdReg(rdReg),
        .reluEnable(reluEnable),
        .shiftAmount(shiftAmount),

        .resp_valid(resp_valid),
        .resp_ready(resp_ready),
        .resp_rd(resp_rd),
        .resp_data(resp_data),

        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_addr(mem_req_addr),
        .mem_req_tag(mem_req_tag),
        .mem_req_cmd(mem_req_cmd),
        .mem_req_size(mem_req_size),
        .mem_req_data(mem_req_data),

        .mem_resp_valid(mem_resp_valid),
        .mem_resp_tag(mem_resp_tag),
        .mem_resp_data(mem_resp_data),

        .core_start(core_start),
        .core_done(core_done),

        .A(A),
        .B(B),
        .C(C),

        .busy(fsm_busy)
    );

    os8_sa #(
        .N(N),
        .W(W),
        .ACCW(ACCW)
    ) u_core (
        .clk(clk),
        .rst_n(rst_n),
        .start(core_start),

        .A(A),
        .B(B),
        .C(C),

        .busy(core_busy),
        .done(core_done)
    );

endmodule
