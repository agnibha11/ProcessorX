//===============================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 07-07-2026
//
// Changes:
// - Added Instruction Cache SRAM memory  -  08-07-2026
// - Added support for stall under Load Hazard for I Cache Memory  -  09-08-2026
// - GSHARE: PC select replaced. Priority:                -  12-07-2026
//     1) MEM misprediction  -> redirect_pc  (correct path, wins)
//     2) IF2 prediction taken -> predict_target (speculative)
//     3) sequential          -> pc+4
//   The old pcSEL/ALUResult/PCImm MUX_PC + MUX_BR are gone; MEM now
//   hands us the exact correct next-PC on a misprediction.
//=================================================================


module if1_stage(input clk, reset, en_low, bubble, cache_miss, cache_we,  input[4:0] cache_wr_index, input [259:0] cache_update, input mispredict, predict_taken, input [31:0] pc_MEM, pc_BP,
output [31:0] pc, PC_4, output [259:0] cache_data);



wire [31:0] pc_next, pc_current, pc_4;

wire halt_pc;
assign halt_pc = en_low || bubble || cache_miss;

//Program Counter
ff PC(
    .clk(clk),
    .reset(reset),
    .d(pc_next),
    .q(pc_current),
    .en_low(halt_pc)
);

//PC + 4 adder
adder PC4(
    .a(pc_current),
    .b(4),
    .result(pc_4)
);


//Next PC MUX
assign pc_next = mispredict ? pc_MEM :
                 predict_taken ? pc_BP :
                 pc_4;

assign pc = pc_current;
assign PC_4 = pc_4; 

//Cache Memory (SRAM)
icache_mem ICACHE(
    .clk(clk),
    .reset(reset),
    .bubble(bubble),
    .predict_taken(predict_taken),
    .we(cache_we),
    .rd_index(pc_current[9:5]),
    .wr_index(cache_wr_index),
    .wr_data(cache_update),
    .rd_data(cache_data)
);

endmodule