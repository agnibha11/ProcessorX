module mux2(A, B, sel, out);
parameter WIDTH = 32;

input wire [WIDTH-1:0] A, B;
input wire sel;
output wire [WIDTH-1:0] out;

assign out = sel ? B : A;

endmodule