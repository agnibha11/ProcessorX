//====================================================
// Author      : Ayush Yadav
// Version     : 1.0
//
// Description
// - Following module acts as a massive combinational path.
// - The reservation station module must use clock division
//   so as to provide this module enough time to execute.
// - Doesn't support NaNs, Infinities, Zeroes, Negative numbers
//
// Change Log
//====================================================

module FloatSqrt (
    input  wire [31:0] X,
    output wire [31:0] Y
);

    // dividing the inputs for ease of use
    wire [ 0:0] X_sig;
    wire [ 9:0] X_exp;
    wire [22:0] X_man;
    wire        X_nrm;

    assign X_sig = X[31];
    assign X_exp = ({2'b0, X[30:23]});
    assign X_man = X[22:0];
    assign X_nrm = |X_exp;

    // arranging X
    wire [25:0] norm_man_fin;
    wire [ 9:0] norm_exp_fin;

    assign norm_man_fin = ~X_exp[0] ? {1'b1, X_man, 2'b00} : {2'b01, X_man, 1'b0};
    assign norm_exp_fin = $signed(X_exp) + (~X_exp[0] ? $signed(10'd1) : $signed(10'd2)) - $signed(10'd127);

    wire [ 5:0] ls_sub_amt;

    LeadingZeroCounter #(.N(32)) lzc_X (
        .X({1'b0, X_man, 8'b0}),
        .Y({ls_sub_amt})
    );

    wire [31:0] sub_X_tmp_man;
    wire [ 9:0] sub_X_tmp_exp;

    assign sub_X_tmp_man = {1'b0, X_man, 8'b0} << ls_sub_amt;
    assign sub_X_tmp_exp = $signed(10'd2) - $signed({3'b0, ls_sub_amt}); // subnorm exp = 1, 1+1 = 2

    wire [25:0] sub_man_fin;
    wire [ 9:0] sub_exp_fin;

    assign sub_man_fin = ~sub_X_tmp_exp[0] ? {1'b0, sub_X_tmp_man[31:9], 2'b00} : {sub_X_tmp_man[31:9], 3'b000};
    assign sub_exp_fin = ~sub_X_tmp_exp[0] ? $signed(sub_X_tmp_exp) - $signed(10'd126) : $signed(sub_X_tmp_exp) - $signed(127);

    wire [25:0] X_man_fin;
    wire [ 9:0] X_exp_fin;

    assign X_man_fin = X_nrm ? norm_man_fin : sub_man_fin;
    assign X_exp_fin = X_nrm ? norm_exp_fin : sub_exp_fin;

    // doing SQRT by cascading sqrt cells
    wire [49:0] dividends [25:0];
    wire [49:0] extra_dividends [25:0];
    wire [25:0] divisors [25:0];
    wire [24:0] quotients [25:0];

    // init
    assign dividends[0] = 50'b0;
    assign extra_dividends[0] = {X_man_fin, 24'b0};
    assign divisors[0] = 26'b0;
    assign quotients[0] = 25'b0;

    // cascading
    generate
        for (genvar i = 0; i < 25; i = i + 1) begin
            SqrtCell sqrt_cell (
                .dividend_in(dividends[i]), .extra_dividend_in(extra_dividends[i]),
                .divisor_in(divisors[i]),
                .quotient_in(quotients[i]),

                .dividend_out(dividends[i+1]), .extra_dividend_out(extra_dividends[i+1]),
                .divisor_out(divisors[i+1]),
                .quotient_out(quotients[i+1])
            );
        end
    endgenerate

    // output renaming for ease of use
    wire [24:0] sqrt_man25;
    wire [ 9:0] sqrt_exp25;

    assign sqrt_man25 = quotients[25];
    assign sqrt_exp25 = $signed({X_exp_fin[9], X_exp_fin[9:1]}) + $signed(10'd127);

    // the output will always be a NORMAL number as the exponent gets divided by 2
    // thus subnormal generation logic is not needed and sqrt_exp25 is already in NORMAL range
    // due to the arrangement of number beforehand the sqrt MSB is always = 1

    // rounding
    wire [22:0] mantissa, mantissa_r;
    wire        rnd_inc;
    wire        carry;
    wire [ 9:0] r_exp;

    assign mantissa = sqrt_man25[23:1];
    assign rnd_inc = sqrt_man25[0] & (|dividends[25] | sqrt_man25[1]); // dividends[25] here is remainder
    assign {carry, mantissa_r} = mantissa + {22'b0, rnd_inc};

    assign r_exp = $signed(sqrt_exp25) + $signed({9'b0, carry}) - $signed(10'd1);

    // output generation

    assign Y = {
        1'b0,
        r_exp[7:0],
        mantissa_r
    };

endmodule