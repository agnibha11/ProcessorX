`timescale 1ns/1ps

module immgen_tb;

reg  [31:0] Instr;
wire [31:0] Imm;

// DUT
immgen dut (
    .Instr(Instr),
    .Imm(Imm)
);

// Statistics
integer test_count;
integer pass_count;
integer fail_count;
integer i;

// Random helper
reg [31:0] r;

// Temporary values
reg [11:0] imm12;
reg [12:0] imm13;
reg [19:0] imm20;
reg [20:0] imm21;
reg [31:0] expected;
reg [31:0] instr_tmp;

// -------------------------------
// Encode helpers
// -------------------------------

function [31:0] encode_i;
    input [11:0] imm;
    input [4:0]  rs1;
    input [2:0]  funct3;
    input [4:0]  rd;
    input [6:0]  opcode;
    begin
        encode_i = {imm, rs1, funct3, rd, opcode};
    end
endfunction

function [31:0] encode_s;
    input [11:0] imm;
    input [4:0]  rs2;
    input [4:0]  rs1;
    input [2:0]  funct3;
    input [6:0]  opcode;
    begin
        encode_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
    end
endfunction

function [31:0] encode_b;
    input [12:0] imm;
    input [4:0]  rs2;
    input [4:0]  rs1;
    input [2:0]  funct3;
    input [6:0]  opcode;
    begin
        encode_b = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
    end
endfunction

function [31:0] encode_u;
    input [19:0] imm;
    input [4:0]  rd;
    input [6:0]  opcode;
    begin
        encode_u = {imm, rd, opcode};
    end
endfunction

function [31:0] encode_j;
    input [20:0] imm;
    input [4:0]  rd;
    input [6:0]  opcode;
    begin
        encode_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
    end
endfunction

// -------------------------------
// Expected-value helpers
// -------------------------------

function [31:0] sext12;
    input [11:0] imm;
    begin
        sext12 = {{20{imm[11]}}, imm};
    end
endfunction

function [31:0] sext13;
    input [12:0] imm;
    begin
        sext13 = {{19{imm[12]}}, imm};
    end
endfunction

function [31:0] sext21;
    input [20:0] imm;
    begin
        sext21 = {{11{imm[20]}}, imm};
    end
endfunction

// -------------------------------
// Scoreboard task
// -------------------------------

task check;
    input [31:0] instr_val;
    input [31:0] exp_val;
    begin
        test_count = test_count + 1;
        Instr = instr_val;
        #1; // settle combinational logic

        if (Imm !== exp_val) begin
            fail_count = fail_count + 1;
            $display("FAIL test=%0d opcode=%b instr=%h exp=%h got=%h time=%0t",
                     test_count, Instr[6:0], Instr, exp_val, Imm, $time);
        end
        else begin
            pass_count = pass_count + 1;
            $display("PASS test=%0d opcode=%b instr=%h imm=%h",
                     test_count, Instr[6:0], Instr, Imm);
        end
    end
endtask

// -------------------------------
// Main test
// -------------------------------

initial begin
    $dumpfile("immgen_tb.vcd");
    $dumpvars(0, immgen_tb);

    test_count = 0;
    pass_count  = 0;
    fail_count  = 0;

    Instr = 32'b0;
    #1;

    // -----------------------
    // Directed I-type tests
    // -----------------------

    // ADDI +2047
    imm12 = 12'h7FF;
    instr_tmp = encode_i(imm12, 5'd2, 3'b000, 5'd1, 7'b0010011);
    check(instr_tmp, sext12(imm12));

    // ADDI -1
    imm12 = 12'hFFF;
    instr_tmp = encode_i(imm12, 5'd2, 3'b000, 5'd1, 7'b0010011);
    check(instr_tmp, sext12(imm12));

    // LW -8
    imm12 = 12'hFF8;
    instr_tmp = encode_i(imm12, 5'd3, 3'b010, 5'd4, 7'b0000011);
    check(instr_tmp, sext12(imm12));

    // JALR +16
    imm12 = 12'h010;
    instr_tmp = encode_i(imm12, 5'd5, 3'b000, 5'd1, 7'b1100111);
    check(instr_tmp, sext12(imm12));

    // ECALL (imm = 0)
    imm12 = 12'h000;
    instr_tmp = encode_i(imm12, 5'd0, 3'b000, 5'd0, 7'b1110011);
    check(instr_tmp, sext12(imm12));

    // EBREAK (imm = 1)
    imm12 = 12'h001;
    instr_tmp = encode_i(imm12, 5'd0, 3'b000, 5'd0, 7'b1110011);
    check(instr_tmp, sext12(imm12));

    // -----------------------
    // Directed S-type tests
    // -----------------------

    // SW +28
    imm12 = 12'd28;
    instr_tmp = encode_s(imm12, 5'd3, 5'd4, 3'b010, 7'b0100011);
    check(instr_tmp, sext12(imm12));

    // SH -16
    imm12 = 12'hFF0;
    instr_tmp = encode_s(imm12, 5'd3, 5'd4, 3'b001, 7'b0100011);
    check(instr_tmp, sext12(imm12));

    // -----------------------
    // Directed B-type tests
    // -----------------------

    // BEQ +16
    imm13 = 13'd16;   // must be even; bit0 is implicit 0
    instr_tmp = encode_b(imm13, 5'd2, 5'd1, 3'b000, 7'b1100011);
    check(instr_tmp, sext13(imm13));

    // BNE -8
    imm13 = 13'h1FF8; // -8 in 13-bit two's complement
    instr_tmp = encode_b(imm13, 5'd2, 5'd1, 3'b001, 7'b1100011);
    check(instr_tmp, sext13(imm13));

    // -----------------------
    // Directed U-type tests
    // -----------------------

    // LUI
    imm20 = 20'hABCDE;
    instr_tmp = encode_u(imm20, 5'd5, 7'b0110111);
    check(instr_tmp, {imm20, 12'b0});

    // AUIPC
    imm20 = 20'h12345;
    instr_tmp = encode_u(imm20, 5'd6, 7'b0010111);
    check(instr_tmp, {imm20, 12'b0});

    // -----------------------
    // Directed J-type tests
    // -----------------------

    // JAL +2048
    imm21 = 21'd2048;
    instr_tmp = encode_j(imm21, 5'd1, 7'b1101111);
    check(instr_tmp, sext21(imm21));

    // JAL -8
    imm21 = 21'h1FFFF8; // -8 in 21-bit two's complement
    instr_tmp = encode_j(imm21, 5'd1, 7'b1101111);
    check(instr_tmp, sext21(imm21));

    // -----------------------
    // Default / invalid opcode
    // -----------------------

    Instr = 32'h00000000; // opcode = 0000000, should hit default
    test_count = test_count + 1;
    #1;
    if (Imm !== 32'b0) begin
        fail_count = fail_count + 1;
        $display("FAIL test=%0d invalid-opcode instr=%h exp=%h got=%h time=%0t",
                 test_count, Instr, 32'b0, Imm, $time);
    end else begin
        pass_count = pass_count + 1;
        $display("PASS test=%0d invalid-opcode instr=%h imm=%h",
                 test_count, Instr, Imm);
    end

    // -----------------------
    // Random testing
    // -----------------------
    for (i = 0; i < 500; i = i + 1) begin
        r = $random;

        case (r[2:0])
            3'd0: begin
                // I-type
                imm12 = r[11:0];
                instr_tmp = encode_i(imm12, r[16:12], 3'b000, r[21:17], 7'b0010011);
                check(instr_tmp, sext12(imm12));
            end

            3'd1: begin
                // S-type
                imm12 = r[11:0];
                instr_tmp = encode_s(imm12, r[16:12], r[21:17], 3'b010, 7'b0100011);
                check(instr_tmp, sext12(imm12));
            end

            3'd2: begin
                // B-type
                imm13 = {r[12:1], 1'b0};
                instr_tmp = encode_b(imm13, r[16:12], r[21:17], 3'b000, 7'b1100011);
                check(instr_tmp, sext13(imm13));
            end

            3'd3: begin
                // U-type
                imm20 = r[19:0];
                instr_tmp = encode_u(imm20, r[11:7], 7'b0110111);
                check(instr_tmp, {imm20, 12'b0});
            end

            default: begin
                // J-type
                imm21 = {r[19:0], 1'b0};
                instr_tmp = encode_j(imm21, r[11:7], 7'b1101111);
                check(instr_tmp, sext21(imm21));
            end
        endcase
    end

    // Summary
    $display("------------------------------------");
    $display("IMMGEN TEST SUMMARY");
    $display("Total Tests : %0d", test_count);
    $display("Passed      : %0d", pass_count);
    $display("Failed      : %0d", fail_count);
    $display("------------------------------------");

    if (fail_count == 0)
        $display("ALL TESTS PASSED");
    else
        $display("SOME TESTS FAILED");

    #20;
    $finish;
end

endmodule