`timescale 1ns/1ps
//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Testbench    : instrmem_tb
//
// Verifies the modified instruction memory that returns a full
// 8-word (32-byte) block on a synchronous, re-gated read.
//
// Method:
//   * Loads the SAME split_instructions.dat (byte-per-line, little
//     endian) into a golden byte array.
//   * Auto-detects how much of the 8 KB is populated.
//   * Sweeps every 32-byte block base across the populated region,
//     pulses re, waits one clock (synchronous read), and compares all
//     8 words of rd_instr against the golden block it assembles the
//     same way the DUT does: word = {mem[b+3],mem[b+2],mem[b+1],mem[b]}.
//   * Also checks reset clears the output and that re=0 holds it.
// Prints PASS/FAIL per block (and per mismatching word) with a summary.
//====================================================

module instrmem_tb;

    localparam DATA_PATH = "../programs/split_instructions.dat"; // same file the DUT loads

    reg          clk, reset, re;
    reg  [31:0]  Addr;
    wire [255:0] rd_instr;

    // ---- DUT ----
    instrmem dut(
        .clk(clk), .reset(reset), .re(re),
        .Addr(Addr), .rd_instr(rd_instr)
    );

    // ---- golden byte memory (mirror of the file) ----
    reg [7:0] gold [0:8191];

    integer i, b, w;
    integer last_byte, num_blocks;
    integer test_count, pass_count, fail_count, word_fail;
    reg [255:0] exp_block;
    reg [31:0]  exp_word, got_word;
    reg         block_ok;

    // assemble the expected 32-bit little-endian word at byte address a
    function [31:0] gword;
        input integer a;
        begin
            gword = {gold[a+3], gold[a+2], gold[a+1], gold[a]};
        end
    endfunction

    // ---- clock ----
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- one block read + check ----
    task read_and_check;
        input integer base;
        begin
            @(negedge clk);
            Addr = base;
            re   = 1'b1;
            @(posedge clk);       // synchronous read latches here
            #1;

            // build expected block: word k at bits [k*32 +: 32]
            for (w = 0; w < 8; w = w + 1)
                exp_block[w*32 +: 32] = gword(base + w*4);

            test_count = test_count + 1;
            block_ok   = (rd_instr === exp_block);

            if (block_ok) begin
                pass_count = pass_count + 1;
                $display("PASS  block @%0h  (words %h_%h_%h_%h_%h_%h_%h_%h)",
                         base,
                         rd_instr[7*32 +: 32], rd_instr[6*32 +: 32],
                         rd_instr[5*32 +: 32], rd_instr[4*32 +: 32],
                         rd_instr[3*32 +: 32], rd_instr[2*32 +: 32],
                         rd_instr[1*32 +: 32], rd_instr[0*32 +: 32]);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL  block @%0h", base);
                for (w = 0; w < 8; w = w + 1) begin
                    exp_word = exp_block[w*32 +: 32];
                    got_word = rd_instr[w*32 +: 32];
                    if (exp_word !== got_word)
                        $display("      word %0d (byte @%0h): exp=%h got=%h",
                                 w, base + w*4, exp_word, got_word);
                end
            end
        end
    endtask

    initial begin
        $dumpfile("instrmem_tb.vcd");
        $dumpvars(0, instrmem_tb);

        test_count = 0; pass_count = 0; fail_count = 0;

        // load our own golden copy of the same file
        for (i = 0; i < 8192; i = i + 1) gold[i] = 8'hxx;
        $readmemh(DATA_PATH, gold);

        // find last populated byte
        last_byte = -1;
        for (i = 0; i < 8192; i = i + 1)
            if (gold[i] !== 8'hxx) last_byte = i;

        if (last_byte < 0) begin
            $display("ERROR: %0s appears empty / not found. Nothing to test.", DATA_PATH);
            $finish;
        end

        num_blocks = (last_byte >> 5) + 1;   // ceil over 32-byte blocks
        $display("Loaded program: last byte @%0d  ->  %0d block(s) to check", last_byte, num_blocks);

        // ---------- reset check ----------
        reset = 1; re = 0; Addr = 0;
        @(posedge clk); #1;
        test_count = test_count + 1;
        if (rd_instr === 256'b0) begin
            pass_count = pass_count + 1;
            $display("PASS  reset clears rd_instr");
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL  reset: rd_instr=%h (expected 0)", rd_instr);
        end
        @(negedge clk); reset = 0;

        // ---------- sweep every populated block ----------
        for (b = 0; b < num_blocks; b = b + 1)
            read_and_check(b * 32);

        // ---------- re=0 hold check ----------
        // do a valid read, then deassert re and change Addr; output must hold
        read_and_check(0);                       // leaves a known block on the bus
        @(negedge clk);
        re   = 1'b0;
        Addr = 32'h0000_0100;                    // change address, but re=0
        exp_block = rd_instr;                    // remember current output
        @(posedge clk); #1;
        test_count = test_count + 1;
        if (rd_instr === exp_block) begin
            pass_count = pass_count + 1;
            $display("PASS  re=0 holds previous block");
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL  re=0 did not hold: was=%h now=%h", exp_block, rd_instr);
        end

        // ---------- summary ----------
        $display("--------------------------------------------------");
        $display("INSTRUCTION MEMORY (block read) TEST SUMMARY");
        $display("Total checks : %0d", test_count);
        $display("Passed       : %0d", pass_count);
        $display("Failed       : %0d", fail_count);
        $display("--------------------------------------------------");
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        #20;
        $finish;
    end

endmodule