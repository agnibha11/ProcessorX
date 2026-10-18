`timescale 1ns/1ps

module FloatSAdd_tb;

    reg  [31:0] A, B;
    wire [31:0] S; // Fixed missing semicolon

    FloatSAdd uut (
        .A(A), .B(B),
        .S(S)
    );

    // Task for applying inputs, waiting for combinational logic, and checking
    task check_mult;
        input [31:0] valA;
        input [31:0] valB;
        input [31:0] expected_S;
        begin
            A = valA;
            B = valB;
            #10; // Wait for combinational propagation
            
            if (S !== expected_S) begin
                $display("FAIL: %h + %h = %h | Expected: %h", valA, valB, S, expected_S);
            end else begin
                $display("PASS: %h + %h = %h", valA, valB, S);
            end
        end
    endtask

    initial begin
        $display("Starting FloatSAdd Combinational Tests...\n");

        // ==========================================
        // 1. Normal Range: Positive Additions
        // ==========================================
        $display("--- Normal Range Positive ---");
        check_mult(32'h3F800000, 32'h3F800000, 32'h40000000); // 1.0 + 1.0 = 2.0
        check_mult(32'h3FC00000, 32'h3FC00000, 32'h40400000); // 1.5 + 1.5 = 3.0
        check_mult(32'h40000000, 32'h40000000, 32'h40800000); // 2.0 + 2.0 = 4.0
        check_mult(32'h40400000, 32'h3F800000, 32'h40800000); // 3.0 + 1.0 = 4.0
        check_mult(32'h3F000000, 32'h3E800000, 32'h3F400000); // 0.5 + 0.25 = 0.75
        check_mult(32'h41200000, 32'h41200000, 32'h41A00000); // 10.0 + 10.0 = 20.0
        check_mult(32'h41480000, 32'h3FA00000, 32'h415C0000); // 12.5 + 1.25 = 13.75
        check_mult(32'h42C80000, 32'h3F000000, 32'h42C90000); // 100.0 + 0.5 = 100.5
        check_mult(32'h44800000, 32'h44000000, 32'h44C00000); // 1024.0 + 512.0 = 1536.0
        check_mult(32'h43800000, 32'h43800000, 32'h44000000); // 256.0 + 256.0 = 512.0

        // ==========================================
        // 2. Normal Range: Mixed Signs (Subtraction)
        // ==========================================
        $display("--- Normal Range Mixed Signs ---");
        check_mult(32'h40000000, 32'hBF800000, 32'h3F800000); // 2.0 + (-1.0) = 1.0
        check_mult(32'h40400000, 32'hBFC00000, 32'h3FC00000); // 3.0 + (-1.5) = 1.5
        check_mult(32'h42C80000, 32'hBF000000, 32'h42C70000); // 100.0 + (-0.5) = 99.5
        check_mult(32'hC1200000, 32'h41A00000, 32'h41200000); // (-10.0) + 20.0 = 10.0
        check_mult(32'h415C0000, 32'hBFA00000, 32'h41480000); // 13.75 + (-1.25) = 12.5
        check_mult(32'h43800000, 32'hC3000000, 32'h43000000); // 256.0 + (-128.0) = 128.0
        
        // ==========================================
        // 3. Normal Range: Negative Additions
        // ==========================================
        $display("--- Normal Range Negative ---");
        check_mult(32'hC0A00000, 32'hC0A00000, 32'hC1200000); // (-5.0) + (-5.0) = -10.0
        check_mult(32'hBF400000, 32'hBE800000, 32'hBF800000); // (-0.75) + (-0.25) = -1.0
        check_mult(32'hC4800000, 32'hC4000000, 32'hC4C00000); // (-1024.0) + (-512.0) = -1536.0

        // ==========================================
        // 4. Extreme Cancellations (Normal -> Subnormal)
        // ==========================================
        $display("--- Extreme Cancellations ---");
        check_mult(32'h3F800001, 32'hBF800000, 32'h34000000); // (1.0 + 2^-23) + (-1.0) = 2^-23
        check_mult(32'h40000001, 32'hC0000000, 32'h34800000); // (2.0 + 2^-22) + (-2.0) = 2^-22
        check_mult(32'h3FC00001, 32'hBFC00000, 32'h34000000); // (1.5 + 2^-23) + (-1.5) = 2^-23
        check_mult(32'h40800005, 32'hC0800000, 32'h36200000); // (4.0 + 5*2^-21) + (-4.0) = 20 * 2^-23

        // ==========================================
        // 5. Subnormal Additions
        // ==========================================
        $display("--- Subnormal Additions ---");
        check_mult(32'h00000001, 32'h00000001, 32'h00000002); // Min subnormal + Min subnormal
        check_mult(32'h00000002, 32'h00000003, 32'h00000005); 
        check_mult(32'h00000010, 32'h00000020, 32'h00000030); 
        check_mult(32'h00400000, 32'h00200000, 32'h00600000); 
        check_mult(32'h80000005, 32'h00000002, 32'h80000003); // Mixed sign subnormals
        check_mult(32'h80600000, 32'h00200000, 32'h80400000); 
        
        // ==========================================
        // 6. Subnormal / Normal Transitions
        // ==========================================
        $display("--- Subnormal/Normal Boundaries ---");
        check_mult(32'h007FFFFE, 32'h00000001, 32'h007FFFFF); // Max Subnormal
        check_mult(32'h007FFFFF, 32'h00000001, 32'h00800000); // Subnormal -> Min Normal boundary
        check_mult(32'h00800000, 32'h80000001, 32'h007FFFFF); // Min Normal -> Max Subnormal
        check_mult(32'h00800000, 32'h007FFFFF, 32'h00FFFFFF); // Min Normal + Max Subnormal
        check_mult(32'h00FFFFFF, 32'h00000001, 32'h01000000); // Normal + Subnormal -> Next Exponent
        check_mult(32'h00800000, 32'h00000001, 32'h00800001); // Min Normal + Min Subnormal
        check_mult(32'h01000000, 32'h00000001, 32'h01000000); // 2^-125 + Min Subnormal

        // ==========================================
        // 7. Large Disparities (Rounding Tests)
        // ==========================================
        $display("--- Large Disparities ---");
        check_mult(32'h3F800000, 32'h00000001, 32'h3F800000); // 1.0 + 2^-149 (completely shifted out)
        check_mult(32'h40000000, 32'h80000001, 32'h40000000); // 2.0 - 2^-149 (completely shifted out)

        $display("\nSimulation Complete.");
        $finish;
    end

endmodule