module ff(d, clk, reset, en_low, q);
parameter WIDTH = 32;

input [WIDTH-1:0] d;
input reset, clk, en_low;
output reg [WIDTH-1:0] q;

//en is active low enable signal, connected to halt pin of Control Unit 

always @(posedge clk or posedge reset) begin
    if(reset)
        q <= {WIDTH{1'b0}};
    else if(en_low == 1'b0)
        q <= d;
    else
        q <= q;
end

endmodule