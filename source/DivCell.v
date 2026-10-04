//====================================================
// Author      : Ayush Yadav
// Version     : 1.0
//
// Description
// - Performs division yielding a single bit of quotient
// - can be cascaded to perform N bit division
// - remainder, dividend-quotient have one bit extra
//      compared to divisor so as to prevent errors in subtraction
//
// Change Log
// - decreased the number of bits in Divisor to prevent errors in subtraction - 4/10/2026
//====================================================

module DivCell # (
    parameter N = 32
) (
    input  wire [N-1:0] DQ_in,  REM_in, 
    input  wire [N-2:0] Divisor,
    output wire [N-1:0] DQ_out, REM_out  
);

    wire [N-1:0] new_REM, diff;

    assign new_REM = {REM_in[N-2:0], DQ_in[N-1]};
    assign diff = $signed(new_REM) - $signed({1'b0, Divisor});

    assign REM_out = diff[N-1] ? new_REM : diff;
    assign DQ_out = {DQ_in[N-2:0], ~diff[N-1]};

endmodule