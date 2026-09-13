`timescale 1ns/1ps
//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Testbench    : icache_mem_tb
//
// Self-checking TB for the L1 instruction-cache SRAM.
// A reference model mirrors the entire 32 x 260 array plus the exact
// timing semantics and compares rd_line every cycle:
//   * synchronous read  : rd_line updates at the clock edge
//   * synchronous write  : mem[wr_index] <= wr_line when we
//   * WRITE-FIRST bypass  : if we && wr_index==rd_index, the read output
//                           this edge is the value just written
//   * reset              : whole array cleared (all valid bits -> 0)
//
// Directed tests cover reset, basic write/read-back, the write-first
// bypass, read-vs-write to different indices (no aliasing), overwrite,
// and every index; then a large random phase hammers all combinations.
//====================================================

module icache_mem_tb;

    localparam INDEX_BITS = 5;
    localparam TAG_BITS   = 3;
    localparam DATA_BITS  = 256;
    localparam LINE       = 1 + TAG_BITS + DATA_BITS;   // 260
    localparam N          = (1 << INDEX_BITS);          // 32

    reg                   clk, reset, we;
    reg  [INDEX_BITS-1:0] rd_index, wr_index;
    reg  [LINE-1:0]       wr_line;
    wire [LINE-1:0]       rd_line;

    // ---- DUT ----
    icache_mem dut (
        .clk(clk), .reset(reset), .we(we),
        .rd_index(rd_index), .wr_index(wr_index),
        .wr_data(wr_line), .rd_data(rd_line)
    );

    // ---- reference model (mirrors the DUT exactly) ----
    reg [LINE-1:0] ref_mem [0:N-1];
    reg [LINE-1:0] ref_rd_line;
    integer k;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (k = 0; k < N; k = k + 1)
                ref_mem[k] = {LINE{1'b0}};
            ref_rd_line = {LINE{1'b0}};
        end else begin
            // read is evaluated against the PRE-write contents, with
            // write-first bypass when the same index is read and written
            if (we && (wr_index == rd_index))
                ref_rd_line = wr_line;
            else
                ref_rd_line = ref_mem[rd_index];
            // then apply the write
            if (we)
                ref_mem[wr_index] = wr_line;
        end
    end

    integer test_count, pass_count, fail_count, i;

    task check;
        begin
            test_count = test_count + 1;
            if (rd_line !== ref_rd_line) begin
                fail_count = fail_count + 1;
                $display("FAIL test=%0d  we=%b rd_idx=%0d wr_idx=%0d  t=%0t",
                         test_count, we, rd_index, wr_index, $time);
                $display("     exp=%h", ref_rd_line);
                $display("     got=%h", rd_line);
            end else begin
                pass_count = pass_count + 1;
                $display("PASS test=%0d  we=%b rd_idx=%0d wr_idx=%0d  rd_line[valid,tag]=%b,%h",
                         test_count, we, rd_index, wr_index,
                         rd_line[LINE-1], rd_line[LINE-2 -: TAG_BITS]);
            end
        end
    endtask

    // one cycle: apply inputs, clock, compare
    task step;
        input                   we_v;
        input [INDEX_BITS-1:0]  rdi;
        input [INDEX_BITS-1:0]  wri;
        input [LINE-1:0]        wl;
        begin
            @(negedge clk);
            we       = we_v;
            rd_index = rdi;
            wr_index = wri;
            wr_line  = wl;
            @(posedge clk);       // DUT + reference update rd_line together
            #1;
            check;
        end
    endtask

    // random 260-bit line
    function [LINE-1:0] rand_line;
        input dummy;
        reg [LINE-1:0] r;
        begin
            r[255:0]   = {$random,$random,$random,$random,$random,$random,$random,$random};
            r[259:256] = $random;                // low 4 bits -> {valid, tag}
            rand_line  = r;
        end
    endfunction

    // build a line with explicit valid/tag/data-seed (data = seed replicated-ish)
    function [LINE-1:0] make_line;
        input        v;
        input [2:0]  tg;
        input [31:0] seed;
        reg   [255:0] d;
        integer j;
        begin
            for (j = 0; j < 8; j = j + 1)
                d[j*32 +: 32] = seed + j;         // distinct word per slot
            make_line = {v, tg, d};
        end
    endfunction

    // ---- clock ----
    initial clk = 0;
    always #5 clk = ~clk;

    reg [LINE-1:0] L0, L1, L2;

    initial begin
        $dumpfile("icache_mem_tb.vcd");
        $dumpvars(0, icache_mem_tb);

        test_count = 0; pass_count = 0; fail_count = 0;
        we = 0; rd_index = 0; wr_index = 0; wr_line = 0;

        // ---------------- reset ----------------
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        reset = 0;

        // (1) after reset, reading any index returns 0 (all valid bits clear)
        step(1'b0, 5'd0,  5'd0,  {LINE{1'b0}});   // rd_line should be 0
        step(1'b0, 5'd7,  5'd0,  {LINE{1'b0}});
        step(1'b0, 5'd31, 5'd0,  {LINE{1'b0}});

        // (2) basic write then read-back
        L0 = make_line(1'b1, 3'd5, 32'hAAAA_0000);
        step(1'b1, 5'd0,  5'd10, L0);             // write idx10 (read idx0 -> still 0)
        step(1'b0, 5'd10, 5'd0,  {LINE{1'b0}});   // read idx10 -> L0

        // (3) WRITE-FIRST bypass: write and read same index in one cycle
        L1 = make_line(1'b1, 3'd2, 32'hBBBB_1111);
        step(1'b1, 5'd10, 5'd10, L1);             // rd_line must be L1 THIS cycle
        step(1'b0, 5'd10, 5'd0,  {LINE{1'b0}});   // and persists -> L1

        // (4) read one index while writing a DIFFERENT index (no aliasing)
        L2 = make_line(1'b1, 3'd7, 32'hCCCC_2222);
        step(1'b1, 5'd10, 5'd20, L2);             // read idx10(=L1) while writing idx20
        step(1'b0, 5'd20, 5'd0,  {LINE{1'b0}});   // read idx20 -> L2

        // (5) overwrite an index, read back new value
        L0 = make_line(1'b1, 3'd1, 32'hDDDD_3333);
        step(1'b1, 5'd10, 5'd10, L0);             // bypass gives new value
        step(1'b0, 5'd10, 5'd0,  {LINE{1'b0}});   // confirm persisted new value

        // (6) fill every index with a unique line, then read them all back
        for (i = 0; i < N; i = i + 1)
            step(1'b1, i[4:0], i[4:0], make_line(1'b1, i[2:0], 32'h1000_0000 + (i<<8)));
        for (i = 0; i < N; i = i + 1)
            step(1'b0, i[4:0], 5'd0, {LINE{1'b0}});

        // ---------------- random phase ----------------
        for (i = 0; i < 5000; i = i + 1)
            step($random & 1'b1,
                 $random & 5'h1F,
                 $random & 5'h1F,
                 rand_line(0));

        // ---------------- reset mid-stream, then confirm cleared ----------------
        @(negedge clk); reset = 1;
        @(posedge clk); @(negedge clk); reset = 0;
        step(1'b0, 5'd10, 5'd0, {LINE{1'b0}});    // idx10 must read 0 again
        step(1'b0, 5'd20, 5'd0, {LINE{1'b0}});

        // ---------------- summary ----------------
        $display("--------------------------------------------------");
        $display("ICACHE MEMORY (SRAM) TEST SUMMARY");
        $display("Total tests : %0d", test_count);
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);
        $display("--------------------------------------------------");
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        #20;
        $finish;
    end

endmodule