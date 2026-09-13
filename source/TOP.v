//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 30-06-2026
//
// Changes:
// - Added new IF1 and IF2 Stages for Cache  -  07-07-2026
// - Implemented full Instruction Cache control  -  08-07-2026
// - Added GShare+BTB Dynamic Branch Predictor  -  12-07-2026
//====================================================

module top(input clk, input reset);

//Wires between ID and IF1 Stage and IF2 Stage (unstaged)
wire halt_ID;

//Wires between Hazard Unit and IF1 stage (unstaged)
wire bubble_HU;


//Wires between IF1 Stage and IF1/IF2 Reg
wire [31:0] pc_IF1, PC_4_IF1;

//Wires between IF1 Stage and IF2 Stage
wire [259:0] cache_data_IF1, cache_update_IF2;
wire cache_miss_IF2, cacheWE_IF2;
wire [4:0] cache_wr_index_IF2;

//Wires between IF1/IF2 Reg and IF2 Stage
wire [31:0] pc_IF1IF2, PC_4_IF1IF2;

//Wires between IF2 and IF/ID Reg
wire [31:0] Instr_IF2, pc_IF2, PC_4_IF2;

//Wires between MEM Stage and IF1/IF2, IF/ID, ID/EX, EX/MEM Reg
wire flush_MEM;

//Gshare Resolution Wires
wire        mispredict_MEM;
wire [31:0] redirect_pc_MEM;
wire        update_en_MEM, update_is_cond_MEM, update_taken_MEM, update_btb_MEM;
wire [9:0]  update_pht_index_MEM;
wire [31:0] update_pc_MEM, update_target_MEM;

// Branch Predictor Wires
wire        predict_taken_BP;
wire [31:0] predict_target_BP, pred_next_pc_BP;
wire [9:0]  pht_index_predict_BP;
wire        predict_squash_BP;


//Wires between IF/ID reg and ID Stage
wire [31:0] Instr_IFID, pc_IFID, PC_4_IFID;
wire [31:0] pred_next_pc_IFID;
wire [9:0]  pht_index_IFID;


//Wires between WB and ID Stage/EX Stage (unstaged)
wire reg_WE_WB;
wire [4:0] rd_reg_WB;
wire [31:0] wr_data_WB;

//Wires between Forwarding Unit and ID Stage (unstaged)
wire rs1_fwrd_FU, rs2_fwrd_FU;

//Wires between ID Stage and ID/EX Reg
wire dmemWE_ID, dmemRE_ID, regWE_ID, rs1SEL_ID, rs2SEL_ID;
wire [4:0] ALUControl_ID, rd_reg_ID, rs1_out_ID, rs2_out_ID;
wire [2:0] dmemMode_ID;
wire [1:0] regSEL_ID, pcSEL_ID;
wire [31:0] rd_out1_ID, rd_out2_ID, ImmData_ID, pc_out_ID, PC_4_out_ID;


//Wires from ID/EX Reg to EX Stage
wire dmemWE_IDEX, dmemRE_IDEX, regWE_IDEX, rs1SEL_IDEX, rs2SEL_IDEX;
wire [4:0] ALUControl_IDEX, rd_reg_IDEX, rs1_out_IDEX, rs2_out_IDEX;
wire [2:0] dmemMode_IDEX;
wire [1:0] regSEL_IDEX, pcSEL_IDEX;
wire [31:0] rd_out1_IDEX, rd_out2_IDEX, ImmData_IDEX, pc_out_IDEX, PC_4_out_IDEX;
wire [31:0] pred_next_pc_IDEX;
wire [9:0]  pht_index_IDEX;


//Wires between Forwarding Unit and EX Stage (unstaged)
wire [1:0] rs1_fwrd_EXFU, rs2_fwrd_EXFU;

//Wires between MEM stage and EX Stage (unstaged)
wire [31:0] wr_data_MEM;

//Wires from mem stage
wire cache_miss_MEM;

