`timescale 1ns/1ps

module tb_complete_zfe;
    // ================================================================
    // 1. SIGNALS & CONSTANTS
    // ================================================================
    reg clk, rst;
    reg start_lu;
    wire lu_done;
    localparam SF = 16777216.0; 

    reg signed [31:0] h [0:14];
    reg signed [31:0] A [0:4][0:4];        // NEW: Original Matrix A storage
    reg signed [31:0] Ainv_storage [0:4][0:4];
    wire signed [31:0] Ainv_wire [0:4][0:4];
    reg signed [31:0] sA0, sA1, sA2, sA3, sA4;
    reg signed [31:0] sB0, sB1, sB2, sB3, sB4;
    wire signed [31:0] sC [0:4][0:4];
    reg signed [31:0] final_w0, final_w1, final_w2, final_w3, final_w4;

    // --- NEW EQUALIZER SIGNALS ---
    reg eq_enable;
    reg signed [31:0] eq_data_in;
    wire signed [31:0] eq_data_out;
    wire eq_valid_out;

    function signed [31:0] encode; input real v;
        encode = $rtoi(v * SF + (v>=0 ? 0.5 : -0.5)); 
    endfunction
    
    function real decode;
        input signed [31:0] v; 
        decode = $itor(v) / SF; 
    endfunction

    // ================================================================
    // 2. MODULE INSTANTIATIONS
    // ================================================================

    lu_inverse_5x5_q8_24 lu_dut (
        .clk(clk), .rst(rst), .start(start_lu),
        .A00(h[6]), .A01(h[5]), .A02(h[4]), .A03(h[3]), .A04(h[2]),
        .A10(h[7]), .A11(h[6]), .A12(h[5]), .A13(h[4]), .A14(h[3]),
        .A20(h[8]), .A21(h[7]), .A22(h[6]), .A23(h[5]), .A24(h[4]),
        .A30(h[9]), .A31(h[8]), .A32(h[7]), .A33(h[6]), .A34(h[5]),
        .A40(h[10]),.A41(h[9]), .A42(h[8]), .A43(h[7]), .A44(h[6]),
        .Ainv00(Ainv_wire[0][0]), .Ainv01(Ainv_wire[0][1]), .Ainv02(Ainv_wire[0][2]), 
        .Ainv03(Ainv_wire[0][3]), .Ainv04(Ainv_wire[0][4]),
        .Ainv10(Ainv_wire[1][0]), .Ainv11(Ainv_wire[1][1]), .Ainv12(Ainv_wire[1][2]), 
        .Ainv13(Ainv_wire[1][3]), .Ainv14(Ainv_wire[1][4]),
        .Ainv20(Ainv_wire[2][0]), .Ainv21(Ainv_wire[2][1]), .Ainv22(Ainv_wire[2][2]), 
        .Ainv23(Ainv_wire[2][3]), .Ainv24(Ainv_wire[2][4]),
        .Ainv30(Ainv_wire[3][0]), .Ainv31(Ainv_wire[3][1]), .Ainv32(Ainv_wire[3][2]), 
        .Ainv33(Ainv_wire[3][3]), .Ainv34(Ainv_wire[3][4]),
        .Ainv40(Ainv_wire[4][0]), .Ainv41(Ainv_wire[4][1]), .Ainv42(Ainv_wire[4][2]), 
        .Ainv43(Ainv_wire[4][3]), .Ainv44(Ainv_wire[4][4]),
        .done(lu_done)
    );

    systolic_5x5_q8_24 systolic_dut (
        .clk(clk), .rst(rst),
        .A0(sA0), .A1(sA1), .A2(sA2), .A3(sA3), .A4(sA4),
        .B0(sB0), .B1(sB1), .B2(sB2), .B3(sB3), .B4(sB4),
        .C00(sC[0][0]), .C10(sC[1][0]), .C20(sC[2][0]), .C30(sC[3][0]), .C40(sC[4][0]) 
    );

    equalizer_q8_24 zfe_eq (
        .clk(clk),
        .rst(rst),
        .enable(eq_enable),
        .data_in(eq_data_in),
        .w0(final_w0), .w1(final_w1), .w2(final_w2), .w3(final_w3), .w4(final_w4),
        .data_out(eq_data_out),
        .valid_out(eq_valid_out)
    );

    // ================================================================
    // 3. MAIN TEST SEQUENCE
    // ================================================================
    initial begin 
        clk = 0;
        forever #5 clk = ~clk; 
    end

    integer i, k, r, o;
    integer data_file_in, data_file_out;
    real temp_r;

    // --- Concurrent File Writer Block ---
    initial data_file_out = 0;
    
    always @(posedge clk) begin
        if (eq_valid_out && data_file_out != 0) begin
            $fwrite(data_file_out, "%f\n", decode(eq_data_out));
        end
    end

    initial begin
        rst = 1;
        start_lu = 0;
        eq_enable = 0;
        eq_data_in = 0;
        {sA0, sA1, sA2, sA3, sA4, sB0, sB1, sB2, sB3, sB4} = 0;
        
        #30 rst = 0;

        // Step 1: Load Channel Impulse Response
        data_file_in = $fopen("E:/Verilog/equalizer_4/equalizer_4.srcs/sources_1/new/sampled_effective_u.txt", "r");
        
        if (data_file_in == 0) $finish;
        for (i = 0; i < 15; i = i + 1) begin
            o = $fscanf(data_file_in, "%f\n", temp_r);
            h[i] = encode(temp_r);
        end
        $fclose(data_file_in);

        // ================================================================
        // NEW: Reconstruct and Print Matrix A (Toeplitz structure)
        // ================================================================
        $display("\n--- Original Matrix A (Real Format) ---");
        for (i = 0; i < 5; i = i + 1) begin
            for (k = 0; k < 5; k = k + 1) begin
                A[i][k] = h[6 + i - k];           // Reconstruct Toeplitz matrix from h[]
                $write("%f ", decode(A[i][k]));
            end
            $display("");
        end

        // Step 2: Calculate Matrix Inverse
        #10 start_lu = 1;
        #10 start_lu = 0;
        wait(lu_done == 1);
        #10;

        $display("\n--- Inverse Matrix A^-1 (Real Format) ---");
        for (i = 0; i < 5; i = i + 1) begin
            for (k = 0; k < 5; k = k + 1) begin
                case (i)
                    0: Ainv_storage[0][k] = (k==0)? Ainv_wire[0][0] : (k==1)? Ainv_wire[0][1] :
                                             (k==2)? Ainv_wire[0][2] : (k==3)? Ainv_wire[0][3] : Ainv_wire[0][4];
                    1: Ainv_storage[1][k] = (k==0)? Ainv_wire[1][0] : (k==1)? Ainv_wire[1][1] :
                                             (k==2)? Ainv_wire[1][2] : (k==3)? Ainv_wire[1][3] : Ainv_wire[1][4];
                    2: Ainv_storage[2][k] = (k==0)? Ainv_wire[2][0] : (k==1)? Ainv_wire[2][1] :
                                             (k==2)? Ainv_wire[2][2] : (k==3)? Ainv_wire[2][3] : Ainv_wire[2][4];
                    3: Ainv_storage[3][k] = (k==0)? Ainv_wire[3][0] : (k==1)? Ainv_wire[3][1] :
                                             (k==2)? Ainv_wire[3][2] : (k==3)? Ainv_wire[3][3] : Ainv_wire[3][4];
                    4: Ainv_storage[4][k] = (k==0)? Ainv_wire[4][0] : (k==1)? Ainv_wire[4][1] :
                                             (k==2)? Ainv_wire[4][2] : (k==3)? Ainv_wire[4][3] : Ainv_wire[4][4];
                endcase
            end
            $display("%f %f %f %f %f", 
                     decode(Ainv_storage[i][0]), decode(Ainv_storage[i][1]), 
                     decode(Ainv_storage[i][2]), decode(Ainv_storage[i][3]), 
                     decode(Ainv_storage[i][4]));
        end

        // Step 3: Systolic Weight Calculation
        $display("\nStarting Systolic Pulse for Weights...");
        for (k = 0; k < 20; k = k + 1) begin
            sA0 <= (k >= 0 && k < 5) ? Ainv_storage[0][k] : 0;
            sA1 <= (k >= 1 && k < 6) ? Ainv_storage[1][k-1] : 0;
            sA2 <= (k >= 2 && k < 7) ? Ainv_storage[2][k-2] : 0;
            sA3 <= (k >= 3 && k < 8) ? Ainv_storage[3][k-3] : 0;
            sA4 <= (k >= 4 && k < 9) ? Ainv_storage[4][k-4] : 0;
            sB0 <= (k == 0) ? encode(1.0) : 0; 
            sB1 <= 0; sB2 <= 0; sB3 <= 0; sB4 <= 0;
            #10;
        end
        {sA0, sA1, sA2, sA3, sA4, sB0, sB1, sB2, sB3, sB4} = 0;
        #150; 

        // Step 4: Extract and Store Weights
        final_w0 = sC[0][0];
        final_w1 = sC[1][0]; 
        final_w2 = sC[2][0];
        final_w3 = sC[3][0]; 
        final_w4 = sC[4][0];

        $display("\n--- Calculated ZFE Weights (Real Format) ---");
        $display("w0: %f, w1: %f, w2: %f, w3: %f, w4: %f", 
                 decode(final_w0), decode(final_w1), decode(final_w2), 
                 decode(final_w3), decode(final_w4));
        
        // ================================================================
        // NEW STEP: Hardware Orchestration (Streaming)
        // ================================================================
        $display("\nStarting Hardware Equalization Stream...");
        
        data_file_in = $fopen("E:/Verilog/equalizer_4/equalizer_4.srcs/sources_1/new/rxfilter_response.txt", "r");
        data_file_out = $fopen("E:/Verilog/equalizer_4/equalizer_4.srcs/sources_1/new/equalizer_response.txt", "w");

        if (data_file_in == 0 || data_file_out == 0) begin
            $display("ERROR: Could not open streaming files.");
            $finish;
        end

        @(posedge clk);
        
        while (!$feof(data_file_in)) begin
            r = $fscanf(data_file_in, "%f\n", temp_r);
            if (r == 1) begin
                eq_data_in <= encode(temp_r);
                eq_enable  <= 1'b1;
                @(posedge clk);
            end
        end

        // Flush pipeline
        eq_data_in <= 0;
        for (i = 0; i < 400; i = i + 1) begin
            @(posedge clk);
        end
        
        eq_enable <= 1'b0;
        repeat(5) @(posedge clk);
        
        $fclose(data_file_in);
        $fclose(data_file_out);
        $display("Equalization Complete. All data processed and output written.");

        $finish;
    end
endmodule