//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 07-07-2026

//
// Changes:
// - Added support for HALT, to keep FSM in IDLE forever  -  08-06-2026
// - Added support for flush when branch taken  -  08-06-2026
// - Removed System Verilog constructs for proper Yosys synthesis  -  09-07-2026
//====================================================
module icache_ctrl(input clk, reset, halt, flush, input [31:0] pc, input [259:0] cache_data, input [255:0] imem_data,
output reg [31:0] Instr, imem_addr, output reg cache_miss, imemRE, cacheWE, output reg [4:0] cache_wr_index, output reg [259:0] cache_refill);

localparam [31:0] NOP = 32'h00000000; 
// This is to ensure the first state is always IDLE never REFILL
localparam NORUN = 2'b00; //When the CPU has not run even once
localparam IDLE = 2'b01;
localparam REFILL = 2'b10;

//FSM state
reg [1:0] state;

//address decomposition
wire [2:0] tag_addr, word_offset_addr;
wire [4:0] index_addr;
wire [31:0] block_base_addr;

assign tag_addr   = pc[12:10];
assign index_addr = pc[9:5];
assign word_offset_addr  = pc[4:2];               // which of the 8 words
assign block_base_addr = {pc[31:5], 5'b00000};  // clear low 5 bits

//cache data decomposition
wire valid_cache;
wire [2:0] tag_cache;
wire [255:0] block_cache; 

assign valid_cache = cache_data[259];
assign tag_cache = cache_data[258:256];
assign block_cache = cache_data[255:0];

//check for cache hit or cache miss
wire hit;
assign hit = valid_cache && (tag_cache == tag_addr);

wire [31:0] word_cache, word_imem;

//Word select from 8 words of cache (used only when cache hit)
assign word_cache = block_cache[word_offset_addr*32 +: 32];
// This one is to redirect the data to ID direcly in the event of a cache miss
assign word_imem = imem_data[word_offset_addr*32 +: 32];

always @(*) begin
    case(state)
        NORUN: begin
            Instr = NOP;
            cache_miss = 1'b0;
            imemRE = 1'b0;
            cacheWE = 1'b0;
        end
        IDLE: begin
            cacheWE = 1'b0; // Since in IDLE, so wont write to cache in next cycle
            if(hit) begin
                Instr = word_cache;
                cache_miss = 1'b0;
                imemRE = 1'b0; //Disable read
            end
            else begin
                Instr = NOP; //Inject NOP into ID Stage
                //flush has higher priority over cache_miss
                if(!flush) begin
                    cache_miss = 1'b1; //To induce a stall
                    imemRE = 1'b1; //Prepare the IMEM for read in next cycle
                    imem_addr = block_base_addr;
                end
                else begin
                    cache_miss = 1'b0;
                    imemRE = 1'b0;
                end
            end
        end
        REFILL: begin
            // Read from lower memory
            Instr = word_imem; // Instruction redirected from IMEM to ID
            cache_miss = 1'b0; //The stall will end after this cycle
            cacheWE = 1'b1; // The Cache refill will happen in next cycle
            cache_wr_index = index_addr;
            cache_refill = {1'b1, tag_addr, imem_data}; //The data to write to cache
            imemRE = 1'b0; //Disable read for Imem 
        end
        default: begin
            Instr = NOP;
            cache_miss = 1'b0;
            imemRE = 1'b0;
            imem_addr = block_base_addr;
            cacheWE = 1'b0;
            cache_wr_index = index_addr;
            cache_refill = {1'b1, tag_addr, imem_data};
        end
    endcase 
end

// Cache Controller FSM updates
always @(posedge clk or posedge reset) begin
    if(reset || flush)
        state <= NORUN;  
    else begin
        case(state)
            NORUN: state <= IDLE;
            IDLE: state <= (hit || halt) ? IDLE : REFILL; //Halt instruction will keep it in IDLE forever
            REFILL: state <= IDLE; // 1 cycle refill only
            default: state <= NORUN;
        endcase
    end 
end
endmodule