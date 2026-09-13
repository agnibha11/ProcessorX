`timescale 1ns/1ps

module alu_tb;

    // DUT inputs
    reg  [31:0] A, B;
    reg  [4:0]  ALUControl;

    // DUT outputs
    wire [31:0] Result;
    wire Z;

    // Instantiate DUT
    alu dut (
        .A(A),
        .B(B),
        .ALUControl(ALUControl),
        .Result(Result),
        .Z(Z)
    );

    // Same encoding as the ALU
    localparam ADD   = 5'b00000;
    localparam SUB   = 5'b00001;
    localparam AND   = 5'b00010;
    localparam OR    = 5'b00011;
    localparam XOR   = 5'b00100;
    localparam SLL   = 5'b00101;
    localparam SRL   = 5'b00110;
    localparam SRA   = 5'b00111;
    localparam equal = 5'b01000;
    localparam SLT   = 5'b01001;
    localparam SLTU  = 5'b01010;
    localparam greater_equal      = 5'b01011;
    localparam greater_equal_sign = 5'b01100;
    localparam JALR  = 5'b01101;
    localparam not_equal = 5'b01110;
    localparam MUL   = 5'b01111;
    localparam MULH  = 5'b10000;
    localparam MULHSU= 5'b10001;
    localparam MULHU = 5'b10010;
    localparam DIV   = 5'b10011;
    localparam DIVU  = 5'b10100;
    localparam REM   = 5'b10101;
    localparam REMU  = 5'b10110;

    integer test_count;
    integer pass_count;
    integer fail_count;
    integer i;

    reg [31:0] expected_result;
    reg        expected_z;

    // Golden model
    function [31:0] golden_result;
        input [31:0] a;
        input [31:0] b;
        input [4:0]  ctrl;

        reg signed [63:0] prod_ss;
        reg signed [63:0] prod_su;
        reg signed [63:0] prod_uu;
        begin
            prod_ss = $signed(a) * $signed(b);
            prod_su = $signed(a) * $signed({1'b0, b});
            prod_uu = a * b;

            case (ctrl)
                ADD:  golden_result = a + b;
                SUB:  golden_result = a - b;
                AND:  golden_result = a & b;
                OR:   golden_result = a | b;
                XOR:  golden_result = a ^ b;
                SLL:  golden_result = a << b[4:0];
                SRL:  golden_result = a >> b[4:0];
                SRA:  golden_result = $signed(a) >>> b[4:0];

                equal:  golden_result = (a == b) ? 32'd1 : 32'd0;
                SLTU:   golden_result = (a < b) ? 32'd1 : 32'd0;
                SLT:    golden_result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
                greater_equal:
                        golden_result = (a >= b) ? 32'd1 : 32'd0;
                greater_equal_sign:
                        golden_result = ($signed(a) >= $signed(b)) ? 32'd1 : 32'd0;

                JALR:   golden_result = ($signed(a) + $signed(b)) & 32'hFFFFFFFE;
                not_equal:
                        golden_result = (a != b) ? 32'd1 : 32'd0;

                MUL:    golden_result = prod_ss[31:0];
                MULH:   golden_result = prod_ss[63:32];
                MULHSU: golden_result = prod_su[63:32];
                MULHU:  golden_result = prod_uu[63:32];

                DIV: begin
                    if (b == 0)
                        golden_result = 32'hFFFFFFFF;
                    else if (a == 32'h80000000 && b == 32'hFFFFFFFF)
                        golden_result = 32'h80000000;
                    else
                        golden_result = $signed(a) / $signed(b);
                end

                DIVU: begin
                    if (b == 0)
                        golden_result = 32'hFFFFFFFF;
                    else
                        golden_result = a / b;
                end

                REM: begin
                    if (b == 0)
                        golden_result = a;
                    else if (a == 32'h80000000 && b == 32'hFFFFFFFF)
                        golden_result = 32'h00000000;
                    else
                        golden_result = $signed(a) % $signed(b);
                end

                REMU: begin
                    if (b == 0)
                        golden_result = a;
                    else
                        golden_result = a % b;
                end

                default:
                    golden_result = 32'hXXXXXXXX;
            endcase
        end
    endfunction

    // Scoreboard task
    task score_board;
        input [31:0] ta;
        input [31:0] tb;
        input [4:0]  tctrl;
        begin
            test_count = test_count + 1;

            #10; // allow combinational logic to settle

            expected_result = golden_result(ta, tb, tctrl);
            expected_z      = ~|expected_result;

            if ((Result !== expected_result) || (Z !== expected_z)) begin
                fail_count = fail_count + 1;
                $display("FAIL  test=%0d  ctrl=%b  A=%h  B=%h  expected=%h  got=%h  expected_Z=%b  got_Z=%b  time=%0t",
                         test_count, tctrl, ta, tb, expected_result, Result, expected_z, Z, $time);
            end
            else begin
                pass_count = pass_count + 1;
                $display("PASS  test=%0d  ctrl=%b  A=%h  B=%h  result=%h  Z=%b",
                         test_count, tctrl, ta, tb, Result, Z);
            end
        end
    endtask

    // Test sequence
    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);

        test_count = 0;
        pass_count  = 0;
        fail_count  = 0;

        // ----------------------------
        // Directed tests for RV32IM
        // ----------------------------

        // MUL
        A = 32'd6; B = 32'd7; ALUControl = MUL;
        score_board(A, B, ALUControl);

        // MULH
        A = 32'h80000000; B = 32'd2; ALUControl = MULH;
        score_board(A, B, ALUControl);

        // MULHSU
        A = 32'hFFFFFFFE; B = 32'd10; ALUControl = MULHSU;
        score_board(A, B, ALUControl);

        // MULHU
        A = 32'hFFFFFFFF; B = 32'hFFFFFFFF; ALUControl = MULHU;
        score_board(A, B, ALUControl);

        // DIV
        A = 32'd20; B = 32'd6; ALUControl = DIV;
        score_board(A, B, ALUControl);

        // DIV by zero
        A = 32'd12345678; B = 32'd0; ALUControl = DIV;
        score_board(A, B, ALUControl);

        // DIV overflow case: INT_MIN / -1
        A = 32'h80000000; B = 32'hFFFFFFFF; ALUControl = DIV;
        score_board(A, B, ALUControl);

        // DIVU
        A = 32'd20; B = 32'd6; ALUControl = DIVU;
        score_board(A, B, ALUControl);

        // REM
        A = 32'd20; B = 32'd6; ALUControl = REM;
        score_board(A, B, ALUControl);

        // REM by zero
        A = 32'hDEADBEEF; B = 32'd0; ALUControl = REM;
        score_board(A, B, ALUControl);

        // REM overflow case: INT_MIN % -1
        A = 32'h80000000; B = 32'hFFFFFFFF; ALUControl = REM;
        score_board(A, B, ALUControl);

        // REMU
        A = 32'd20; B = 32'd6; ALUControl = REMU;
        score_board(A, B, ALUControl);

        // ----------------------------
        // Random testing
        // ----------------------------
        for (i = 0; i < 3000; i = i + 1) begin
            case ($unsigned($random) % 23)
                0:  ALUControl = ADD;
                1:  ALUControl = SUB;
                2:  ALUControl = AND;
                3:  ALUControl = OR;
                4:  ALUControl = XOR;
                5:  ALUControl = SLL;
                6:  ALUControl = SRL;
                7:  ALUControl = SRA;
                8:  ALUControl = equal;
                9:  ALUControl = SLT;
                10: ALUControl = SLTU;
                11: ALUControl = greater_equal;
                12: ALUControl = greater_equal_sign;
                13: ALUControl = JALR;
                14: ALUControl = not_equal;
                15: ALUControl = MUL;
                16: ALUControl = MULH;
                17: ALUControl = MULHSU;
                18: ALUControl = MULHU;
                19: ALUControl = DIV;
                20: ALUControl = DIVU;
                21: ALUControl = REM;
                22: ALUControl = REMU;
                default: ALUControl = ADD;
            endcase

            A = $random;
            B = $random;

            score_board(A, B, ALUControl);
        end

        // Summary of Results
        $display("--------------------------------------------------");
        $display("ALU TEST SUMMARY");
        $display("Total tests : %0d", test_count);
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);
        $display("--------------------------------------------------");

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        #10;
        $finish;
    end

endmodule