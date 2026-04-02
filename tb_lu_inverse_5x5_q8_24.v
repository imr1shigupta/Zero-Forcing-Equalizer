`timescale 1ns/1ps

module tb_lu_inverse_5x5_q8_24;

    // Clock / Reset
    reg clk;
    reg rst;
    reg start;

    initial clk = 0;
    always #5 clk = ~clk;

    // Scaling
    real SF;
    initial SF = 16777216.0;

    // Inputs
    reg signed [31:0] A00, A01, A02, A03, A04;
    reg signed [31:0] A10, A11, A12, A13, A14;
    reg signed [31:0] A20, A21, A22, A23, A24;
    reg signed [31:0] A30, A31, A32, A33, A34;
    reg signed [31:0] A40, A41, A42, A43, A44;

    // Outputs
    wire signed [31:0] Ainv00, Ainv01, Ainv02, Ainv03, Ainv04;
    wire signed [31:0] Ainv10, Ainv11, Ainv12, Ainv13, Ainv14;
    wire signed [31:0] Ainv20, Ainv21, Ainv22, Ainv23, Ainv24;
    wire signed [31:0] Ainv30, Ainv31, Ainv32, Ainv33, Ainv34;
    wire signed [31:0] Ainv40, Ainv41, Ainv42, Ainv43, Ainv44;

    wire done;

    // DUT
    lu_inverse_5x5_q8_24 dut (
        .clk(clk), .rst(rst), .start(start),

        .A00(A00), .A01(A01), .A02(A02), .A03(A03), .A04(A04),
        .A10(A10), .A11(A11), .A12(A12), .A13(A13), .A14(A14),
        .A20(A20), .A21(A21), .A22(A22), .A23(A23), .A24(A24),
        .A30(A30), .A31(A31), .A32(A32), .A33(A33), .A34(A34),
        .A40(A40), .A41(A41), .A42(A42), .A43(A43), .A44(A44),

        .Ainv00(Ainv00), .Ainv01(Ainv01), .Ainv02(Ainv02), .Ainv03(Ainv03), .Ainv04(Ainv04),
        .Ainv10(Ainv10), .Ainv11(Ainv11), .Ainv12(Ainv12), .Ainv13(Ainv13), .Ainv14(Ainv14),
        .Ainv20(Ainv20), .Ainv21(Ainv21), .Ainv22(Ainv22), .Ainv23(Ainv23), .Ainv24(Ainv24),
        .Ainv30(Ainv30), .Ainv31(Ainv31), .Ainv32(Ainv32), .Ainv33(Ainv33), .Ainv34(Ainv34),
        .Ainv40(Ainv40), .Ainv41(Ainv41), .Ainv42(Ainv42), .Ainv43(Ainv43), .Ainv44(Ainv44),

        .done(done)
    );

    // Temp variables
    real A[0:4][0:4];
    real Ainv[0:4][0:4];
    real I[0:4][0:4];

    integer i, j, k;

    initial begin
        rst = 1; start = 0;
        #30; rst = 0;

        // ---------------- INPUT MATRIX ----------------
        A00 = 4.0*SF; A01 = 1.0*SF; A02 = 0.5*SF; A03 = 0.0*SF; A04 = 0.0*SF;
        A10 = 1.0*SF; A11 = 3.0*SF; A12 = 0.0*SF; A13 = 0.5*SF; A14 = 0.0*SF;
        A20 = 0.5*SF; A21 = 0.0*SF; A22 = 2.5*SF; A23 = 0.0*SF; A24 = 0.5*SF;
        A30 = 0.0*SF; A31 = 0.5*SF; A32 = 0.0*SF; A33 = 2.0*SF; A34 = 0.5*SF;
        A40 = 0.0*SF; A41 = 0.0*SF; A42 = 0.5*SF; A43 = 0.5*SF; A44 = 1.5*SF;

        // Convert to real array
        A[0][0]=4.0; A[0][1]=1.0; A[0][2]=0.5; A[0][3]=0.0; A[0][4]=0.0;
        A[1][0]=1.0; A[1][1]=3.0; A[1][2]=0.0; A[1][3]=0.5; A[1][4]=0.0;
        A[2][0]=0.5; A[2][1]=0.0; A[2][2]=2.5; A[2][3]=0.0; A[2][4]=0.5;
        A[3][0]=0.0; A[3][1]=0.5; A[3][2]=0.0; A[3][3]=2.0; A[3][4]=0.5;
        A[4][0]=0.0; A[4][1]=0.0; A[4][2]=0.5; A[4][3]=0.5; A[4][4]=1.5;

        // PRINT INPUT
        $display("\n--- Input Matrix A ---");
        for(i=0;i<5;i=i+1)
            $display("%f %f %f %f %f", A[i][0],A[i][1],A[i][2],A[i][3],A[i][4]);

        // Start
        #10; start = 1;
        #10; start = 0;

        wait(done);

        // Convert inverse to real
        Ainv[0][0]=$itor(Ainv00)/SF; Ainv[0][1]=$itor(Ainv01)/SF; Ainv[0][2]=$itor(Ainv02)/SF; Ainv[0][3]=$itor(Ainv03)/SF; Ainv[0][4]=$itor(Ainv04)/SF;
        Ainv[1][0]=$itor(Ainv10)/SF; Ainv[1][1]=$itor(Ainv11)/SF; Ainv[1][2]=$itor(Ainv12)/SF; Ainv[1][3]=$itor(Ainv13)/SF; Ainv[1][4]=$itor(Ainv14)/SF;
        Ainv[2][0]=$itor(Ainv20)/SF; Ainv[2][1]=$itor(Ainv21)/SF; Ainv[2][2]=$itor(Ainv22)/SF; Ainv[2][3]=$itor(Ainv23)/SF; Ainv[2][4]=$itor(Ainv24)/SF;
        Ainv[3][0]=$itor(Ainv30)/SF; Ainv[3][1]=$itor(Ainv31)/SF; Ainv[3][2]=$itor(Ainv32)/SF; Ainv[3][3]=$itor(Ainv33)/SF; Ainv[3][4]=$itor(Ainv34)/SF;
        Ainv[4][0]=$itor(Ainv40)/SF; Ainv[4][1]=$itor(Ainv41)/SF; Ainv[4][2]=$itor(Ainv42)/SF; Ainv[4][3]=$itor(Ainv43)/SF; Ainv[4][4]=$itor(Ainv44)/SF;

        // PRINT INVERSE
        $display("\n--- Inverse Matrix Ainv ---");
        for(i=0;i<5;i=i+1)
            $display("%f %f %f %f %f", Ainv[i][0],Ainv[i][1],Ainv[i][2],Ainv[i][3],Ainv[i][4]);

        // MATRIX MULTIPLICATION: I = A * Ainv
        for(i=0;i<5;i=i+1)
            for(j=0;j<5;j=j+1) begin
                I[i][j] = 0;
                for(k=0;k<5;k=k+1)
                    I[i][j] = I[i][j] + A[i][k]*Ainv[k][j];
            end

        // PRINT RESULT
        $display("\n--- A * Ainv (Should be Identity) ---");
        for(i=0;i<5;i=i+1)
            $display("%f %f %f %f %f", I[i][0],I[i][1],I[i][2],I[i][3],I[i][4]);

        $finish;
    end

endmodule