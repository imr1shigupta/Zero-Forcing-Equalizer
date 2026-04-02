`timescale 1ns/1ps
module pe_q8_24 (
    input  wire               clk,
    input  wire               rst,

    input  wire signed [31:0] a_in,   // Q8.24
    input  wire signed [31:0] b_in,   // Q8.24

    output wire signed [31:0] acc     // Q8.24
);

    // -----------------------------
    // Internal signals
    // -----------------------------
    wire signed [63:0] mult;          // Q16.48
    wire signed [31:0] mult_q8_24;    // Q8.24

    reg  signed [55:0] acc_r;         // Q32.24 accumulator

    // -----------------------------
    // Multiply
    // -----------------------------
    assign mult = a_in * b_in;

    // Scale Q16.48 → Q8.24
    assign mult_q8_24 = mult >>> 24;

    // -----------------------------
    // Accumulate (signed-safe)
    // -----------------------------
    always @(posedge clk) begin
        if (rst)
            acc_r <= 56'sd0;
        else
            acc_r <= acc_r + $signed({{24{mult_q8_24[31]}}, mult_q8_24});
    end

    // -----------------------------
    // Output truncate to Q8.24
    // -----------------------------
    assign acc = acc_r[31:0];

endmodule
