//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 12-07-2026
//====================================================

module branch_predictor(input clk, reset, enable_bp, update_en, update_is_cond, update_taken, update_btb, input [9:0] update_pht_index, input [31:0] pc, PC_4, update_pc, update_target,
output taken, output [31:0] target_out, pred_next_pc, output [9:0] pht_index);

wire btb_hit, btb_is_cond, pht_taken;
wire [31:0] btb_target;
wire [9:0] g_index;

//Gshare and PHT updates only when update is enabled and it is conditional branch
gshare GSHARE(
    .clk(clk),
    .reset(reset),
    .update_en(update_en && update_is_cond),
    .update_taken(update_taken),
    .pc(pc),
    .update_index(update_pht_index),
    .pht_index(g_index),
    .taken(pht_taken)
);

assign pht_index = g_index;

//Branch Target Buffer is updted for unconditional branches too
btb BTB(
    .clk(clk),
    .reset(reset),
    .update_en(update_btb),
    .update_is_cond(update_is_cond),
    .pc(pc),
    .update_pc(update_pc),
    .target_in(update_target),
    .hit(btb_hit),
    .is_cond(btb_is_cond),
    .target_out(btb_target)
);

//The branch prediction
assign taken = enable_bp && btb_hit && (!btb_is_cond || pht_taken);
assign target_out = btb_target;
assign pred_next_pc = taken ? btb_target : PC_4;

endmodule