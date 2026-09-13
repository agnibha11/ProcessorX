`timescale 1ns/1ps
//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Testbench    : branch_predictor_tb   (tests gshare + btb together)
//
// A reference model mirrors ALL predictor state:
//   ref_ghr  (10b), ref_pht[1024] (2b saturating), ref_btb[32] (v/tag/tgt/cond)
// and reproduces the exact predict + update semantics, checking the four
// outputs (predict_taken, predict_target, pred_npc, pht_index) every cycle.
//
// Prediction (combinational):
//   pht_index     = ghr ^ pc[11:2]
//   predict_taken = predict_valid & btb_hit & (!is_cond | pht[idx][1])
//   predict_target= btb_target
//   pred_npc      = predict_taken ? btb_target : pc4
// Update (posedge):
//   branch (upd_en & upd_is_branch): saturating PHT[upd_idx], ghr<<=taken
//   btb    (upd_btb): install {valid,cond=upd_is_branch,tag,target} at upd_pc
//
// Directed tests give a few state-independent ABSOLUTE assertions
// (reset empty, unconditional hit, tag mismatch); the long random phase
// exercises GHR shifting, PHT saturation, BTB install/evict/tag against
// the reference. Quiet PASS + watchdog $finish (no giant VCD dump).
//====================================================

module branch_predictor_tb;

    reg         clk, reset;
    reg  [31:0] pc_predict, pc4_predict;
    reg         predict_valid;
    reg         upd_en, upd_is_branch, upd_taken, upd_btb;
    reg  [9:0]  upd_pht_index;
    reg  [31:0] upd_pc, upd_target;

    wire        predict_taken;
    wire [31:0] predict_target, pred_npc;
    wire [9:0]  pht_index;

    branch_predictor dut(
        .clk(clk), .reset(reset),
        .pc(pc_predict), .PC_4(pc4_predict), .enable_bp(predict_valid),
        .taken(predict_taken), .target_out(predict_target),
        .pred_next_pc(pred_npc), .pht_index(pht_index),
        .update_en(upd_en), .update_is_cond(upd_is_branch), .update_taken(upd_taken),
        .update_pht_index(upd_pht_index), .update_pc(upd_pc), .update_target(upd_target),
        .update_btb(upd_btb)
    );

    // ---- reference state ----
    reg [9:0]  ref_ghr;
    reg [1:0]  ref_pht [0:1023];
    reg        ref_v   [0:31];
    reg [24:0] ref_tag [0:31];
    reg [31:0] ref_tgt [0:31];
    reg        ref_cond[0:31];
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ref_ghr <= 10'b0;
            for (i = 0; i < 1024; i = i + 1) ref_pht[i] <= 2'b01;
            for (i = 0; i < 32;   i = i + 1) begin
                ref_v[i] <= 1'b0; ref_tag[i] <= 0; ref_tgt[i] <= 0; ref_cond[i] <= 0;
            end
        end else begin
            if (upd_en && upd_is_branch) begin
                if (upd_taken) begin
                    if (ref_pht[upd_pht_index] != 2'b11)
                        ref_pht[upd_pht_index] <= ref_pht[upd_pht_index] + 2'b01;
                end else begin
                    if (ref_pht[upd_pht_index] != 2'b00)
                        ref_pht[upd_pht_index] <= ref_pht[upd_pht_index] - 2'b01;
                end
                ref_ghr <= {ref_ghr[8:0], upd_taken};
            end
            if (upd_btb) begin
                ref_v[upd_pc[6:2]]    <= 1'b1;
                ref_tag[upd_pc[6:2]]  <= upd_pc[31:7];
                ref_tgt[upd_pc[6:2]]  <= upd_target;
                ref_cond[upd_pc[6:2]] <= upd_is_branch;
            end
        end
    end

    // ---- expected outputs ----
    reg        e_taken;
    reg [31:0] e_target, e_npc;
    reg [9:0]  e_index;

    task compute_expected;
        reg [9:0]  idx;
        reg [4:0]  bidx;
        reg        bhit, bcond, ptk;
        reg [31:0] btgt;
        begin
            idx  = ref_ghr ^ pc_predict[11:2];
            ptk  = ref_pht[idx][1];
            bidx = pc_predict[6:2];
            bhit = ref_v[bidx] && (ref_tag[bidx] == pc_predict[31:7]);
            bcond= ref_cond[bidx];
            btgt = ref_tgt[bidx];

            e_index  = idx;
            e_taken  = predict_valid && bhit && (!bcond || ptk);
            e_target = btgt;
            e_npc    = e_taken ? btgt : pc4_predict;
        end
    endtask

    integer test_count, pass_count, fail_count;

    task check;
        reg bad;
        begin
            test_count = test_count + 1;
            compute_expected;
            bad = 0;
            if (predict_taken  !== e_taken)  bad = 1;
            if (pht_index      !== e_index)  bad = 1;
            if (pred_npc       !== e_npc)    bad = 1;
            // predict_target is the raw BTB slot; compare it too
            if (predict_target !== e_target) bad = 1;
            if (bad) begin
                fail_count = fail_count + 1;
                $display("FAIL t=%0d pc=%h  taken e=%b g=%b | idx e=%h g=%h | npc e=%h g=%h | tgt e=%h g=%h  @%0t",
                    test_count, pc_predict, e_taken, predict_taken, e_index, pht_index,
                    e_npc, pred_npc, e_target, predict_target, $time);
            end else
                pass_count = pass_count + 1;
        end
    endtask

    // full-control single cycle
    task step;
        input [31:0] pc, pc4; input pv;
        input uen, uisbr, utk; input [9:0] uidx;
        input [31:0] upc, utgt; input ubtb;
        begin
            @(negedge clk);
            pc_predict=pc; pc4_predict=pc4; predict_valid=pv;
            upd_en=uen; upd_is_branch=uisbr; upd_taken=utk; upd_pht_index=uidx;
            upd_pc=upc; upd_target=utgt; upd_btb=ubtb;
            #1; check;
            @(posedge clk); #1;
        end
    endtask

    // convenience wrappers (no update)
    task predict; input [31:0] pc; input pv;
        begin step(pc, pc+4, pv, 0,0,0,0, 0,0, 0); end
    endtask

    // install a BTB entry WITHOUT touching GHR/PHT (upd_en=0)
    task install_btb; input [31:0] pc, tgt; input cond;
        begin step(pc, pc+4, 1'b1, 1'b0, cond, 1'b0, 10'b0, pc, tgt, 1'b1); end
    endtask

    integer k;
    reg [31:0] A, B, T;
    reg [9:0]  tr_idx;
    reg [31:0] B2, C, D;      // moved here (Verilog-2001: no reg decls in unnamed blocks)

    initial clk = 0; always #5 clk = ~clk;

    // watchdog
    initial begin
        #20000000;
        $display("TIMEOUT: last test_count=%0d (pass=%0d fail=%0d)", test_count, pass_count, fail_count);
        $finish;
    end

    initial begin
        test_count=0; pass_count=0; fail_count=0;
        pc_predict=0; pc4_predict=4; predict_valid=1;
        upd_en=0; upd_is_branch=0; upd_taken=0; upd_pht_index=0; upd_pc=0; upd_target=0; upd_btb=0;

        // reset
        reset=1; @(posedge clk); @(posedge clk); @(negedge clk); reset=0;

        // ---------- ABSOLUTE 1: empty BTB after reset -> never taken ----------
        A = 32'h0000_0100; B = 32'h0000_0240; T = 32'h0000_1000;
        predict(A, 1);
        if (predict_taken !== 1'b0)
            $display("ABS-FAIL reset: predict_taken=%b (want 0)", predict_taken);
        else $display("ABS-PASS reset empty BTB -> not taken");
        predict(B, 1);

        // ---------- ABSOLUTE 2: unconditional BTB hit -> taken (PHT irrelevant) ----------
        install_btb(A, T, 1'b0);          // cond=0 (jump), target T
        predict(A, 1);                    // must be taken with target T
        if (predict_taken !== 1'b1 || predict_target !== T || pred_npc !== T)
            $display("ABS-FAIL uncond hit: taken=%b tgt=%h npc=%h", predict_taken, predict_target, pred_npc);
        else $display("ABS-PASS unconditional hit -> taken, target forwarded");

        // ---------- ABSOLUTE 3: tag mismatch (same index, diff tag) -> miss ----------
        // choose B2 with same index as A (pc[6:2]) but different tag (pc[31:7])
        B2 = {A[31:7] ^ 25'h1, A[6:0]};   // flip a tag bit, keep index & low bits
        predict(B2, 1);
        if (predict_taken !== 1'b0)
            $display("ABS-FAIL tag mismatch: taken=%b (want 0)", predict_taken);
        else $display("ABS-PASS tag mismatch -> miss (not taken)");

        // ---------- ABSOLUTE 4: conditional hit, untrained PHT -> not taken ----------
        install_btb(B, T, 1'b1);          // cond=1
        predict(B, 1);                    // PHT weakly-not-taken -> not taken
        if (predict_taken !== 1'b0)
            $display("ABS-FAIL cond untrained: taken=%b (want 0)", predict_taken);
        else $display("ABS-PASS conditional + untrained PHT -> not taken");

        // ---------- ABSOLUTE 5: conditional hit, TRAINED PHT -> taken ----------
        // Train the exact counter B will use next cycle. B is installed (cond).
        // After a branch-update with taken=1, ghr becomes {ref_ghr[8:0],1}, so
        // next cycle's index for B is ({ref_ghr[8:0],1} ^ B[11:2]). Train that.
        tr_idx = ({ref_ghr[8:0], 1'b1}) ^ B[11:2];
        // branch update: PHT[tr_idx] 01->10 (MSB=1), ghr shifts; no BTB change
        step(A, A+4, 1'b1,  1'b1, 1'b1, 1'b1, tr_idx,  32'b0, 32'b0, 1'b0);
        predict(B, 1);                    // now index == tr_idx, pht=10 -> taken
        if (predict_taken !== 1'b1 || predict_target !== T)
            $display("ABS-FAIL cond trained: taken=%b tgt=%h (want 1,%h)", predict_taken, predict_target, T);
        else $display("ABS-PASS conditional + trained PHT -> taken");

        // ---------- BTB eviction / replacement (same index, different tag) ----------
        C = 32'h0000_0080;                 // some pc
        D = {C[31:7] ^ 25'h5, C[6:0]};     // same index, different tag
        install_btb(C, 32'h2000, 1'b0);
        predict(C, 1);                     // hit -> taken (uncond)
        install_btb(D, 32'h3000, 1'b0);    // evicts C's slot
        predict(C, 1);                     // now miss (tag changed)
        predict(D, 1);                     // hit

        // ---------- PHT saturation sweep at a fixed index (ref-checked) ----------
        // hammer taken then not-taken on one index; reference tracks saturation
        for (k = 0; k < 6; k = k + 1)
            step(32'h40, 32'h44, 1'b1, 1'b1, 1'b1, 1'b1, 10'h55, 32'b0, 32'b0, 1'b0);
        for (k = 0; k < 6; k = k + 1)
            step(32'h40, 32'h44, 1'b1, 1'b1, 1'b1, 1'b0, 10'h55, 32'b0, 32'b0, 1'b0);

        // ================= random phase =================
        // pcs and update pcs kept in a small window so BTB sees hits, evicts,
        // and tag aliasing; updates randomly train PHT / shift GHR / install BTB.
        for (i = 0; i < 8000; i = i + 1) begin
            step( (($random & 32'hFF) << 2),               // pc_predict  (word aligned, 0..0x3FC)
                  (($random & 32'hFF) << 2) + 4,           // pc4
                  ($random & 1'b1) | 1'b1,                 // predict_valid mostly 1
                  ($random & 1'b1),                        // upd_en
                  ($random & 1'b1),                        // upd_is_branch
                  ($random & 1'b1),                        // upd_taken
                  ($random & 10'h3FF),                     // upd_pht_index
                  (($random & 32'hFF) << 2),               // upd_pc  (same window)
                  {$random},                               // upd_target
                  ($random & 1'b1) );                      // upd_btb
            if ((i % 1000) == 0)
                $display("... random progress i=%0d test_count=%0d fails=%0d", i, test_count, fail_count);
        end

        // occasionally exercise predict_valid=0 (stall) explicitly
        for (i = 0; i < 200; i = i + 1)
            step( (($random & 32'hFF) << 2), (($random & 32'hFF) << 2)+4, 1'b0,
                  ($random & 1'b1), ($random & 1'b1), ($random & 1'b1), ($random & 10'h3FF),
                  (($random & 32'hFF) << 2), {$random}, ($random & 1'b1) );

        $display("--------------------------------------------------");
        $display("BRANCH PREDICTOR (Gshare + BTB) TEST SUMMARY");
        $display("Total checks : %0d", test_count);
        $display("Passed       : %0d", pass_count);
        $display("Failed       : %0d", fail_count);
        $display("--------------------------------------------------");
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else                 $display("SOME TESTS FAILED");
        $finish;
    end

endmodule