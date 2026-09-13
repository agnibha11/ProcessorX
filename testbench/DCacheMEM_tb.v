`timescale 1ns/1ps
//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Testbench    : dcache_mem_tb
//
// Self-checking TB for the L1 data-cache SRAM (32 x 261 bits:
// valid|dirty|tag[3]|data[256]). A reference model mirrors the whole
// array plus the exact timing semantics and compares rd_data every
// cycle:
//   * synchronous read  : rd_data updates at the clock edge
//   * synchronous write   : cache[wr_index] <= wr_data when we
//   * WRITE-FIRST bypass  : we && wr_index==rd_index -> read returns
//                           the just-written line that same edge
//   * reset               : whole array cleared (all valid & dirty low)
//
// Directed tests exercise reset, write/read-back, write-first bypass,
// read-vs-write to different indices (no aliasing), overwrite, the
// dirty & valid bits specifically, filling every index, and a mid-
// stream reset. Then a long random phase hammers all combinations.
//====================================================

module dcache_mem_tb;

    localparam LINE = 261;
    localparam N    = 32;

    reg              clk, reset, we;
    reg  [4:0]       rd_index, wr_index;
    reg  [LINE-1:0]  wr_data;
    wire [LINE-1:0]  rd_data;

    // ---- DUT ----
    dcache_mem dut(
        .clk(clk), .reset(reset), .we(we),
        .rd_index(rd_index), .wr_index(wr_index),
        .wr_data(wr_data), .rd_data(rd_data)
    );

    // ---- reference mirror ----
    reg [LINE-1:0] ref_mem [0:N-1];
    reg [LINE-1:0] ref_rd;
    integer k;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (k = 0; k < N; k = k + 1)
                ref_mem[k] = {LINE{1'b0}};
            ref_rd = {LINE{1'b0}};
        end else begin
            // read evaluated against PRE-write contents, write-first bypass
            if (we && (wr_index == rd_index))
                ref_rd = wr_data;
            else
                ref_rd = ref_mem[rd_index];
            if (we)
                ref_mem[wr_index] = wr_data;
        end
    end

    integer test_count, pass_count, fail_count, i;

    task check;
        begin
            test_count = test_count + 1;
            if (rd_data !== ref_rd) begin
                fail_count = fail_count + 1;
                $display("FAIL test=%0d we=%b rd_idx=%0d wr_idx=%0d t=%0t",
                         test_count, we, rd_index, wr_index, $time);
                $display("     exp v=%b d=%b tag=%h : %h",
                         ref_rd[260], ref_rd[259], ref_rd[258:256], ref_rd[255:0]);
                $display("     got v=%b d=%b tag=%h : %h",
                         rd_data[260], rd_data[259], rd_data[258:256], rd_data[255:0]);
            end else begin
                pass_count = pass_count + 1;
                $display("PASS test=%0d we=%b rd_idx=%0d wr_idx=%0d  [v%b d%b tag%h]",
                         test_count, we, rd_index, wr_index,
                         rd_data[260], rd_data[259], rd_data[258:256]);
            end
        end
    endtask

    // one cycle: apply inputs, clock, compare
    task step;
        input        we_v;
        input [4:0]  rdi, wri;
        input [LINE-1:0] wl;
        begin
            @(negedge clk);
            we = we_v; rd_index = rdi; wr_index = wri; wr_data = wl;
            @(posedge clk);      // DUT + reference update together
            #1;
            check;
        end
    endtask

    // build a line: valid, dirty, tag, distinct-per-word data from seed
    function [LINE-1:0] mk;
        input v; input dty; input [2:0] tg; input [31:0] seed;
        reg [255:0] d;
        integer j;
        begin
            for (j = 0; j < 8; j = j + 1)
                d[j*32 +: 32] = seed + j;
            mk = {v, dty, tg, d};
        end
    endfunction

    // random 261-bit line (sized 5-bit top field keeps width exact)
    function [LINE-1:0] rnd;
        input dummy;
        reg [LINE-1:0] r;
        reg [4:0] top;
        begin
            r[255:0] = {$random,$random,$random,$random,$random,$random,$random,$random};
            top      = $random;            // {valid,dirty,tag}
            r[260:256] = top;
            rnd = r;
        end
    endfunction

    initial clk = 0; always #5 clk = ~clk;

    reg [LINE-1:0] L0, L1, L2;

    initial begin
        $dumpfile("dcache_mem_tb.vcd");
        $dumpvars(0, dcache_mem_tb);
        test_count=0; pass_count=0; fail_count=0;
        we=0; rd_index=0; wr_index=0; wr_data=0;

        // ---------------- reset ----------------
        reset=1; @(posedge clk); @(posedge clk); @(negedge clk); reset=0;

        // (1) after reset every index reads 0 (invalid, clean)
        step(1'b0, 5'd0,  5'd0, {LINE{1'b0}});
        step(1'b0, 5'd15, 5'd0, {LINE{1'b0}});
        step(1'b0, 5'd31, 5'd0, {LINE{1'b0}});

        // (2) write a line, read it back next cycle
        L0 = mk(1'b1, 1'b0, 3'd5, 32'hA000_0000);
        step(1'b1, 5'd0,  5'd12, L0);           // write idx12
        step(1'b0, 5'd12, 5'd0,  {LINE{1'b0}}); // read idx12 -> L0

        // (3) WRITE-FIRST bypass: write & read same index same cycle
        L1 = mk(1'b1, 1'b1, 3'd2, 32'hB000_1111);
        step(1'b1, 5'd12, 5'd12, L1);           // rd_data must be L1 THIS cycle
        step(1'b0, 5'd12, 5'd0,  {LINE{1'b0}}); // and persists

        // (4) no aliasing: read one index while writing another
        L2 = mk(1'b1, 1'b0, 3'd7, 32'hC000_2222);
        step(1'b1, 5'd12, 5'd20, L2);           // read idx12(=L1) while writing idx20
        step(1'b0, 5'd20, 5'd0,  {LINE{1'b0}}); // read idx20 -> L2

        // (5) DIRTY-bit specific: set dirty, read back, confirm bit held
        L0 = mk(1'b1, 1'b1, 3'd3, 32'hD000_3333);
        step(1'b1, 5'd0, 5'd5, L0);
        step(1'b0, 5'd5, 5'd0, {LINE{1'b0}});   // expect dirty=1 in rd_data

        // (6) clear dirty by overwriting the same line clean
        L0 = mk(1'b1, 1'b0, 3'd3, 32'hD000_4444);
        step(1'b1, 5'd5, 5'd5, L0);             // write-first: clean line back
        step(1'b0, 5'd5, 5'd0, {LINE{1'b0}});   // expect dirty=0

        // (7) VALID-bit specific: invalidate a line (write valid=0)
        step(1'b1, 5'd5, 5'd5, mk(1'b0,1'b0,3'd0,32'h0));
        step(1'b0, 5'd5, 5'd0, {LINE{1'b0}});   // expect valid=0

        // (8) fill every index uniquely, then read all back
        for (i=0;i<N;i=i+1)
            step(1'b1, i[4:0], i[4:0], mk(1'b1, i[0], i[2:0], 32'h1000_0000 + (i<<8)));
        for (i=0;i<N;i=i+1)
            step(1'b0, i[4:0], 5'd0, {LINE{1'b0}});

        // ---------------- random phase ----------------
        for (i=0;i<6000;i=i+1)
            step($random & 1'b1, $random & 5'h1F, $random & 5'h1F, rnd(0));

        // ---------------- mid-stream reset ----------------
        @(negedge clk); reset=1; @(posedge clk); @(negedge clk); reset=0;
        step(1'b0, 5'd12, 5'd0, {LINE{1'b0}});  // must read 0 again
        step(1'b0, 5'd20, 5'd0, {LINE{1'b0}});

        // ---------------- summary ----------------
        $display("--------------------------------------------------");
        $display("D-CACHE MEMORY (SRAM) TEST SUMMARY");
        $display("Total tests : %0d", test_count);
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);
        $display("--------------------------------------------------");
        if (fail_count==0) $display("ALL TESTS PASSED");
        else               $display("SOME TESTS FAILED");
        #20; $finish;
    end

endmodule