//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 29-06-2026
//
//====================================================

module forwardunit(input [4:0] ex_mem_rd, mem_wb_rd, id_ex_rs1, id_ex_rs2, if_id_rs1, if_id_rs2, ex_mem_rs2, input ex_mem_regWE, mem_wb_regWE, output [1:0] ex_rs1_fwrd, ex_rs2_fwrd, output id_rs1_fwrd, id_rs2_fwrd, mem_rs2_fwrd);
/*List of Hazards and forwards:
1. EX/MEM.RegisterRd == ID/EX.RegisterRs1/2
2. MEM/WB.RegisterRd == ID/EX.RegisterRs1/2
3. MEM/WB.RegisterRd == IF/ID.RegisterRs1/2
4. MEM/WB.RegisterRd == EX/MEM.RegisterRs2
*/

//Forward Encoding for Hazard 1 and 2
localparam EXMEM = 2'b01;
localparam MEMWB = 2'b10;
localparam NoFWRD = 2'b00;

//Hazard 1a and 2a (rs1)
assign ex_rs1_fwrd = (ex_mem_regWE && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1)) ? EXMEM :
                     (mem_wb_regWE && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1)) ? MEMWB :
                     NoFWRD;


//Hazard 1b and 2b (rs2)
assign ex_rs2_fwrd = (ex_mem_regWE && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2)) ? EXMEM :
                     (mem_wb_regWE && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2)) ? MEMWB :
                     NoFWRD;

//Hazard 3a (rs1)
assign id_rs1_fwrd = (mem_wb_regWE && (mem_wb_rd != 0) && (mem_wb_rd == if_id_rs1)) ? 1'b1 : 1'b0;

//Hazard 3b (rs2)
assign id_rs2_fwrd = (mem_wb_regWE && (mem_wb_rd != 0) && (mem_wb_rd == if_id_rs2)) ? 1'b1 : 1'b0;

//Hazard 4
assign mem_rs2_fwrd = (mem_wb_regWE && (mem_wb_rd != 0) && (mem_wb_rd == ex_mem_rs2)) ? 1'b1 : 1'b0;

endmodule