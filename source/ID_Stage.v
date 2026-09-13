//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 27-06-2026
//
// Changes: 
// 1. Added rd field forwarding to WB stage  -  27/06/26
// 2. Added output for PC+4 to be used in WB Stage  - 27-06-2026
// 3. Added WB-ID Bypass for WB-ID RAW Hazard  -  27-06-2026
// 4. Shifted WB-ID Hazard Detection logic to Forwarding Unit  - 29-06-2026
// 5. Passed rs1, rs2 to next stage  - 29-06-2026
// 6. Added bubble input from Hazard Unit  -  30-06-2026
//====================================================

module id_stage(input clk, reset, reg_WE_WB, rs1_fwrd, rs2_fwrd, bubble, input [4:0] rd_reg_WB, input [31:0] Instr, pc, wr_data_WB, PC_4_in,
output  dmemWE, dmemRE, regWE, rs1SEL, rs2SEL, halt, output [4:0] ALUControl, rd_reg, rs1_out, rs2_out, output [2:0] dmemMode, output [1:0] regSEL, pcSEL, output [31:0] rd_out1, rd_out2, ImmData, pc_out, PC_4_out);

//ALUControl, rs1SEL, rs2SEL, ImmData, PC, pcSEL, rd_out1, rd_out2 to EX Stage
//dmemWE, dmemRE, dmemMode to MEM Stage
//regWE, regSEL, rd_reg, PC_4_out to WB Stage
//halt to IF stage (directly)

wire [31:0] rd_out1_interim, rd_out2_interim;

assign PC_4_out = PC_4_in;

//Pass the Program Counter
assign pc_out = pc;

//pass the rd field to WB stage
assign rd_reg = Instr[11:7];

//WB-ID RAW Hazard Handling
assign rd_out1 = (rs1_fwrd) ? wr_data_WB : rd_out1_interim;
assign rd_out2 = (rs2_fwrd) ? wr_data_WB : rd_out2_interim;

//Pass the rs1 and rs2 to next stage
assign rs1_out = Instr[19:15];
assign rs2_out = Instr[24:20];

//Register File
regfile REGFILE(
    .clk(clk),
    .reset(reset),
    .rs1(Instr[19:15]),
    .rs2(Instr[24:20]),
    .rd(rd_reg_WB),
    .w_data(wr_data_WB),
    .w_en(reg_WE_WB),
    .data_1(rd_out1_interim),
    .data_2(rd_out2_interim)
);

//Immediate Data Generation
immgen IMMGEN(
    .Instr(Instr),
    .Imm(ImmData)
);

//Control Unit
controlunit CTRLUNIT(
    .Instr(Instr),
    .bubble(bubble),
    .ALUControl(ALUControl),
    .dmemMode(dmemMode),
    .regSEL(regSEL),
    .pcSEL(pcSEL),
    .dmemWE(dmemWE),
    .dmemRE(dmemRE),
    .regWE(regWE),
    .rs1SEL(rs1SEL),
    .rs2SEL(rs2SEL),
    .halt(halt)
);

endmodule