module os8_rocc_cmd_regs #(
    parameter int XLEN = 64
)(
    input  logic                 clk,
    input  logic                 rst_n,

    input  logic                 cmd_valid,
    output logic                 cmd_ready,
    input  logic [6:0]           cmd_funct,
    input  logic [XLEN-1:0]      cmd_rs1,
    input  logic [4:0]           cmd_rd,

    input  logic                 fsm_busy,

    output logic [XLEN-1:0]      aPtr,
    output logic [XLEN-1:0]      bPtr,
    output logic [XLEN-1:0]      cPtr,

    output logic [4:0]           rdReg,

    output logic                 reluEnable,
    output logic [4:0]           shiftAmount,

    output logic [2:0]           opMode,
    output logic                 start_pulse
);

    localparam logic [2:0] MODE_FULL          = 3'd0;
    localparam logic [2:0] MODE_LOAD_A        = 3'd1;
    localparam logic [2:0] MODE_LOAD_B        = 3'd2;
    localparam logic [2:0] MODE_COMPUTE       = 3'd3;
    localparam logic [2:0] MODE_STORE         = 3'd4;
    localparam logic [2:0] MODE_LOAD_AB       = 3'd5;
    localparam logic [2:0] MODE_COMPUTE_STORE = 3'd6;

    assign cmd_ready = !fsm_busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aPtr        <= '0;
            bPtr        <= '0;
            cPtr        <= '0;
            rdReg       <= '0;
            reluEnable  <= 1'b0;
            shiftAmount <= 5'd0;
            opMode      <= MODE_FULL;
            start_pulse <= 1'b0;
        end else begin
            start_pulse <= 1'b0;

            if (cmd_valid && cmd_ready) begin
                case (cmd_funct)
                    7'd0: aPtr <= cmd_rs1;
                    7'd1: bPtr <= cmd_rs1;
                    7'd2: cPtr <= cmd_rs1;

                    7'd7: begin
                        reluEnable  <= cmd_rs1[0];
                        shiftAmount <= cmd_rs1[5:1];
                    end

                    7'd3,
                    7'd8,
                    7'd9,
                    7'd10,
                    7'd11,
                    7'd12,
                    7'd13: begin
                        rdReg       <= cmd_rd;
                        start_pulse <= 1'b1;

                        case (cmd_funct)
                            7'd3:  opMode <= MODE_FULL;
                            7'd8:  opMode <= MODE_LOAD_A;
                            7'd9:  opMode <= MODE_LOAD_B;
                            7'd10: opMode <= MODE_COMPUTE;
                            7'd11: opMode <= MODE_STORE;
                            7'd12: opMode <= MODE_LOAD_AB;
                            7'd13: opMode <= MODE_COMPUTE_STORE;
                            default: opMode <= MODE_FULL;
                        endcase
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
