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

module FloatMul (
    input  wire [31:0] A, B,
    output wire [31:0] P
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

    // getting the full mantissas and multiplying
    wire [23:0] A24, B24;
    wire [47:0] prod;
    wire [ 9:0] p_exp;
    wire [ 1:0] sub_nrm_bias;

    assign A24 = {A_nrm, A_man};
    assign B24 = {B_nrm, B_man};
    assign prod = A24 * B24;
    assign sub_nrm_bias = {1'b0, ~A_nrm} + {1'b0, ~B_nrm};
    assign p_exp = $signed(A_exp) + $signed(B_exp) - $signed(10'd125) + $signed({8'b0, sub_nrm_bias});

    // calculating leading zero count in p_exp
    wire [6:0] lz; 
    LeadingZeroCounter #(.N(64)) LZC (
        .X({prod, 16'hffff}),
        .Y(lz)
    );

    // calculating resultant P and E for if E < 1 : potential SUBNORMAL
    wire [ 4:0] rs_amt;
    wire [47:0] prod_Elt1;
    wire [ 9:0] p_exp_Elt1;

    assign rs_amt = (($signed(10'd1) - $signed(p_exp)) < 10'd31) ? $signed(10'd1) - $signed(p_exp) : 10'd31;
    assign prod_Elt1 = prod >> rs_amt;
    assign p_exp_Elt1 = (($signed(p_exp) + $signed({5'b0, rs_amt})) == 10'd1) ? 10'd0 : ($signed(p_exp) + $signed({5'b0, rs_amt}));

    // calculating resultant P and E for if E >= 1 : potential NORMAL / SUBNORMAL
    wire [ 4:0] ls_amt;
    wire [47:0] prod_Egt1_tmp, prod_Egt1;
    wire [ 9:0] p_exp_Egt1_tmp, p_exp_Egt1;

    assign ls_amt = ($signed({4'b0, lz}) < ($signed(p_exp) - $signed(10'd2))) ? {4'b0, lz} : ($signed(p_exp) - $signed(10'd2));
    assign prod_Egt1_tmp = prod << ls_amt;
    assign p_exp_Egt1_tmp = p_exp - {5'b0, ls_amt};

    assign prod_Egt1 = prod_Egt1_tmp << 1;
    assign p_exp_Egt1 = prod_Egt1_tmp[47] ? p_exp_Egt1_tmp - 10'd1 : 10'd0;

    // selecting results based on exponent value
    wire [47:0] prod_preRnd;
    wire [ 9:0] p_exp_preRnd;

    assign prod_preRnd = ($signed(p_exp) <= $signed(10'd1)) ? prod_Elt1 : prod_Egt1;
    assign p_exp_preRnd = ($signed(p_exp) <= $signed(10'd1)) ? p_exp_Elt1 : p_exp_Egt1;

    // rounding
    wire [22:0] mantissa, mantissa_r;
    wire        rnd_inc;
    wire        carry;
    wire [ 9:0] r_exp;

    assign mantissa = prod_preRnd[47:25];
    assign rnd_inc = prod_preRnd[24] & (|prod_preRnd[23:0] | prod_preRnd[25]);
    assign {carry, mantissa_r} = mantissa + {22'b0, rnd_inc};

    assign r_exp = $signed(p_exp_preRnd) + $signed({9'b0, carry});

    // output generation
    wire [ 7:0] capped_exp;
    wire [22:0] capped_m;

    assign capped_exp = ($signed(r_exp) < $signed(10'd0)) ? 8'b0 : (($signed(r_exp) >= $signed(10'd255)) ? 10'd255 : r_exp[7:0]);
    assign capped_m = ($signed(r_exp) < $signed(10'd0)) ? 23'b0 : (($signed(r_exp) >= $signed(10'd255)) ? 23'b0 : mantissa_r);

    assign P = {
        A[31] ^ B[31],
        capped_exp,
        capped_m
    };

endmodule