//Wires from EX Stage to EX/MEM Reg
wire [31:0] ALUResult_EX, pc_imm_EX, rd_out2_EX, PC_4_out_EX, ImmData_EX;
wire dmemWE_EX, dmemRE_EX, regWE_EX;
wire [4:0] rd_reg_EX, rs1_EX, rs2_EX;
wire [2:0] dmemMode_EX;
wire [1:0] regSEL_EX, pcSEL_EX;

//Wires between EX/MEM Reg and MEM Stage
wire [31:0] ALUResult_EXMEM, pc_imm_EXMEM, rd_out2_EXMEM, PC_4_out_EXMEM, ImmData_EXMEM;
wire dmemWE_EXMEM, dmemRE_EXMEM, regWE_EXMEM;
wire [4:0] rd_reg_EXMEM, rs1_EXMEM, rs2_EXMEM;
wire [2:0] dmemMode_EXMEM;
wire [1:0] regSEL_EXMEM, pcSEL_EXMEM;
wire [31:0] pred_next_pc_EXMEM;
wire [9:0]  pht_index_EXMEM;

//Wires between Forwarding Unit and MEM Stage (unstaged)
wire mem_rs2_fwrd_FU;

//Wires between MEM Stage and MEM/WB Reg
wire [31:0] PC_4_out_MEM, memData_MEM, ImmData_MEM;
wire regWE_MEM;
wire [1:0] regSEL_MEM;
wire [4:0] rd_reg_MEM;
wire [31:0] ALUResult_MEM;

//Wires from MEM/WB to Forwarding Unit (unstaged)
wire [4:0] rd_reg_MEMWB;
wire regWE_MEMWB;

//Wires between MEM/WB Reg and WB Stage
wire [31:0] ALUResult_MEMWB, memData_MEMWB, PC_4_out_MEMWB, ImmData_MEMWB;
wire [1:0] regSEL_MEMWB;

// global wires
wire cache_miss;
assign cache_miss = cache_miss_IF2 || cache_miss_MEM;

if1_stage IF1(
    .clk(clk),
    .reset(reset),
    .en_low(halt_ID),
    .bubble(bubble_HU),
    .cache_miss(cache_miss),
    .cache_we(cacheWE_IF2),
    .cache_wr_index(cache_wr_index_IF2),
    .cache_update(cache_update_IF2),
    .mispredict(mispredict_MEM),
    .predict_taken(predict_taken_BP),
    .pc_MEM(redirect_pc_MEM),
    .pc_BP(predict_target_BP),
    .cache_data(cache_data_IF1),
    .pc(pc_IF1),
    .PC_4(PC_4_IF1)
);

if1_if2 IF1_IF2(
    .clk(clk),
    .reset(reset),
    .stall(cache_miss),
    .bubble(bubble_HU),
    .flush(flush_MEM),
    .predict_squash(predict_squash_BP),
    .pc_in(pc_IF1),
    .PC_4_in(PC_4_IF1),
    .pc_out(pc_IF1IF2),
    .PC_4_out(PC_4_IF1IF2)
);

if2_stage IF2(
    .clk(clk),
    .reset(reset),
    .halt(halt_ID),
    .flush(flush_MEM),
    .pc_in(pc_IF1IF2),
    .PC_4_in(PC_4_IF1IF2),
    .cache_data(cache_data_IF1),
    .cache_miss(cache_miss_IF2),
    .cacheWE(cacheWE_IF2),
    .cache_update(cache_update_IF2),
    .cache_wr_index(cache_wr_index_IF2),
    .pc_out(pc_IF2),
    .PC_4_out(PC_4_IF2),
    .Instr(Instr_IF2)
);

branch_predictor PREDICTOR(
    .clk(clk),
    .reset(reset),
    .enable_bp(!cache_miss && !bubble_HU),
    .update_en(update_en_MEM),
    .update_is_cond(update_is_cond_MEM),
    .update_taken(update_taken_MEM),
    .update_btb(update_btb_MEM),
    .update_pht_index(update_pht_index_MEM),
    .pc(pc_IF1IF2),
    .PC_4(PC_4_IF1IF2),
    .update_pc(update_pc_MEM),
    .update_target(update_target_MEM),
    .taken(predict_taken_BP),
    .target_out(predict_target_BP),
    .pred_next_pc(pred_next_pc_BP),
    .pht_index(pht_index_predict_BP)
);

