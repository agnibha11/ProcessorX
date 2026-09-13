//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 30-06-2026
//
// - Added stall for cache miss from Memory  -  09-07-2026
// - GSHARE: thread next_pc[31:0] and pht_index[9:0] to MEM  - 12-07-2026
//====================================================

module ex_mem(
    input clk, reset, flush, stall,
    input [31:0] ALUResult_in, pc_imm_in, rd_out2_in, PC_4_in, ImmData_in,
    input dmemWE_in, dmemRE_in, regWE_in,
    input [4:0] rd_reg_in, rs1_in, rs2_in,
    input [2:0] dmemMode_in,
    input [1:0] regSEL_in, pcSEL_in,
    input [31:0] pred_next_pc_in,
    input [9:0] pht_index_in,
    output reg [31:0] ALUResult_out, pc_imm_out, rd_out2_out, PC_4_out, ImmData_out,
    output reg dmemWE_out, dmemRE_out, regWE_out,
    output reg [4:0] rd_reg_out, rs1_out, rs2_out,
    output reg [2:0] dmemMode_out,
    output reg [1:0] regSEL_out, pcSEL_out,
    output reg [31:0] pred_next_pc_out,
    output reg [9:0] pht_index_out
);

always @(posedge clk or posedge reset) begin
    if(reset || flush) begin
        ALUResult_out <= 0;
        pc_imm_out <= 0;
        rd_out2_out <= 0;
        PC_4_out <= 0;
        ImmData_out <= 0;
        dmemWE_out <= 0;
        dmemRE_out <= 0;
        regWE_out <= 0;
        rd_reg_out <= 0;
        rs1_out <= 0;
        rs2_out <= 0;
        dmemMode_out <= 0;
        regSEL_out <= 0;
        pcSEL_out <= 0;
        pred_next_pc_out <= 32'b0;
        pht_index_out <= 10'b0;
    end
    else if(!stall) begin
        ALUResult_out <= ALUResult_in;
        pc_imm_out <= pc_imm_in;
        rd_out2_out <= rd_out2_in;
        PC_4_out <= PC_4_in;
        ImmData_out <= ImmData_in;
        dmemWE_out <= dmemWE_in;
        dmemRE_out <= dmemRE_in;
        regWE_out <= regWE_in;
        rd_reg_out <= rd_reg_in;
        rs1_out <= rs1_in;
        rs2_out <= rs2_in;
        dmemMode_out <= dmemMode_in;
        regSEL_out <= regSEL_in;
        pcSEL_out <= pcSEL_in;
        pred_next_pc_out <= pred_next_pc_in;
        pht_index_out <= pht_index_in;
    end
end
endmodule