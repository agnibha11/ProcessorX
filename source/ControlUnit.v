//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 20-06-2026
//
// Changes:
// - Added M extension, extended ALUControl to 5 bits  -  20-06-2026
// - Added input to detect Hazard an insert Bubble -  29-06-2026
//====================================================


module controlunit(input [31:0] Instr, input bubble, output reg [4:0] ALUControl, output reg [2:0] dmemMode, output reg [1:0] regSEL, pcSEL, output reg dmemWE, dmemRE, regWE, rs1SEL, rs2SEL, halt);

//ALU Definitions
localparam ADD = 5'b00000;
localparam SUB = 5'b00001;
localparam AND = 5'b00010;
localparam OR = 5'b00011;
localparam XOR = 5'b00100;
localparam SLL = 5'b00101; //Shift Left Logical
localparam SRL = 5'b00110; //Shift Right Logical (Fill MSBs with 0s)
localparam SRA = 5'b00111; //Shift Right Arithmatic (Fill MSBs with sign bit)
localparam equal = 5'b01000;
localparam SLT = 5'b01001; // Set Less than
localparam SLTU = 5'b01010; //Set Less than unsigned
localparam greater_equal = 5'b01011; //Greater Than or Equal
localparam greater_equal_sign = 5'b01100; //Greater Than or Equal Signed
localparam JALR = 5'b01101; //Jump And Link Register Target address calculation
localparam not_equal = 5'b01110; //Not equal for branch instructions
localparam MUL = 5'b01111; //lower 32 bit returned (signed)
localparam MULH = 5'b10000; //upper 32 bit returned (signed)
localparam MULHSU = 5'b10001; //upper 32 bit returned (signed * unsigned)
localparam MULHU = 5'b10010; //upper 32 bit returned (unsigned)
localparam DIV = 5'b10011; //Signed division
localparam DIVU = 5'b10100; //Unsigned division 
localparam REM = 5'b10101; //Signed remainder
localparam REMU = 5'b10110; //Unsigned remainder

//extract funct3 funct7 opcode
wire [6:0] funct7, opcode;
wire [2:0] funct3;

assign funct7 = Instr[31:25];
assign opcode = Instr[6:0];
assign funct3 = Instr[14:12];

//Initialize all control signals to 0 at the begining
initial begin
    dmemMode    = 3'b000;
    dmemWE      = 1'b0;
    dmemRE      = 1'b0;
    regWE       = 1'b0;
    rs1SEL      = 1'b0;
    rs2SEL      = 1'b0;
    regSEL      = 2'b00; //00-dmemData, 01-ALUResult, 10-ImmData, 11-PC+4
    pcSEL       = 2'b00; //00-PC+4, 01-ALUResult, 10-PC+ImmData, 11-Branch
    ALUControl  = 5'b00000;
    halt        = 1'b0; //halt is active high instruction
end