assign predict_squash_BP = predict_taken_BP;

if_id IF_ID(
    .clk(clk),
    .reset(reset),
    .flush(flush_MEM),
    .stall(cache_miss_MEM),
    .halt(halt_ID),
    .bubble(bubble_HU),
    .Instr_in(Instr_IF2),
    .pc_in(pc_IF2),
    .PC_4_in(PC_4_IF2),
    .pred_next_pc_in(pred_next_pc_BP),
    .pht_index_in(pht_index_predict_BP),
    .Instr_out(Instr_IFID),
    .pc_out(pc_IFID),
    .PC_4_out(PC_4_IFID),
    .pred_next_pc_out(pred_next_pc_IFID),
    .pht_index_out(pht_index_IFID)
);

id_stage ID(
    .clk(clk),
    .reset(reset),
    .reg_WE_WB(reg_WE_WB),
    .rs1_fwrd(rs1_fwrd_FU),
    .rs2_fwrd(rs2_fwrd_FU),
    .bubble(bubble_HU),
    .rd_reg_WB(rd_reg_WB),
    .Instr(Instr_IFID),
    .pc(pc_IFID),
    .wr_data_WB(wr_data_WB),
    .PC_4_in(PC_4_IFID),
    .dmemWE(dmemWE_ID),
    .dmemRE(dmemRE_ID),
    .regWE(regWE_ID),
    .rs1SEL(rs1SEL_ID),
    .rs2SEL(rs2SEL_ID),
    .halt(halt_ID),
    .ALUControl(ALUControl_ID),
    .rd_reg(rd_reg_ID),
    .rs1_out(rs1_out_ID),
    .rs2_out(rs2_out_ID),
    .dmemMode(dmemMode_ID),
    .regSEL(regSEL_ID),
    .pcSEL(pcSEL_ID),
    .rd_out1(rd_out1_ID),
    .rd_out2(rd_out2_ID),
    .ImmData(ImmData_ID),
    .pc_out(pc_out_ID),
    .PC_4_out(PC_4_out_ID)
);

hazardunit HAZARD(
    .id_ex_memRE(dmemRE_IDEX),
    .id_ex_rd(rd_reg_IDEX),
    .if_id_rs1(rs1_out_ID),
    .if_id_rs2(rs2_out_ID),
    .bubble(bubble_HU)
);

id_ex ID_EX(
    .clk(clk),
    .reset(reset),
    .flush(flush_MEM),
    .stall(cache_miss_MEM),
    .dmemWE_in(dmemWE_ID),
    .dmemRE_in(dmemRE_ID),
    .regWE_in(regWE_ID),
    .rs2SEL_in(rs2SEL_ID),
    .rs1SEL_in(rs1SEL_ID),
    .ALUControl_in(ALUControl_ID),
    .rd_reg_in(rd_reg_ID),
    .rs1_out_in(rs1_out_ID),
    .rs2_out_in(rs2_out_ID),
    .dmemMode_in(dmemMode_ID),
    .regSEL_in(regSEL_ID),
    .pcSEL_in(pcSEL_ID),
    .rd_out1_in(rd_out1_ID),
    .rd_out2_in(rd_out2_ID),
    .ImmData_in(ImmData_ID),
    .pc_in(pc_out_ID),
    .PC_4_in(PC_4_out_ID),
    .pred_next_pc_in(pred_next_pc_IFID),
    .pht_index_in(pht_index_IFID),
    .dmemWE_out(dmemWE_IDEX),
    .dmemRE_out(dmemRE_IDEX),
    .regWE_out(regWE_IDEX),
    .rs2SEL_out(rs2SEL_IDEX),
    .rs1SEL_out(rs1SEL_IDEX),
    .ALUControl_out(ALUControl_IDEX),
    .rd_reg_out(rd_reg_IDEX),
    .rs1_out_out(rs1_out_IDEX),
    .rs2_out_out(rs2_out_IDEX),
    .dmemMode_out(dmemMode_IDEX),
    .regSEL_out(regSEL_IDEX),
    .pcSEL_out(pcSEL_IDEX),
    .rd_out1_out(rd_out1_IDEX),
    .rd_out2_out(rd_out2_IDEX),
    .ImmData_out(ImmData_IDEX),
    .pc_out(pc_out_IDEX),
    .PC_4_out(PC_4_out_IDEX),
    .pred_next_pc_out(pred_next_pc_IDEX),
    .pht_index_out(pht_index_IDEX)
);

