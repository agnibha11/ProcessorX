`timescale 1ns/1ps

module controlunit_tb;

    // DUT input
    reg [31:0] Instr;

    // DUT outputs
    wire [4:0] ALUControl;
    wire [2:0] dmemMode;
    wire [1:0] regSEL, pcSEL;
    wire dmemWE, dmemRE, regWE, rs1SEL, rs2SEL;

    // Instantiate DUT
    controlunit dut (
        .Instr(Instr),
        .ALUControl(ALUControl),
        .dmemMode(dmemMode),
        .regSEL(regSEL),
        .pcSEL(pcSEL),
        .dmemWE(dmemWE),
        .dmemRE(dmemRE),
        .regWE(regWE),
        .rs1SEL(rs1SEL),
        .rs2SEL(rs2SEL)
    );

    // Must match DUT encodings
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

    localparam ERR   = 5'b11111;

    integer test_count;
    integer pass_count;
    integer fail_count;
    integer i;

    // ------------------------------------------------------------
    // Instruction encoders
    // ------------------------------------------------------------
    function [31:0] enc_r;
        input [6:0] funct7;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            enc_r = {funct7, rs2, rs1, funct3, rd, opcode};
        end
    endfunction

    function [31:0] enc_i;
        input [11:0] imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            enc_i = {imm, rs1, funct3, rd, opcode};
        end
    endfunction

    function [31:0] enc_s;
        input [11:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [6:0] opcode;
        begin
            enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
        end
    endfunction

    function [31:0] enc_b;
        input [12:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [6:0] opcode;
        begin
            enc_b = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
        end
    endfunction

    function [31:0] enc_u;
        input [19:0] imm;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            enc_u = {imm, rd, opcode};
        end
    endfunction

    function [31:0] enc_j;
        input [20:0] imm;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
        end
    endfunction

    // ------------------------------------------------------------
    // Check task
    // ------------------------------------------------------------
    task check_ctrl;
        input [31:0] instr;
        input [4:0]  exp_alu;
        input [2:0]  exp_dmemMode;
        input [1:0]  exp_regSEL;
        input [1:0]  exp_pcSEL;
        input        exp_dmemWE;
        input        exp_dmemRE;
        input        exp_regWE;
        input        exp_rs1SEL;
        input        exp_rs2SEL;
        begin
            Instr = instr;
            #1; // allow combinational decode to settle

            test_count = test_count + 1;

            if ((ALUControl !== exp_alu) ||
                (dmemMode   !== exp_dmemMode) ||
                (regSEL     !== exp_regSEL) ||
                (pcSEL      !== exp_pcSEL) ||
                (dmemWE     !== exp_dmemWE) ||
                (dmemRE     !== exp_dmemRE) ||
                (regWE      !== exp_regWE) ||
                (rs1SEL     !== exp_rs1SEL) ||
                (rs2SEL     !== exp_rs2SEL)) begin

                fail_count = fail_count + 1;
                $display("FAIL  test=%0d  Instr=%h", test_count, instr);
                $display("      exp: ALU=%05b dmemMode=%03b regSEL=%b pcSEL=%b dmemWE=%b dmemRE=%b regWE=%b rs1SEL=%b rs2SEL=%b",
                         exp_alu, exp_dmemMode, exp_regSEL, exp_pcSEL, exp_dmemWE, exp_dmemRE, exp_regWE, exp_rs1SEL, exp_rs2SEL);
                $display("      got: ALU=%05b dmemMode=%03b regSEL=%b pcSEL=%b dmemWE=%b dmemRE=%b regWE=%b rs1SEL=%b rs2SEL=%b",
                         ALUControl, dmemMode, regSEL, pcSEL, dmemWE, dmemRE, regWE, rs1SEL, rs2SEL);
            end
            else begin
                pass_count = pass_count + 1;
                $display("PASS  test=%0d  Instr=%h", test_count, instr);
            end
        end
    endtask

    // ------------------------------------------------------------
    // Main test sequence
    // ------------------------------------------------------------
    initial begin
        $dumpfile("controlunit_tb.vcd");
        $dumpvars(0, controlunit_tb);

        test_count = 0;
        pass_count  = 0;
        fail_count  = 0;

        Instr = 32'h00000013;
        #1;

        // --------------------------------------------------------
        // LUI
        // --------------------------------------------------------
        check_ctrl(
            enc_u(20'hABCDE, 5'd9, 7'b0110111),
            ADD, 3'b000, 2'b10, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0
        );

        // --------------------------------------------------------
        // AUIPC
        // --------------------------------------------------------
        check_ctrl(
            enc_u(20'h12345, 5'd8, 7'b0010111),
            ADD, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1
        );

        // --------------------------------------------------------
        // JAL
        // --------------------------------------------------------
        check_ctrl(
            enc_j(21'h1A2B4, 5'd1, 7'b1101111),
            ADD, 3'b000, 2'b11, 2'b10, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0
        );

        // --------------------------------------------------------
        // JALR
        // --------------------------------------------------------
        check_ctrl(
            enc_i(12'h7F8, 5'd2, 3'b000, 5'd1, 7'b1100111),
            JALR, 3'b000, 2'b11, 2'b01, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1
        );

        // --------------------------------------------------------
        // R-type legal operations
        // opcode = 0110011
        // --------------------------------------------------------
        check_ctrl(enc_r(7'b0000000, 5'd3, 5'd2, 3'h0, 5'd1, 7'b0110011),
                   ADD, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // ADD

        check_ctrl(enc_r(7'b0100000, 5'd3, 5'd2, 3'h0, 5'd1, 7'b0110011),
                   SUB, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // SUB

        check_ctrl(enc_r(7'b0000000, 5'd3, 5'd2, 3'h4, 5'd1, 7'b0110011),
                   XOR, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // XOR

        check_ctrl(enc_r(7'b0000000, 5'd3, 5'd2, 3'h6, 5'd1, 7'b0110011),
                   OR,  3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // OR

        check_ctrl(enc_r(7'b0000000, 5'd3, 5'd2, 3'h7, 5'd1, 7'b0110011),
                   AND, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // AND

        check_ctrl(enc_r(7'b0000000, 5'd3, 5'd2, 3'h1, 5'd1, 7'b0110011),
                   SLL, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // SLL

        check_ctrl(enc_r(7'b0000000, 5'd3, 5'd2, 3'h5, 5'd1, 7'b0110011),
                   SRL, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // SRL

        check_ctrl(enc_r(7'b0100000, 5'd3, 5'd2, 3'h5, 5'd1, 7'b0110011),
                   SRA, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // SRA

        check_ctrl(enc_r(7'b0000000, 5'd3, 5'd2, 3'h2, 5'd1, 7'b0110011),
                   SLT, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // SLT

        check_ctrl(enc_r(7'b0000000, 5'd3, 5'd2, 3'h3, 5'd1, 7'b0110011),
                   SLTU, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // SLTU

        // --------------------------------------------------------
        // M extension legal operations
        // opcode = 0110011, funct7 = 0000001
        // --------------------------------------------------------
        check_ctrl(enc_r(7'b0000001, 5'd6, 5'd5, 3'h0, 5'd4, 7'b0110011),
                   MUL, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // MUL

        check_ctrl(enc_r(7'b0000001, 5'd6, 5'd5, 3'h1, 5'd4, 7'b0110011),
                   MULH, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // MULH

        check_ctrl(enc_r(7'b0000001, 5'd6, 5'd5, 3'h2, 5'd4, 7'b0110011),
                   MULHSU, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // MULHSU

        check_ctrl(enc_r(7'b0000001, 5'd6, 5'd5, 3'h3, 5'd4, 7'b0110011),
                   MULHU, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // MULHU

        check_ctrl(enc_r(7'b0000001, 5'd6, 5'd5, 3'h4, 5'd4, 7'b0110011),
                   DIV, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // DIV

        check_ctrl(enc_r(7'b0000001, 5'd6, 5'd5, 3'h5, 5'd4, 7'b0110011),
                   DIVU, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // DIVU

        check_ctrl(enc_r(7'b0000001, 5'd6, 5'd5, 3'h6, 5'd4, 7'b0110011),
                   REM, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // REM

        check_ctrl(enc_r(7'b0000001, 5'd6, 5'd5, 3'h7, 5'd4, 7'b0110011),
                   REMU, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0); // REMU

        // --------------------------------------------------------
        // I-type ALU operations
        // opcode = 0010011
        // --------------------------------------------------------
        check_ctrl(enc_i(12'h123, 5'd2, 3'h0, 5'd1, 7'b0010011),
                   ADD, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // ADDI

        check_ctrl(enc_i(12'h123, 5'd2, 3'h4, 5'd1, 7'b0010011),
                   XOR, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // XORI

        check_ctrl(enc_i(12'h123, 5'd2, 3'h6, 5'd1, 7'b0010011),
                   OR,  3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // ORI

        check_ctrl(enc_i(12'h123, 5'd2, 3'h7, 5'd1, 7'b0010011),
                   AND, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // ANDI

        check_ctrl(enc_i(12'h123, 5'd2, 3'h2, 5'd1, 7'b0010011),
                   SLT, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // SLTI

        check_ctrl(enc_i(12'h123, 5'd2, 3'h3, 5'd1, 7'b0010011),
                   SLTU, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // SLTIU

        // Shift-immediate encodings:
        check_ctrl(enc_i(12'h003, 5'd2, 3'h1, 5'd1, 7'b0010011),
                   SLL, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // SLLI

        check_ctrl(enc_i(12'h003, 5'd2, 3'h5, 5'd1, 7'b0010011),
                   SRL, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // SRLI

        check_ctrl(enc_i(12'h403, 5'd2, 3'h5, 5'd1, 7'b0010011),
                   SRA, 3'b000, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // SRAI

        // --------------------------------------------------------
        // Loads
        // opcode = 0000011
        // --------------------------------------------------------
        check_ctrl(enc_i(12'h010, 5'd2, 3'h0, 5'd1, 7'b0000011),
                   ADD, 3'b100, 2'b00, 2'b00, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1); // LB

        check_ctrl(enc_i(12'h010, 5'd2, 3'h1, 5'd1, 7'b0000011),
                   ADD, 3'b010, 2'b00, 2'b00, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1); // LH

        check_ctrl(enc_i(12'h010, 5'd2, 3'h2, 5'd1, 7'b0000011),
                   ADD, 3'b000, 2'b00, 2'b00, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1); // LW

        check_ctrl(enc_i(12'h010, 5'd2, 3'h4, 5'd1, 7'b0000011),
                   ADD, 3'b011, 2'b00, 2'b00, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1); // LBU

        check_ctrl(enc_i(12'h010, 5'd2, 3'h5, 5'd1, 7'b0000011),
                   ADD, 3'b001, 2'b00, 2'b00, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1); // LHU

        // Illegal load funct3 -> default dmemMode = 111
        check_ctrl(enc_i(12'h010, 5'd2, 3'h3, 5'd1, 7'b0000011),
                   ADD, 3'b111, 2'b00, 2'b00, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1);

        // --------------------------------------------------------
        // Stores
        // opcode = 0100011
        // --------------------------------------------------------
        check_ctrl(enc_s(12'h020, 5'd3, 5'd2, 3'h0, 7'b0100011),
                   ADD, 3'b011, 2'b00, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1); // SB

        check_ctrl(enc_s(12'h020, 5'd3, 5'd2, 3'h1, 7'b0100011),
                   ADD, 3'b001, 2'b00, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1); // SH

        check_ctrl(enc_s(12'h020, 5'd3, 5'd2, 3'h2, 7'b0100011),
                   ADD, 3'b000, 2'b00, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1); // SW

        // Illegal store funct3 -> default dmemMode = 111
        check_ctrl(enc_s(12'h020, 5'd3, 5'd2, 3'h3, 7'b0100011),
                   ADD, 3'b111, 2'b00, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1);

        // --------------------------------------------------------
        // Branches
        // opcode = 1100011
        // pcSEL = 11, branch decision is made outside the control unit
        // --------------------------------------------------------
        check_ctrl(enc_b(13'h010, 5'd3, 5'd2, 3'h0, 7'b1100011),
                   equal, 3'b000, 2'b00, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // BEQ

        check_ctrl(enc_b(13'h010, 5'd3, 5'd2, 3'h1, 7'b1100011),
                   not_equal, 3'b000, 2'b00, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // BNE

        check_ctrl(enc_b(13'h010, 5'd3, 5'd2, 3'h4, 7'b1100011),
                   SLT, 3'b000, 2'b00, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // BLT

        check_ctrl(enc_b(13'h010, 5'd3, 5'd2, 3'h5, 7'b1100011),
                   greater_equal_sign, 3'b000, 2'b00, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // BGE

        check_ctrl(enc_b(13'h010, 5'd3, 5'd2, 3'h6, 7'b1100011),
                   SLTU, 3'b000, 2'b00, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // BLTU

        check_ctrl(enc_b(13'h010, 5'd3, 5'd2, 3'h7, 7'b1100011),
                   greater_equal, 3'b000, 2'b00, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // BGEU

        // Illegal branch funct3 -> ALUControl defaults to ERR, pcSEL still 11
        check_ctrl(enc_b(13'h010, 5'd3, 5'd2, 3'h2, 7'b1100011),
                   ERR, 3'b000, 2'b00, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);

        // --------------------------------------------------------
        // Illegal opcode sanity check
        // This will FAIL unless your RTL drives safe defaults for
        // unsupported opcodes.
        // --------------------------------------------------------
        check_ctrl(32'h00000000,
                   ERR, 3'b000, 2'b00, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);

        // --------------------------------------------------------
        // Summary
        // --------------------------------------------------------
        $display("--------------------------------------------------");
        $display("CONTROL UNIT TEST SUMMARY");
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