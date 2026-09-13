module adder(a, b, result);

//Adjustable width adder
parameter WIDTH = 32;
input wire [WIDTH-1:0] a,b;
output wire [WIDTH-1:0] result;

assign result = a + b;

endmodule