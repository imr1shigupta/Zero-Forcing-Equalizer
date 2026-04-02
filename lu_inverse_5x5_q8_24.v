`timescale 1ns/1ps

module lu_inverse_5x5_q8_24 (
    input  wire clk,
    input  wire rst,
    input  wire start,

    // -------- Input Matrix A (Q8.24) --------
    input wire signed [31:0] A00, A01, A02, A03, A04,
    input wire signed [31:0] A10, A11, A12, A13, A14,
    input wire signed [31:0] A20, A21, A22, A23, A24,
    input wire signed [31:0] A30, A31, A32, A33, A34,
    input wire signed [31:0] A40, A41, A42, A43, A44,

    // -------- Output Matrix Ainv (Q8.24) --------
    output reg signed [31:0] Ainv00, Ainv01, Ainv02, Ainv03, Ainv04,
    output reg signed [31:0] Ainv10, Ainv11, Ainv12, Ainv13, Ainv14,
    output reg signed [31:0] Ainv20, Ainv21, Ainv22, Ainv23, Ainv24,
    output reg signed [31:0] Ainv30, Ainv31, Ainv32, Ainv33, Ainv34,
    output reg signed [31:0] Ainv40, Ainv41, Ainv42, Ainv43, Ainv44,

    output reg done
);

    // ------------------------------------------------------------
    // Internal storage
    // ------------------------------------------------------------
    reg signed [31:0] L [0:4][0:4];
    reg signed [31:0] U [0:4][0:4];
    reg signed [31:0] Y [0:4][0:4];
    reg signed [31:0] X [0:4][0:4];

    reg signed [63:0] acc;
    reg signed [31:0] recip;

    reg [2:0] k, i, j;

    // ------------------------------------------------------------
    // FSM states
    // ------------------------------------------------------------
    localparam IDLE      = 4'd0,
               LOAD      = 4'd1,
               LU_RECIP  = 4'd2,
               LU_UPDATE = 4'd3,
               FWD_INIT  = 4'd4,
               FWD_ACC   = 4'd5,
               BWD_INIT  = 4'd6,
               BWD_ACC   = 4'd7,
               WRITE     = 4'd8,
               DONE      = 4'd9;

    reg [3:0] state;

    // ------------------------------------------------------------
    // Q8.24 reciprocal (shared divider)
    // Q8.24 format: 1.0 = 16777216 = 2^24
    // ------------------------------------------------------------
    function signed [31:0] q8_24_recip;
        input signed [31:0] x;
        reg signed [63:0] tmp;
        begin
            tmp = (64'sd1 <<< 48) / x;   // Q32.48
            q8_24_recip = tmp[31:0];      // Q8.24
        end
    endfunction

    // ------------------------------------------------------------
    // Sequential FSM
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done  <= 1'b0;

            k <= 3'd0; i <= 3'd0; j <= 3'd0;
            acc <= 56'sd0;
            recip <= 32'sd0;

            // Reset outputs
            Ainv00<=0; Ainv01<=0; Ainv02<=0; Ainv03<=0; Ainv04<=0;
            Ainv10<=0; Ainv11<=0; Ainv12<=0; Ainv13<=0; Ainv14<=0;
            Ainv20<=0; Ainv21<=0; Ainv22<=0; Ainv23<=0; Ainv24<=0;
            Ainv30<=0; Ainv31<=0; Ainv32<=0; Ainv33<=0; Ainv34<=0;
            Ainv40<=0; Ainv41<=0; Ainv42<=0; Ainv43<=0; Ainv44<=0;
        end
        else begin
            case (state)

            // ----------------------------------------------------
            IDLE: begin
                done <= 1'b0;
                if (start) state <= LOAD;
            end

            // ----------------------------------------------------
            // Load U directly from inputs, init L = I
            LOAD: begin
                U[0][0]<=A00; U[0][1]<=A01; U[0][2]<=A02; U[0][3]<=A03; U[0][4]<=A04;
                U[1][0]<=A10; U[1][1]<=A11; U[1][2]<=A12; U[1][3]<=A13; U[1][4]<=A14;
                U[2][0]<=A20; U[2][1]<=A21; U[2][2]<=A22; U[2][3]<=A23; U[2][4]<=A24;
                U[3][0]<=A30; U[3][1]<=A31; U[3][2]<=A32; U[3][3]<=A33; U[3][4]<=A34;
                U[4][0]<=A40; U[4][1]<=A41; U[4][2]<=A42; U[4][3]<=A43; U[4][4]<=A44;

                // Q8.24 format: 1.0 = 16777216 = 2^24
                L[0][0]<=32'sd16777216; L[1][1]<=32'sd16777216; L[2][2]<=32'sd16777216;
                L[3][3]<=32'sd16777216; L[4][4]<=32'sd16777216;

                k <= 3'd0;
                state <= LU_RECIP;
            end

            // ----------------------------------------------------
            LU_RECIP: begin
                recip <= q8_24_recip(U[k][k]);
                i <= k + 1'b1;
                j <= k;
                state <= LU_UPDATE;
            end

            // ----------------------------------------------------
            LU_UPDATE: begin
                if (i < 5) begin
                    // FORCED 64-BIT CAST TO PREVENT TRUNCATION
                    if (j == k)
                        L[i][k] <= ((64'sd0 + U[i][k]) * recip) >>> 24;

                    // FORCED 64-BIT CAST TO PREVENT TRUNCATION
                    U[i][j] <= U[i][j] - (((64'sd0 + L[i][k]) * U[k][j]) >>> 24);

                    if (j < 4)
                        j <= j + 1'b1;
                    else begin
                        j <= k;
                        i <= i + 1'b1;
                    end
                end
                else begin
                    if (k < 4) begin
                        k <= k + 1'b1;
                        state <= LU_RECIP;
                    end
                    else begin
                        i <= 3'd0;
                        j <= 3'd0;
                        state <= FWD_INIT;
                    end
                end
            end

            // ----------------------------------------------------
            FWD_INIT: begin
                // Q8.24 format: 1.0 = 16777216 = 2^24
                acc <= (i == j) ? (56'sd1 <<< 24) : 56'sd0;
                k   <= 3'd0;
                state <= FWD_ACC;
            end

            FWD_ACC: begin
                if (k < i) begin
                    // FORCED 64-BIT CAST TO PREVENT TRUNCATION
                    acc <= acc - (((64'sd0 + L[i][k]) * Y[k][j]) >>> 24);
                    k <= k + 1'b1;
                end
                else begin
                    Y[i][j] <= acc[31:0];
                    if (j < 4)
                        j <= j + 1'b1;
                    else begin
                        j <= 3'd0;
                        i <= i + 1'b1;
                    end

                    if (i == 4 && j == 4) begin
                        i <= 3'd4;
                        j <= 3'd4;
                        state <= BWD_INIT;
                    end
                    else state <= FWD_INIT;
                end
            end

            // ----------------------------------------------------
            BWD_INIT: begin
                acc <= Y[i][j];
                k <= i + 1'b1;
                state <= BWD_ACC;
            end

            BWD_ACC: begin
                if (k < 5) begin
                    // FORCED 64-BIT CAST TO PREVENT TRUNCATION
                    acc <= acc - (((64'sd0 + U[i][k]) * X[k][j]) >>> 24);
                    k <= k + 1'b1;
                end
                else begin
                    // FORCED 64-BIT CAST TO PREVENT TRUNCATION
                    X[i][j] <= ((64'sd0 + acc) * q8_24_recip(U[i][i])) >>> 24;

                    if (j > 0)
                        j <= j - 1'b1;
                    else begin
                        j <= 3'd4;
                        i <= i - 1'b1;
                    end

                    if (i == 0 && j == 0)
                        state <= WRITE;
                    else
                        state <= BWD_INIT;
                end
            end

            // ----------------------------------------------------
            WRITE: begin
                Ainv00<=X[0][0]; Ainv01<=X[0][1]; Ainv02<=X[0][2]; Ainv03<=X[0][3]; Ainv04<=X[0][4];
                Ainv10<=X[1][0]; Ainv11<=X[1][1]; Ainv12<=X[1][2]; Ainv13<=X[1][3]; Ainv14<=X[1][4];
                Ainv20<=X[2][0]; Ainv21<=X[2][1]; Ainv22<=X[2][2]; Ainv23<=X[2][3]; Ainv24<=X[2][4];
                Ainv30<=X[3][0]; Ainv31<=X[3][1]; Ainv32<=X[3][2]; Ainv33<=X[3][3]; Ainv34<=X[3][4];
                Ainv40<=X[4][0]; Ainv41<=X[4][1]; Ainv42<=X[4][2]; Ainv43<=X[4][3]; Ainv44<=X[4][4];
                state <= DONE;
            end

            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;

            endcase
        end
    end

endmodule