ex_stage EX(
    .dmemWE_in(dmemWE_IDEX),
    .dmemRE_in(dmemRE_IDEX),
    .regWE_in(regWE_IDEX),
    .rs1SEL(rs1SEL_IDEX),
    .rs2SEL(rs2SEL_IDEX),
    .ALUControl(ALUControl_IDEX),
    .rd_reg_in(rd_reg_IDEX),
    .rs1_in(rs1_out_IDEX),
    .rs2_in(rs2_out_IDEX),
    .dmemMode_in(dmemMode_IDEX),
    .regSEL_in(regSEL_IDEX),
    .pcSEL_in(pcSEL_IDEX),
    .rs1_fwrd(rs1_fwrd_EXFU),
    .rs2_fwrd(rs2_fwrd_EXFU),
    .rd_out1(rd_out1_IDEX),
    .rd_out2(rd_out2_IDEX),
    .ImmData_in(ImmData_IDEX),
    .pc(pc_out_IDEX),
    .PC_4_in(PC_4_out_IDEX),
    .wr_data_WB(wr_data_WB),
    .wr_data_MEM(wr_data_MEM),
    .ALUResult(ALUResult_EX),
    .pc_imm(pc_imm_EX),
    .rd_out2_out(rd_out2_EX),
    .PC_4_out(PC_4_out_EX),
    .ImmData_out(ImmData_EX),
    .dmemWE_out(dmemWE_EX),
    .dmemRE_out(dmemRE_EX),
    .regWE_out(regWE_EX),
    .rd_reg_out(rd_reg_EX),
    .rs1_out(rs1_EX),
    .rs2_out(rs2_EX),
    .dmemMode_out(dmemMode_EX),
    .regSEL_out(regSEL_EX),
    .pcSEL_out(pcSEL_EX)
);

ex_mem EX_MEM(
    .clk(clk),
    .reset(reset),
    .flush(flush_MEM),
    .stall(cache_miss_MEM),
    .ALUResult_in(ALUResult_EX),
    .pc_imm_in(pc_imm_EX),
    .rd_out2_in(rd_out2_EX),
    .PC_4_in(PC_4_out_EX),
    .ImmData_in(ImmData_EX),
    .dmemWE_in(dmemWE_EX),
    .dmemRE_in(dmemRE_EX),
    .regWE_in(regWE_EX),
    .rd_reg_in(rd_reg_EX),
    .rs1_in(rs1_EX),
    .rs2_in(rs2_EX),
    .dmemMode_in(dmemMode_EX),
    .regSEL_in(regSEL_EX),
    .pcSEL_in(pcSEL_EX),
    .pred_next_pc_in(pred_next_pc_IDEX),
    .pht_index_in(pht_index_IDEX),
    .ALUResult_out(ALUResult_EXMEM),
    .pc_imm_out(pc_imm_EXMEM),
    .rd_out2_out(rd_out2_EXMEM),
    .PC_4_out(PC_4_out_EXMEM),
    .ImmData_out(ImmData_EXMEM),
    .dmemWE_out(dmemWE_EXMEM),
    .dmemRE_out(dmemRE_EXMEM),
    .regWE_out(regWE_EXMEM),
    .rd_reg_out(rd_reg_EXMEM),
    .rs1_out(rs1_EXMEM),
    .rs2_out(rs2_EXMEM),
    .dmemMode_out(dmemMode_EXMEM),
    .regSEL_out(regSEL_EXMEM),
    .pcSEL_out(pcSEL_EXMEM),
    .pred_next_pc_out(pred_next_pc_EXMEM),
    .pht_index_out(pht_index_EXMEM)
);

