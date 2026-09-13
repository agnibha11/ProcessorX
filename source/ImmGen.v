module immgen(input [31:0] Instr, output reg [31:0] Imm);
//the lower 7 bits of every type of instruction is opcode used to detect the type of instruction
//Decoding Instruction Type
wire [6:0] opcode;
assign opcode = Instr[6:0]; 

//This unit is entirely combinational
always @(*) begin
    casex(opcode)
        7'b00x0011, 7'b1110011, 7'b1100111: Imm = {{21{Instr[31]}},Instr[30:20]}; //I Type 
        7'b0100011: Imm = {{21{Instr[31]}},Instr[30:25],Instr[11:7]}; //S Type
        7'b1100011: Imm = {{20{Instr[31]}},Instr[7],Instr[30:25],Instr[11:8],1'b0}; //B Type
        7'b0x10111: Imm = {Instr[31:12],12'b0}; //U Type
        7'b1101111: Imm = {{12{Instr[31]}},Instr[19:12],Instr[20],Instr[30:25],Instr[24:21],1'b0}; //J Type
        default: Imm = 0;
    endcase
end
endmodule