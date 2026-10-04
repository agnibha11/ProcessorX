//====================================================
// Author      : Ayush Yadav
// Version     : 1.0
//
// Description
// - Following module acts as a massive combinational path.
// - The reservation station module must use clock division
//   so as to provide this module enough time to execute.
//
// Change Log
//====================================================

module FloatDiv (
    input  wire [31:0] A, B,
    output wire [31:0] Q
);

    // dividing the inputs for ease of use
    wire [ 0:0] A_sig, B_sig;
    wire [ 9:0] A_exp, B_exp;
    wire [22:0] A_man, B_man;
    wire        A_nrm, B_nrm;

    assign A_sig = A[31];
    assign A_exp = {2'b0, A[30:23]};
    assign A_man = A[22:0];
    assign A_nrm = |A_exp;

    assign B_sig = B[31];
    assign B_exp = {2'b0, B[30:23]};
    assign B_man = B[22:0];
    assign B_nrm = |B_exp;

    // adding the hidden bit to both mantissas and attempting to get MSB = 1 via left shift
    wire [ 5:0] ls_A_amt, ls_B_amt;
    wire [23:0] A24, B24;
    wire [ 9:0] A_exp_adj, B_exp_adj;

    LeadingZeroCounter #(.N(32)) lzc_A (
        .X({A_nrm, A_man, 8'b0}),
        .Y({ls_A_amt})
    );

    LeadingZeroCounter #(.N(32)) lzc_B (
        .X({B_nrm, B_man, 8'b0}),
        .Y({ls_B_amt})
    );

    assign A24 = {A_nrm, A_man} << ls_A_amt;
    assign B24 = {B_nrm, B_man} << ls_B_amt;

    // adjusting the exponents to account for LEFT SHIFT and subnormals using 2^-126 rather than 2^-127
    assign A_exp_adj = $signed(A_exp) - $signed({4'b0, ls_A_amt}) + $signed({9'b0, ~A_nrm});
    assign B_exp_adj = $signed(B_exp) - $signed({4'b0, ls_B_amt}) + $signed({9'b0, ~B_nrm});

    //      if the number still doesnt have MSB = 1 then its 0
    // cascaded DivCell to form the full quotient

    wire [24:0] DQ_buf [24:0];
    wire [24:0] REM_buf [24:0];

    generate
        for (genvar i = 0; i < 25; i = i + 1) begin
            if (i == 0) begin
                DivCell #(.N(25)) div0 (
                    .DQ_in({A24[0], 24'b0}), .REM_in({2'b0, A24[23:1]}), .Divisor(B24),
                    .DQ_out(DQ_buf[i]), .REM_out(REM_buf[i])
                );
            end else begin
                DivCell #(.N(25)) div1 (
                    .DQ_in(DQ_buf[i-1]), .REM_in(REM_buf[i-1]), .Divisor(B24),
                    .DQ_out(DQ_buf[i]), .REM_out(REM_buf[i])
                );
            end
        end
    endgenerate

    wire [ 9:0] Q_exp;
    wire [24:0] Q_div, REM_div;

    //      the division result is in 1.X format i convert it to 0.X format by adding 1 to exponent (127+1=128)
    //      it is converted to this format so that the roudning and formatting logic is same as FloatMul
    assign Q_exp = $signed(A_exp_adj) - $signed(B_exp_adj) + $signed(10'd128);
    assign Q_div = DQ_buf[24];
    assign REM_div = REM_buf[24];

    // calculating leading zero count in p_exp
    wire [9:0] lz;

    assign lz = {9'b0, ~Q_div[24]}; // there can be at max 1 leading zero

    // calculating resultant P and E for if E < 1 : potential SUBNORMAL
    wire [ 4:0] rs_amt;
    wire [24:0] Q_Elt1;
    wire [ 9:0] Q_exp_Elt1;

    assign rs_amt = (($signed(10'd1) - $signed(Q_exp)) < 10'd25) ? $signed(10'd1) - $signed(Q_exp) : 10'd25;
    assign Q_Elt1 = Q_div >> rs_amt;
    assign Q_exp_Elt1 = (($signed(Q_exp) + $signed({5'b0, rs_amt})) == 10'd1) ? 10'd0 : ($signed(Q_exp) + $signed({5'b0, rs_amt}));

    // calculating resultant P and E for if E >= 1 : potential NORMAL / SUBNORMAL
    wire [ 4:0] ls_amt;
    wire [24:0] Q_Egt1_tmp, Q_Egt1;
    wire [ 9:0] Q_exp_Egt1_tmp, Q_exp_Egt1;

    assign ls_amt = ($signed(lz) < ($signed(Q_exp) - $signed(10'd2))) ? lz : ($signed(Q_exp) - $signed(10'd2));
    assign Q_Egt1_tmp = Q_div << ls_amt;
    assign Q_exp_Egt1_tmp = Q_exp - {5'b0, ls_amt};

    assign Q_Egt1 = Q_Egt1_tmp << 1;
    assign Q_exp_Egt1 = Q_Egt1_tmp[24] ? Q_exp_Egt1_tmp - 10'd1 : 10'd0;

    // selecting results based on exponent value
    wire [24:0] Q_preRnd;
    wire [ 9:0] Q_exp_preRnd;

    assign Q_preRnd = ($signed(Q_exp) <= $signed(10'd1)) ? Q_Elt1 : Q_Egt1;
    assign Q_exp_preRnd = ($signed(Q_exp) <= $signed(10'd1)) ? Q_exp_Elt1 : Q_exp_Egt1;

    // rounding
    wire [22:0] mantissa, mantissa_r;
    wire        rnd_inc;
    wire        carry;
    wire [ 9:0] r_exp;

    assign mantissa = Q_preRnd[24:2];
    assign rnd_inc = Q_preRnd[1] & ((Q_preRnd[0] | |REM_div) | Q_preRnd[2]);
    assign {carry, mantissa_r} = mantissa + {22'b0, rnd_inc};

    assign r_exp = $signed(Q_exp_preRnd) + $signed({9'b0, carry});

    // output generation
    wire [ 7:0] capped_exp;
    wire [22:0] capped_m;

    assign capped_exp = ($signed(r_exp) < $signed(10'd0)) ? 8'b0 : (($signed(r_exp) >= $signed(10'd255)) ? 10'd255 : r_exp[7:0]);
    assign capped_m = ($signed(r_exp) < $signed(10'd0)) ? 23'b0 : (($signed(r_exp) >= $signed(10'd255)) ? 23'b0 : mantissa_r);

    assign Q = {
        A[31] ^ B[31],
        capped_exp,
        capped_m
    };

endmodule