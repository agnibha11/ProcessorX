//====================================================
// Project     : RISCV Single Cycle Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// Last Updated: 20-06-2026
//
// Changes:
// - Extended ALUControl to 5 bits for M ext.    20-06-2026
//====================================================


module datapath(input clk, reset, regWE, rs1SEL, rs2SEL, halt, input [1:0] pcSEL, regSEL, input [4:0] ALUControl, input [31:0] Instr, dmemData, output [31:0] pc, ALUResult, dmemWriteData);

wire [31:0] pc_current, pc_next; //Program Counter
wire [31:0] rd_out1, rd_out2, wr_data; //Register file i/p and o/p
wire [31:0] mux_rs1, mux_rs2; // o/p wire of MUXes at i/p of ALU
wire [31:0] ImmData; // o/p of ImmGen carrying Immediate data
wire [31:0] pc_4, pc_imm; // o/p of PC+4 and PC+Imm adders
wire [31:0] mux_branch; // o/p of MUX selecting is branch taken or not

/*
//Program counter
ff PC(
    .clk(clk),
    .reset(reset),
    .d(pc_next),
    .q(pc_current),
    .en_low(halt)
);
*/

assign pc = pc_current;

/*
//Register File
regfile REGFILE(
    .clk(clk),
    .reset(reset),
    .rs1(Instr[19:15]),
    .rs2(Instr[24:20]),
    .rd(Instr[11:7]),
    .w_data(wr_data),
    .w_en(regWE),
    .data_1(rd_out1),
    .data_2(rd_out2)
);
*/

assign dmemWriteData = rd_out2; //Data to be written in DMEM

/*
// MUX for RS1/PC for ALU A input
mux2 MUX_A(
    .B(pc_current),
    .A(rd_out1),
    .sel(rs1SEL),
    .out(mux_rs1)
);

// MUX for RS2/ImmData for ALU B input
mux2 MUX_B(
    .B(ImmData),
    .A(rd_out2),
    .sel(rs2SEL),
    .out(mux_rs2)
);

//ALU
alu ALU(
    .A(mux_rs1),
    .B(mux_rs2),
    .ALUControl(ALUControl),
    .Result(ALUResult)
);
*/

//Write Back MUX
/*
mux4 MUX_WB(
    .A(dmemData),
    .B(ALUResult),
    .C(ImmData),
    .D(pc_4),
    .sel(regSEL),
    .out(wr_data)
);
*/

/*
//Branch taken or not MUX
mux2 MUX_BR(
    .A(pc_4),
    .B(pc_imm),
    .sel(ALUResult[0]),
    .out(mux_branch)
);

//PC select MUX
mux4 MUX_PC(
    .A(pc_4),
    .B(ALUResult),
    .C(pc_imm),
    .D(mux_branch),
    .sel(pcSEL),
    .out(pc_next)
);
*/

/*
//PC + 4 adder
adder PC4(
    .a(pc_current),
    .b(4),
    .result(pc_4)
);

//PC + ImmData adder
adder PCIMM(
    .a(pc_current),
    .b(ImmData),
    .result(pc_imm)
);

//Immediate Data Generation
immgen IMMGEN(
    .Instr(Instr),
    .Imm(ImmData)
);
*/

endmodule