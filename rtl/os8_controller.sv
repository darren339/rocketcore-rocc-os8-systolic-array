module os8_controller #(
    parameter int XLEN = 64,
    parameter int N    = 8,
    parameter int W    = 8,
    parameter int ACCW = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,

    input  logic                    start_pulse,
    input  logic [2:0]              opMode,

    input  logic [XLEN-1:0]         aPtr,
    input  logic [XLEN-1:0]         bPtr,
    input  logic [XLEN-1:0]         cPtr,

    input  logic [4:0]              rdReg,
    input  logic                    reluEnable,
    input  logic [4:0]              shiftAmount,

    output logic                    resp_valid,
    input  logic                    resp_ready,
    output logic [4:0]              resp_rd,
    output logic [XLEN-1:0]         resp_data,

    output logic                    mem_req_valid,
    input  logic                    mem_req_ready,
    output logic [XLEN-1:0]         mem_req_addr,
    output logic [7:0]              mem_req_tag,
    output logic [4:0]              mem_req_cmd,
    output logic [2:0]              mem_req_size,
    output logic [XLEN-1:0]         mem_req_data,

    input  logic                    mem_resp_valid,
    input  logic [7:0]              mem_resp_tag,
    input  logic [XLEN-1:0]         mem_resp_data,

    output logic                    core_start,
    input  logic                    core_done,

    output logic signed [W-1:0]     A [0:N-1][0:N-1],
    output logic signed [W-1:0]     B [0:N-1][0:N-1],
    input  logic signed [ACCW-1:0]  C [0:N-1][0:N-1],

    output logic                    busy
);

    localparam logic [4:0] M_XRD = 5'd0;
    localparam logic [4:0] M_XWR = 5'd1;

    localparam logic [2:0] MODE_FULL          = 3'd0;
    localparam logic [2:0] MODE_LOAD_A        = 3'd1;
    localparam logic [2:0] MODE_LOAD_B        = 3'd2;
    localparam logic [2:0] MODE_COMPUTE       = 3'd3;
    localparam logic [2:0] MODE_STORE         = 3'd4;
    localparam logic [2:0] MODE_LOAD_AB       = 3'd5;
    localparam logic [2:0] MODE_COMPUTE_STORE = 3'd6;

    typedef enum logic [12:0] {
        S_IDLE          = 13'b0000000000001,
        S_LOAD_A_REQ    = 13'b0000000000010,
        S_LOAD_A_RESP   = 13'b0000000000100,
        S_LOAD_B_REQ    = 13'b0000000001000,
        S_LOAD_B_RESP   = 13'b0000000010000,
        S_START         = 13'b0000000100000,
        S_WAIT          = 13'b0000001000000,
        S_STORE_SELECT  = 13'b0000010000000,
        S_STORE_ACT     = 13'b0000100000000,
        S_STORE_PACK    = 13'b0001000000000,
        S_STORE_C_REQ   = 13'b0010000000000,
        S_STORE_C_WAIT  = 13'b0100000000000,
        S_RESP          = 13'b1000000000000
    } state_t;

    state_t state;

    logic [2:0] activeMode;

    logic [15:0] total_cycles;
    logic [15:0] load_cycles;
    logic [15:0] compute_cycles;
    logic [15:0] store_cycles;

    logic [3:0] rowCnt;
    logic [3:0] colCnt;

    logic [XLEN-1:0] mem_req_addr_reg;

    logic signed [ACCW-1:0] cRaw_reg;
    logic signed [ACCW-1:0] cAct_wire;
    logic signed [ACCW-1:0] cAct_reg;

    logic [63:0] storeData64_reg;

    assign busy = (state != S_IDLE);

    os8_activation_unit #(
        .W(ACCW)
    ) u_activation (
        .in_data      (cRaw_reg),
        .relu_enable  (reluEnable),
        .shift_amount (shiftAmount),
        .out_data     (cAct_wire)
    );

    always_comb begin
        resp_valid    = 1'b0;
        resp_rd       = rdReg;
        resp_data     = {store_cycles, compute_cycles, load_cycles, total_cycles};

        mem_req_valid = 1'b0;
        mem_req_addr  = mem_req_addr_reg;
        mem_req_tag   = 8'd0;
        mem_req_cmd   = M_XRD;
        mem_req_size  = 3'd0;
        mem_req_data  = '0;

        core_start    = 1'b0;

        case (state)
            S_LOAD_A_REQ: begin
                mem_req_valid = 1'b1;
                mem_req_cmd   = M_XRD;
                mem_req_size  = 3'd0;
            end

            S_LOAD_B_REQ: begin
                mem_req_valid = 1'b1;
                mem_req_cmd   = M_XRD;
                mem_req_size  = 3'd0;
            end

            S_START: begin
                core_start = 1'b1;
            end

            S_STORE_C_REQ: begin
                mem_req_valid = 1'b1;
                mem_req_cmd   = M_XWR;
                mem_req_size  = 3'd2;
                mem_req_data  = storeData64_reg[XLEN-1:0];
            end

            S_RESP: begin
                resp_valid = 1'b1;
            end

            default: begin
            end
        endcase
    end

    integer r;
    integer c;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= S_IDLE;
            activeMode        <= MODE_FULL;

            rowCnt            <= '0;
            colCnt            <= '0;
            mem_req_addr_reg  <= '0;

            cRaw_reg          <= '0;
            cAct_reg          <= '0;
            storeData64_reg   <= '0;

            total_cycles      <= '0;
            load_cycles       <= '0;
            compute_cycles    <= '0;
            store_cycles      <= '0;

            for (r = 0; r < N; r = r + 1) begin
                for (c = 0; c < N; c = c + 1) begin
                    A[r][c] <= '0;
                    B[r][c] <= '0;
                end
            end

        end else begin

            if (state != S_IDLE && state != S_RESP) begin
                total_cycles <= total_cycles + 1'b1;

                case (state)
                    S_LOAD_A_REQ,
                    S_LOAD_A_RESP,
                    S_LOAD_B_REQ,
                    S_LOAD_B_RESP:
                        load_cycles <= load_cycles + 1'b1;

                    S_START,
                    S_WAIT:
                        compute_cycles <= compute_cycles + 1'b1;

                    S_STORE_SELECT,
                    S_STORE_ACT,
                    S_STORE_PACK,
                    S_STORE_C_REQ,
                    S_STORE_C_WAIT:
                        store_cycles <= store_cycles + 1'b1;

                    default: begin
                    end
                endcase
            end

            case (state)

                S_IDLE: begin
                    rowCnt <= '0;
                    colCnt <= '0;

                    if (start_pulse) begin
                        activeMode        <= opMode;
                        rowCnt            <= '0;
                        colCnt            <= '0;
                        mem_req_addr_reg  <= aPtr;

                        cRaw_reg          <= '0;
                        cAct_reg          <= '0;
                        storeData64_reg   <= '0;

                        total_cycles      <= '0;
                        load_cycles       <= '0;
                        compute_cycles    <= '0;
                        store_cycles      <= '0;

                        case (opMode)
                            MODE_FULL: begin
                                for (r = 0; r < N; r = r + 1) begin
                                    for (c = 0; c < N; c = c + 1) begin
                                        A[r][c] <= '0;
                                        B[r][c] <= '0;
                                    end
                                end
                                state <= S_LOAD_A_REQ;
                            end

                            MODE_LOAD_A: begin
                                for (r = 0; r < N; r = r + 1)
                                    for (c = 0; c < N; c = c + 1)
                                        A[r][c] <= '0;

                                state <= S_LOAD_A_REQ;
                            end

                            MODE_LOAD_B: begin
                                for (r = 0; r < N; r = r + 1)
                                    for (c = 0; c < N; c = c + 1)
                                        B[r][c] <= '0;

                                mem_req_addr_reg <= bPtr;
                                state            <= S_LOAD_B_REQ;
                            end

                            MODE_LOAD_AB: begin
                                for (r = 0; r < N; r = r + 1) begin
                                    for (c = 0; c < N; c = c + 1) begin
                                        A[r][c] <= '0;
                                        B[r][c] <= '0;
                                    end
                                end
                                state <= S_LOAD_A_REQ;
                            end

                            MODE_COMPUTE,
                            MODE_COMPUTE_STORE: begin
                                state <= S_START;
                            end

                            MODE_STORE: begin
                                mem_req_addr_reg <= cPtr;
                                state            <= S_STORE_SELECT;
                            end

                            default: begin
                                state <= S_RESP;
                            end
                        endcase
                    end
                end

                S_LOAD_A_REQ: begin
                    if (mem_req_valid && mem_req_ready)
                        state <= S_LOAD_A_RESP;
                end

                S_LOAD_A_RESP: begin
                    if (mem_resp_valid) begin
                        A[rowCnt][colCnt] <= mem_resp_data[7:0];

                        if ((rowCnt == N-1) && (colCnt == N-1)) begin
                            rowCnt           <= '0;
                            colCnt           <= '0;
                            mem_req_addr_reg <= bPtr;

                            if ((activeMode == MODE_FULL) || (activeMode == MODE_LOAD_AB))
                                state <= S_LOAD_B_REQ;
                            else
                                state <= S_RESP;

                        end else if (colCnt == N-1) begin
                            rowCnt           <= rowCnt + 1'b1;
                            colCnt           <= '0;
                            mem_req_addr_reg <= mem_req_addr_reg + 1;
                            state            <= S_LOAD_A_REQ;

                        end else begin
                            colCnt           <= colCnt + 1'b1;
                            mem_req_addr_reg <= mem_req_addr_reg + 1;
                            state            <= S_LOAD_A_REQ;
                        end
                    end
                end

                S_LOAD_B_REQ: begin
                    if (mem_req_valid && mem_req_ready)
                        state <= S_LOAD_B_RESP;
                end

                S_LOAD_B_RESP: begin
                    if (mem_resp_valid) begin
                        B[rowCnt][colCnt] <= mem_resp_data[7:0];

                        if ((rowCnt == N-1) && (colCnt == N-1)) begin
                            rowCnt <= '0;
                            colCnt <= '0;

                            if (activeMode == MODE_FULL)
                                state <= S_START;
                            else
                                state <= S_RESP;

                        end else if (colCnt == N-1) begin
                            rowCnt           <= rowCnt + 1'b1;
                            colCnt           <= '0;
                            mem_req_addr_reg <= mem_req_addr_reg + 1;
                            state            <= S_LOAD_B_REQ;

                        end else begin
                            colCnt           <= colCnt + 1'b1;
                            mem_req_addr_reg <= mem_req_addr_reg + 1;
                            state            <= S_LOAD_B_REQ;
                        end
                    end
                end

                S_START: begin
                    state <= S_WAIT;
                end

                S_WAIT: begin
                    if (core_done) begin
                        rowCnt           <= '0;
                        colCnt           <= '0;
                        mem_req_addr_reg <= cPtr;

                        if ((activeMode == MODE_FULL) || (activeMode == MODE_COMPUTE_STORE))
                            state <= S_STORE_SELECT;
                        else
                            state <= S_RESP;
                    end
                end

                S_STORE_SELECT: begin
                    cRaw_reg <= C[rowCnt][colCnt];
                    state    <= S_STORE_ACT;
                end

                S_STORE_ACT: begin
                    cAct_reg <= cAct_wire;
                    state    <= S_STORE_PACK;
                end

                S_STORE_PACK: begin
                    storeData64_reg <= {cAct_reg[31:0], cAct_reg[31:0]};
                    state <= S_STORE_C_REQ;
                end

                S_STORE_C_REQ: begin
                    if (mem_req_valid && mem_req_ready)
                        state <= S_STORE_C_WAIT;
                end

                S_STORE_C_WAIT: begin
                    if (mem_resp_valid) begin
                        if ((rowCnt == N-1) && (colCnt == N-1)) begin
                            state <= S_RESP;

                        end else if (colCnt == N-1) begin
                            rowCnt           <= rowCnt + 1'b1;
                            colCnt           <= '0;
                            mem_req_addr_reg <= mem_req_addr_reg + 4;
                            state            <= S_STORE_SELECT;

                        end else begin
                            colCnt           <= colCnt + 1'b1;
                            mem_req_addr_reg <= mem_req_addr_reg + 4;
                            state            <= S_STORE_SELECT;
                        end
                    end
                end

                S_RESP: begin
                    if (resp_valid && resp_ready)
                        state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
