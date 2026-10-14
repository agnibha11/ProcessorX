`timescale 1ns/1ps

module FloatSqrt_tb;

    reg  [31:0] X;
    wire [31:0] Y;

    // Corrected module instantiation
    FloatSqrt uut (
        .X(X),
        .Y(Y)
    );

    // Task for applying inputs, waiting for combinational logic, and checking
    task check_sqrt;
        input [31:0] valX;
        input [31:0] expected_Y;
        begin
            X = valX;
            #10; // Wait for combinational propagation
            
            if (Y !== expected_Y) begin
                $display("FAIL: sqrt %h = %h | Expected: %h", valX, Y, expected_Y);
            end else begin
                $display("PASS: sqrt %h = %h", valX, Y);
            end
        end
    endtask

    initial begin
        $display("Starting Floating Point Sqrt Combinational Tests...\n");

        // ---------------------------------------------------------
        // 2. Identity and Perfect Squares (Integers)
        // ---------------------------------------------------------
        $display("--- Testing Perfect Squares ---");
        check_sqrt(32'h3f800000, 32'h3f800000); // sqrt(1.0) = 1.0
        check_sqrt(32'h40800000, 32'h40000000); // sqrt(4.0) = 2.0
        check_sqrt(32'h41100000, 32'h40400000); // sqrt(9.0) = 3.0
        check_sqrt(32'h41800000, 32'h40800000); // sqrt(16.0) = 4.0
        check_sqrt(32'h41c80000, 32'h40a00000); // sqrt(25.0) = 5.0
        check_sqrt(32'h42c80000, 32'h41200000); // sqrt(100.0) = 10.0
        check_sqrt(32'h43100000, 32'h41400000); // sqrt(144.0) = 12.0
        check_sqrt(32'h461c4000, 32'h42c80000); // sqrt(10000.0) = 100.0

        // ---------------------------------------------------------
        // 3. Fractions and Decimals
        // ---------------------------------------------------------
        $display("--- Testing Fractions ---");
        check_sqrt(32'h3e800000, 32'h3f000000); // sqrt(0.25) = 0.5
        check_sqrt(32'h3d800000, 32'h3e800000); // sqrt(0.0625) = 0.25
        check_sqrt(32'h40100000, 32'h3fc00000); // sqrt(2.25) = 1.5
        check_sqrt(32'h40c80000, 32'h40200000); // sqrt(6.25) = 2.5

        // ---------------------------------------------------------
        // 4. Common Irrationals and Non-Perfect Roots
        // ---------------------------------------------------------
        $display("--- Testing Irrationals & Non-perfect roots ---");
        check_sqrt(32'h40000000, 32'h3fb504f3); // sqrt(2.0) = 1.4142135
        check_sqrt(32'h3f000000, 32'h3f3504f3); // sqrt(0.5) = 0.7071067
        check_sqrt(32'h41000000, 32'h403504f3); // sqrt(8.0) = 2.8284271
        check_sqrt(32'h40490fdb, 32'h3fe2dfc5); // sqrt(pi) = 1.7724538
        check_sqrt(32'h402df854, 32'h3fd3094c); // sqrt(e) = 1.6487212

        // ---------------------------------------------------------
        // 5. Very Large Normal Numbers (Even Powers of 2)
        // ---------------------------------------------------------
        $display("--- Testing Large Normal Numbers ---");
        check_sqrt(32'h58800000, 32'h4c000000); // sqrt(2^50) = 2^25
        check_sqrt(32'h67800000, 32'h53800000); // sqrt(2^80) = 2^40
        check_sqrt(32'h71800000, 32'h58800000); // sqrt(2^100) = 2^50
        check_sqrt(32'h7d800000, 32'h5e800000); // sqrt(2^124) = 2^62
        check_sqrt(32'h7e800000, 32'h5f000000); // sqrt(2^126) = 2^63

        // ---------------------------------------------------------
        // 6. Very Small Normal Numbers (Even Powers of 2)
        // ---------------------------------------------------------
        $display("--- Testing Small Normal Numbers ---");
        check_sqrt(32'h35800000, 32'h3a800000); // sqrt(2^-20) = 2^-10
        check_sqrt(32'h26800000, 32'h33000000); // sqrt(2^-50) = 2^-25
        check_sqrt(32'h15800000, 32'h2a800000); // sqrt(2^-100) = 2^-50
        check_sqrt(32'h01800000, 32'h20800000); // sqrt(2^-124) = 2^-62
        check_sqrt(32'h00800000, 32'h20000000); // sqrt(2^-126) = 2^-63 (Smallest normal)

        // ---------------------------------------------------------
        // 7. Subnormal (Denormalized) Numbers
        // Note: The square root of a subnormal number often results 
        // in a normal number. Using even powers of 2 for exact matches.
        // ---------------------------------------------------------
        $display("--- Testing Subnormals ---");
        check_sqrt(32'h00200000, 32'h1f800000); // sqrt(2^-128) = 2^-64
        check_sqrt(32'h00080000, 32'h1f000000); // sqrt(2^-130) = 2^-65
        check_sqrt(32'h00020000, 32'h1e800000); // sqrt(2^-132) = 2^-66
        check_sqrt(32'h00008000, 32'h1e000000); // sqrt(2^-134) = 2^-67
        check_sqrt(32'h00002000, 32'h1d800000); // sqrt(2^-136) = 2^-68
        check_sqrt(32'h00000800, 32'h1d000000); // sqrt(2^-138) = 2^-69
        check_sqrt(32'h00000200, 32'h1c800000); // sqrt(2^-140) = 2^-70
        check_sqrt(32'h00000080, 32'h1c000000); // sqrt(2^-142) = 2^-71
        check_sqrt(32'h00000020, 32'h1b800000); // sqrt(2^-144) = 2^-72
        check_sqrt(32'h00000008, 32'h1b000000); // sqrt(2^-146) = 2^-73
        check_sqrt(32'h00000002, 32'h1a800000); // sqrt(2^-148) = 2^-74
        
        $display("\nSimulation Complete.");
        $finish;
    end

endmodule