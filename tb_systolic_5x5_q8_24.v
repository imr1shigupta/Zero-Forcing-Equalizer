`timescale 1ns/1ps

module tb_systolic_5x5_q8_24;

    // ============================================================
    // 1. Parameters & Signals
    // ============================================================
    reg clk;
    reg rst;

    // Inputs (32-bit width) [cite: 23-24]
    reg signed [31:0] A0, A1, A2, A3, A4;
    reg signed [31:0] B0, B1, B2, B3, B4;

    // Outputs (2D array for easier viewing) [cite: 24-25]
    wire signed [31:0] C[0:4][0:4]; 

    // Scaling Factor for Q8.24 (2^24 = 16777216) [cite: 25]
    localparam SF = 16777216.0;

    // Internal Memory to hold the full matrices [cite: 26-27]
    reg signed [31:0] A_MAT [0:4][0:4];
    reg signed [31:0] B_MAT [0:4][0:4];

    integer i, j, k;

    // ============================================================
    // 2. DUT Instantiation (Updated to Q8.24 Module)
    // ============================================================
    systolic_5x5_q8_24 dut (
        .clk(clk),
        .rst(rst),
        .A0(A0), .A1(A1), .A2(A2), .A3(A3), .A4(A4),
        .B0(B0), .B1(B1), .B2(B2), .B3(B3), .B4(B4),
        .C00(C[0][0]), .C01(C[0][1]), .C02(C[0][2]), .C03(C[0][3]), .C04(C[0][4]),
        .C10(C[1][0]), .C11(C[1][1]), .C12(C[1][2]), .C13(C[1][3]), .C14(C[1][4]),
        .C20(C[2][0]), .C21(C[2][1]), .C22(C[2][2]), .C23(C[2][3]), .C24(C[2][4]),
        .C30(C[3][0]), .C31(C[3][1]), .C32(C[3][2]), .C33(C[3][3]), .C34(C[3][4]),
        .C40(C[4][0]), .C41(C[4][1]), .C42(C[4][2]), .C43(C[4][3]), .C44(C[4][4])
    );

    // ============================================================
    // 3. Clock Generation [cite: 30]
    // ============================================================
    initial clk = 0;
    always #5 clk = ~clk; 

    // ============================================================
    // 4. Test Sequence
    // ============================================================
    initial begin
        // --- Initialize Matrices with Real Numbers ---
        for (i=0; i<5; i=i+1) begin
            for (j=0; j<5; j=j+1) begin
                if (i==j) A_MAT[i][j] = 1.0 * SF; // Identity matrix initialization [cite: 31]
                else      A_MAT[i][j] = 0;
            end
        end

        // Testing small decimal values suited for Q8.24 precision [cite: 33-34]
        A_MAT[0][0] = 0.5 * SF; 
        A_MAT[0][1] = 1.25 * SF; 
        A_MAT[0][2] = 2.0 * SF; 
        A_MAT[0][3] = -0.75 * SF; 
        A_MAT[0][4] = 1.1 * SF;

        // Matrix B: Fill with fractional values [cite: 35-36]
        for (i=0; i<5; i=i+1) begin
            for (j=0; j<5; j=j+1) begin
                B_MAT[i][j] = (i * 0.1 + j * 0.05 + 0.1) * SF; 
            end
        end

        // --- Print Input Matrices (Just like original version) --- [cite: 37]
        $display("\n--- Input Matrix A (Real Q8.24) ---");
        for(i=0; i<5; i=i+1) 
            $display("%f %f %f %f %f", $itor(A_MAT[i][0])/SF, $itor(A_MAT[i][1])/SF, $itor(A_MAT[i][2])/SF, $itor(A_MAT[i][3])/SF, $itor(A_MAT[i][4])/SF); 
        
        $display("\n--- Input Matrix B (Real Q8.24) ---");
        for(i=0; i<5; i=i+1) 
            $display("%f %f %f %f %f", $itor(B_MAT[i][0])/SF, $itor(B_MAT[i][1])/SF, $itor(B_MAT[i][2])/SF, $itor(B_MAT[i][3])/SF, $itor(B_MAT[i][4])/SF); 

        // --- Reset System --- [cite: 40-41]
        rst = 1;
        {A0, A1, A2, A3, A4, B0, B1, B2, B3, B4} = 0;
        #20;
        rst = 0;

        // --- Feed Data (The Systolic Pulse) --- [cite: 43]
        for (k = 0; k < 20; k = k + 1) begin
            A0 <= get_A(0, k); A1 <= get_A(1, k); A2 <= get_A(2, k); A3 <= get_A(3, k); A4 <= get_A(4, k); 
            B0 <= get_B(0, k); B1 <= get_B(1, k); B2 <= get_B(2, k); B3 <= get_B(3, k); B4 <= get_B(4, k); 
            #10;
        end

        // Stop feeding inputs [cite: 47-48]
        {A0, A1, A2, A3, A4, B0, B1, B2, B3, B4} = 0;

        #50; // Wait for final calculations [cite: 48]

        // --- Check and Display Results --- [cite: 49-50]
        $display("\n--- Output Matrix C (Q8.24 Calculated) ---");
        for (i=0; i<5; i=i+1) begin
             $display("%f %f %f %f %f", 
                $itor(C[i][0])/SF, $itor(C[i][1])/SF, $itor(C[i][2])/SF, $itor(C[i][3])/SF, $itor(C[i][4])/SF);
        end 
        $finish;
    end

    // ============================================================
    // 5. Helper Functions for Skewing (Logic same as Q16.16)
    // ============================================================
    function signed [31:0] get_A;
        input integer row_idx, cycle;
        integer data_idx;
        begin
            data_idx = cycle - row_idx; 
            get_A = (data_idx >= 0 && data_idx < 5) ? A_MAT[row_idx][data_idx] : 32'sd0; 
        end
    endfunction

    function signed [31:0] get_B;
        input integer col_idx, cycle;
        integer data_idx;
        begin
            data_idx = cycle - col_idx; 
            get_B = (data_idx >= 0 && data_idx < 5) ? B_MAT[data_idx][col_idx] : 32'sd0;
        end
    endfunction

endmodule