//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 12-07-2026
//====================================================
//10 Bit GHR with 1024 entries of PHT henc 2KB PHT
module gshare(input clk, reset, update_en, update_taken, input [31:0] pc, input [9:0] update_index,
output [9:0] pht_index, output taken);

//pht_taken is the MSB of the 2 bit counter
//update_taken is the actual outcome
//update_en comes from the MEM stage

localparam ENTRIES = 1024; //Entries in PHT

reg [9:0] GHR;
reg [1:0] PHT [0:ENTRIES-1];

integer i;

//this is staged till the MEM stage and then returned in the event of a PHT update
assign pht_index = GHR ^ pc[11:2]; //this is because all instruction are always 4 byte aligned, so lower t bits always 0
assign taken = PHT[pht_index][1];

always @(posedge clk or posedge reset) begin
    if(reset) begin
        GHR <= 10'b0;
        for(i = 0; i < ENTRIES; i = i + 1)
            PHT[i] <= 2'b01; //The initial state is weakly not-taken
    end
    else if (update_en) begin
        //Update the GHR and PHT after the Branch resolution in MEM Stage
        if(update_taken) begin
            if(PHT[update_index] != 2'b11)
                PHT[update_index] <= PHT[update_index] + 2'b01; //Increase confidence
        end
        else begin
            if(PHT[update_index] != 2'b00)
                PHT[update_index] <= PHT[update_index] - 2'b01; 
        end
        //Update the GHR
        GHR <= {GHR[8:0],update_taken};
    end
end

endmodule