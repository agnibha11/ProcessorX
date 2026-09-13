//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 12-07-2026
//====================================================
//32 Entries BTB Cache, so 32Bytes of BTB
module btb (input clk, reset, update_en, update_is_cond, input [31:0] pc, update_pc, target_in,
output hit, is_cond, output [31:0] target_out);

localparam ENTRIES = 32;

// The Branch Target Buffer Cache
reg valid [0:31];
reg [24:0] tag_btb [0:31];
reg [31:0] target [0:31];
reg cond [0:31];

integer i;

// Current PC Decomposition
wire [4:0] index_current;
wire [24:0] tag_addr_current;
assign index_current = pc[6:2];
assign tag_addr_current = pc[31:7]; //25 bit tag

// Check for hits using current PC
assign hit = valid[index_current] && (tag_addr_current == tag_btb[index_current]);
assign target_out = target[index_current];
assign is_cond = cond[index_current];

//Update PC decompositon
wire [4:0] index_update;
wire [24:0] tag_addr_update;
assign index_update = update_pc[6:2];
assign tag_addr_update = update_pc[31:7]; //25 bit tag


always @(posedge clk or posedge reset) begin
    if(reset) begin
        for (i = 0; i < ENTRIES; i = i+1) begin
            valid[i] <= 1'b0;
            tag_btb[i] <= 25'b0;
            target[i] <= 32'b0;
            cond[i] <= 1'b0;
        end
    end
    else if(update_en) begin
        //This update is after resolution in MEM stage
        valid[index_update] <= 1'b1;
        tag_btb[index_update] <= tag_addr_update;
        target[index_update] <= target_in;
        cond[index_update] <= update_is_cond;
    end
end
endmodule