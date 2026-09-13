//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 07-07-2026
//
// Changes:
// - Added Instruction Cache Controller  -  08-07-2026
// - Added support for flush when branch taken  -  08-07-2026
//====================================================

module if2_stage(input clk, reset, halt, flush, input [31:0] pc_in, PC_4_in, input [259:0] cache_data, 
output cache_miss, cacheWE, output [31:0] Instr, pc_out, PC_4_out, output[259:0] cache_update, output [4:0] cache_wr_index);

// Pass the PC(s)
assign pc_out = pc_in;
assign PC_4_out = PC_4_in;

//Wires between Instruction Memory and Cache Controller
wire [255:0] imem_data;
wire imemRE;
wire [31:0] imem_addr;

//Instruction memory
instrmem imem(
    .clk(clk),
    .reset(reset),
    .re(imemRE),
    .Addr(imem_addr),
    .rd_instr(imem_data)
);

// Cache Controller
icache_ctrl ICACHE_CTRL(
    .clk(clk),
    .reset(reset),
    .halt(halt),
    .pc(pc_in),
    .flush(flush),
    .cache_data(cache_data),
    .imem_data(imem_data),
    .Instr(Instr),
    .cache_miss(cache_miss),
    .imemRE(imemRE),
    .imem_addr(imem_addr),
    .cacheWE(cacheWE),
    .cache_wr_index(cache_wr_index),
    .cache_refill(cache_update)
);

endmodule