always @(*) begin

    if(bubble) begin
        dmemMode    = 3'b000;
        dmemWE      = 1'b0;
        dmemRE      = 1'b0;
        regWE       = 1'b0;
        rs1SEL      = 1'b0;
        rs2SEL      = 1'b0;
        regSEL      = 2'b00; //00-dmemData, 01-ALUResult, 10-ImmData, 11-PC+4
        pcSEL       = 2'b00; //00-PC+4, 01-ALUResult, 10-PC+ImmData, 11-Branch
        ALUControl  = 5'b0000;
        halt        = 1'b0; //halt is active high instruction
    end
    else begin
        case(opcode)
            // LUI
            7'b0110111: begin 
                dmemMode    = 3'b000; //Does not matter, memory not accessed
                dmemWE      = 1'b0; //Write disabled
                dmemRE      = 1'b0; //Read disabled
                regWE       = 1'b1; //Write enabled for REG File  
                rs1SEL      = 1'b0; //does not matter
                rs2SEL      = 1'b0; //does not matter
                regSEL      = 2'b10; //Write Back MUX set to ImmData
                pcSEL       = 2'b00; //set to normal PC+4 counter
                ALUControl  = ADD; //Does not matter
                halt        = 1'b0; //halt is active high instruction
            end

            //AUIPC (ALU used as PC+ImmData is not the next PC value)
            7'b0010111: begin
                dmemMode    = 3'b000; //Does not matter, memory not accessed
                dmemWE      = 1'b0; //Write disabled
                dmemRE      = 1'b0; //Read disabled
                regWE       = 1'b1; //Write enabled for REG File  
                rs1SEL      = 1'b1; //A i/p of ALU set to PC
                rs2SEL      = 1'b1; //B i/p of ALU set to ImmData
                regSEL      = 2'b01; //Write Back MUX set to ALUResult
                pcSEL       = 2'b00; //set to normal PC+4 counter
                ALUControl  = ADD; //ADD Operation
                halt        = 1'b0; //halt is active high instruction
            end

            //JAL (ALU not used as PC+ImmData is the next PC value)
            7'b1101111: begin
                dmemMode    = 3'b000; //Does not matter, memory not accessed
                dmemWE      = 1'b0; //Write disabled
                dmemRE      = 1'b0; //Read disabled
                regWE       = 1'b1; //Write enabled for REG File  
                rs1SEL      = 1'b0; //does not matter
                rs2SEL      = 1'b0; //does not matter
                regSEL      = 2'b11; //Write Back MUX set to PC+4
                pcSEL       = 2'b10; //set to PC+ImmData
                ALUControl  = ADD; //does not matter
                halt        = 1'b0; //halt is active high instruction
            end

            //JALR
            7'b1100111: begin
                dmemMode    = 3'b000; //Does not matter, memory not accessed
                dmemWE      = 1'b0; //Write disabled
                dmemRE      = 1'b0; //Read disabled
                regWE       = 1'b1; //Write enabled for REG File  
                rs1SEL      = 1'b0; //A i/p set to rs1
                rs2SEL      = 1'b1; //B i/p set to ImmData
                regSEL      = 2'b11; //Write Back MUX set to PC+4
                pcSEL       = 2'b01; //set to ALUResult
                ALUControl  = JALR; // ADD rs1 + ImmData and clear LSB to 0
                halt        = 1'b0; //halt is active high instruction
            end

            //R Type
            7'b0110011: begin
                dmemMode    = 3'b000; //Does not matter, memory not accessed
                dmemWE      = 1'b0; //Write disabled
                dmemRE      = 1'b0; //Read disabled
                regWE       = 1'b1; //Write enabled for REG File  
                rs1SEL      = 1'b0; //A i/p set to rs1
                rs2SEL      = 1'b0; //B i/p set to rs2
                regSEL      = 2'b01; //Write Back MUX set to ALUResult
                pcSEL       = 2'b00; //set to normal PC+4 counter
                halt        = 1'b0; //halt is active high instruction

                case(funct3)
                    3'h0: ALUControl = (funct7 == 7'b0) ? ADD : (funct7 == 7'h20) ? SUB : (funct7 == 7'h01) ? MUL : 5'b11111;
                    3'h4: ALUControl = (funct7 == 7'b0) ? XOR : (funct7 == 7'h01) ? DIV : 5'b11111;
                    3'h6: ALUControl = (funct7 == 7'b0) ? OR : (funct7 == 7'h01) ? REM : 5'b11111;
                    3'h7: ALUControl = (funct7 == 7'b0) ? AND : (funct7 == 7'h01) ? REMU : 5'b11111;
                    3'h1: ALUControl = (funct7 == 7'b0) ? SLL : (funct7 == 7'h01) ? MULH : 5'b11111;
                    3'h5: ALUControl = (funct7 == 7'b0) ? SRL : (funct7 == 7'h20) ? SRA : (funct7 == 7'h01) ? DIVU : 5'b11111;
                    3'h2: ALUControl = (funct7 == 7'b0) ? SLT : (funct7 == 7'h01) ? MULHSU : 5'b11111;
                    3'h3: ALUControl = (funct7 == 7'b0) ? SLTU : (funct7 == 7'h01) ? MULHU : 5'b11111;
                    default: ALUControl = 5'b11111; //This sets the ALU o/p to XX..XXX
            endcase
            end

            // I Type ALU RegtoReg operations
            7'b0010011: begin
                dmemMode    = 3'b000; //Does not matter, memory not accessed
                dmemWE      = 1'b0; //Write disabled
                dmemRE      = 1'b0; //Read disabled
                regWE       = 1'b1; //Write enabled for REG File  
                rs1SEL      = 1'b0; //A i/p set to rs1
                rs2SEL      = 1'b1; //B i/p set to ImmData
                regSEL      = 2'b01; //Write Back MUX set to ALUResult
                pcSEL       = 2'b00; //set to normal PC+4 counter
                halt        = 1'b0; //halt is active high instruction

                case(funct3)
                    3'h0: ALUControl = ADD;
                    3'h4: ALUControl = XOR;
                    3'h6: ALUControl = OR;
                    3'h7: ALUControl = AND;
                    3'h1: ALUControl = (funct7 == 7'h0) ? SLL : 5'b11111;
                    3'h5: ALUControl = (funct7 == 7'h0) ? SRL : (funct7 == 7'h20) ? SRA : 5'b11111;
                    3'h2: ALUControl = SLT;
                    3'h3: ALUControl = SLTU;
                    default: ALUControl = 5'b11111;          
                endcase
            end

            //I Type Memory operations
            7'b0000011: begin
                dmemWE      = 1'b0; //Write disabled
                dmemRE      = 1'b1; //Read enabled
                regWE       = 1'b1; //Write enabled for REG File  
                rs1SEL      = 1'b0; //A i/p set to rs1
                rs2SEL      = 1'b1; //B i/p set to ImmData
                regSEL      = 2'b00; //Write Back MUX set to dmem output
                pcSEL       = 2'b00; //set to normal PC+4 counter
                ALUControl  = ADD; //ALL Operations need Addition only
                halt        = 1'b0; //halt is active high instruction

                case(funct3)
                    3'h0: dmemMode = 3'b100; //LB (sign extend)
                    3'h1: dmemMode = 3'b010; //LH (sign extend)
                    3'h2: dmemMode = 3'b000; //LW
                    3'h4: dmemMode = 3'b011; //LBU (zero extend)
                    3'h5: dmemMode = 3'b001; //LHU (zero extend)
                    default: dmemMode = 3'b111; //Default to 4 byte read
            endcase
            end

            //S Type
            7'b0100011: begin
                dmemWE      = 1'b1; //Write enabled
                dmemRE      = 1'b0; //Read disabled
                regWE       = 1'b0; //Write disabled for REG File  
                rs1SEL      = 1'b0; //A i/p set to rs1
                rs2SEL      = 1'b1; //B i/p set to ImmData
                regSEL      = 2'b00; //Write Back MUX does not matter
                pcSEL       = 2'b00; //set to normal PC+4 counter
                ALUControl  = ADD; // All instruction add rs1 + ImmData
                halt        = 1'b0; //halt is active high instruction

                case(funct3)
                    3'h0: dmemMode = 3'b011; //SB
                    3'h1: dmemMode = 3'b001; //SH
                    3'h2: dmemMode = 3'b000; //SW
                    default: dmemMode = 3'b111; //SW
                endcase
            end

            //B Type
            7'b1100011: begin
                dmemMode    = 3'b000; //does not matter
                dmemWE      = 1'b0; //Write disabled
                dmemRE      = 1'b0; //Read disabled
                regWE       = 1'b0; //Write disabled for REG File  
                rs1SEL      = 1'b0; //A i/p set to rs1
                rs2SEL      = 1'b0; //B i/p set to rs2
                regSEL      = 2'b00; //Write Back MUX does not matter
                pcSEL       = 2'b11; //set to Branch Instruction Path (logic for branch taken or not is decided outside Control Unit, in datapath)
                halt        = 1'b0; //halt is active high instruction

                case(funct3)
                    3'h0: ALUControl = equal; //BEQ
                    3'h1: ALUControl = not_equal; //BNE
                    3'h4: ALUControl = SLT; //BLT
                    3'h5: ALUControl = greater_equal_sign; //BGE
                    3'h6: ALUControl = SLTU; //BLTU
                    3'h7: ALUControl = greater_equal; //BGEU
                    default: ALUControl = 5'b11111;
            endcase
            end
            default: begin
                //check for halt instruction
                halt = (Instr == 32'hFFFFFFFF) ? 1'b1 : 1'b0;
                dmemMode    = 3'b000;
                dmemWE      = 1'b0;
                dmemRE      = 1'b0;
                regWE       = 1'b0;
                rs1SEL      = 1'b0;
                rs2SEL      = 1'b0;
                regSEL      = 2'b00;
                pcSEL       = 2'b00;
                ALUControl  = 5'b11111; //Corresponds to an Error Code for Testbench
            end
        endcase
    end
end


        
endmodule