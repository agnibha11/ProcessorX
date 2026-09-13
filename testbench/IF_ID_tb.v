
`timescale 1ns/1ps

module if_stage_tb;

reg clk, reset;
reg en_low, bubble, flush;
reg [1:0] pcSEL;
reg [31:0] PCImm, ALUResult;

wire [31:0] Instr, pc, PC_4;
wire [31:0] Instr_out, pc_out, PC_4_out;

if_stage DUT_IF(
    .clk(clk), .reset(reset), .en_low(en_low), .bubble(bubble),
    .pcSEL(pcSEL), .PCImm(PCImm), .ALUResult(ALUResult),
    .Instr(Instr), .pc(pc), .PC_4(PC_4)
);

if_id DUT_IFID(
    .clk(clk), .reset(reset), .flush(flush), .bubble(bubble),
    .Instr_in(Instr), .pc_in(pc), .PC_4_in(PC_4),
    .Instr_out(Instr_out), .pc_out(pc_out), .PC_4_out(PC_4_out)
);

// Match your current program (~67 instructions)
reg [31:0] golden_imem [0:66];

reg [31:0] prev_pc;
reg [31:0] prev_pc4;
reg [31:0] prev_instr;

reg [31:0] hold_pc;
reg [31:0] hold_pc4;
reg [31:0] hold_instr;

integer total, pass, fail, i;

initial begin
    $readmemh("../programs/instructions.dat", golden_imem);
end

initial clk = 0;
always #5 clk = ~clk;

task report;
input cond;
input [255:0] msg;
begin
    total = total + 1;
    if(cond) begin
        pass = pass + 1;
        $display("[PASS] %0s  t=%0t", msg, $time);
    end else begin
        fail = fail + 1;
        $display("[FAIL] %0s  t=%0t", msg, $time);
        $display("  pc=%h pc_out=%h", pc, pc_out);
        $display("  PC4=%h PC4_out=%h", PC_4, PC_4_out);
        $display("  Instr=%h Instr_out=%h", Instr, Instr_out);
    end
end
endtask

initial begin
    $dumpfile("if_stage_tb.vcd");
    $dumpvars(0, if_stage_tb);

    total=0; pass=0; fail=0;

    reset=1;
    en_low=0;
    bubble=0;
    flush=0;
    pcSEL=2'b00;
    PCImm=0;
    ALUResult=0;

    prev_pc=0;
    prev_pc4=0;
    prev_instr=0;

    #6;
    

    @(posedge clk);
    #1;
    report(Instr_out==0 && pc_out==0 && PC_4_out==0,
           "Reset clears IF/ID");
           
    #6;
    reset=0;

    // Initialize golden previous values
    prev_pc    = pc;
    prev_pc4   = PC_4;
    prev_instr = Instr;

    // Sequential fetch
    for(i=0;i<5;i=i+1) begin
        @(posedge clk);
        #1;
        report(PC_4==pc+4,"PC increments by 4");
        report(pc_out==prev_pc,"IFID captures previous PC");
        report(PC_4_out==prev_pc4,"IFID captures previous PC+4");
        report(Instr_out==prev_instr,"IFID captures previous instruction");

        prev_pc    = pc;
        prev_pc4   = PC_4;
        prev_instr = Instr;
    end

    // Bubble
    hold_pc    = pc_out;
    hold_pc4   = PC_4_out;
    hold_instr = Instr_out;

    bubble=1;
    repeat(3) begin
        @(posedge clk);
        #1;
        report(pc_out==hold_pc,"Bubble holds PC");
        report(PC_4_out==hold_pc4,"Bubble holds PC+4");
        report(Instr_out==hold_instr,"Bubble holds instruction");
    end

    bubble=0;
    @(posedge clk);
    #1;
    report(pc_out!=hold_pc,"Resume after bubble");

    prev_pc=pc;
    prev_pc4=PC_4;
    prev_instr=Instr;

    // Flush
    flush=1;
    @(posedge clk);
    #1;
    report(Instr_out==0,"Flush clears instruction");
    report(pc_out==0,"Flush clears PC");
    report(PC_4_out==0,"Flush clears PC+4");
    flush=0;

    // JAL
    pcSEL=2'b10;
    PCImm=32'h40;
    @(posedge clk);
    #1;
    report(pc==32'h40,"JAL changes PC");

    // JALR
    pcSEL=2'b01;
    ALUResult=32'h80;
    @(posedge clk);
    #1;
    report(pc==32'h80,"JALR changes PC");

    // Branch taken
    pcSEL=2'b11;
    PCImm=32'h24;
    ALUResult=32'h1;
    @(posedge clk);
    #1;
    report(pc==32'h24,"Branch taken");

    // Branch not taken
    ALUResult=0;
    @(posedge clk);
    #1;
    report(PC_4==pc+4,"Branch not taken");

    // Halt
    en_low=1;
    hold_pc=pc;
    @(posedge clk);
    #1;
    report(pc==hold_pc,"Halt freezes PC");
    @(posedge clk);
    #1;
    report(pc==hold_pc,"Halt continues freeze");
    en_low=0;
    @(posedge clk);
    #1;
    report(pc!=hold_pc,"Resume after halt");

    $display("-------------------------------------");
    $display("TOTAL : %0d", total);
    $display("PASS  : %0d", pass);
    $display("FAIL  : %0d", fail);
    $display("-------------------------------------");

    $finish;
end

endmodule