`timescale 1ns/1ps

module tb_pe_q8_24;

    // ----------------------------------
    // Clock / Reset
    // ----------------------------------
    reg clk;
    reg rst;

    always #5 clk = ~clk;   // 100 MHz clock

    // ----------------------------------
    // DUT signals
    // ----------------------------------
    reg  signed [31:0] a_in;
    reg  signed [31:0] b_in;
    wire signed [31:0] acc;

    // ----------------------------------
    // Instantiate DUT
    // ----------------------------------
    pe_q8_24 dut (
        .clk (clk),
        .rst (rst),
        .a_in(a_in),
        .b_in(b_in),
        .acc (acc)
    );

    // ----------------------------------
    // Helper functions
    // ----------------------------------
    function signed [31:0] to_q8_24;
        input real r;
        begin
            to_q8_24 = $rtoi(r * 16777216.0);
        end
    endfunction

    function real to_real;
        input signed [31:0] q;
        begin
            to_real = q / 16777216.0;
        end
    endfunction

    // ----------------------------------
    // Debug variables
    // ----------------------------------
    real prev_acc, a_real, b_real, prod;

    // ----------------------------------
    // Test sequence
    // ----------------------------------
    initial begin
        clk  = 0;
        rst  = 1;
        a_in = 0;
        b_in = 0;

        #20;
        rst = 0;

        // ==================================
        // TEST 1
        // ==================================
        @(posedge clk);
        a_in = to_q8_24(1.5);
        b_in = to_q8_24(2.0);

        a_real = 1.5;
        b_real = 2.0;
        prod   = a_real * b_real;

        @(posedge clk);
        #1;

        $display("\n---- TEST 1 DEBUG ----");
        $display("Previous acc      = 0.0 (reset)");
        $display("Input a_in        = %f", a_real);
        $display("Input b_in        = %f", b_real);
        $display("Product (a*b)     = %f", prod);
        $display("New acc           = %f", to_real(acc));
        $display("Expected acc      = %f", prod);

        if (acc !== to_q8_24(prod))
            $display("❌ TEST 1 FAIL");
        else
            $display("✅ TEST 1 PASS");

        // ==================================
        // TEST 2
        // ==================================
        prev_acc = to_real(acc);

        a_real = to_real(a_in);
        b_real = to_real(b_in);
        prod   = a_real * b_real;

        @(posedge clk);
        #1;

        $display("\n---- TEST 2 DEBUG ----");
        $display("Previous acc      = %f", prev_acc);
        $display("Input a_in        = %f", a_real);
        $display("Input b_in        = %f", b_real);
        $display("Product (a*b)     = %f", prod);
        $display("New acc           = %f", to_real(acc));
        $display("Expected acc      = %f", prev_acc + prod);

        if (acc !== to_q8_24(prev_acc + prod))
            $display("❌ TEST 2 FAIL");
        else
            $display("✅ TEST 2 PASS");

        // ==================================
        // TEST 3
        // ==================================
        prev_acc = to_real(acc);

        a_in = to_q8_24(-1.25);
        b_in = to_q8_24(2.0);

        a_real = -1.25;
        b_real = 2.0;
        prod   = a_real * b_real;

        @(posedge clk);
        #1;

        $display("\n---- TEST 3 DEBUG ----");
        $display("Previous acc      = %f", prev_acc);
        $display("Input a_in        = %f", a_real);
        $display("Input b_in        = %f", b_real);
        $display("Product (a*b)     = %f", prod);
        $display("New acc           = %f", to_real(acc));
        $display("Expected acc      = %f", prev_acc + prod);

        if (acc !== to_q8_24(prev_acc + prod))
            $display("❌ TEST 3 FAIL");
        else
            $display("✅ TEST 3 PASS");

        // ==================================
        $display("\nAll tests complete.");
        $stop;
    end

endmodule