//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 30-06-2026
//
// Changes:
// 1. Added halt input signal  -  30/06/2026
// 2. Added stall for cache miss from Memory  -  09-07-2026
// 3. GSHARE: thread next_pc[31:0] and pht_index[9:0] to MEM  - 12-07-2026
//====================================================

module if_id(
    input clk, reset, flush, halt, bubble, stall,
    input [31:0] Instr_in, pc_in, PC_4_in,
    input [31:0] pred_next_pc_in,
    input [9:0] pht_index_in,
    output reg [31:0] Instr_out, pc_out, PC_4_out,
    output reg [31:0] pred_next_pc_out,
    output reg [9:0] pht_index_out
);

always @(posedge clk or posedge reset) begin
    if(reset || flush) begin
        Instr_out <= 32'd0;
        pc_out <= 32'd0;
        PC_4_out <= 32'd0;
        pred_next_pc_out <= 32'b0;
        pht_index_out <= 10'b0;
    end
    else if (!halt && !bubble && !stall) begin
        Instr_out <= Instr_in;
        pc_out <= pc_in;
        PC_4_out <= PC_4_in;
        pred_next_pc_out <= pred_next_pc_in;
        pht_index_out <= pht_index_in;
    end
end

endmodule