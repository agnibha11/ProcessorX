`timescale 1ns/1ps
//====================================================
// Project     : RV32IM 6-Stage Pipelined Processor
// Testbench    : dcache_ctrl_tb
//
// Self-checking TB for the write-back / write-allocate D-cache
// controller. A reference model mirrors the FSM (NORUN/IDLE/EVICT/
// REFILL) AND the load-extract / store-merge / block semantics, and
// checks the controller's outputs every cycle.
//
// Directed tests: reset/NORUN, read hit (all offsets + all load
// modes), write hit (dirty set, all store modes), clean read miss,
// clean write miss (write-allocate), dirty read miss (eviction ->
// refill), dirty write miss, non-memory op (must not stall / must not
// write cache), and the mem_rs2_fwrd store-data-latch case. Then a
// long random phase drives arbitrary op/mode/addr/line/block.
//
// The reference encodes the INTENDED behaviour (all outputs defaulted
// every cycle, no latches). If your controller still has the missing-
// default latch bugs, the affected cycles report FAIL with exp-vs-got.
//
// Port names match the user's module:
//   in : clk reset dmemRE_in dmemWE_in dmemMode[2:0] addr[31:0]
//        st_fwrd_data[31:0] cache_data[260:0] block_dmem[255:0]
//   out: data[31:0] dmem_addr[31:0] cache_miss dmemRE_out dmemWE_out
//        cacheWE dmem_wr_data[255:0] cache_wr_index[4:0]
//        cache_refill[260:0]
//====================================================

module dcache_ctrl_tb;

    localparam NORUN  = 2'b00;
    localparam IDLE   = 2'b01;
    localparam EVICT  = 2'b10;
    localparam REFILL = 2'b11;

    // ---- DUT I/O ----
    reg         clk, reset, dmemRE_in, dmemWE_in;
    reg  [2:0]  dmemMode;
    reg  [31:0] addr, st_fwrd_data;
    reg  [260:0] cache_data;
    reg  [255:0] block_dmem;

    wire [31:0]  data, dmem_addr;
    wire         cache_miss, dmemRE_out, dmemWE_out, cacheWE;
    wire [255:0] dmem_wr_data;
    wire [4:0]   cache_wr_index;
    wire [260:0] cache_refill;

    dcache_ctrl dut(
        .clk(clk), .reset(reset),
        .dmemRE_in(dmemRE_in), .dmemWE_in(dmemWE_in),
        .dmemMode(dmemMode), .addr(addr), .st_fwrd_data(st_fwrd_data),
        .cache_data(cache_data), .block_dmem(block_dmem),
        .data(data), .dmem_addr(dmem_addr),
        .cache_miss(cache_miss), .dmemRE_out(dmemRE_out), .dmemWE_out(dmemWE_out),
        .cacheWE(cacheWE), .dmem_wr_data(dmem_wr_data),
        .cache_wr_index(cache_wr_index), .cache_refill(cache_refill)
    );

    // ---- reference FSM state (mirrors DUT) ----
    reg [1:0] ref_state;
    reg [31:0] ref_stlatch;

    wire        mem_op   = dmemRE_in || dmemWE_in;
    wire        v_c      = cache_data[260];
    wire        d_c      = cache_data[259];
    wire [2:0]  t_c      = cache_data[258:256];
    wire [2:0]  t_a      = addr[12:10];
    wire        ref_hit  = v_c && (t_c == t_a);
    wire        ref_evict= v_c && d_c;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ref_state   <= NORUN;
            ref_stlatch <= 32'b0;
        end else begin
            if (ref_state == IDLE) ref_stlatch <= st_fwrd_data;   // mirror the latch
            case (ref_state)
                NORUN:  ref_state <= IDLE;
                IDLE:   ref_state <= (mem_op && !ref_hit) ? (ref_evict ? EVICT : REFILL) : IDLE;
                EVICT:  ref_state <= REFILL;
                REFILL: ref_state <= IDLE;
                default:ref_state <= NORUN;
            endcase
        end
    end

    // ---- reference helper functions (same semantics as the DUT) ----
    function [31:0] ref_load;
        input [255:0] blk; input [2:0] wo; input [1:0] bo; input [2:0] mode;
        reg [31:0] w; reg [15:0] h; reg [7:0] b;
        begin
            w = blk[wo*32 +: 32];
            h = bo[1] ? w[31:16] : w[15:0];
            b = (bo==2'b00)?w[7:0]:(bo==2'b01)?w[15:8]:(bo==2'b10)?w[23:16]:w[31:24];
            case (mode)
                3'b000: ref_load = w;
                3'b001: ref_load = {16'b0, h};
                3'b010: ref_load = {{16{h[15]}}, h};
                3'b011: ref_load = {24'b0, b};
                3'b100: ref_load = {{24{b[7]}}, b};
                default: ref_load = w;
            endcase
        end
    endfunction

    function [255:0] ref_merge;
        input [255:0] blk; input [2:0] wo; input [1:0] bo; input [2:0] mode; input [31:0] sd;
        reg [31:0] w;
        begin
            w = blk[wo*32 +: 32];
            case (mode)
                3'b000:         w = sd;
                3'b001,3'b010:  w = bo[1] ? {sd[15:0], w[15:0]} : {w[31:16], sd[15:0]};
                3'b011,3'b100:  w = (bo==2'b00)?{w[31:8],sd[7:0]}:
                                    (bo==2'b01)?{w[31:16],sd[7:0],w[7:0]}:
                                    (bo==2'b10)?{w[31:24],sd[7:0],w[15:0]}:
                                                {sd[7:0],w[23:0]};
                default:        w = sd;
            endcase
            ref_merge = blk;
            ref_merge[wo*32 +: 32] = w;
        end
    endfunction

    // ---- expected outputs ----
    reg [31:0]  e_data, e_dmem_addr;
    reg         e_miss, e_dRE, e_dWE, e_cWE;
    reg [255:0] e_dmem_wr;
    reg [4:0]   e_wr_index;
    reg [260:0] e_refill;
    reg [47:0]  sname;

    // which outputs matter this cycle (payloads only checked when their
    // enable is expected asserted -> a correct default-driven design
    // still passes, a latch bug on an *enable* is always caught)
    task expected;
        reg [2:0] wo; reg [1:0] bo; reg [31:0] bb, ea;
        begin
            wo = addr[4:2]; bo = addr[1:0];
            bb = {addr[31:5],5'b0};
            ea = {19'b0, t_c, addr[9:5], 5'b0};

            e_data=32'b0; e_miss=0; e_dRE=0; e_dWE=0; e_cWE=0;
            e_dmem_addr=bb; e_dmem_wr=cache_data[255:0]; e_wr_index=addr[9:5];
            e_refill=261'b0;

            case (ref_state)
                NORUN: sname="NORUN ";
                IDLE: begin
                    sname="IDLE  ";
                    if (mem_op) begin
                        if (ref_hit) begin
                            if (dmemRE_in)
                                e_data = ref_load(cache_data[255:0], wo, bo, dmemMode);
                            else begin
                                e_cWE=1;
                                e_refill={1'b1,1'b1,t_a, ref_merge(cache_data[255:0],wo,bo,dmemMode,st_fwrd_data)};
                            end
                        end else begin
                            e_miss=1;
                            if (ref_evict) begin
                                e_dWE=1; e_dmem_addr=ea; e_dmem_wr=cache_data[255:0];
                            end else begin
                                e_dRE=1; e_dmem_addr=bb;
                            end
                        end
                    end
                end
                EVICT: begin
                    sname="EVICT ";
                    e_miss=1; e_dRE=1; e_dmem_addr=bb;
                end
                REFILL: begin
                    sname="REFILL";
                    e_miss=0; e_cWE=1; e_wr_index=addr[9:5];
                    if (dmemRE_in) begin
                        e_data = ref_load(block_dmem, wo, bo, dmemMode);
                        e_refill = {1'b1,1'b0,t_a, block_dmem};
                    end else begin
                        e_refill = {1'b1,1'b1,t_a, ref_merge(block_dmem,wo,bo,dmemMode,ref_stlatch)};
                    end
                end
                default: sname="??????";
            endcase
        end
    endtask

    integer test_count, pass_count, fail_count, i;

    task check;
        reg bad;
        begin
            test_count = test_count + 1;
            expected;
            bad = 0;
            // always-critical control signals
            if (cache_miss !== e_miss) bad=1;
            if (dmemRE_out !== e_dRE)   bad=1;
            if (dmemWE_out !== e_dWE)   bad=1;
            if (cacheWE    !== e_cWE)   bad=1;
            // load result checked when a load is producing it
            if ((ref_state==IDLE && ref_hit && dmemRE_in && mem_op) ||
                (ref_state==REFILL && dmemRE_in))
                if (data !== e_data) bad=1;
            // dmem address/data checked when a dmem access is expected
            if (e_dRE && (dmem_addr !== e_dmem_addr)) bad=1;
            if (e_dWE && (dmem_addr !== e_dmem_addr)) bad=1;
            if (e_dWE && (dmem_wr_data !== e_dmem_wr)) bad=1;
            // cache write checked when we write the cache
            if (e_cWE && (cache_wr_index !== e_wr_index)) bad=1;
            if (e_cWE && (cache_refill   !== e_refill))   bad=1;

            if (bad) begin
                fail_count = fail_count + 1;
                $display("FAIL test=%0d state=%0s op=%s%s hit=%b evict=%b t=%0t",
                    test_count, sname,
                    dmemRE_in?"R":"-", dmemWE_in?"W":"-", ref_hit, ref_evict, $time);
                $display("   miss e=%b g=%b | dRE e=%b g=%b | dWE e=%b g=%b | cWE e=%b g=%b",
                    e_miss,cache_miss, e_dRE,dmemRE_out, e_dWE,dmemWE_out, e_cWE,cacheWE);
                if (e_dRE||e_dWE) $display("   dmem_addr e=%h g=%h", e_dmem_addr, dmem_addr);
                if (e_dWE)        $display("   dmem_wr   e=%h g=%h", e_dmem_wr, dmem_wr_data);
                if (e_cWE)        $display("   refill    e=%h g=%h", e_refill, cache_refill);
                if ((ref_state==REFILL&&dmemRE_in)||(ref_state==IDLE&&ref_hit&&dmemRE_in&&mem_op))
                    $display("   data      e=%h g=%h", e_data, data);
            end else begin
                pass_count = pass_count + 1;
                $display("PASS test=%0d state=%0s op=%s%s miss=%b cWE=%b",
                    test_count, sname, dmemRE_in?"R":"-", dmemWE_in?"W":"-", cache_miss, cacheWE);
            end
        end
    endtask

    // apply inputs, check current state, advance one cycle
    task step;
        input rE, wE; input [2:0] md; input [31:0] a, sd;
        input [260:0] cl; input [255:0] bd;
        begin
            @(negedge clk);
            dmemRE_in=rE; dmemWE_in=wE; dmemMode=md;
            addr=a; st_fwrd_data=sd; cache_data=cl; block_dmem=bd;
            #1; check;
            @(posedge clk); #1;
        end
    endtask

    // helpers
    function [255:0] rnd_blk; input d; begin
        rnd_blk={$random,$random,$random,$random,$random,$random,$random,$random}; end
    endfunction
    function [260:0] mk_line; input v; input dty; input [2:0] tg; input [255:0] blk;
        begin mk_line={v,dty,tg,blk}; end
    endfunction

    initial clk=0; always #5 clk=~clk;

    reg [255:0] blk;
    reg [31:0]  A;
    reg vbit, dbit; reg [2:0] rtag;

    initial begin
        $dumpfile("dcache_ctrl_tb.vcd");
        $dumpvars(0, dcache_ctrl_tb);
        test_count=0; pass_count=0; fail_count=0;

        // reset
        dmemRE_in=0; dmemWE_in=0; dmemMode=0; addr=0; st_fwrd_data=0;
        cache_data=0; block_dmem=0;
        reset=1; @(posedge clk); @(posedge clk); @(negedge clk); reset=0;

        // (1) NORUN first cycle -> no stall, no cache write
        step(0,0,3'b000,32'h0,32'h0,261'b0,256'b0);

        // (2) non-memory op in IDLE -> must NOT stall / NOT write cache
        step(0,0,3'b000,32'h40, 32'h0, mk_line(1'b1,1'b0,3'd0,rnd_blk(0)), rnd_blk(0));

        // (3) read hit, sweep all 8 word offsets, LW
        for (i=0;i<8;i=i+1) begin
            A = 32'h100 | (i<<2);
            blk = rnd_blk(0);
            step(1,0,3'b000, A, 32'h0, mk_line(1'b1,1'b0,A[12:10],blk), rnd_blk(0));
        end

        // (4) read hit, all load modes at a byte-offset that exercises them
        A = 32'h0000_0126;   // word offset 1, byte offset 2
        blk = rnd_blk(0);
        step(1,0,3'b000,A,0,mk_line(1'b1,0,A[12:10],blk),rnd_blk(0)); // LW
        step(1,0,3'b001,A,0,mk_line(1'b1,0,A[12:10],blk),rnd_blk(0)); // LHU
        step(1,0,3'b010,A,0,mk_line(1'b1,0,A[12:10],blk),rnd_blk(0)); // LH
        step(1,0,3'b011,A,0,mk_line(1'b1,0,A[12:10],blk),rnd_blk(0)); // LBU
        step(1,0,3'b100,A,0,mk_line(1'b1,0,A[12:10],blk),rnd_blk(0)); // LB

        // (5) write hit -> dirty line, all store modes
        A = 32'h0000_0244;   // word offset 1, byte offset 0
        blk = rnd_blk(0);
        step(0,1,3'b000,A,32'hDEADBEEF,mk_line(1'b1,0,A[12:10],blk),rnd_blk(0)); // SW
        step(0,1,3'b001,A,32'h0000CAFE,mk_line(1'b1,0,A[12:10],blk),rnd_blk(0)); // SH
        step(0,1,3'b011,A,32'h000000A5,mk_line(1'b1,0,A[12:10],blk),rnd_blk(0)); // SB

        // (6) CLEAN read miss (invalid line) -> REFILL, 1 bubble
        A = 32'h0000_0480;
        step(1,0,3'b000,A,0, mk_line(1'b0,0,3'd0,rnd_blk(0)), rnd_blk(0)); // IDLE miss
        step(1,0,3'b000,A,0, mk_line(1'b0,0,3'd0,rnd_blk(0)), rnd_blk(0)); // REFILL

        // (7) CLEAN write miss (valid, clean, wrong tag) -> allocate+merge
        A = 32'h0000_0C60;   // tag 3
        step(0,1,3'b000,A,32'h11223344, mk_line(1'b1,1'b0,3'd5,rnd_blk(0)), rnd_blk(0)); // miss
        step(0,1,3'b000,A,32'h11223344, mk_line(1'b1,1'b0,3'd5,rnd_blk(0)), rnd_blk(0)); // REFILL (uses latch)

        // (8) DIRTY read miss -> EVICT then REFILL, 2 bubbles
        A = 32'h0000_0704; blk = rnd_blk(0);
        step(1,0,3'b000,A,0, mk_line(1'b1,1'b1,3'd2,blk), rnd_blk(0)); // IDLE miss (dirty) -> EVICT
        step(1,0,3'b000,A,0, mk_line(1'b1,1'b1,3'd2,blk), rnd_blk(0)); // EVICT
        step(1,0,3'b000,A,0, mk_line(1'b1,1'b1,3'd2,blk), rnd_blk(0)); // REFILL

        // (9) DIRTY write miss -> EVICT, REFILL, allocate+merge dirty
        A = 32'h0000_0A24; blk = rnd_blk(0);
        step(0,1,3'b001,A,32'hBEEF, mk_line(1'b1,1'b1,3'd1,blk), rnd_blk(0)); // miss (dirty)
        step(0,1,3'b001,A,32'hBEEF, mk_line(1'b1,1'b1,3'd1,blk), rnd_blk(0)); // EVICT
        step(0,1,3'b001,A,32'hBEEF, mk_line(1'b1,1'b1,3'd1,blk), rnd_blk(0)); // REFILL

        // ---------------- random phase ----------------
        for (i=0;i<6000;i=i+1) begin
            A     = ($random & 32'h0000_1FFF) & 32'hFFFF_FFFC;
            vbit  = $random; dbit = $random; rtag = $random;
            // bias: ~1/3 of the time make it a guaranteed hit
            if (($random % 3)==0) begin vbit=1'b1; rtag=A[12:10]; end
            step($random&1'b1, $random&1'b1,
                 $random & 3'h7, A, $random,
                 mk_line(vbit,dbit,rtag,rnd_blk(0)), rnd_blk(0));
        end

        $display("--------------------------------------------------");
        $display("D-CACHE CONTROLLER TEST SUMMARY");
        $display("Total tests : %0d", test_count);
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);
        $display("--------------------------------------------------");
        if (fail_count==0) $display("ALL TESTS PASSED");
        else               $display("SOME TESTS FAILED");
        #20; $finish;
    end

endmodule