//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 09-07-2026
//
//====================================================

module dcache_ctrl(input clk, reset, dmemRE_in, dmemWE_in, input [2:0] dmemMode, input [31:0] addr, st_fwrd_data, input [260:0] cache_data, input [255:0] block_dmem,
output reg [31:0] data, dmem_addr, output reg cache_miss, dmemRE_out, dmemWE_out, cacheWE, output reg [255:0] dmem_wr_data, output reg [4:0] cache_wr_index, output reg [260:0] cache_refill);

//FSM states
localparam NORUN = 2'b00;
localparam IDLE = 2'b01;
localparam EVICT = 2'b10;
localparam REFILL = 2'b11;

reg [1:0] state;

//checks if theres a memory operation at all
wire mem_op;
assign mem_op = dmemRE_in || dmemWE_in;
// No memory operation, then it can simply proceed without any memory operations

// address decomposition
wire [2:0] tag_addr, word_offset_addr;
wire [4:0] index_addr;
wire [1:0] byte_offset_addr;
wire [31:0] block_base_addr;

assign tag_addr = addr[12:10];
assign index_addr = addr[9:5];
assign word_offset_addr = addr[4:2];
assign byte_offset_addr = addr[1:0];
assign block_base_addr = {addr[31:5],5'b00000}; // block aligned address

// cache data decomposition
wire valid_cache, dirty_cache;
wire [2:0] tag_cache;
wire [255:0] block_cache;

assign valid_cache = cache_data[260];
assign dirty_cache = cache_data[259];
assign tag_cache = cache_data[258:256];
assign block_cache = cache_data[255:0];

//hit and evict signals
wire hit, evict;
wire [31:0] evict_addr;
assign hit = valid_cache && (tag_cache == tag_addr);
assign evict = valid_cache && dirty_cache;
assign evict_addr = {19'b0,tag_cache,index_addr,5'b00000}; //this is block aligned too

//store the forward data in the event of a stall
//hence after an IDLE or REFILL state, it latches the data.
reg [31:0] st_fwrd_data_latch;
always @(posedge clk or posedge reset) begin
    if(reset)
        st_fwrd_data_latch <= 0;
    else if(state == IDLE) //It latches wrong data at IDLE to IDLE, while correct data at IDLE to REFILL/EVICT
        st_fwrd_data_latch <= st_fwrd_data;
end

//function to load data using dmemMode
function [31:0] load_data;
    input [255:0] block;
    input [2:0] word_offset;
    input [1:0] byte_offset;
    input [2:0] mode;
    reg [31:0] word;
    reg [15:0] half_word;
    reg [7:0] byte_word;
    begin
        word = block[word_offset * 32 +: 32];
        half_word = byte_offset[1] ? word[31:16] : word[15:0];
        byte_word = byte_offset == 2'b00 ? word[7:0] :
                    byte_offset == 2'b01 ? word[15:8] :
                    byte_offset == 2'b10 ? word[23:16] : word[31:24];
        case(mode)
            3'b000: load_data = word; //LW
            3'b001: load_data = {16'b0,half_word}; //LHU
            3'b010: load_data = {{16{half_word[15]}}, half_word}; //LH
            3'b011: load_data = {24'b0,byte_word}; //LBU
            3'b100: load_data = {{24{byte_word[7]}},byte_word}; //LB
            default: load_data = word; //safe choice
        endcase
    end
endfunction

