`timescale 1ns/1ps

module forwardunit_tb;

reg  [4:0] ex_mem_rd;
reg  [4:0] mem_wb_rd;
reg  [4:0] id_ex_rs1;
reg  [4:0] id_ex_rs2;
reg  [4:0] if_id_rs1;
reg  [4:0] if_id_rs2;
reg  [4:0] ex_mem_rs2;

reg ex_mem_regWE;
reg mem_wb_regWE;

wire [1:0] ex_rs1_fwrd;
wire [1:0] ex_rs2_fwrd;
wire       id_rs1_fwrd;
wire       id_rs2_fwrd;
wire       mem_rs2_fwrd;

//--------------------------------------------------
// DUT
//--------------------------------------------------

forwardunit dut(
    .ex_mem_rd(ex_mem_rd),
    .mem_wb_rd(mem_wb_rd),
    .id_ex_rs1(id_ex_rs1),
    .id_ex_rs2(id_ex_rs2),
    .if_id_rs1(if_id_rs1),
    .if_id_rs2(if_id_rs2),
    .ex_mem_rs2(ex_mem_rs2),
    .ex_mem_regWE(ex_mem_regWE),
    .mem_wb_regWE(mem_wb_regWE),
    .ex_rs1_fwrd(ex_rs1_fwrd),
    .ex_rs2_fwrd(ex_rs2_fwrd),
    .id_rs1_fwrd(id_rs1_fwrd),
    .id_rs2_fwrd(id_rs2_fwrd),
    .mem_rs2_fwrd(mem_rs2_fwrd)
);

//--------------------------------------------------
// Scoreboard
//--------------------------------------------------

localparam NOFWRD = 2'b00;
localparam EXMEM  = 2'b01;
localparam MEMWB  = 2'b10;

reg [1:0] exp_ex_rs1;
reg [1:0] exp_ex_rs2;
reg       exp_id_rs1;
reg       exp_id_rs2;
reg       exp_mem_rs2;

integer test_count;
integer pass_count;
integer fail_count;
integer i;

//--------------------------------------------------
// Expected Value Calculator
//--------------------------------------------------

task calc_expected;
begin

    // Hazard 1a + 2a
    if(ex_mem_regWE &&
       (ex_mem_rd != 5'd0) &&
       (ex_mem_rd == id_ex_rs1))

        exp_ex_rs1 = EXMEM;

    else if(mem_wb_regWE &&
            (mem_wb_rd != 5'd0) &&
            (mem_wb_rd == id_ex_rs1))

        exp_ex_rs1 = MEMWB;

    else
        exp_ex_rs1 = NOFWRD;


    // Hazard 1b + 2b
    if(ex_mem_regWE &&
       (ex_mem_rd != 5'd0) &&
       (ex_mem_rd == id_ex_rs2))

        exp_ex_rs2 = EXMEM;

    else if(mem_wb_regWE &&
            (mem_wb_rd != 5'd0) &&
            (mem_wb_rd == id_ex_rs2))

        exp_ex_rs2 = MEMWB;

    else
        exp_ex_rs2 = NOFWRD;


    // Hazard 3a
    exp_id_rs1 =
        mem_wb_regWE &&
        (mem_wb_rd != 5'd0) &&
        (mem_wb_rd == if_id_rs1);

    // Hazard 3b
    exp_id_rs2 =
        mem_wb_regWE &&
        (mem_wb_rd != 5'd0) &&
        (mem_wb_rd == if_id_rs2);

    // Hazard 4
    exp_mem_rs2 =
        mem_wb_regWE &&
        (mem_wb_rd != 5'd0) &&
        (mem_wb_rd == ex_mem_rs2);

end
endtask

//--------------------------------------------------
// Checker
//--------------------------------------------------

task check_outputs;
begin

    test_count = test_count + 1;

    calc_expected;

    #1;

    if(ex_rs1_fwrd !== exp_ex_rs1 ||
       ex_rs2_fwrd !== exp_ex_rs2 ||
       id_rs1_fwrd !== exp_id_rs1 ||
       id_rs2_fwrd !== exp_id_rs2 ||
       mem_rs2_fwrd !== exp_mem_rs2)

    begin

        fail_count = fail_count + 1;

        $display("FAIL Test %0d", test_count);

        $display("Expected EX_RS1=%b Got=%b",
                  exp_ex_rs1, ex_rs1_fwrd);

        $display("Expected EX_RS2=%b Got=%b",
                  exp_ex_rs2, ex_rs2_fwrd);

        $display("Expected ID_RS1=%b Got=%b",
                  exp_id_rs1, id_rs1_fwrd);

        $display("Expected ID_RS2=%b Got=%b",
                  exp_id_rs2, id_rs2_fwrd);

        $display("Expected MEM_RS2=%b Got=%b",
                  exp_mem_rs2, mem_rs2_fwrd);

    end

    else begin

        pass_count = pass_count + 1;

        $display("PASS Test %0d", test_count);

    end

end
endtask

//--------------------------------------------------
// Stimulus
//--------------------------------------------------

initial begin

    $dumpfile("forwardunit_tb.vcd");
    $dumpvars(0,forwardunit_tb);

    test_count = 0;
    pass_count = 0;
    fail_count = 0;

    //--------------------------------------------------
    // No hazards
    //--------------------------------------------------

    ex_mem_rd = 0;
    mem_wb_rd = 0;

    id_ex_rs1 = 1;
    id_ex_rs2 = 2;

    if_id_rs1 = 3;
    if_id_rs2 = 4;

    ex_mem_rs2 = 5;

    ex_mem_regWE = 0;
    mem_wb_regWE = 0;

    check_outputs();

    //--------------------------------------------------
    // Hazard 1a
    //--------------------------------------------------

    ex_mem_rd = 5;
    id_ex_rs1 = 5;
    ex_mem_regWE = 1;

    check_outputs();

    //--------------------------------------------------
    // Hazard 1b
    //--------------------------------------------------

    ex_mem_rd = 10;
    id_ex_rs2 = 10;

    check_outputs();

    //--------------------------------------------------
    // Hazard 2a
    //--------------------------------------------------

    ex_mem_regWE = 0;

    mem_wb_rd = 12;
    id_ex_rs1 = 12;
    mem_wb_regWE = 1;

    check_outputs();

    //--------------------------------------------------
    // Hazard 2b
    //--------------------------------------------------

    mem_wb_rd = 20;
    id_ex_rs2 = 20;

    check_outputs();

    //--------------------------------------------------
    // WB-ID
    //--------------------------------------------------

    if_id_rs1 = 8;
    mem_wb_rd = 8;

    check_outputs();

    if_id_rs2 = 8;

    check_outputs();

    //--------------------------------------------------
    // Store forwarding
    //--------------------------------------------------

    ex_mem_rs2 = 15;
    mem_wb_rd = 15;

    check_outputs();

    //--------------------------------------------------
    // Priority test
    //--------------------------------------------------

    ex_mem_regWE = 1;
    mem_wb_regWE = 1;

    ex_mem_rd = 25;
    mem_wb_rd = 25;
    id_ex_rs1 = 25;

    check_outputs();

    //--------------------------------------------------
    // x0 should never forward
    //--------------------------------------------------

    ex_mem_rd = 0;
    mem_wb_rd = 0;

    ex_mem_regWE = 1;
    mem_wb_regWE = 1;

    id_ex_rs1 = 0;
    id_ex_rs2 = 0;
    if_id_rs1 = 0;
    if_id_rs2 = 0;
    ex_mem_rs2 = 0;

    check_outputs();

    //--------------------------------------------------
    // Random Tests
    //--------------------------------------------------

    for(i=0;i<1000;i=i+1)
    begin

        ex_mem_rd    = $random & 5'h1F;
        mem_wb_rd    = $random & 5'h1F;

        id_ex_rs1    = $random & 5'h1F;
        id_ex_rs2    = $random & 5'h1F;

        if_id_rs1    = $random & 5'h1F;
        if_id_rs2    = $random & 5'h1F;

        ex_mem_rs2   = $random & 5'h1F;

        ex_mem_regWE = $random;
        mem_wb_regWE = $random;

        check_outputs();

    end

    //--------------------------------------------------
    // Summary
    //--------------------------------------------------

    $display("--------------------------------------");
    $display("FORWARD UNIT TEST SUMMARY");
    $display("Total Tests : %0d", test_count);
    $display("Passed      : %0d", pass_count);
    $display("Failed      : %0d", fail_count);
    $display("--------------------------------------");

    if(fail_count == 0)
        $display("ALL TESTS PASSED");
    else
        $display("SOME TESTS FAILED");

    #20;
    $finish;

end

endmodule