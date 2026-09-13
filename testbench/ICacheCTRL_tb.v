`timescale 1ns/1ps

module icache_ctrl_tb;

    // ---- set this to match your module's NOP encoding ----
    localparam [31:0] NOP_EXPECT = 32'h00000000;   // your module uses 0x0
    // localparam [31:0] NOP_EXPECT = 32'h00000013; // canonical RV32I NOP

    // FSM state encodings (must match the DUT)
    localparam [1:0] NORUN  = 2'b00;
    localparam [1:0] IDLE   = 2'b01;
    localparam [1:0] REFILL = 2'b10;

    // ---- DUT I/O ----
    reg         clk, reset;
    reg  [31:0] pc;
    reg  [259:0] cache_data;
    reg  [255:0] imem_data;

    wire [31:0]  Instr, imem_addr;
    wire         cache_miss, imemRE, cacheWE;
    wire [4:0]   cache_wr_index;
    wire [259:0] cache_refill;

    // ---- DUT ----
    icache_ctrl dut(
        .clk(clk), .reset(reset),
        .pc(pc), .cache_data(cache_data), .imem_data(imem_data),
        .Instr(Instr), .imem_addr(imem_addr),
        .cache_miss(cache_miss), .imemRE(imemRE), .cacheWE(cacheWE),
        .cache_wr_index(cache_wr_index), .cache_refill(cache_refill),
        .halt(1'b0), .flush(1'b0)
    );

    // ---- reference FSM state (mirrors the DUT) ----
    reg [1:0] ref_state;

    // hit computed from current inputs (used by both outputs and next-state)
    wire        ref_valid = cache_data[259];
    wire [2:0]  ref_tagc  = cache_data[258:256];
    wire [2:0]  ref_tagp  = pc[12:10];
    wire        ref_hit   = ref_valid && (ref_tagc == ref_tagp);

    // reference state advances in lockstep with the DUT
    always @(posedge clk or posedge reset) begin
        if (reset)
            ref_state <= NORUN;
        else case (ref_state)
            NORUN:   ref_state <= IDLE;
            IDLE:    ref_state <= ref_hit ? IDLE : REFILL;
            REFILL:  ref_state <= IDLE;
            default: ref_state <= NORUN;
        endcase
    end

    // ---- expected outputs ----
    reg [31:0]  exp_Instr, exp_imem_addr;
    reg         exp_cache_miss, exp_imemRE, exp_cacheWE;
    reg [4:0]   exp_cache_wr_index;
    reg [259:0] exp_cache_refill;
    reg [47:0]  state_name;

    integer test_count, pass_count, fail_count, i;

    task compute_expected;
        reg [2:0]   tg;
        reg [4:0]   idx;
        reg [2:0]   wof;
        reg [31:0]  base;
        reg [255:0] bc;
        reg         h;
        begin
            tg   = pc[12:10];
            idx  = pc[9:5];
            wof  = pc[4:2];
            base = {pc[31:5], 5'b00000};
            bc   = cache_data[255:0];
            h    = cache_data[259] && (cache_data[258:256] == tg);

            // defaults (a correct controller drives these every cycle)
            exp_Instr          = NOP_EXPECT;
            exp_cache_miss     = 1'b0;
            exp_imemRE         = 1'b0;
            exp_imem_addr      = base;
            exp_cacheWE        = 1'b0;
            exp_cache_wr_index = idx;
            exp_cache_refill   = {1'b1, tg, imem_data};

            case (ref_state)
                NORUN: begin
                    state_name = "NORUN ";
                    exp_Instr      = NOP_EXPECT;
                    exp_cache_miss = 1'b0;
                end
                IDLE: begin
                    state_name = "IDLE  ";
                    if (h) begin
                        exp_Instr      = bc[wof*32 +: 32];
                        exp_cache_miss = 1'b0;
                    end else begin
                        exp_Instr      = NOP_EXPECT;
                        exp_cache_miss = 1'b1;
                        exp_imemRE     = 1'b1;
                        exp_imem_addr  = base;
                    end
                end
                REFILL: begin
                    state_name = "REFILL";
                    exp_Instr          = imem_data[wof*32 +: 32];
                    exp_cache_miss     = 1'b0;
                    exp_cacheWE        = 1'b1;
                    exp_cache_wr_index = idx;
                    exp_cache_refill   = {1'b1, tg, imem_data};
                    exp_imemRE         = 1'b0;
                end
                default: begin
                    state_name = "??????";
                    exp_Instr      = NOP_EXPECT;
                    exp_cache_miss = 1'b0;
                end
            endcase
        end
    endtask

    // ---- checker: compares always-critical signals every cycle, and the
    //      payload signals (imem_addr / wr_index / refill) only when their
    //      enable is expected high (i.e. where they are semantically used) ----
    task check;
        reg bad;
        begin
            test_count = test_count + 1;
            compute_expected;

            bad = 0;
            if (Instr      !== exp_Instr)      bad = 1;
            if (cache_miss !== exp_cache_miss) bad = 1;
            if (imemRE     !== exp_imemRE)      bad = 1;
            if (cacheWE    !== exp_cacheWE)     bad = 1;
            if (exp_imemRE && (imem_addr      !== exp_imem_addr))      bad = 1;
            if (exp_cacheWE && (cache_wr_index !== exp_cache_wr_index)) bad = 1;
            if (exp_cacheWE && (cache_refill   !== exp_cache_refill))   bad = 1;

            if (bad) begin
                fail_count = fail_count + 1;
                $display("FAIL test=%0d  state=%0s  pc=%h  hit=%b  t=%0t",
                         test_count, state_name, pc, ref_hit, $time);
                $display("     Instr      exp=%h got=%h", exp_Instr, Instr);
                $display("     cache_miss exp=%b got=%b   imemRE exp=%b got=%b   cacheWE exp=%b got=%b",
                         exp_cache_miss, cache_miss, exp_imemRE, imemRE, exp_cacheWE, cacheWE);
                if (exp_imemRE)
                    $display("     imem_addr  exp=%h got=%h", exp_imem_addr, imem_addr);
                if (exp_cacheWE) begin
                    $display("     wr_index   exp=%0d got=%0d", exp_cache_wr_index, cache_wr_index);
                    $display("     refill     exp=%h got=%h", exp_cache_refill, cache_refill);
                end
            end else begin
                pass_count = pass_count + 1;
                $display("PASS test=%0d  state=%0s  pc=%h  Instr=%h  miss=%b RE=%b WE=%b",
                         test_count, state_name, pc, Instr, cache_miss, imemRE, cacheWE);
            end
        end
    endtask

    // ---- one cycle: apply inputs, check current-state outputs, advance ----
    task do_cycle;
        input [31:0]  pc_v;
        input [259:0] cd_v;
        input [255:0] id_v;
        begin
            pc         = pc_v;
            cache_data = cd_v;
            imem_data  = id_v;
            #1;                 // let combinational outputs settle
            check;
            @(posedge clk);     // DUT + reference state advance together
            #1;
        end
    endtask

    // ---- helpers ----
    function [255:0] rand256;
        input dummy;
        begin
            rand256 = {$random,$random,$random,$random,$random,$random,$random,$random};
        end
    endfunction

    // build a cache line that HITS for address a  (valid=1, tag=a[12:10])
    function [259:0] hit_line;
        input [31:0] a;
        input [255:0] blk;
        begin
            hit_line = {1'b1, a[12:10], blk};
        end
    endfunction

    // build a cache line that MISSES for address a (valid=0)
    function [259:0] invalid_line;
        input [255:0] blk;
        begin
            invalid_line = {1'b0, 3'b000, blk};
        end
    endfunction

    // ---- clock ----
    initial clk = 0;
    always #5 clk = ~clk;

    // scratch
    reg [255:0] blkA, blkB;
    reg [31:0]  addr;
    reg         rvalid;   // 1-bit, so the concat width stays exactly 260
    reg [2:0]   rtag;

    initial begin
        $dumpfile("icache_ctrl_tb.vcd");
        $dumpvars(0, icache_ctrl_tb);

        test_count = 0; pass_count = 0; fail_count = 0;

        // ---------------- reset ----------------
        reset = 1; pc = 0; cache_data = 0; imem_data = 0;
        @(posedge clk);      // state <- NORUN
        @(posedge clk);      // stays NORUN
        @(negedge clk);
        reset = 0;

        // ---------------- directed ----------------
        blkA = rand256(0);
        blkB = rand256(0);

        // (1) First cycle after reset must be NORUN: NOP, no stall, no RE/WE
        do_cycle(32'h0000_0100, hit_line(32'h0000_0100, blkA), rand256(0));
        //     -> state now IDLE

        // (2) IDLE hit, sweep all 8 word offsets (each hit keeps IDLE)
        for (i = 0; i < 8; i = i + 1) begin
            addr = 32'h0000_0100 | (i << 2);       // same block, vary word offset
            blkA = rand256(0);
            do_cycle(addr, hit_line(addr, blkA), rand256(0));
        end

        // (3) IDLE miss (invalid) -> expect NOP, miss=1, RE=1, addr=block base
        addr = 32'h0000_0344;                       // index=26, tag=0, offset=1
        do_cycle(addr, invalid_line(rand256(0)), rand256(0));
        //     -> state now REFILL

        // (4) REFILL -> forward word from imem_data, WE=1, wr_index, refill line
        blkB = rand256(0);
        do_cycle(addr, rand256(0) /*ignored*/, blkB);
        //     -> state now IDLE

        // (5) miss via TAG MISMATCH (valid=1 but wrong tag)
        addr = 32'h0000_0C60;                       // tag = 3
        do_cycle(addr, {1'b1, 3'b101, rand256(0)}, rand256(0)); // stored tag 5 != 3 -> miss
        // (6) its refill, sweep offset by choosing addr word offset
        do_cycle(addr, rand256(0), rand256(0));

        // (7) refill correctness across offsets: force miss then refill for each offset
        for (i = 0; i < 8; i = i + 1) begin
            addr = 32'h0000_1200 | (i << 2);
            do_cycle(addr, invalid_line(rand256(0)), rand256(0)); // IDLE miss -> REFILL
            do_cycle(addr, rand256(0), rand256(0));               // REFILL forwards word i
        end

        // (8) a couple of plain hits again to confirm return to normal
        addr = 32'h0000_0080;
        blkA = rand256(0);
        do_cycle(addr, hit_line(addr, blkA), rand256(0));
        do_cycle(addr, hit_line(addr, rand256(0)), rand256(0));

        // ---------------- random ----------------
        for (i = 0; i < 6000; i = i + 1) begin
            addr = ($random & 32'h0000_1FFF) & 32'hFFFF_FFFC;  // 8 KB space, word aligned
            if ($random & 1) begin
                // bias toward a hittable line so the FSM sees plenty of hits AND misses
                cache_data = {1'b1, addr[12:10], rand256(0)};
            end else begin
                rvalid = $random;          // 32-bit -> 1-bit reg keeps LSB
                rtag   = $random;          // 32-bit -> 3-bit reg keeps low 3 bits
                cache_data = {rvalid, rtag, rand256(0)};  // exactly 1+3+256 = 260
            end
            imem_data = rand256(0);
            do_cycle(addr, cache_data, imem_data);
        end

        // ---------------- summary ----------------
        $display("--------------------------------------------------");
        $display("ICACHE CONTROLLER TEST SUMMARY");
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