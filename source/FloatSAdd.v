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

module FloatSAdd (
    input  wire [31:0] A, B,
    output wire [31:0] S
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

    // getting mantissa24
    wire [23:0] A_man24, B_man24;
    assign A_man24 = {A_nrm, A_man};
    assign B_man24 = {B_nrm, B_man};

    // finding the bigger value
    wire isA_exp_big, isA_exp_eq, isA_big;
    assign isA_exp_big = $signed(A_exp) > $signed(B_exp);
    assign isA_exp_eq = $signed(A_exp) == $signed(B_exp);

    assign isA_big = isA_exp_eq ? (A_man24 >= B_man24) : isA_exp_big;

    // swapping the value accordingly
    wire         big_sig;
    wire  [ 9:0] big_exp, sml_exp;
    wire  [23:0] big_man24, sml_man24;
    wire         isSub; // effective operation based on the sign

    assign isSub = A_sig ^ B_sig;

    assign big_sig = isA_big ? A_sig : B_sig;
    assign big_exp = isA_big ? A_exp : B_exp;
    assign sml_exp = isA_big ? B_exp : A_exp;
    assign big_man24 = isA_big ? A_man24 : B_man24;
    assign sml_man24 = isA_big ? B_man24 : A_man24;

    // shifting small number to match the exponent with the big one
    wire [ 9:0] exp_diff, setup_rs_amt;
    wire [ 9:0] sft_sml_exp;
    wire [49:0] sft_sml_man_full;
    wire [26:0] sft_sml_man;

    assign exp_diff = $signed(big_exp) - $signed(sml_exp) - $signed({9'b0, (~|sml_exp) & (|big_exp)});
    assign setup_rs_amt = ($signed(exp_diff) < 10'd26) ? exp_diff : 10'd26;
    assign sft_sml_man_full = {sml_man24, 26'b0} >> setup_rs_amt;
    assign sft_sml_man = {sft_sml_man_full[49:24], |sft_sml_man_full[23:0]};

    // ADD / SUB
    wire        res_sig;
    wire [27:0] res_man;
    wire [ 9:0] res_exp;
    wire        grbg;

    assign res_sig = big_sig;
    assign {grbg, res_man} = {1'b0, big_man24, 3'b0} + ({28{isSub}} ^ {1'b0, sft_sml_man}) + {27'b0, isSub};
    //      res_man here has one-extra bit to account for the carry that might be produced
    //      grbg bit is produced and is thrown off during 2s complement addition (subtraction)
    assign res_exp = $signed(big_exp) + $signed(10'd2) + $signed({9'b0, ~|big_exp}); // last term for subnormal handling

    // calculating leading zero count in result
    wire [5:0] lz; 
    LeadingZeroCounter #(.N(32)) LZC (
        .X({res_man, 4'hf}),
        .Y(lz)
    );

    // the minimum value of E is 3

    // calculating resultant SUM and E for if E >= 1 : potential NORMAL / SUBNORMAL
    wire [ 4:0] ls_amt;
    wire [27:0] sum_Egt1_tmp, sum_Egt1;
    wire [ 9:0] s_exp_Egt1_tmp, s_exp_Egt1;

    assign ls_amt = ($signed({4'b0, lz}) < ($signed(res_exp) - $signed(10'd2))) ? {4'b0, lz} : ($signed(res_exp) - $signed(10'd2));
    assign sum_Egt1_tmp = res_man << ls_amt;
    assign s_exp_Egt1_tmp = res_exp - {5'b0, ls_amt};

    assign sum_Egt1 = sum_Egt1_tmp << 1;
    assign s_exp_Egt1 = sum_Egt1_tmp[27] ? s_exp_Egt1_tmp - 10'd1 : 10'd0;

    // selecting results based on exponent value
    // in this case there is no E < 1 option but this section is preserved to keep flow similar to other modules
    wire [27:0] sum_preRnd;
    wire [ 9:0] s_exp_preRnd;

    assign sum_preRnd = sum_Egt1;
    assign s_exp_preRnd = s_exp_Egt1;

    // rounding
    wire [22:0] mantissa, mantissa_r;
    wire        rnd_inc;
    wire        carry;
    wire [ 9:0] r_exp;

    assign mantissa = sum_preRnd[27:5];
    assign rnd_inc = sum_preRnd[4] & (|sum_preRnd[3:0] | sum_preRnd[5]);
    assign {carry, mantissa_r} = mantissa + {22'b0, rnd_inc};

    assign r_exp = $signed(s_exp_preRnd) + $signed({9'b0, carry});

    // output generation
    wire [ 7:0] capped_exp;
    wire [22:0] capped_m;

    assign capped_exp = ($signed(r_exp) < $signed(10'd0)) ? 8'b0 : (($signed(r_exp) >= $signed(10'd255)) ? 10'd255 : r_exp[7:0]);
    assign capped_m = ($signed(r_exp) < $signed(10'd0)) ? 23'b0 : (($signed(r_exp) >= $signed(10'd255)) ? 23'b0 : mantissa_r);

    assign S = {
        res_sig,
        capped_exp,
        capped_m
    };

endmodule