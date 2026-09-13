//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 09-07-2026
//
//====================================================

// 32 entries and 8 word per block
// 1KB Cache Memory
module dcache_mem(input clk, reset, we, input [4:0] rd_index, wr_index, input [260:0] wr_data,
output reg [260:0] rd_data);

localparam LINE_WIDTH = 261; 
localparam ENTRIES = 32;

// The Cache memory
reg [LINE_WIDTH-1:0] cache [0:ENTRIES-1]; //1KB Cache

integer i;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        for(i = 0; i < ENTRIES; i = i + 1)
            cache[i] <= 0;
        rd_data <= 0; 
    end
    else begin
        if(we)
            cache[wr_index] <= wr_data;

        // Synchronous read with write first bypass    
        if(we && (wr_index == rd_index))
            rd_data <= wr_data;
        else
            rd_data <= cache[rd_index];
    end

end

endmodule