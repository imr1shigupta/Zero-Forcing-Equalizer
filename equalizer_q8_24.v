`timescale 1ns/1ps

module equalizer_q8_24 (
    input  wire               clk,
    input  wire               rst,
    input  wire               enable,
    input  wire signed [31:0] data_in,   // Q8.24
    input  wire signed [31:0] w0,        // Q8.24 
    input  wire signed [31:0] w1,        // Q8.24 
    input  wire signed [31:0] w2,        // Q8.24 
    input  wire signed [31:0] w3,        // Q8.24 
    input  wire signed [31:0] w4,        // Q8.24 
    output reg  signed [31:0] data_out,  // Q8.24
    output reg                valid_out  
);

    // =========================================================================
    // 1. CIRCULAR BUFFER (Distributed RAM)
    // =========================================================================
    (* ram_style = "distributed" *) 
    reg signed [31:0] ram [0:511];
    reg [8:0] wr_ptr;

    wire [8:0] addr1 = wr_ptr - 9'd100;
    wire [8:0] addr2 = wr_ptr - 9'd200;
    wire [8:0] addr3 = wr_ptr - 9'd300;
    wire [8:0] addr4 = wr_ptr - 9'd400;

    // Pipeline Stage 1: Memory Read
    reg signed [31:0] tap0, tap1, tap2, tap3, tap4;
    reg en_stg1;

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr  <= 9'd0;
            en_stg1 <= 1'b0;
            tap0 <= 0; tap1 <= 0; tap2 <= 0; tap3 <= 0; tap4 <= 0;
        end else begin
            en_stg1 <= enable;
            
            if (enable) begin
                ram[wr_ptr] <= data_in;       
                wr_ptr      <= wr_ptr + 9'd1; 
            end
            
            // --- THE FIX IS HERE ---
            // tap0 must use the incoming data directly (Delay = 0)
            tap0 <= data_in;    
            
            // Taps 1-4 read the historical data from RAM
            tap1 <= ram[addr1]; // T-100
            tap2 <= ram[addr2]; // T-200
            tap3 <= ram[addr3]; // T-300
            tap4 <= ram[addr4]; // T-400
        end
    end

    // =========================================================================
    // 2. PIPELINED MULTIPLY-ACCUMULATE (MAC)
    // =========================================================================
    
    wire signed [63:0] prod0 = $signed(w0) * $signed(tap0);
    wire signed [63:0] prod1 = $signed(w1) * $signed(tap1);
    wire signed [63:0] prod2 = $signed(w2) * $signed(tap2);
    wire signed [63:0] prod3 = $signed(w3) * $signed(tap3);
    wire signed [63:0] prod4 = $signed(w4) * $signed(tap4);

    // Stage 2: Multiply and Truncate back to Q8.24
    reg signed [31:0] p0, p1, p2, p3, p4;
    reg en_stg2;

    always @(posedge clk) begin
        if (rst) begin
            en_stg2 <= 1'b0;
            p0 <= 0; p1 <= 0; p2 <= 0; p3 <= 0; p4 <= 0;
        end else begin
            en_stg2 <= en_stg1;
            p0 <= (prod0 >>> 24); 
            p1 <= (prod1 >>> 24);
            p2 <= (prod2 >>> 24);
            p3 <= (prod3 >>> 24);
            p4 <= (prod4 >>> 24);
        end
    end

    // Stage 3: Adder Tree Level 1
    reg signed [31:0] sum01, sum23, p4_d1;
    reg en_stg3;

    always @(posedge clk) begin
        if (rst) begin
            en_stg3 <= 1'b0;
            sum01 <= 0; sum23 <= 0; p4_d1 <= 0;
        end else begin
            en_stg3 <= en_stg2;
            sum01 <= p0 + p1;
            sum23 <= p2 + p3;
            p4_d1 <= p4;      
        end
    end

    // Stage 4: Adder Tree Level 2
    reg signed [31:0] sum0123, p4_d2;
    reg en_stg4;

    always @(posedge clk) begin
        if (rst) begin
            en_stg4 <= 1'b0;
            sum0123 <= 0; p4_d2 <= 0;
        end else begin
            en_stg4 <= en_stg3;
            sum0123 <= sum01 + sum23;
            p4_d2   <= p4_d1; 
        end
    end

    // Stage 5: Final Accumulation & Output
    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            data_out  <= 32'sd0;
        end else begin
            valid_out <= en_stg4;
            data_out  <= sum0123 + p4_d2;
        end
    end

endmodule