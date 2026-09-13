`timescale 1ns/1ps

module regfile_tb;

reg clk;
reg reset;

reg [4:0] rs1, rs2, rd;
reg [31:0] w_data;
reg w_en;

wire [31:0] data_1, data_2;

// DUT
regfile dut(
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd),

    .w_data(w_data),

    .w_en(w_en),

    .clk(clk),
    .reset(reset),

    .data_1(data_1),
    .data_2(data_2)

);


// Golden Model
reg [31:0] golden_regs [31:0];

// Statistics
integer i;
integer test_count;
integer pass_count;
integer fail_count;


// Clock generation

initial
    clk = 0;

always #5 clk = ~clk;


// Scoreboard
task score_board;

reg [31:0] expected_1;
reg [31:0] expected_2;

begin

    test_count = test_count + 1;

    expected_1 = (rs1 == 0) ? 32'b0 : golden_regs[rs1];
    expected_2 = (rs2 == 0) ? 32'b0 : golden_regs[rs2];


    if((data_1 !== expected_1) || (data_2 !== expected_2)) begin
        fail_count = fail_count + 1;
        $display("FAIL test=%0d rs1=%0d rs2=%0d rd=%0d we=%b wdata=%h exp1=%h got1=%h exp2=%h got2=%h time=%0t", test_count,rs1,rs2,rd,w_en,w_data,expected_1,data_1,expected_2,data_2,$time);
    end

    else begin
        pass_count = pass_count + 1;
        $display("PASS test=%0d rs1=%0d rs2=%0d rd=%0d",test_count,rs1,rs2,rd);
    end

end

endtask

// Main test
initial begin

    $dumpfile("regfile_tb.vcd");
    $dumpvars(0,regfile_tb);


    test_count = 0;
    pass_count = 0;
    fail_count = 0;

    // Initialize Golden Model
    for(i=0;i<32;i=i+1)
        golden_regs[i]=0;



    // Reset DUT
    reset = 1;
    w_en = 0;
    rs1 = 0;
    rs2 = 0;
    rd = 0;
    w_data = 0;

    #20;

    reset = 0;

    // Random Testing
    for(i=0;i<2000;i=i+1) begin

        rs1 = $unsigned($random)%32;
        rs2 = $unsigned($random)%32;
        rd  = $unsigned($random)%32;
        w_data = $random;
        w_en = $unsigned($random)%2;

        // Update DUT and Golden on clock edge

        @(posedge clk);
        if(w_en && (rd!=0))
            golden_regs[rd] = w_data;
        

        #5;
        score_board();
    end



    // Summary


    $display("------------------------------------");

    $display("REGISTER FILE TEST SUMMARY");

    $display("Total Tests : %0d",test_count);

    $display("Passed      : %0d",pass_count);

    $display("Failed      : %0d",fail_count);

    $display("------------------------------------");


    if(fail_count==0)

        $display("ALL TESTS PASSED");

    else

        $display("SOME TESTS FAILED");


    #20;

    $finish;


end


endmodule