//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 30-06-2026
//
//====================================================

module mem_wb(
    input clk, reset, 
    input [31:0] ALUResult_in, memData_in, PC_4_in, ImmData_in,
    input regWE_in,
    input [1:0] regSEL_in,
    input [4:0] rd_reg_in,
    output reg [31:0] ALUResult_out, memData_out, PC_4_out, ImmData_out,
    output reg regWE_out,
    output reg [1:0] regSEL_out,
    output reg [4:0] rd_reg_out
);

always @(posedge clk or posedge reset) begin
    if(reset) begin
        ALUResult_out <= 0;
        memData_out <= 0;
        PC_4_out <= 0;
        ImmData_out <= 0;
        regWE_out <= 0;
        regSEL_out <= 0;
        rd_reg_out <= 0;
    end
    else begin
        ALUResult_out <= ALUResult_in;
        memData_out <= memData_in;
        PC_4_out <= PC_4_in;
        ImmData_out <= ImmData_in;
        regWE_out <= regWE_in;
        regSEL_out <= regSEL_in;
        rd_reg_out <= rd_reg_in;
    end
end
endmodule