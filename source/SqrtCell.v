//====================================================
// Author      : Ayush Yadav
// Version     : 1.0
//
// Description
// - Performs sqrt yielding a single bit of sqrt using long division method
// - can be cascaded to perform 25 bit sqrt
// - the module can be edited to perform N bit operation but that is not needed right now
//
// Change Log
//====================================================

module SqrtCell (
    input  wire [49:0] dividend_in, extra_dividend_in,
    input  wire [25:0] divisor_in,
    input  wire [24:0] quotient_in,

    output wire [49:0] dividend_out, extra_dividend_out,
    output wire [25:0] divisor_out,
    output wire [24:0] quotient_out
);
    wire [49:0] new_dividend;
    wire [25:0] trial_div;
    assign trial_div = {divisor_in[24:0], 1'b1};
    assign new_dividend = {dividend_in[47:0], extra_dividend_in[49:48]};

    assign extra_dividend_out = {extra_dividend_in[47:0], 2'b0};

    wire [50:0] diff;
    assign diff = $signed({1'b0, new_dividend}) - $signed({25'b0, trial_div});

    wire new_qBit;
    assign new_qBit = diff[50] ? 1'b0 : 1'b1;

    assign dividend_out = diff[50] ? new_dividend : diff[49:0];
    assign divisor_out = diff[50] ? {divisor_in[24:0], 1'b0} : trial_div + 26'd1;
    assign quotient_out = {quotient_in[23:0], new_qBit};

endmodule