mem_stage MEM(
    .clk(clk),
    .reset(reset),
    .dmemWE_in(dmemWE_EXMEM),
    .dmemRE_in(dmemRE_EXMEM),
    .mem_rs2_fwrd(mem_rs2_fwrd_FU),
    .dmemMode_in(dmemMode_EXMEM),
    .ALUREsult_direct(ALUResult_EX),
    .data(rd_out2_EXMEM),
    .ALUResult_in(ALUResult_EXMEM),
    .PC_4_in(PC_4_out_EXMEM),
    .PC_Imm_in(pc_imm_EXMEM),
    .ImmData_in(ImmData_EXMEM),
    .wr_data_WB(wr_data_WB),
    .regWE_in(regWE_EXMEM),
    .regSEL_in(regSEL_EXMEM),
    .pcSEL_in(pcSEL_EXMEM),
    .rd_reg_in(rd_reg_EXMEM),
    .pred_next_pc_in(pred_next_pc_EXMEM),
    .pht_index_in(pht_index_EXMEM),
    .ALUResult_out(ALUResult_MEM),
    .memData(memData_MEM),
    .PC_4_out(PC_4_out_MEM),
    .ImmData_out(ImmData_MEM),
    .wr_data(wr_data_MEM),
    .regWE_out(regWE_MEM),
    .cache_miss(cache_miss_MEM),
    .regSEL_out(regSEL_MEM),
    .rd_reg_out(rd_reg_MEM),
    //GShare
    .mispredict(mispredict_MEM),
    .update_en(update_en_MEM),
    .update_taken(update_taken_MEM),
    .update_btb(update_btb_MEM),
    .update_is_cond(update_is_cond_MEM),
    .update_pht_index(update_pht_index_MEM),
    .redirect_pc(redirect_pc_MEM),
    .update_target(update_target_MEM),
    .update_pc(update_pc_MEM)
);

assign flush_MEM = mispredict_MEM;

//assign ALUResult_0_MEM = ALUResult_EXMEM[0];

forwardunit FORWARD(
    .ex_mem_rd(rd_reg_EXMEM),
    .mem_wb_rd(rd_reg_MEMWB),
    .id_ex_rs1(rs1_out_IDEX),
    .id_ex_rs2(rs2_out_IDEX),
    .if_id_rs1(rs1_out_ID),
    .if_id_rs2(rs2_out_ID),
    .ex_mem_rs2(rs2_EXMEM),
    .ex_mem_regWE(regWE_EXMEM),
    .mem_wb_regWE(regWE_MEMWB),
    .ex_rs1_fwrd(rs1_fwrd_EXFU),
    .ex_rs2_fwrd(rs2_fwrd_EXFU),
    .id_rs1_fwrd(rs1_fwrd_FU),
    .id_rs2_fwrd(rs2_fwrd_FU),
    .mem_rs2_fwrd(mem_rs2_fwrd_FU)
);

mem_wb MEM_WB(
    .clk(clk),
    .reset(reset),
    .ALUResult_in(ALUResult_MEM),
    .memData_in(memData_MEM),
    .PC_4_in(PC_4_out_MEM),
    .ImmData_in(ImmData_MEM),
    .regWE_in(regWE_MEM),
    .regSEL_in(regSEL_MEM),
    .rd_reg_in(rd_reg_MEM),
    .ALUResult_out(ALUResult_MEMWB),
    .memData_out(memData_MEMWB),
    .PC_4_out(PC_4_out_MEMWB),
    .ImmData_out(ImmData_MEMWB),
    .regWE_out(regWE_MEMWB),
    .regSEL_out(regSEL_MEMWB),
    .rd_reg_out(rd_reg_MEMWB)
);


wb_stage WB(
    .regWE_in(regWE_MEMWB),
    .regSEL(regSEL_MEMWB),
    .rd_reg_in(rd_reg_MEMWB),
    .ALUResult(ALUResult_MEMWB),
    .dmemData(memData_MEMWB),
    .ImmData(ImmData_MEMWB),
    .PC_4(PC_4_out_MEMWB),
    .regWE_out(reg_WE_WB),
    .rd_reg_out(rd_reg_WB),
    .wr_data(wr_data_WB)
);

endmodule