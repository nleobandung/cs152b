`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/14/2026 10:32:53 AM
// Design Name: 
// Module Name: logical_shift_L
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// S = A << B, zero-filled. Shift amounts >= 16 give 0.
module logical_shift_L(
    input wire[15:0] A,
    input wire[15:0] B,
    output wire[15:0] S
    );
    wire big_shift;
    wire[15:0] mux_output;

    // any of B[15:4] set means shift >= 16
    or_reduce16 u_big(.A({4'b0000, B[15:4]}), .Y(big_shift));

    mux16bit u_mux(
               .A(A),                    .B({A[14:0], 1'b0}),
               .C({A[13:0], 2'b0}),      .D({A[12:0], 3'b0}),
               .E({A[11:0], 4'b0}),      .F({A[10:0], 5'b0}),
               .G({A[9:0], 6'b0}),       .H({A[8:0], 7'b0}),
               .I({A[7:0], 8'b0}),       .J({A[6:0], 9'b0}),
               .K({A[5:0], 10'b0}),      .L({A[4:0], 11'b0}),
               .M({A[3:0], 12'b0}),      .N({A[2:0], 13'b0}),
               .O({A[1:0], 14'b0}),      .P({A[0], 15'b0}),
               .S0(B[0]), .S1(B[1]), .S2(B[2]), .S3(B[3]),
               .Q(mux_output)
    );
    mux2bit u_2mux(.A(mux_output), .B(16'h0000), .S(big_shift), .Q(S));
endmodule
