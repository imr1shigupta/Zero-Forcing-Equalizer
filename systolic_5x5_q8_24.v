// =================================================================
// Systolic Array 5x5 Matrix Multiplier for Q8.24 Fixed-Point
// Implements dataflow for Matrix Multiplication with Q8.24 format
// =================================================================
`timescale 1ns/1ps
module systolic_5x5_q8_24 (
    input wire clk,
    input wire rst,

    // Inputs for A (Rows injected from left)
    input wire signed [31:0] A0, A1, A2, A3, A4,
    // Inputs for B (Columns injected from top)
    input wire signed [31:0] B0, B1, B2, B3, B4,

    // Output Result Matrix C
    output wire signed [31:0] C00, C01, C02, C03, C04,
    output wire signed [31:0] C10, C11, C12, C13, C14,
    output wire signed [31:0] C20, C21, C22, C23, C24,
    output wire signed [31:0] C30, C31, C32, C33, C34,
    output wire signed [31:0] C40, C41, C42, C43, C44
);

    // Registered pipelines for A and B data movement
    reg signed [31:0] A_pipe [0:4][0:4];
    reg signed [31:0] B_pipe [0:4][0:4];

    // Combinational wires for PE results
    wire signed [31:0] acc [0:4][0:4];

    integer i, j;

    // -------------------------------------------------------------
    // Pipeline Registers Logic (Sequential)
    // -------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    A_pipe[i][j] <= 32'sd0;
                    B_pipe[i][j] <= 32'sd0;
                end
            end
        end else begin
            // 1. Handle Injection and Shifting for A (Horizontal)
            A_pipe[0][0] <= A0;
            A_pipe[1][0] <= A1;
            A_pipe[2][0] <= A2;
            A_pipe[3][0] <= A3;
            A_pipe[4][0] <= A4;

            for (i = 0; i < 5; i = i + 1) begin
                for (j = 1; j < 5; j = j + 1) begin
                    A_pipe[i][j] <= A_pipe[i][j-1];
                end
            end

            // 2. Handle Injection and Shifting for B (Vertical)
            B_pipe[0][0] <= B0;
            B_pipe[0][1] <= B1;
            B_pipe[0][2] <= B2;
            B_pipe[0][3] <= B3;
            B_pipe[0][4] <= B4;

            for (i = 1; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    B_pipe[i][j] <= B_pipe[i-1][j];
                end
            end
        end
    end

    // -------------------------------------------------------------
    // PE Grid Instantiation (Structural)
    // Instantiates 25 PE cells (pe_q8_24)
    // -------------------------------------------------------------
    genvar r, c;
    generate
        for (r = 0; r < 5; r = r + 1) begin : ROW
            for (c = 0; c < 5; c = c + 1) begin : COL
                pe_q8_24 PE_inst (
                    .clk (clk),
                    .rst (rst),
                    .a_in(A_pipe[r][c]),
                    .b_in(B_pipe[r][c]),
                    .acc (acc[r][c])
                );
            end
        end
    endgenerate

    // -------------------------------------------------------------
    // Output Mapping (Continuous Assignment)
    // Maps PE accumulator results to output ports
    // -------------------------------------------------------------
    assign C00 = acc[0][0]; assign C01 = acc[0][1]; assign C02 = acc[0][2]; assign C03 = acc[0][3]; assign C04 = acc[0][4];
    assign C10 = acc[1][0]; assign C11 = acc[1][1]; assign C12 = acc[1][2]; assign C13 = acc[1][3]; assign C14 = acc[1][4];
    assign C20 = acc[2][0]; assign C21 = acc[2][1]; assign C22 = acc[2][2]; assign C23 = acc[2][3]; assign C24 = acc[2][4];
    assign C30 = acc[3][0]; assign C31 = acc[3][1]; assign C32 = acc[3][2]; assign C33 = acc[3][3]; assign C34 = acc[3][4];
    assign C40 = acc[4][0]; assign C41 = acc[4][1]; assign C42 = acc[4][2]; assign C43 = acc[4][3]; assign C44 = acc[4][4];

endmodule
