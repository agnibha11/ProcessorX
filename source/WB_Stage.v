//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 27-06-2026
//
//====================================================

module wb_stage(input regWE_in, input [1:0] regSEL, input [4:0] rd_reg_in, input [31:0] ALUResult, dmemData, ImmData, PC_4, output regWE_out, output [4:0] rd_reg_out, output [31:0] wr_data);
//Forward the signals (not staged) to IF Stage
assign rd_reg_out = rd_reg_in;
assign regWE_out = regWE_in;

//Write back MUX
mux4 MUX_WB(
    .A(dmemData),
    .B(ALUResult),
    .C(ImmData),
    .D(PC_4),
    .sel(regSEL),
    .out(wr_data)
);

endmodule