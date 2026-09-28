`timescale 1ns/1ps

module FloatMul_tb;

    reg  [31:0] A, B;
    wire [31:0] P; // Fixed missing semicolon

    // Corrected module instantiation
    FloatMul uut (
        .A(A),
        .B(B),
        .P(P)
    );

    // Task for applying inputs, waiting for combinational logic, and checking
    task check_mult;
        input [31:0] valA;
        input [31:0] valB;
        input [31:0] expected_P;
        begin
            A = valA;
            B = valB;
            #10; // Wait for combinational propagation
            
            if (P !== expected_P) begin
                $display("FAIL: %h * %h = %h | Expected: %h", valA, valB, P, expected_P);
            end else begin
                $display("PASS: %h * %h = %h", valA, valB, P);
            end
        end
    endtask

    initial begin
        $display("Starting Extended FloatMul Combinational Tests...\n");

        $display("--- ZERO TESTS (10 Cases) ---");
        // +0.0 * +0.0 = +0.0
        check_mult(32'h00000000, 32'h00000000, 32'h00000000);
        // -0.0 * +0.0 = -0.0
        check_mult(32'h80000000, 32'h00000000, 32'h80000000);
        // +0.0 * -0.0 = -0.0
        check_mult(32'h00000000, 32'h80000000, 32'h80000000);
        // -0.0 * -0.0 = +0.0
        check_mult(32'h80000000, 32'h80000000, 32'h00000000);
        // +1.0 * +0.0 = +0.0
        check_mult(32'h3F800000, 32'h00000000, 32'h00000000);
        // -1.0 * +0.0 = -0.0
        check_mult(32'hBF800000, 32'h00000000, 32'h80000000);
        // +0.0 * +1.0 = +0.0
        check_mult(32'h00000000, 32'h3F800000, 32'h00000000);
        // -0.0 * +1.0 = -0.0
        check_mult(32'h80000000, 32'h3F800000, 32'h80000000);
        // +Subnormal * +0.0 = +0.0
        check_mult(32'h00100000, 32'h00000000, 32'h00000000);
        // -Subnormal * +0.0 = -0.0
        check_mult(32'h80100000, 32'h00000000, 32'h80000000);

        $display("\n--- NORMAL TESTS (15 Cases) ---");
        // +1.0 * +1.0 = +1.0
        check_mult(32'h3F800000, 32'h3F800000, 32'h3F800000);
        // -1.0 * +1.0 = -1.0
        check_mult(32'hBF800000, 32'h3F800000, 32'hBF800000);
        // -1.0 * -1.0 = +1.0
        check_mult(32'hBF800000, 32'hBF800000, 32'h3F800000);
        // +2.0 * +2.0 = +4.0
        check_mult(32'h40000000, 32'h40000000, 32'h40800000);
        // +2.0 * +3.0 = +6.0
        check_mult(32'h40000000, 32'h40400000, 32'h40C00000);
        // -1.5 * +2.5 = -3.75
        check_mult(32'hBFC00000, 32'h40200000, 32'hC0700000);
        // +10.0 * +10.0 = +100.0
        check_mult(32'h41200000, 32'h41200000, 32'h42C80000);
        // +0.5 * +0.5 = +0.25
        check_mult(32'h3F000000, 32'h3F000000, 32'h3E800000);
        // +0.75 * +0.5 = +0.375
        check_mult(32'h3F400000, 32'h3F000000, 32'h3EC00000);
        // +1.25 * +1.25 = +1.5625
        check_mult(32'h3FA00000, 32'h3FA00000, 32'h3FC80000);
        // +16.0 * +0.0625 = +1.0
        check_mult(32'h41800000, 32'h3D800000, 32'h3F800000);
        // +1.0 * +2.0 = +2.0
        check_mult(32'h3F800000, 32'h40000000, 32'h40000000);
        // +2.0 * +1.0 = +2.0 (Commutative check)
        check_mult(32'h40000000, 32'h3F800000, 32'h40000000);
        // +1.5 * +1.5 = +2.25
        check_mult(32'h3FC00000, 32'h3FC00000, 32'h40100000);
        // +3.0 * +3.0 = +9.0
        check_mult(32'h40400000, 32'h40400000, 32'h41100000);

        $display("\n--- SUBNORMAL TESTS (10 Cases) ---");
        // MinSubnormal * 1.0 = MinSubnormal
        check_mult(32'h00000001, 32'h3F800000, 32'h00000001);
        // MinSubnormal * 2.0 = MinSubnormal * 2
        check_mult(32'h00000001, 32'h40000000, 32'h00000002);
        // MinSubnormal * 4.0 = MinSubnormal * 4
        check_mult(32'h00000001, 32'h40800000, 32'h00000004);
        // MidSubnormal * 1.0 = MidSubnormal
        check_mult(32'h00100000, 32'h3F800000, 32'h00100000);
        // MidSubnormal * 2.0 = MidSubnormal * 2
        check_mult(32'h00100000, 32'h40000000, 32'h00200000);
        // MidSubnormal * 0.5 = MidSubnormal / 2
        check_mult(32'h00100000, 32'h3F000000, 32'h00080000);
        // MaxSubnormal * 1.0 = MaxSubnormal
        check_mult(32'h007FFFFF, 32'h3F800000, 32'h007FFFFF);
        // MinSubnormal * MinSubnormal = Underflow to +0.0
        check_mult(32'h00000001, 32'h00000001, 32'h00000000);
        // MidSubnormal * MidSubnormal = Underflow to +0.0
        check_mult(32'h00400000, 32'h00400000, 32'h00000000);
        // MinSubnormal * 0.5 = Underflow to +0.0 (Rounding to nearest even)
        check_mult(32'h00000001, 32'h3F000000, 32'h00000000);

        $display("\n--- TRANSITION TESTS: NORM <-> SUBNORM (8 Cases) ---");
        // MaxSubnormal * 2.0 = Normal (Exp=1, Man=1...10)
        check_mult(32'h007FFFFF, 32'h40000000, 32'h00FFFFFE);
        // MaxSubnormal * 4.0 = Normal (Exp=2, Man=1...00)
        check_mult(32'h007FFFFF, 32'h40800000, 32'h017FFFFE);
        // MinNormal * 0.5 = Subnormal (2^-127 -> 0x00400000)
        check_mult(32'h00800000, 32'h3F000000, 32'h00400000);
        // MinNormal * 0.25 = Subnormal (2^-128 -> 0x00200000)
        check_mult(32'h00800000, 32'h3E800000, 32'h00200000);
        // Small Normal * Small Normal = Subnormal (2^-63 * 2^-64 = 2^-127)
        check_mult(32'h20000000, 32'h1F800000, 32'h00400000);
        // Small Normal * Small Normal = Subnormal (1.5 * 2^-63 * 2^-64 = 1.5 * 2^-127)
        check_mult(32'h20400000, 32'h1F800000, 32'h00600000);
        // Subnormal * Normal = MinNormal (0.5 * 2^-126 * 2.0 = 1.0 * 2^-126)
        check_mult(32'h00400000, 32'h40000000, 32'h00800000);
        // Subnormal * Normal = MinNormal (0.25 * 2^-126 * 4.0 = 1.0 * 2^-126)
        check_mult(32'h00200000, 32'h40800000, 32'h00800000);

        $display("\n--- OVERFLOW TO INFINITY TESTS (6 Cases) ---");
        // MaxNormal * 2.0 = +Infinity
        check_mult(32'h7F7FFFFF, 32'h40000000, 32'h7F800000);
        // MaxNormal * MaxNormal = +Infinity
        check_mult(32'h7F7FFFFF, 32'h7F7FFFFF, 32'h7F800000);
        // -MaxNormal * 2.0 = -Infinity
        check_mult(32'hFF7FFFFF, 32'h40000000, 32'hFF800000);
        // MaxNormal * -MaxNormal = -Infinity
        check_mult(32'h7F7FFFFF, 32'hFF7FFFFF, 32'hFF800000);
        // LargeNormal * LargeNormal = +Infinity
        check_mult(32'h70000000, 32'h70000000, 32'h7F800000);
        // Threshold crossing: 2^64 * 2^64 = 2^128 (+Infinity)
        check_mult(32'h5F800000, 32'h5F800000, 32'h7F800000);

        $display("\n--- ROUNDING & EDGE CASES (7 Cases) ---");
        // MinSubnormal * 1.5 = Round up to 2 * 2^-149 (Nearest even)
        check_mult(32'h00000001, 32'h3FC00000, 32'h00000002);
        // MinSubnormal * 1.25 = Round down to 1 * 2^-149 (Nearest)
        check_mult(32'h00000001, 32'h3FA00000, 32'h00000001);
        // MinSubnormal * 1.75 = Round up to 2 * 2^-149 (Nearest)
        check_mult(32'h00000001, 32'h3FE00000, 32'h00000002);
        // MaxSubnormal * 0.5 = 0x003FFFFF.5 -> Round to even -> 0x00400000
        check_mult(32'h007FFFFF, 32'h3F000000, 32'h00400000);
        // MaxSubnormal * (1 + 2^-23) -> Rounds precisely up to MinNormal
        check_mult(32'h007FFFFF, 32'h3F800001, 32'h00800000);
        // (1 + 2^-23) * (1 + 2^-23) = 1 + 2^-22 (Nearest even)
        check_mult(32'h3F800001, 32'h3F800001, 32'h3F800002);
        // (1 + 3*2^-23) * (1 + 3*2^-23) = 1 + 6*2^-23
        check_mult(32'h3F800003, 32'h3F800003, 32'h3F800006);

        $display("\nSimulation Complete.");
        $finish;
    end

endmodule