`timescale 1ns/1ps

module tb_os8_wrapper_full;

    localparam int N     = 2;
    localparam int W     = 8;
    localparam int ACCW  = 32;
    localparam int XLEN  = 64;

    localparam logic [6:0] FUNCT_SET_A   = 7'd0;
    localparam logic [6:0] FUNCT_SET_B   = 7'd1;
    localparam logic [6:0] FUNCT_SET_C   = 7'd2;
    localparam logic [6:0] FUNCT_FULL    = 7'd3;
    localparam logic [6:0] FUNCT_ACT_CFG = 7'd7;

    localparam logic [4:0] MEM_READ  = 5'd0;
    localparam logic [4:0] MEM_WRITE = 5'd1;

    localparam logic [XLEN-1:0] A_BASE = 64'd100;
    localparam logic [XLEN-1:0] B_BASE = 64'd200;
    localparam logic [XLEN-1:0] C_BASE = 64'd300;

    logic clk;
    logic rst_n;

    logic                 cmd_valid;
    wire                  cmd_ready;
    logic [6:0]           cmd_funct;
    logic [XLEN-1:0]      cmd_rs1;
    logic [4:0]           cmd_rd;

    wire                  resp_valid;
    logic                 resp_ready;
    wire [4:0]            resp_rd;
    wire [XLEN-1:0]       resp_data;

    wire                  mem_req_valid;
    logic                 mem_req_ready;
    wire [XLEN-1:0]       mem_req_addr;
    wire [7:0]            mem_req_tag;
    wire [4:0]            mem_req_cmd;
    wire [2:0]            mem_req_size;
    wire [XLEN-1:0]       mem_req_data;

    logic                 mem_resp_valid;
    logic [7:0]           mem_resp_tag;
    logic [XLEN-1:0]      mem_resp_data;

    wire busy;

    /*
     * Byte-addressable testbench memory.
     */
    logic [7:0] mem [0:1023];

    /*
     * Pending memory request.
     *
     * The request is captured at a positive edge. The response is driven
     * at the following negative edge and sampled by the DUT at the next
     * positive edge.
     */
    logic                 pending_valid;
    logic                 pending_is_read;
    logic [XLEN-1:0]      pending_addr;
    logic [7:0]           pending_tag;

    integer pass_count;
    integer fail_count;
    integer read_count;
    integer store_count;

    logic signed [ACCW-1:0] stored_C00;
    logic signed [ACCW-1:0] stored_C01;
    logic signed [ACCW-1:0] stored_C10;
    logic signed [ACCW-1:0] stored_C11;

    /*
     * Observation signals for GTKWave.
     */
    wire [XLEN-1:0] observe_aPtr         = dut.aPtr;
    wire [XLEN-1:0] observe_bPtr         = dut.bPtr;
    wire [XLEN-1:0] observe_cPtr         = dut.cPtr;
    wire            observe_reluEnable  = dut.reluEnable;
    wire [4:0]      observe_shiftAmount = dut.shiftAmount;
    wire [2:0]      observe_opMode       = dut.opMode;
    wire            observe_start_pulse = dut.start_pulse;
    wire            observe_core_start  = dut.core_start;
    wire            observe_core_done   = dut.core_done;

    wire signed [W-1:0] observe_A00 = dut.A[0][0];
    wire signed [W-1:0] observe_A01 = dut.A[0][1];
    wire signed [W-1:0] observe_A10 = dut.A[1][0];
    wire signed [W-1:0] observe_A11 = dut.A[1][1];

    wire signed [W-1:0] observe_B00 = dut.B[0][0];
    wire signed [W-1:0] observe_B01 = dut.B[0][1];
    wire signed [W-1:0] observe_B10 = dut.B[1][0];
    wire signed [W-1:0] observe_B11 = dut.B[1][1];

    wire signed [ACCW-1:0] observe_C00 = dut.C[0][0];
    wire signed [ACCW-1:0] observe_C01 = dut.C[0][1];
    wire signed [ACCW-1:0] observe_C10 = dut.C[1][0];
    wire signed [ACCW-1:0] observe_C11 = dut.C[1][1];

    os8_wrapper #(
        .N    (N),
        .W    (W),
        .ACCW (ACCW),
        .XLEN (XLEN)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),

        .cmd_valid      (cmd_valid),
        .cmd_ready      (cmd_ready),
        .cmd_funct      (cmd_funct),
        .cmd_rs1        (cmd_rs1),
        .cmd_rd         (cmd_rd),

        .resp_valid     (resp_valid),
        .resp_ready     (resp_ready),
        .resp_rd        (resp_rd),
        .resp_data      (resp_data),

        .mem_req_valid  (mem_req_valid),
        .mem_req_ready  (mem_req_ready),
        .mem_req_addr   (mem_req_addr),
        .mem_req_tag    (mem_req_tag),
        .mem_req_cmd    (mem_req_cmd),
        .mem_req_size   (mem_req_size),
        .mem_req_data   (mem_req_data),

        .mem_resp_valid (mem_resp_valid),
        .mem_resp_tag   (mem_resp_tag),
        .mem_resp_data  (mem_resp_data),

        .busy           (busy)
    );

    always #5 clk = ~clk;

    task automatic send_cmd(
        input logic [6:0]      funct,
        input logic [XLEN-1:0] rs1_value,
        input logic [4:0]      rd_value
    );
        begin
            while (cmd_ready !== 1'b1)
                @(posedge clk);

            @(negedge clk);

            cmd_valid = 1'b1;
            cmd_funct = funct;
            cmd_rs1   = rs1_value;
            cmd_rd    = rd_value;

            @(posedge clk);
            @(negedge clk);

            cmd_valid = 1'b0;
            cmd_funct = '0;
            cmd_rs1   = '0;
            cmd_rd    = '0;
        end
    endtask

    task automatic check_result(
        input string                    result_name,
        input logic signed [ACCW-1:0]   actual,
        input logic signed [ACCW-1:0]   expected
    );
        begin
            if (actual === expected) begin
                $display(
                    "PASS: %s = %0d",
                    result_name,
                    actual
                );

                pass_count = pass_count + 1;
            end
            else begin
                $display(
                    "FAIL: %s expected %0d, received %0d",
                    result_name,
                    expected,
                    actual
                );

                fail_count = fail_count + 1;
            end
        end
    endtask

    /*
     * Capture requests at the positive clock edge.
     */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_valid   <= 1'b0;
            pending_is_read <= 1'b0;
            pending_addr    <= '0;
            pending_tag     <= '0;

            read_count      <= 0;
            store_count     <= 0;

            stored_C00      <= '0;
            stored_C01      <= '0;
            stored_C10      <= '0;
            stored_C11      <= '0;
        end
        else begin
            /*
             * The DUT has sampled the response at this positive edge.
             */
            if (pending_valid && mem_resp_valid)
                pending_valid <= 1'b0;

            /*
             * Capture a newly accepted request only when there is no
             * previous response still pending.
             */
            if (mem_req_valid &&
                mem_req_ready &&
                !pending_valid) begin

                pending_valid <= 1'b1;
                pending_addr  <= mem_req_addr;
                pending_tag   <= mem_req_tag;

                if (mem_req_cmd == MEM_READ) begin
                    pending_is_read <= 1'b1;
                    read_count      <= read_count + 1;

                    $display(
                        "READ REQUEST: addr=%0d data=%0d tag=%0d",
                        mem_req_addr,
                        $signed(mem[mem_req_addr]),
                        mem_req_tag
                    );
                end
                else if (mem_req_cmd == MEM_WRITE) begin
                    pending_is_read <= 1'b0;

                    /*
                     * One 32-bit C element is stored per request.
                     */
                    case (mem_req_addr)
                        C_BASE + 0: begin
                            stored_C00 <=
                                $signed(mem_req_data[31:0]);
                        end

                        C_BASE + 4: begin
                            stored_C01 <=
                                $signed(mem_req_data[31:0]);
                        end

                        C_BASE + 8: begin
                            stored_C10 <=
                                $signed(mem_req_data[31:0]);
                        end

                        C_BASE + 12: begin
                            stored_C11 <=
                                $signed(mem_req_data[31:0]);
                        end

                        default: begin
                            $display(
                                "WARNING: unexpected store address %0d",
                                mem_req_addr
                            );
                        end
                    endcase

                    /*
                     * Store the low 32 bits in the byte-addressable
                     * testbench memory.
                     */
                    mem[mem_req_addr + 0] <= mem_req_data[7:0];
                    mem[mem_req_addr + 1] <= mem_req_data[15:8];
                    mem[mem_req_addr + 2] <= mem_req_data[23:16];
                    mem[mem_req_addr + 3] <= mem_req_data[31:24];

                    $display(
                        "WRITE REQUEST %0d: addr=%0d data=%0d hex=0x%08h",
                        store_count,
                        mem_req_addr,
                        $signed(mem_req_data[31:0]),
                        mem_req_data[31:0]
                    );

                    if (store_count == 0) begin
                        $display("");
                        $display("A loaded by controller:");
                        $display(
                            "A = [[%0d, %0d], [%0d, %0d]]",
                            observe_A00,
                            observe_A01,
                            observe_A10,
                            observe_A11
                        );

                        $display("B loaded by controller:");
                        $display(
                            "B = [[%0d, %0d], [%0d, %0d]]",
                            observe_B00,
                            observe_B01,
                            observe_B10,
                            observe_B11
                        );

                        $display("C produced by systolic array:");
                        $display(
                            "C = [[%0d, %0d], [%0d, %0d]]",
                            observe_C00,
                            observe_C01,
                            observe_C10,
                            observe_C11
                        );
                        $display("");
                    end

                    store_count <= store_count + 1;
                end
                else begin
                    pending_valid   <= 1'b0;
                    pending_is_read <= 1'b0;

                    $display(
                        "FAIL: unsupported mem_req_cmd=%0d",
                        mem_req_cmd
                    );

                    fail_count = fail_count + 1;
                end
            end
        end
    end

    /*
     * Drive responses at the negative clock edge.
     *
     * The response remains stable until the following positive edge,
     * where it is sampled by the controller.
     */
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_resp_valid <= 1'b0;
            mem_resp_tag   <= '0;
            mem_resp_data  <= '0;
        end
        else begin
            mem_resp_valid <= 1'b0;
            mem_resp_tag   <= '0;
            mem_resp_data  <= '0;

            if (pending_valid) begin
                mem_resp_valid <= 1'b1;
                mem_resp_tag   <= pending_tag;

                if (pending_is_read) begin
                    mem_resp_data <= {
                        {(XLEN-W){mem[pending_addr][W-1]}},
                        mem[pending_addr]
                    };

                    $display(
                        "READ RESPONSE: addr=%0d data=%0d tag=%0d",
                        pending_addr,
                        $signed(mem[pending_addr]),
                        pending_tag
                    );
                end
                else begin
                    /*
                     * Store acknowledgement.
                     */
                    mem_resp_data <= '0;

                    $display(
                        "WRITE RESPONSE: addr=%0d tag=%0d",
                        pending_addr,
                        pending_tag
                    );
                end
            end
        end
    end

    initial begin : TEST_SEQUENCE
        integer i;
        integer timeout_cycles;

        clk              = 1'b0;
        rst_n            = 1'b0;

        cmd_valid        = 1'b0;
        cmd_funct        = '0;
        cmd_rs1          = '0;
        cmd_rd           = '0;

        resp_ready       = 1'b0;
        mem_req_ready    = 1'b1;

        mem_resp_valid   = 1'b0;
        mem_resp_tag     = '0;
        mem_resp_data    = '0;

        pending_valid    = 1'b0;
        pending_is_read  = 1'b0;
        pending_addr     = '0;
        pending_tag      = '0;

        pass_count       = 0;
        fail_count       = 0;
        read_count       = 0;
        store_count      = 0;

        stored_C00       = '0;
        stored_C01       = '0;
        stored_C10       = '0;
        stored_C11       = '0;

        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 8'd0;

        /*
         * Matrix A:
         *
         * [1 2]
         * [3 4]
         */
        mem[A_BASE + 0] = 8'sd1;
        mem[A_BASE + 1] = 8'sd2;
        mem[A_BASE + 2] = 8'sd3;
        mem[A_BASE + 3] = 8'sd4;

        /*
         * Matrix B:
         *
         * [5 6]
         * [7 8]
         */
        mem[B_BASE + 0] = 8'sd5;
        mem[B_BASE + 1] = 8'sd6;
        mem[B_BASE + 2] = 8'sd7;
        mem[B_BASE + 3] = 8'sd8;

        /*
         * Expected C:
         *
         * [19 22]
         * [43 50]
         */
        $dumpfile("os8_wrapper_full.vcd");
        $dumpvars(0, tb_os8_wrapper_full);

        repeat (5)
            @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        repeat (3)
            @(posedge clk);

        $display("");
        $display("Configuring accelerator...");

        send_cmd(
            FUNCT_SET_A,
            A_BASE,
            5'd0
        );

        send_cmd(
            FUNCT_SET_B,
            B_BASE,
            5'd0
        );

        send_cmd(
            FUNCT_SET_C,
            C_BASE,
            5'd0
        );

        /*
         * ReLU disabled and shift amount zero.
         */
        send_cmd(
            FUNCT_ACT_CFG,
            64'd0,
            5'd0
        );

        $display(
            "Pointers: A=%0d B=%0d C=%0d",
            observe_aPtr,
            observe_bPtr,
            observe_cPtr
        );

        /*
         * Full sequence:
         * load A → load B → compute → store C.
         */
        send_cmd(
            FUNCT_FULL,
            64'd0,
            5'd6
        );

        /*
         * Keep the response channel ready throughout operation.
         */
        @(negedge clk);
        resp_ready = 1'b1;

        timeout_cycles = 0;

        while ((resp_valid !== 1'b1) &&
               (timeout_cycles < 3000)) begin
            @(posedge clk);
            timeout_cycles = timeout_cycles + 1;
        end

        if (resp_valid !== 1'b1) begin
            $display(
                "FAIL: timeout waiting for final RoCC response"
            );

            fail_count = fail_count + 1;
        end
        else begin
            $display(
                "Final response received: rd=%0d data=0x%016h",
                resp_rd,
                resp_data
            );
        end

        @(posedge clk);
        @(negedge clk);

        resp_ready = 1'b0;

        repeat (5)
            @(posedge clk);

        $display("");
        $display("Checking loaded matrix A...");

        check_result(
            "A[0][0]",
            {{(ACCW-W){observe_A00[W-1]}}, observe_A00},
            32'sd1
        );

        check_result(
            "A[0][1]",
            {{(ACCW-W){observe_A01[W-1]}}, observe_A01},
            32'sd2
        );

        check_result(
            "A[1][0]",
            {{(ACCW-W){observe_A10[W-1]}}, observe_A10},
            32'sd3
        );

        check_result(
            "A[1][1]",
            {{(ACCW-W){observe_A11[W-1]}}, observe_A11},
            32'sd4
        );

        $display("");
        $display("Checking loaded matrix B...");

        check_result(
            "B[0][0]",
            {{(ACCW-W){observe_B00[W-1]}}, observe_B00},
            32'sd5
        );

        check_result(
            "B[0][1]",
            {{(ACCW-W){observe_B01[W-1]}}, observe_B01},
            32'sd6
        );

        check_result(
            "B[1][0]",
            {{(ACCW-W){observe_B10[W-1]}}, observe_B10},
            32'sd7
        );

        check_result(
            "B[1][1]",
            {{(ACCW-W){observe_B11[W-1]}}, observe_B11},
            32'sd8
        );

        $display("");
        $display("Checking stored matrix C...");

        check_result(
            "C[0][0]",
            stored_C00,
            32'sd19
        );

        check_result(
            "C[0][1]",
            stored_C01,
            32'sd22
        );

        check_result(
            "C[1][0]",
            stored_C10,
            32'sd43
        );

        check_result(
            "C[1][1]",
            stored_C11,
            32'sd50
        );

        if (read_count == 8) begin
            $display(
                "PASS: eight input memory reads were observed"
            );

            pass_count = pass_count + 1;
        end
        else begin
            $display(
                "FAIL: expected 8 reads, received %0d",
                read_count
            );

            fail_count = fail_count + 1;
        end

        if (store_count == 4) begin
            $display(
                "PASS: four C-memory writes were observed"
            );

            pass_count = pass_count + 1;
        end
        else begin
            $display(
                "FAIL: expected 4 stores, received %0d",
                store_count
            );

            fail_count = fail_count + 1;
        end

        if (resp_rd == 5'd6) begin
            $display("PASS: resp_rd = 6");
            pass_count = pass_count + 1;
        end
        else begin
            $display(
                "FAIL: expected resp_rd=6, received %0d",
                resp_rd
            );

            fail_count = fail_count + 1;
        end

        $display("");
        $display("========================================");
        $display("OS8 WRAPPER FULL-SEQUENCE TEST SUMMARY");
        $display("Pass count: %0d", pass_count);
        $display("Fail count: %0d", fail_count);
        $display("========================================");

        if (fail_count == 0)
            $display("FULL WRAPPER SEQUENCE: PASS");
        else
            $display("FULL WRAPPER SEQUENCE: FAIL");

        repeat (5)
            @(posedge clk);

        $finish;
    end

endmodule
