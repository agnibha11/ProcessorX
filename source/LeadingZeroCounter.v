//====================================================
// Author      : Ayush Yadav
// Version     : 1.0
//
// Description
// - Counts Leading Zeroes in the input.
// - N = power of 2 (always)
// - uses recursion to generate the tree
//====================================================

module LeadingZeroCounter #(
    parameter N = 32
) (
    input  wire [      N-1:0] X,
    output wire [$clog2(N):0] Y
);

    wire [(N/2)-1 : 0] H, L;

    assign H = X[N-1:N/2];
    assign L = X[(N/2)-1:0];

    wire [$clog2(N/2):0] H_zero, L_zero;

    generate
        if (N > 2) begin
            LeadingZeroCounter #(.N(N/2)) H_tree (
                .X(H),
                .Y(H_zero)
            );

            LeadingZeroCounter #(.N(N/2)) L_tree (
                .X(L),
                .Y(L_zero)
            );

            assign Y = (H_zero == N/2) ? H_zero + L_zero : H_zero;
        end else begin
            assign Y[1] = ~X[1] & ~X[0];
            assign Y[0] = ~X[1] & X[0];
        end
    endgenerate

endmodule