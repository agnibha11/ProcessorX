//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 07-07-2026
//
// Changes:
// - Added stall support for Instruction Cache Miss  -  08-07-2026
// - Added bubble support for LW Hazard stall  -  09-07-2026
// - GSHARE: added predict_squash. When IF2 predicts a branch taken,
//   the instruction sequentially fetched behind it (currently in IF1)
//   is wrong-path and must be squashed -> flush THIS register only
//   (1-cycle bubble). `flush` here carries the MEM misprediction flush.
//====================================================

module if1_if2(input clk, reset, stall, flush, bubble, predict_squash, input [31:0] pc_in, PC_4_in,
output reg [31:0] pc_out, PC_4_out);

// Pass the PC(s)
always @(posedge clk or posedge reset) begin
    if(reset || flush || predict_squash) begin
        pc_out <= 0;
        PC_4_out <= 0;
    end
    else if (!stall && !bubble) begin
        pc_out <= pc_in;
        PC_4_out <= PC_4_in;
    end
end

endmodule