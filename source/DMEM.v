//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 20-06-2026

//
// Changes:
// - Added support for HALT, to keep FSM in IDLE forever  -  08-06-2026
// - Added support for flush when branch taken  -  08-06-2026
// - Modified to support Data Cache  -  09-07-2026
//====================================================
module dmem(input clk, reset, w_en, rd_en, input [31:0] addr, input [255:0] w_data, output reg [255:0] rd_data);
//addr is always 32 bit since RISC V CPU has address space that is 32 bit wide (4GB of space)

reg [7:0] mem [0:8191]; //8KB of data memory
parameter ADDR_WIDTH = 13; //Actual size of the address bus -> log2(8192)

wire [ADDR_WIDTH-1:0] a ;
assign a = addr[ADDR_WIDTH-1:0]; //internal adddress bus

//Little Endian

integer i;
always @(posedge clk or posedge reset) begin
    if(reset) begin
        for(i = 0; i < 8192; i = i+1)
            mem[i] <= 0;
        rd_data <= 256'b0;
    end
    else begin
        if(w_en) begin
            for (i = 0; i < 32; i = i + 1)
                mem[a + i] <= w_data[i*8 +: 8];
        end
        if (rd_en) begin
            for (i = 0; i < 8; i = i + 1)
                rd_data[i*32 +: 32] <= {mem[a + i*4 + 3],
                                        mem[a + i*4 + 2],
                                        mem[a + i*4 + 1],
                                        mem[a + i*4]};
        end
    end
end
endmodule