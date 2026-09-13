`timescale 1ns/1ps
//====================================================
// Project     : RV32IM 5 Stage Pipelined Processor
// Testbench    : dmem_tb  (block data memory behind the D-cache)
//
// Verifies the 8 KB block DMEM:
//   * synchronous block WRITE / READ, rd_data holds when re=0, reset clears
//   * LITTLE-ENDIAN checked two ways: (A) backdoor byte order in dut.mem[],
//     (B) read assembly vs hand-computed known values + golden model.
//
// RUN-FOREVER FIX:
//   - NO $dumpvars(0,...): that recursively dumped both 8192-byte memory
//     arrays every change -> gigantic VCD -> looked like it never ended.
//   - per-test PASS prints silenced (only FAILs + section lines print).
//   - a watchdog $finish guarantees termination no matter what.
//====================================================

module dmem_tb;

    reg          clk, reset, re, we;
    reg  [31:0]  addr;
    reg  [255:0] w_data;
    wire [255:0] rd_data;

    dmem dut(
        .clk(clk), .reset(reset), .rd_en(re), .w_en(we),
        .addr(addr), .w_data(w_data), .rd_data(rd_data)
    );

    reg [7:0] gold [0:8191];
    integer test_count, pass_count, fail_count, i, k, base;
    reg [255:0] exp_blk, hold_prev;

    initial clk = 0; always #5 clk = ~clk;

    // ---- WATCHDOG: hard stop so the sim can never run forever ----
    initial begin
        #5000000;
        $display("TIMEOUT: watchdog fired. last test_count=%0d", test_count);
        $display("Passed=%0d Failed=%0d", pass_count, fail_count);
        $finish;
    end

    task build_expected;
        input integer a;
        begin
            for (i = 0; i < 8; i = i + 1)
                exp_blk[i*32 +: 32] = {gold[a+i*4+3], gold[a+i*4+2],
                                       gold[a+i*4+1], gold[a+i*4]};
        end
    endtask

    task do_write;
        input [31:0] a;
        input [255:0] d;
        begin
            @(negedge clk);
            we = 1'b1; re = 1'b0; addr = a; w_data = d;
            @(posedge clk); #1;
            we = 1'b0;
            base = a[12:0];
            for (k = 0; k < 32; k = k + 1)
                gold[base + k] = d[k*8 +: 8];
        end
    endtask

    task do_read_check;
        input [31:0] a;
        begin
            @(negedge clk);
            re = 1'b1; we = 1'b0; addr = a;
            @(posedge clk); #1;
            re = 1'b0;
            base = a[12:0];
            build_expected(base);
            test_count = test_count + 1;
            if (rd_data !== exp_blk) begin
                fail_count = fail_count + 1;
                $display("FAIL read @%0h  t=%0t", a, $time);
                for (i = 0; i < 8; i = i + 1)
                    if (rd_data[i*32 +: 32] !== exp_blk[i*32 +: 32])
                        $display("   word %0d (@%0h): exp=%h got=%h",
                                 i, a+i*4, exp_blk[i*32 +: 32], rd_data[i*32 +: 32]);
            end else
                pass_count = pass_count + 1;
        end
    endtask

    task le_storage_check;
        input [31:0] a;
        reg bad;
        begin
            base = a[12:0]; bad = 0;
            for (k = 0; k < 32; k = k + 1)
                if (dut.mem[base + k] !== gold[base + k]) begin
                    bad = 1;
                    $display("   byte @%0h: mem=%h expected=%h", a+k, dut.mem[base+k], gold[base+k]);
                end
            test_count = test_count + 1;
            if (bad) begin
                fail_count = fail_count + 1;
                $display("FAIL LE-storage @%0h (byte k must live at a+k)", a);
            end else begin
                pass_count = pass_count + 1;
                $display("PASS LE-storage @%0h (LSB at lowest address)", a);
            end
        end
    endtask

    task hold_check;
        input [31:0] newaddr;
        begin
            hold_prev = rd_data;
            @(negedge clk);
            re = 1'b0; we = 1'b0; addr = newaddr;
            @(posedge clk); #1;
            test_count = test_count + 1;
            if (rd_data !== hold_prev) begin
                fail_count = fail_count + 1;
                $display("FAIL re=0 hold: was=%h now=%h", hold_prev, rd_data);
            end else begin
                pass_count = pass_count + 1;
                $display("PASS re=0 holds rd_data");
            end
        end
    endtask

    task assert_eq;
        input [31:0] got, exp;
        begin
            test_count = test_count + 1;
            if (got !== exp) begin
                fail_count = fail_count + 1;
                $display("FAIL assert: exp=%h got=%h", exp, got);
            end else
                pass_count = pass_count + 1;
        end
    endtask

    reg [255:0] blkA, blkB;

    initial begin
        // OPTIONAL scalar-only waveform (never dump the memory arrays):
        // $dumpfile("dmem_tb.vcd");
        // $dumpvars(1, clk, reset, re, we, addr, w_data, rd_data);

        test_count=0; pass_count=0; fail_count=0;
        re=0; we=0; addr=0; w_data=0;
        for (i=0;i<8192;i=i+1) gold[i] = 8'h00;

        reset=1; @(posedge clk); @(posedge clk); @(negedge clk); reset=0;

        do_read_check(32'h0000_0000);

        for (k=0;k<32;k=k+1) blkA[k*8 +: 8] = k[7:0];
        do_write(32'h0000_0040, blkA);
        le_storage_check(32'h0000_0040);

        do_read_check(32'h0000_0040);
        assert_eq(rd_data[31:0],    32'h03020100);
        assert_eq(rd_data[63:32],   32'h07060504);
        assert_eq(rd_data[255:224], 32'h1f1e1d1c);
        $display("PASS LE-read assembly (word0=%h word7=%h)", rd_data[31:0], rd_data[255:224]);

        blkB = 256'b0; blkB[31:0] = 32'h4433_2211;
        do_write(32'h0000_0080, blkB);
        assert_eq({24'b0, dut.mem[13'h0080]}, 32'h0000_0011);
        assert_eq({24'b0, dut.mem[13'h0082]}, 32'h0000_0033);
        do_read_check(32'h0000_0080);
        assert_eq(rd_data[31:0], 32'h4433_2211);
        $display("PASS round-trip 0x44332211 (mem[a]=%h read=%h)", dut.mem[13'h0080], rd_data[31:0]);

        blkA = {8{32'hAAAA_1111}};
        blkB = {8{32'hBBBB_2222}};
        do_write(32'h0000_0100, blkA);
        do_write(32'h0000_0120, blkB);
        do_read_check(32'h0000_0100);
        do_read_check(32'h0000_0120);

        do_read_check(32'h0000_0100);
        hold_check(32'h0000_1FE0);

        blkA = {8{32'hDEAD_BEEF}};
        do_write(32'h0000_0100, blkA);
        do_read_check(32'h0000_0100);

        blkB = {8{32'hFACE_0FF0}};
        do_write(32'h0000_1FE0, blkB);
        le_storage_check(32'h0000_1FE0);
        do_read_check(32'h0000_1FE0);

        for (i=0;i<2000;i=i+1) begin
            addr = ($random & 32'h0000_1FFF) & 32'hFFFF_FFE0;
            if ($random & 1)
                do_write(addr, {$random,$random,$random,$random,
                                $random,$random,$random,$random});
            else
                do_read_check(addr);
            if ((i % 500) == 0) $display("... random progress i=%0d test_count=%0d", i, test_count);
        end

        @(negedge clk); reset=1; @(posedge clk); @(negedge clk); reset=0;
        for (i=0;i<8192;i=i+1) gold[i] = 8'h00;
        do_read_check(32'h0000_0040);
        do_read_check(32'h0000_0100);

        $display("--------------------------------------------------");
        $display("BLOCK DMEM TEST SUMMARY");
        $display("Total checks : %0d", test_count);
        $display("Passed       : %0d", pass_count);
        $display("Failed       : %0d", fail_count);
        $display("--------------------------------------------------");
        if (fail_count==0) $display("ALL TESTS PASSED");
        else               $display("SOME TESTS FAILED");
        $finish;
    end

endmodule