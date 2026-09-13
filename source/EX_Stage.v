//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 27-06-2026
//
// Changes:
// 1. Added output for PC+4 to be used in WB Stage  -  27-06-2026
// 2. Added output for ImmData to be used in WB Stage  -  27-06-2026
// 3. Added MUX of rs1/rs2 forwarding and Hazard Handling  -  29-06-2026
// 4. Passed rs1, rs2 to next stage  - 29-06-2026
// 5. Shifted Branch resolution from EX to MEM  -  29-06-2026
//====================================================

module ex_stage(input dmemWE_in, dmemRE_in, regWE_in, rs1SEL, rs2SEL, input [4:0] ALUControl, rd_reg_in, rs1_in, rs2_in, input [2:0] dmemMode_in, input [1:0] regSEL_in, pcSEL_in, rs1_fwrd, rs2_fwrd, input [31:0] rd_out1, rd_out2, ImmData_in, pc, PC_4_in, wr_data_WB, wr_data_MEM, 
output [31:0] ALUResult, pc_imm, rd_out2_out, PC_4_out, ImmData_out, output dmemWE_out, dmemRE_out, regWE_out, output [4:0] rd_reg_out, rs1_out, rs2_out, output [2:0] dmemMode_out, output [1:0] regSEL_out, pcSEL_out);

wire [31:0] mux_rs1, mux_rs2;

//Forward Encoding for Hazard 1 and 2
localparam EXMEM = 2'b01;
localparam MEMWB = 2'b10;
localparam NoFWRD = 2'b00;


//Pass the signals from previous stage
//To MEM Stage
assign dmemWE_out = dmemWE_in;
assign dmemRE_out = dmemRE_in;
assign dmemMode_out = dmemMode_in;
assign rd_out2_out = fwrd_mux_rs2;
assign rs1_out = rs1_in;
assign rs2_out = rs2_in;

//TO WB Stage
assign regWE_out = regWE_in;
assign regSEL_out = regSEL_in;
assign rd_reg_out = rd_reg_in;
assign PC_4_out = PC_4_in;
assign ImmData_out = ImmData_in;

//To MEM Stage
assign pcSEL_out = pcSEL_in;

//Forwarding rs1/rs2
wire [31:0] fwrd_mux_rs1, fwrd_mux_rs2;

assign fwrd_mux_rs1 = (rs1_fwrd == EXMEM) ? wr_data_MEM : 
                      (rs1_fwrd == MEMWB) ? wr_data_WB :
                      rd_out1;

assign fwrd_mux_rs2 = (rs2_fwrd == EXMEM) ? wr_data_MEM : 
                      (rs2_fwrd == MEMWB) ? wr_data_WB :
                      rd_out2;

// MUX for RS1/PC for ALU A input
mux2 MUX_A(
    .B(pc),
    .A(fwrd_mux_rs1),
    .sel(rs1SEL),
    .out(mux_rs1)
);

// MUX for RS2/ImmData for ALU B input
mux2 MUX_B(
    .B(ImmData_in),
    .A(fwrd_mux_rs2),
    .sel(rs2SEL),
    .out(mux_rs2)
);

//ALU
alu ALU(
    .A(mux_rs1),
    .B(mux_rs2),
    .ALUControl(ALUControl),
    .Result(ALUResult)
);

//PC + ImmData adder
adder PCIMM(
    .a(pc),
    .b(ImmData_in),
    .result(pc_imm)
);

endmodule