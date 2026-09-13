module mux4(A, B, C, D, sel, out);
parameter WIDTH = 32;
input wire [WIDTH-1:0] A,B,C,D;
input wire [1:0] sel;
output reg [WIDTH-1:0] out;

always @(*) begin
    case(sel)
        2'b00: out = A;
        2'b01: out = B;
        2'b10: out = C;
        default: out = D;
    endcase
end
endmodule