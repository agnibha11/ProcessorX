//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 30-06-2026
//
// Changes:
// - Added stall for cache miss from Memory  -  09-07-2026
// - GSHARE: thread next_pc[31:0] and pht_index[9:0] to MEM  - 12-07-2026
//====================================================

module id_ex(
    input clk, reset, flush, stall,
    input dmemWE_in, dmemRE_in, regWE_in, rs2SEL_in, rs1SEL_in, 
    input [4:0] ALUControl_in, rd_reg_in, rs1_out_in, rs2_out_in,
    input [2:0] dmemMode_in, 
    input [1:0] regSEL_in, pcSEL_in,
    input [31:0] rd_out1_in, rd_out2_in, ImmData_in, pc_in, PC_4_in,
    input [31:0] pred_next_pc_in,
    input [9:0] pht_index_in,
    output reg dmemWE_out, dmemRE_out, regWE_out, rs1SEL_out, rs2SEL_out, 
    output reg [4:0] ALUControl_out, rd_reg_out, rs1_out_out, rs2_out_out,
    output reg [2:0] dmemMode_out, 
    output reg [1:0] regSEL_out, pcSEL_out,
    output reg [31:0] rd_out1_out, rd_out2_out, ImmData_out, pc_out, PC_4_out,
    output reg [31:0] pred_next_pc_out,
    output reg [9:0] pht_index_out
);

always @(posedge clk or posedge reset) begin
    if(reset || flush) begin
        dmemWE_out <= 0;
        dmemRE_out <= 0;
        regWE_out <= 0;
        rs1SEL_out <= 0;
        rs2SEL_out <= 0;
        ALUControl_out <= 0;
        rd_reg_out <= 0;
        rs1_out_out <= 0;
        rs2_out_out <= 0;
        dmemMode_out <= 0;
        regSEL_out <= 0;
        pcSEL_out <= 0;
        rd_out1_out <= 0;
        rd_out2_out <= 0;
        ImmData_out <= 0;
        pc_out <= 0;
        PC_4_out <= 0;
        pred_next_pc_out <= 32'b0;
        pht_index_out <= 10'b0;
    end
    else begin
        if(!stall) begin
            dmemWE_out <= dmemWE_in;
            dmemRE_out <= dmemRE_in;
            regWE_out <= regWE_in;
            rs1SEL_out <= rs1SEL_in;
            rs2SEL_out <= rs2SEL_in;
            ALUControl_out <= ALUControl_in;
            rd_reg_out <= rd_reg_in;
            rs1_out_out <= rs1_out_in;
            rs2_out_out <= rs2_out_in;
            dmemMode_out <= dmemMode_in;
            regSEL_out <= regSEL_in;
            pcSEL_out <= pcSEL_in;
            rd_out1_out <= rd_out1_in;
            rd_out2_out <= rd_out2_in;
            ImmData_out <= ImmData_in;
            pc_out <= pc_in;
            PC_4_out <= PC_4_in;
            pred_next_pc_out <= pred_next_pc_in;
            pht_index_out <= pht_index_in;
        end
    end
end
endmodule