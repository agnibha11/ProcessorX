//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Author      : Agnibha Sarkar
//
// Revision    : v1.0
// First Updated: 20-06-2026
//
// Changes:
// - Added not_equal    18-06-2026
// - Added M extension, extended ALUControl to 5 bits    20-06-2026
//====================================================


module alu(input[31:0] A, B, input[4:0] ALUControl, output reg [31:0] Result, output Z);

//Zero Flag 
assign Z = ~(|Result);

//constants
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

wire [63:0] prod_sign, prod_unsigned, prod_su;
assign prod_sign = $signed(A) * $signed(B);
assign prod_unsigned = A * B;
assign prod_su = $signed(A) * $signed({1'b0,B});

always @(*) begin
   case(ALUControl)
      ADD: Result = A + B;
      SUB: Result = A - B;
      AND: Result = A & B;
      OR: Result = A | B;
      XOR: Result = A ^ B;
      SLL: Result = A << B[4:0];
      SRL: Result = A >> B[4:0];
      SRA: Result = $signed(A) >>> B[4:0];
      equal: Result = (A == B) ? 1 : 0;
      SLTU: Result = (A < B) ? 1 : 0;
      SLT: Result = ($signed(A) < $signed(B)) ? 1 : 0;
      greater_equal: Result = (A >= B) ? 1 : 0;
      greater_equal_sign: Result = ($signed(A) >= $signed(B)) ? 1 : 0;
      JALR: Result = ($signed(A) + $signed(B)) & 32'hFFFFFFFE;
      not_equal: Result = (A != B) ? 1 : 0;
      MUL: Result = prod_sign[31:0];
      MULH: Result = prod_sign[63:32];
      MULHSU: Result = prod_su[63:32];
      MULHU: Result = prod_unsigned[63:32];
      DIV: begin
         if(B == 0)
            Result = 32'hFFFFFFFF;

         else if(A == 32'h80000000 &&
                  B == 32'hFFFFFFFF)
            Result = 32'h80000000;

         else
            Result = $signed(A) / $signed(B);
      end
      DIVU: begin
         if(B == 0)  
            Result = 32'hFFFFFFFF;
         else 
            Result = A/B;
      end
      REM: begin
         if(B == 0) 
            Result = A; 
         else
            Result = $signed(A) % $signed(B);
      end
      REMU: Result = (B == 0) ? A : A % B;
      default: Result = 32'hXXXXXXXX; //ALU can't retain a value, purely combinational
   endcase
end
endmodule