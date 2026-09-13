//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 20-06-2026
//
// Changes:
// Instruction Memory size updated   20-06-2026
// Changed to Byte stoarge Little Endian Memory  -  07-07-2026
// Increased memory size to 8KB  -  07-07-2026
// Read operation is now synchronous  -  08-07-2026
//====================================================

// The input address is 8 word block aligned starting address
module instrmem(input clk, reset, re, input [31:0] Addr, output reg [255:0] rd_instr);
	parameter INSTR_COUNT = 28;
	
	reg [7:0] mem [0:8191]; // 8KB Instruction Memory

	parameter INITIAL_DATA_PATH = "../programs/split_instructions.dat";
	
	initial
		$readmemh(INITIAL_DATA_PATH, mem);
	
	integer i;

	//Little Endian Memory loading
	always @(posedge clk or posedge reset) begin
		if(reset)
			rd_instr <= 0;
		else if(re) begin
			for(i = 0; i < 8; i = i + 1) 
				rd_instr[i*32 +: 32] <= {mem[Addr + i*4 + 3],mem[Addr + i*4 +2],mem[Addr+ i*4 + 1],mem[Addr + i*4]};
		end
	end
endmodule