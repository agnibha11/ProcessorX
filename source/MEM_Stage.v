//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 27-06-2026
//
// Changes:
// 1. Added output for PC+4 to be used in WB Stage  -  27-06-2026
// 2. Added output for ImmData to be used in WB Stage
// 3. Added MUX for Hazard Control and forwarding  -  29-06-2026
// 4. Removed - (Passed rs2 to next stage stage)  -  30-06-2026
// 5. Shifted Branch resolution from EX to MEM  -  29-06-2026
// 6. Added output for wr_data from MEM stage  -  30/06/2026
// 7. Added Data Cache Memory and Data Cache Controller  -  09-07-2026
// 8. GSHARE: branch resolution now produces MISPREDICT + correct
//    redirect PC, and drives the predictor update.     -  12-07-2026
//====================================================

module mem_stage(input clk, reset, dmemWE_in, dmemRE_in, mem_rs2_fwrd, input [2:0] dmemMode_in, input [31:0] ALUREsult_direct, data, ALUResult_in, PC_4_in, PC_Imm_in, ImmData_in, wr_data_WB, input regWE_in, input [1:0] regSEL_in, pcSEL_in, input [4:0] rd_reg_in, input [31:0] pred_next_pc_in, input [9:0] pht_index_in,
output [31:0] ALUResult_out, memData, PC_4_out, ImmData_out, wr_data , output regWE_out, cache_miss, output [1:0] regSEL_out,  output [4:0] rd_reg_out,
output mispredict, update_en, update_is_cond, update_taken, update_btb, output [9:0] update_pht_index, output [31:0] redirect_pc, update_target, update_pc);
//Wires for Cache Controller
wire dcache_miss;

//Forward signals from previous stage

//To WB Stage with detection of a NOP due to cache miss
assign ALUResult_out = dcache_miss ? 32'b0 : ALUResult_in;
assign PC_4_out      = dcache_miss ? 32'b0 : PC_4_in;
assign ImmData_out   = dcache_miss ? 32'b0 : ImmData_in;
assign regSEL_out    = dcache_miss ? 2'b0  : regSEL_in;
assign rd_reg_out    = dcache_miss ? 5'b0  : rd_reg_in;
assign regWE_out     = regWE_in && !dcache_miss;
//assign rs2_out = rs2_in;

//TO EX Stage for Forwarding
assign wr_data = (regSEL_in == 2'b01) ? ALUResult_in :
                 (regSEL_in == 2'b10) ? ImmData_in :
                 (regSEL_in == 2'b11) ? PC_4_in :
                 32'hXXXXXXXX;


//GShare Branch Resolution
wire is_ctrl; //check if the instruction or Branch JAL or JALR
wire branch_taken; // Will the branch be actually taken?
wire [31:0] actual_target; //The actual target
assign is_ctrl= pcSEL_in == 2'b11 || pcSEL_in == 2'b10 || pcSEL_in == 2'b01;
assign branch_taken = (pcSEL_in == 2'b11) ? ALUResult_in[0] :
                      (is_ctrl) ? 1'b1 : 1'b0;

assign redirect_pc = pcSEL_in == 2'b01 ? ALUResult_in: //JALR 
                       pcSEL_in == 2'b10 ? PC_Imm_in: //JAL
                       (pcSEL_in == 2'b11 && ALUResult_in[0]) ? PC_Imm_in : PC_4_in;

//check is mispredicted
assign mispredict = is_ctrl && (redirect_pc != pred_next_pc_in);
//assign redirect_pc = actual_target;

assign update_en = is_ctrl;
assign update_is_cond = pcSEL_in == 2'b11;
assign update_taken = branch_taken;
assign update_pht_index = pht_index_in;
assign update_pc = PC_4_in - 32'd4;
assign update_target = redirect_pc;
assign update_btb = is_ctrl && branch_taken;

wire [31:0] fwrd_data;

// Hazard Forwarding
assign fwrd_data = mem_rs2_fwrd ? wr_data_WB : data;

//L1 Data Cache
wire [260:0] cache_data, cache_refill;
wire [255:0] block_dmem, dmem_wr_data;
wire [31:0] dmem_addr;
wire [4:0] cache_wr_index;
wire dmemRE, dmemWE, cacheWE;

//Cache SRAM
dcache_mem DCACHE(
    .clk(clk),
    .reset(reset),
    .we(cacheWE),
    .rd_index(ALUREsult_direct[9:5]),
    .wr_index(cache_wr_index),
    .wr_data(cache_refill),
    .rd_data(cache_data)
);

//Cache Controller
dcache_ctrl DCACHECTRL(
    .clk(clk),
    .reset(reset),
    .dmemRE_in(dmemRE_in),
    .dmemWE_in(dmemWE_in),
    .dmemMode(dmemMode_in),
    .addr(ALUResult_in),
    .st_fwrd_data(fwrd_data),
    .cache_data(cache_data),
    .block_dmem(block_dmem),
    .data(memData),
    .dmem_addr(dmem_addr),
    .cache_miss(dcache_miss),
    .dmemRE_out(dmemRE),
    .dmemWE_out(dmemWE),
    .cacheWE(cacheWE),
    .dmem_wr_data(dmem_wr_data),
    .cache_wr_index(cache_wr_index),
    .cache_refill(cache_refill)
);

assign cache_miss = dcache_miss;

//Data Memory DRAM
dmem DMEMORY(
    .clk(clk),
    .reset(reset),
    .w_en(dmemWE),
    .rd_en(dmemRE),
    .addr(dmem_addr),
    .w_data(dmem_wr_data),
    .rd_data(block_dmem)
);

endmodule