//function to modify data for store in cache
function [255:0] write_block;
    input [255:0] block;
    input [2:0] word_offset;
    input [1:0] byte_offset;
    input [2:0] mode;
    input [31:0] store_data;
    reg [31:0] write_word;
    reg [31:0] word;
    begin
        word = block[word_offset * 32 +: 32];
        // modify the word to be written to cache
        case(mode)
            3'b000: write_word = store_data; //SW
            3'b001, 3'b010: write_word = byte_offset[1] ? {store_data[15:0],word[15:0]} : {word[31:16],store_data[15:0]}; //SH
            3'b011, 3'b100: write_word = byte_offset == 2'b00 ? {word[31:8],store_data[7:0]} :
                                         byte_offset == 2'b01 ? {word[31:16],store_data[7:0],word[7:0]} :
                                         byte_offset == 2'b10 ? {word[31:24],store_data[7:0],word[15:0]} :
                                         {store_data[7:0], word[23:0]};
            default: write_word = store_data;
        endcase

        // update the cache block
        write_block = (word_offset == 3'b000) ? {block[255:32],  write_word} :
                      (word_offset == 3'b001) ? {block[255:64],  write_word, block[31:0]} :
                      (word_offset == 3'b010) ? {block[255:96],  write_word, block[63:0]} :
                      (word_offset == 3'b011) ? {block[255:128], write_word, block[95:0]} :
                      (word_offset == 3'b100) ? {block[255:160], write_word, block[127:0]} :
                      (word_offset == 3'b101) ? {block[255:192], write_word, block[159:0]} :
                      (word_offset == 3'b110) ? {block[255:224], write_word, block[191:0]} :
                      {write_word, block[223:0]};
end
endfunction


always @(*) begin
    //Cache address
    cache_wr_index = index_addr;
    case(state)
        IDLE: begin
            //there is no flush and cache miss conflict
            if(mem_op) begin
                if(hit) begin
                    cache_miss = 1'b0; //no stall
                    // decoding the type of operation
                    if(dmemRE_in) begin
                        // Cache Read Hit
                        cacheWE = 1'b0; //No writing to cache
                        dmemRE_out = 1'b0; //No DRAM operations
                        dmemWE_out = 1'b0;
                        data = load_data(block_cache, word_offset_addr /* logic[2:0] */,byte_offset_addr /* logic[1:0] */, dmemMode /* logic[2:0] */);
                    end
                    else begin
                        // Cache Write Hit
                        // Policy: Write-Back
                        cacheWE = 1'b1; // We will write to the cache in the next clock edge
                        //construct the entire cache block
                        dmemRE_out = 1'b0; // No DRAM operations
                        dmemWE_out = 1'b0;
                        cache_refill = {1'b1, 1'b1, tag_addr, write_block(block_cache, word_offset_addr, byte_offset_addr,dmemMode, st_fwrd_data)}; //Marked Dirty
                    end
                end
                else begin
                    //miss
                    cache_miss = 1'b1; //For stalling in next edge
                    cacheWE = 1'b0; // Next we fetch data, no cache write
                    if(evict) begin
                        // Eviction needed
                        dmemWE_out = 1'b1; // We write to DRAM in next edge
                        dmemRE_out = 1'b0; //No reads on same edge
                        dmem_addr = evict_addr; // block aligned address
                        dmem_wr_data = block_cache;
                    end
                    else begin
                        //No eviction
                        dmemRE_out = 1'b1; // Read from DRAM in next edge
                        dmemWE_out = 1'b0; //no writes to DRAM
                        dmem_addr = block_base_addr; //block aligned
                    end
                end
            end
            else begin
                cacheWE = 1'b0; //Disable for safety
                cache_miss = 1'b0; //Disable for safety
                dmemWE_out = dmemWE_in; //pass the control unit value
                dmemRE_out = dmemRE_in; //pass the control unit value
            end
        end

        EVICT: begin
            //next clock is also stall
            cache_miss = 1'b1;
            // DRAM already written on the edge
            dmemWE_out = 1'b0;
            // We need to read from DRAM on next edge
            dmemRE_out = 1'b1;
            dmem_addr = block_base_addr;
        end

        REFILL: begin
            //DRAM has been read after this clock
            dmemRE_out = 1'b0;//disable read
            dmemWE_out = 1'b0;//disable write
            //next clock we remove stall
            cache_miss = 1'b0;
            cacheWE = 1'b1; // We write to cache on next clock
            //check if its read or write miss
            if(dmemRE_in) begin
                // read miss
                //forward data to next stage
                data = load_data(block_dmem /* logic[255:0] */, word_offset_addr /* logic[2:0] */, byte_offset_addr /* logic[1:0] */, dmemMode /* logic[2:0] */);
                // construct the data to be written into cache
                //Not a dirty data
                cache_refill = {1'b1,1'b0, tag_addr, block_dmem};
            end
            else begin
                // write miss
                //Marked dirty
                cache_refill = {1'b1, 1'b1, tag_addr, write_block(block_dmem /* logic[255:0] */, word_offset_addr /* logic[2:0] */, byte_offset_addr /* logic[1:0] */, dmemMode /* logic[2:0] */, st_fwrd_data_latch /* logic[31:0] */)};
            end
        end
        default: begin
            data = 32'b0;
            cache_miss = 1'b0;
            dmemRE_out = 1'b0;
            dmemWE_out = 1'b0;
            dmem_addr = block_base_addr;
            cacheWE = 1'b0;
            cache_refill = {1'b0,1'b0, tag_addr, block_dmem};
        end
    endcase
end

// Controller FSM
always @(posedge clk or posedge reset) begin
    if(reset)
        state <= NORUN;
    else begin
        case(state)
            NORUN: state <= IDLE;
            IDLE: state <= (mem_op && !hit) ? (evict ? EVICT : REFILL) : IDLE;
            EVICT: state <= REFILL;
            REFILL: state <= IDLE;
            default: state <= NORUN;
        endcase
    end
end
endmodule