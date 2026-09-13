`timescale 1ns/1ps

module top_tb;

    reg clk;
    reg reset;

    integer i;

    // DUT
    top DUT(
        .clk(clk),
        .reset(reset)
    );

    // Clock generation : 10 ns period
    initial
        clk = 0;

    always
        #5 clk = ~clk;


    // Main test
    initial begin

        // Apply reset
        reset = 1;
        #20;
        reset = 0;

        // Run processor
        #9000000; 

        // Print register file
        $display("");
        $display("========================================");
        $display("FINAL REGISTER STATE");
        $display("========================================");

        for(i = 0; i < 32; i = i + 1) begin
            $display(
                "x%0d = %h",
                i,
                DUT.ID.REGFILE.REGS[i]
            );
        end

        $display("========================================");
        $display("Final PC = %h", DUT.IF1.pc);
        $display("========================================");

        // Print data memory as 32-bit words, little-endian
        $display("");
        $display("========================================");
        $display("FINAL DATA MEMORY STATE");
        $display("========================================");
        $display("Format: [byte address] = 32-bit word");
        $display("");

        for(i = 0; i < 8192; i = i + 4) begin
            $display(
                "mem[%03h] = %02h %02h %02h %02h   (word = %08h)",
                i,
                DUT.MEM.DMEMORY.mem[i],
                DUT.MEM.DMEMORY.mem[i+1],
                DUT.MEM.DMEMORY.mem[i+2],
                DUT.MEM.DMEMORY.mem[i+3],
                {DUT.MEM.DMEMORY.mem[i+3], DUT.MEM.DMEMORY.mem[i+2], DUT.MEM.DMEMORY.mem[i+1], DUT.MEM.DMEMORY.mem[i]}
            );
        end

        $display("========================================");
        $display("");

        $finish;

    end


    // Waveform dumping
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
    end
endmodule