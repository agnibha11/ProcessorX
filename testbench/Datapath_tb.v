`timescale 1ns/1ps

module datapath_tb;

// DUT inputs
reg clk, reset;
reg regWE, rs1SEL, rs2SEL, halt;
reg [1:0] pcSEL, regSEL;
reg [4:0] ALUControl;
reg [31:0] Instr, dmemData;

// DUT outputs
wire [31:0] pc, ALUResult, dmemWriteData;

// DUT
datapath dut (
    .clk(clk),
    .reset(reset),
    .regWE(regWE),
    .rs1SEL(rs1SEL),
    .rs2SEL(rs2SEL),
    .halt(halt),
    .pcSEL(pcSEL),
    .regSEL(regSEL),
    .ALUControl(ALUControl),
    .Instr(Instr),
    .dmemData(dmemData),
    .pc(pc),
    .ALUResult(ALUResult),
    .dmemWriteData(dmemWriteData)
);

// ALU control encodings
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

localparam MUL    = 5'b01111;
localparam MULH   = 5'b10000;
localparam MULHSU = 5'b10001;
localparam MULHU  = 5'b10010;
localparam DIV    = 5'b10011;
localparam DIVU   = 5'b10100;
localparam REM    = 5'b10101;
localparam REMU   = 5'b10110;

// PC select encodings
localparam PC_PLUS4  = 2'b00;
localparam PC_ALU    = 2'b01;
localparam PC_IMM    = 2'b10;
localparam PC_BRANCH = 2'b11;

// Writeback select encodings
localparam WB_DMEM = 2'b00;
localparam WB_ALU  = 2'b01;
localparam WB_IMM  = 2'b10;
localparam WB_PC4  = 2'b11;

// Common opcodes
localparam OPC_RTYPE = 7'b0110011;
localparam OPC_ITYPE = 7'b0010011;
localparam OPC_LOAD  = 7'b0000011;
localparam OPC_STORE = 7'b0100011;
localparam OPC_BRANCH = 7'b1100011;
localparam OPC_LUI   = 7'b0110111;
localparam OPC_AUIPC = 7'b0010111;
localparam OPC_JAL   = 7'b1101111;
localparam OPC_JALR  = 7'b1100111;

// Golden state
reg [31:0] golden_regs [0:31];
reg [31:0] golden_pc;
reg [31:0] saved_mem_word;

integer i;
integer test_count;
integer pass_count;
integer fail_count;

// Clock
initial clk = 1'b0;
always #5 clk = ~clk;

// ----------------------------
// Instruction encoders
// ----------------------------
function [31:0] mkR;
    input [6:0] funct7;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    input [4:0] rd;
    input [6:0] opcode;
    begin
        mkR = {funct7, rs2, rs1, funct3, rd, opcode};
    end
endfunction

function [31:0] mkI;
    input [31:0] imm;
    input [4:0] rs1;
    input [2:0] funct3;
    input [4:0] rd;
    input [6:0] opcode;
    begin
        mkI = {imm[11:0], rs1, funct3, rd, opcode};
    end
endfunction

function [31:0] mkS;
    input [31:0] imm;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    input [6:0] opcode;
    begin
        mkS = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
    end
endfunction

function [31:0] mkB;
    input [31:0] imm;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    input [6:0] opcode;
    begin
        mkB = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
    end
endfunction

function [31:0] mkU;
    input [31:0] imm;
    input [4:0] rd;
    input [6:0] opcode;
    begin
        mkU = {imm[31:12], rd, opcode};
    end
endfunction

function [31:0] mkJ;
    input [31:0] imm;
    input [4:0] rd;
    input [6:0] opcode;
    begin
        mkJ = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
    end
endfunction

// ----------------------------
// Immediate decoder
// ----------------------------
function [31:0] imm_decode;
    input [31:0] instr;
    begin
        case (instr[6:0])
            OPC_ITYPE,
            OPC_LOAD,
            OPC_JALR:
                imm_decode = {{20{instr[31]}}, instr[31:20]};

            OPC_STORE:
                imm_decode = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            OPC_BRANCH:
                imm_decode = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

            OPC_LUI,
            OPC_AUIPC:
                imm_decode = {instr[31:12], 12'b0};

            OPC_JAL:
                imm_decode = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

            default:
                imm_decode = 32'b0;
        endcase
    end
endfunction

// ----------------------------
// Golden ALU
// ----------------------------
function [31:0] golden_alu;
    input [31:0] a;
    input [31:0] b;
    input [4:0]  ctrl;

    reg signed [63:0] prod_ss;
    reg signed [63:0] prod_su;
    reg [63:0]        prod_uu;
    begin
        prod_ss = $signed(a) * $signed(b);
        prod_su = $signed(a) * $signed({1'b0, b});
        prod_uu = a * b;

        case (ctrl)
            ADD:  golden_alu = a + b;
            SUB:  golden_alu = a - b;
            AND:  golden_alu = a & b;
            OR:   golden_alu = a | b;
            XOR:  golden_alu = a ^ b;
            SLL:  golden_alu = a << b[4:0];
            SRL:  golden_alu = a >> b[4:0];
            SRA:  golden_alu = $signed(a) >>> b[4:0];

            equal: golden_alu = (a == b) ? 32'd1 : 32'd0;
            SLTU:  golden_alu = (a < b) ? 32'd1 : 32'd0;
            SLT:   golden_alu = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;

            greater_equal:
                golden_alu = (a >= b) ? 32'd1 : 32'd0;

            greater_equal_sign:
                golden_alu = ($signed(a) >= $signed(b)) ? 32'd1 : 32'd0;

            JALR:
                golden_alu = ($signed(a) + $signed(b)) & 32'hFFFFFFFE;

            not_equal:
                golden_alu = (a != b) ? 32'd1 : 32'd0;

            MUL:
                golden_alu = prod_ss[31:0];

            MULH:
                golden_alu = prod_ss[63:32];

            MULHSU:
                golden_alu = prod_su[63:32];

            MULHU:
                golden_alu = prod_uu[63:32];

            DIV: begin
                if (b == 0)
                    golden_alu = 32'hFFFFFFFF;
                else if (a == 32'h80000000 && b == 32'hFFFFFFFF)
                    golden_alu = 32'h80000000;
                else
                    golden_alu = $signed(a) / $signed(b);
            end

            DIVU: begin
                if (b == 0)
                    golden_alu = 32'hFFFFFFFF;
                else
                    golden_alu = a / b;
            end

            REM: begin
                if (b == 0)
                    golden_alu = a;
                else if (a == 32'h80000000 && b == 32'hFFFFFFFF)
                    golden_alu = 32'h00000000;
                else
                    golden_alu = $signed(a) % $signed(b);
            end

            REMU: begin
                if (b == 0)
                    golden_alu = a;
                else
                    golden_alu = a % b;
            end

            default:
                golden_alu = 32'hXXXXXXXX;
        endcase
    end
endfunction

// ----------------------------
// Scoreboard task
// ----------------------------
task run_test;
    input [31:0] instr_i;
    input [31:0] dmem_i;
    input regWE_i;
    input rs1SEL_i;
    input rs2SEL_i;
    input [1:0] pcSEL_i;
    input [1:0] regSEL_i;
    input [4:0] aluCtrl_i;
    input check_alu_i;
    input check_dmem_i;

    reg [31:0] imm;
    reg [31:0] cur_pc;
    reg [31:0] a_val, b_val;
    reg [31:0] alu_exp;
    reg [31:0] pc4_exp, pcimm_exp, branch_exp, pc_next_exp;
    reg [31:0] wb_exp;
    reg [31:0] rs2_exp;
    begin
        test_count = test_count + 1;

        // Drive DUT
        Instr      = instr_i;
        dmemData   = dmem_i;
        regWE      = regWE_i;
        rs1SEL     = rs1SEL_i;
        rs2SEL     = rs2SEL_i;
        pcSEL      = pcSEL_i;
        regSEL     = regSEL_i;
        ALUControl = aluCtrl_i;

        // HALT is derived locally from the instruction word in this datapath TB
        halt = (instr_i == 32'hFFFFFFFF);

        #1; // combinational settle

        cur_pc = golden_pc;
        imm    = imm_decode(instr_i);

        a_val = rs1SEL_i ? cur_pc : golden_regs[instr_i[19:15]];
        b_val = rs2SEL_i ? imm    : golden_regs[instr_i[24:20]];

        alu_exp  = golden_alu(a_val, b_val, aluCtrl_i);

        pc4_exp   = cur_pc + 32'd4;
        pcimm_exp = cur_pc + imm;
        branch_exp = alu_exp[0] ? pcimm_exp : pc4_exp;

        case (pcSEL_i)
            PC_PLUS4:  pc_next_exp = pc4_exp;
            PC_ALU:    pc_next_exp = alu_exp;
            PC_IMM:    pc_next_exp = pcimm_exp;
            PC_BRANCH: pc_next_exp = branch_exp;
            default:   pc_next_exp = 32'hXXXXXXXX;
        endcase

        if (halt)
            pc_next_exp = cur_pc;

        case (regSEL_i)
            WB_DMEM: wb_exp = dmem_i;
            WB_ALU:  wb_exp = alu_exp;
            WB_IMM:  wb_exp = imm;
            WB_PC4:  wb_exp = pc4_exp;
            default: wb_exp = 32'hXXXXXXXX;
        endcase

        rs2_exp = golden_regs[instr_i[24:20]];

        // Check current PC and combinational outputs
        if (pc !== cur_pc) begin
            fail_count = fail_count + 1;
            $display("FAIL(pre-PC)  test=%0d instr=%h  expected_pc=%h got_pc=%h  time=%0t",
                     test_count, instr_i, cur_pc, pc, $time);
        end
        else begin
            pass_count = pass_count + 1;
        end

        if (check_alu_i && (ALUResult !== alu_exp)) begin
            fail_count = fail_count + 1;
            $display("FAIL(ALU) test=%0d instr=%h  expected_ALU=%h got_ALU=%h  time=%0t",
                     test_count, instr_i, alu_exp, ALUResult, $time);
        end

        if (check_dmem_i && (dmemWriteData !== rs2_exp)) begin
            fail_count = fail_count + 1;
            $display("FAIL(DMEM-WRITE) test=%0d instr=%h  expected_dmemWriteData=%h got=%h  time=%0t",
                     test_count, instr_i, rs2_exp, dmemWriteData, $time);
        end

        // Advance one clock so PC / regfile update
        @(posedge clk);

        // Golden update
        if (regWE_i && (instr_i[11:7] != 5'd0))
            golden_regs[instr_i[11:7]] = wb_exp;

        golden_regs[5'd0] = 32'b0; // x0 is always zero
        golden_pc = pc_next_exp;

        #1;

        if (pc !== golden_pc) begin
            fail_count = fail_count + 1;
            $display("FAIL(post-PC) test=%0d instr=%h  expected_pc=%h got_pc=%h  time=%0t",
                     test_count, instr_i, golden_pc, pc, $time);
        end
    end
endtask


// Test sequence
initial begin
    $dumpfile("datapath_tb.vcd");
    $dumpvars(0, datapath_tb);

    test_count = 0;
    pass_count  = 0;
    fail_count  = 0;

    // Default inputs
    Instr      = 32'b0;
    dmemData   = 32'b0;
    regWE      = 32'b0;
    rs1SEL     = 32'b0;
    rs2SEL     = 32'b0;
    halt       = 1'b0;
    pcSEL      = PC_PLUS4;
    regSEL     = WB_ALU;
    ALUControl = ADD;

    // Golden reset state
    for (i = 0; i < 32; i = i + 1)
        golden_regs[i] = 32'b0;
    golden_pc = 32'b0;
    saved_mem_word = 32'b0;

    // Reset DUT
    reset = 1'b1;
    #12;
    reset = 1'b0;
    #1;

    // Check reset state
    if (pc !== 32'b0) begin
        $display("FAIL(reset-PC) expected 0 got %h", pc);
        fail_count = fail_count + 1;
    end

    // --------------------------------------------------
    // U-type
    // --------------------------------------------------
    // LUI x1, 0x12345  => x1 = 0x12345000
    run_test(
        mkU(32'h12345000, 5'd1, OPC_LUI),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_IMM,
        ADD,
        1'b0, 1'b0
    );

    // AUIPC x2, 0x00010 => x2 = PC + 0x00010000
    run_test(
        mkU(32'h00010000, 5'd2, OPC_AUIPC),
        32'b0,
        1'b1, 1'b1, 1'b1,
        PC_PLUS4,
        WB_ALU,
        ADD,
        1'b1, 1'b0
    );

    // --------------------------------------------------
    // I-type
    // --------------------------------------------------
    // ADDI x3, x1, 12
    run_test(
        mkI(32'd12, 5'd1, 3'b000, 5'd3, OPC_ITYPE),
        32'b0,
        1'b1, 1'b0, 1'b1,
        PC_PLUS4,
        WB_ALU,
        ADD,
        1'b1, 1'b0
    );

    // ANDI x4, x1, 0x0FF
    run_test(
        mkI(32'h000000FF, 5'd1, 3'b111, 5'd4, OPC_ITYPE),
        32'b0,
        1'b1, 1'b0, 1'b1,
        PC_PLUS4,
        WB_ALU,
        AND,
        1'b1, 1'b0
    );

    // ORI x5, x1, 0x00F
    run_test(
        mkI(32'h0000000F, 5'd1, 3'b110, 5'd5, OPC_ITYPE),
        32'b0,
        1'b1, 1'b0, 1'b1,
        PC_PLUS4,
        WB_ALU,
        OR,
        1'b1, 1'b0
    );

    // XORI x6, x1, 0x055
    run_test(
        mkI(32'h00000055, 5'd1, 3'b100, 5'd6, OPC_ITYPE),
        32'b0,
        1'b1, 1'b0, 1'b1,
        PC_PLUS4,
        WB_ALU,
        XOR,
        1'b1, 1'b0
    );

    // ADDI x14, x0, -1
    run_test(
        mkI(12'hFFF, 5'd0, 3'b000, 5'd14, OPC_ITYPE),
        32'b0,
        1'b1, 1'b0, 1'b1,
        PC_PLUS4,
        WB_ALU,
        ADD,
        1'b1, 1'b0
    );

    // ADDI x15, x0, 7
    run_test(
        mkI(12'd7, 5'd0, 3'b000, 5'd15, OPC_ITYPE),
        32'b0,
        1'b1, 1'b0, 1'b1,
        PC_PLUS4,
        WB_ALU,
        ADD,
        1'b1, 1'b0
    );

    // ADDI x16, x0, 2
    run_test(
        mkI(12'd2, 5'd0, 3'b000, 5'd16, OPC_ITYPE),
        32'b0,
        1'b1, 1'b0, 1'b1,
        PC_PLUS4,
        WB_ALU,
        ADD,
        1'b1, 1'b0
    );

    // LUI x17, 0x80000  => x17 = 0x80000000
    run_test(
        mkU(32'h80000000, 5'd17, OPC_LUI),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_IMM,
        ADD,
        1'b0, 1'b0
    );

    // --------------------------------------------------
    // R-type
    // --------------------------------------------------
    // ADD x7, x1, x3
    run_test(
        mkR(7'b0000000, 5'd3, 5'd1, 3'b000, 5'd7, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        ADD,
        1'b1, 1'b1
    );

    // SUB x8, x7, x3  => should recover x1
    run_test(
        mkR(7'b0100000, 5'd3, 5'd7, 3'b000, 5'd8, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        SUB,
        1'b1, 1'b1
    );

    // SLT x9, x1, x3  => x1 < x3  (true)
    run_test(
        mkR(7'b0000000, 5'd3, 5'd1, 3'b010, 5'd9, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        SLT,
        1'b1, 1'b1
    );

    // SLTU x10, x3, x1 => false
    run_test(
        mkR(7'b0000000, 5'd1, 5'd3, 3'b011, 5'd10, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        SLTU,
        1'b1, 1'b1
    );

    // --------------------------------------------------
    // M-type (R-type with funct7 = 0000001)
    // --------------------------------------------------

    // MUL x18, x15, x16  => 7 * 2 = 14
    run_test(
        mkR(7'b0000001, 5'd16, 5'd15, 3'b000, 5'd18, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        MUL,
        1'b1, 1'b1
    );

    // MULH x19, x17, x16  => signed high of INT_MIN * 2
    run_test(
        mkR(7'b0000001, 5'd16, 5'd17, 3'b001, 5'd19, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        MULH,
        1'b1, 1'b1
    );

    // MULHSU x20, x14, x16  => signed(-1) * unsigned(2)
    run_test(
        mkR(7'b0000001, 5'd16, 5'd14, 3'b010, 5'd20, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        MULHSU,
        1'b1, 1'b1
    );

    // MULHU x21, x14, x14  => unsigned(0xFFFFFFFF) * unsigned(0xFFFFFFFF)
    run_test(
        mkR(7'b0000001, 5'd14, 5'd14, 3'b011, 5'd21, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        MULHU,
        1'b1, 1'b1
    );

    // DIV x22, x15, x16  => 7 / 2 = 3
    run_test(
        mkR(7'b0000001, 5'd16, 5'd15, 3'b100, 5'd22, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        DIV,
        1'b1, 1'b1
    );

    // DIVU x23, x15, x16 => 7 / 2 = 3
    run_test(
        mkR(7'b0000001, 5'd16, 5'd15, 3'b101, 5'd23, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        DIVU,
        1'b1, 1'b1
    );

    // REM x24, x15, x16 => 7 % 2 = 1
    run_test(
        mkR(7'b0000001, 5'd16, 5'd15, 3'b110, 5'd24, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        REM,
        1'b1, 1'b1
    );

    // REMU x25, x15, x16 => 7 % 2 = 1
    run_test(
        mkR(7'b0000001, 5'd16, 5'd15, 3'b111, 5'd25, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        REMU,
        1'b1, 1'b1
    );

    // DIV by zero -> FFFFFFFF
    run_test(
        mkR(7'b0000001, 5'd0, 5'd15, 3'b100, 5'd26, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        DIV,
        1'b1, 1'b1
    );

    // REM by zero -> dividend
    run_test(
        mkR(7'b0000001, 5'd0, 5'd15, 3'b110, 5'd27, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        REM,
        1'b1, 1'b1
    );

    // DIV overflow: INT_MIN / -1 -> INT_MIN
    run_test(
        mkR(7'b0000001, 5'd14, 5'd17, 3'b100, 5'd28, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        DIV,
        1'b1, 1'b1
    );

    // REM overflow: INT_MIN % -1 -> 0
    run_test(
        mkR(7'b0000001, 5'd14, 5'd17, 3'b110, 5'd29, OPC_RTYPE),
        32'b0,
        1'b1, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        REM,
        1'b1, 1'b1
    );

    // --------------------------------------------------
    // S-type (store)
    // --------------------------------------------------
    // SW x8, 16(x2)
    saved_mem_word = golden_regs[5'd8];
    run_test(
        mkS(32'd16, 5'd8, 5'd2, 3'b010, OPC_STORE),
        32'b0,
        1'b0, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        ADD,
        1'b1, 1'b1
    );

    // --------------------------------------------------
    // Load
    // --------------------------------------------------
    // LW x11, 16(x2)  -> memory returns saved_mem_word
    run_test(
        mkI(32'd16, 5'd2, 3'b010, 5'd11, OPC_LOAD),
        saved_mem_word,
        1'b1, 1'b0, 1'b1,
        PC_PLUS4,
        WB_DMEM,
        ADD,
        1'b1, 1'b0
    );

    // --------------------------------------------------
    // B-type (branch)
    // --------------------------------------------------
    // BEQ x1, x1, +8  => taken
    run_test(
        mkB(32'd8, 5'd1, 5'd1, 3'b000, OPC_BRANCH),
        32'b0,
        1'b0, 1'b0, 1'b0,
        PC_BRANCH,
        WB_ALU,
        equal,
        1'b1, 1'b1
    );

    // BNE x1, x2, +8
    run_test(
        mkB(32'd8, 5'd2, 5'd1, 3'b001, OPC_BRANCH),
        32'b0,
        1'b0, 1'b0, 1'b0,
        PC_BRANCH,
        WB_ALU,
        not_equal,
        1'b1, 1'b1
    );

    // BLT x3, x1, +8  => not taken because x3 > x1
    run_test(
        mkB(32'd8, 5'd1, 5'd3, 3'b100, OPC_BRANCH),
        32'b0,
        1'b0, 1'b0, 1'b0,
        PC_BRANCH,
        WB_ALU,
        SLT,
        1'b1, 1'b1
    );

    // --------------------------------------------------
    // J-type
    // --------------------------------------------------
    // JAL x12, +12
    // Use rs1SEL=1 and rs2SEL=1 so ALUResult also becomes PC+Imm
    run_test(
        mkJ(32'd12, 5'd12, OPC_JAL),
        32'b0,
        1'b1, 1'b1, 1'b1,
        PC_IMM,
        WB_PC4,
        ADD,
        1'b1, 1'b0
    );

    // JALR x13, 5(x3)  => target should clear bit 0
    run_test(
        mkI(32'd5, 5'd3, 3'b000, 5'd13, OPC_JALR),
        32'b0,
        1'b1, 1'b0, 1'b1,
        PC_ALU,
        WB_PC4,
        JALR,
        1'b1, 1'b0
    );

    // --------------------------------------------------
    // HALT
    // --------------------------------------------------
    // HALT instruction: PC must freeze
    run_test(
        32'hFFFFFFFF,
        32'b0,
        1'b0, 1'b0, 1'b0,
        PC_PLUS4,
        WB_ALU,
        ADD,
        1'b0, 1'b0
    );

    // Summary
    $display("--------------------------------------------------");
    $display("DATAPATH TEST SUMMARY");
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