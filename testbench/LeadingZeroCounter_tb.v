`timescale 1ns/1ps

module LeadingZeroCounter_tb;

    reg [31:0] X;
    wire [5:0] Y;

    LeadingZeroCounter #(.N(32)) uut (
        .X(X),
        .Y(Y)
    );

    initial begin
            X = 32'h0000_0000;
        #10 X = 32'h0fff_ffff;
        #10 X = 32'h04ff_ffff;
        #10 $finish;
    end

endmodule