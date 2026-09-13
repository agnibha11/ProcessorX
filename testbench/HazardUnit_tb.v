`timescale 1ns/1ps

module hazardunit_tb;

reg id_ex_memRE;
reg ALUResult_0;

reg [4:0] id_ex_rd;
reg [4:0] if_id_rs1;
reg [4:0] if_id_rs2;

reg [1:0] pcSEL;

wire bubble;
wire flush;

//--------------------------------------------------
// DUT
//--------------------------------------------------

hazardunit dut(
    .id_ex_memRE(id_ex_memRE),
    .ALUResult_0(ALUResult_0),
    .id_ex_rd(id_ex_rd),
    .if_id_rs1(if_id_rs1),
    .if_id_rs2(if_id_rs2),
    .pcSEL(pcSEL),
    .bubble(bubble),
    .flush(flush)
);

//--------------------------------------------------
// Scoreboard
//--------------------------------------------------

reg exp_bubble;
reg exp_flush;

integer test_count;
integer pass_count;
integer fail_count;
integer i;

//--------------------------------------------------
// Expected Value Calculator
//--------------------------------------------------

task calc_expected;
begin

    exp_bubble =
        id_ex_memRE &&
        (id_ex_rd != 5'd0) &&
        (
            (id_ex_rd == if_id_rs1) ||
            (id_ex_rd == if_id_rs2)
        );

    exp_flush =
        (pcSEL == 2'b01) ||
        (pcSEL == 2'b10) ||
        (
            (pcSEL == 2'b11) &&
            ALUResult_0
        );

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

    if((bubble !== exp_bubble) ||
       (flush  !== exp_flush))
    begin

        fail_count = fail_count + 1;

        $display("--------------------------------------");
        $display("FAIL Test %0d", test_count);

        $display("Inputs:");
        $display("MemRead      = %b", id_ex_memRE);
        $display("ALUResult_0  = %b", ALUResult_0);
        $display("id_ex_rd     = %0d", id_ex_rd);
        $display("if_id_rs1    = %0d", if_id_rs1);
        $display("if_id_rs2    = %0d", if_id_rs2);
        $display("pcSEL        = %b", pcSEL);

        $display("");

        $display("Expected:");
        $display("bubble = %b", exp_bubble);
        $display("flush  = %b", exp_flush);

        $display("");

        $display("Got:");
        $display("bubble = %b", bubble);
        $display("flush  = %b", flush);

        $display("--------------------------------------");

    end

    else begin

        pass_count = pass_count + 1;

        $display("PASS Test %0d", test_count);

    end

end
endtask

//--------------------------------------------------
// Main Test
//--------------------------------------------------

initial begin

    $dumpfile("hazardunit_tb.vcd");
    $dumpvars(0,hazardunit_tb);

    test_count = 0;
    pass_count = 0;
    fail_count = 0;

    //--------------------------------------------------
    // No Hazard
    //--------------------------------------------------

    id_ex_memRE = 0;
    ALUResult_0 = 0;

    id_ex_rd = 5'd5;
    if_id_rs1 = 5'd2;
    if_id_rs2 = 5'd3;

    pcSEL = 2'b00;

    check_outputs();

    //--------------------------------------------------
    // Load-use Hazard (rs1)
    //--------------------------------------------------

    id_ex_memRE = 1;
    id_ex_rd = 5'd10;
    if_id_rs1 = 5'd10;
    if_id_rs2 = 5'd7;

    check_outputs();

    //--------------------------------------------------
    // Load-use Hazard (rs2)
    //--------------------------------------------------

    id_ex_rd = 5'd12;
    if_id_rs1 = 5'd1;
    if_id_rs2 = 5'd12;

    check_outputs();

    //--------------------------------------------------
    // x0 should NOT stall
    //--------------------------------------------------

    id_ex_rd = 5'd0;
    if_id_rs1 = 5'd0;
    if_id_rs2 = 5'd0;

    check_outputs();

    //--------------------------------------------------
    // MemRead disabled
    //--------------------------------------------------

    id_ex_memRE = 0;
    id_ex_rd = 5'd8;
    if_id_rs1 = 5'd8;

    check_outputs();

    //--------------------------------------------------
    // Taken Branch
    //--------------------------------------------------

    pcSEL = 2'b11;
    ALUResult_0 = 1'b1;

    check_outputs();

    //--------------------------------------------------
    // Branch NOT Taken
    //--------------------------------------------------

    ALUResult_0 = 1'b0;

    check_outputs();

    //--------------------------------------------------
    // JAL
    //--------------------------------------------------

    pcSEL = 2'b10;

    check_outputs();

    //--------------------------------------------------
    // JALR
    //--------------------------------------------------

    pcSEL = 2'b01;

    check_outputs();

    //--------------------------------------------------
    // Sequential PC
    //--------------------------------------------------

    pcSEL = 2'b00;

    check_outputs();

    //--------------------------------------------------
    // Random Testing
    //--------------------------------------------------

    for(i=0;i<1000;i=i+1)
    begin

        id_ex_memRE = $random;

        ALUResult_0 = $random;

        id_ex_rd  = $random & 5'h1F;
        if_id_rs1 = $random & 5'h1F;
        if_id_rs2 = $random & 5'h1F;

        pcSEL = $random & 2'b11;

        check_outputs();

    end

    //--------------------------------------------------
    // Summary
    //--------------------------------------------------

    $display("--------------------------------------");
    $display("HAZARD UNIT TEST SUMMARY");
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