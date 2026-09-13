//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 29-06-2026
//
// Changes:
// 1. Removed jump port declaration
// 2. GSHARE: the flush is no longer generated here. With a branch
//   predictor, a flush happens ONLY on a MISPREDICTION, which is
//   detected in the MEM stage (mem_stage.mispredict). This unit now
//   produces only the load-use bubble.  -  12-07-2026
//====================================================
//====================================================
module hazardunit(input id_ex_memRE, input [4:0] id_ex_rd, if_id_rs1, if_id_rs2, output bubble);

assign bubble = (id_ex_memRE && (id_ex_rd != 0) && (id_ex_rd == if_id_rs1 || id_ex_rd == if_id_rs2));

//Note: All flushes must be synchronous
//assign flush = (pcSEL == 2'b11 && ALUResult_0 == 1'b1) || (pcSEL == 2'b01) || (pcSEL == 2'b10) ? 1'b1 : 1'b0;

endmodule