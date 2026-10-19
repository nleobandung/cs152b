`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/14/2026 10:32:53 AM
// Design Name: 
// Module Name: logical_shift_R
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


// S = A >> B, zero-filled. Shift amounts >= 16 give 0.
module logical_shift_R(
    input wire[15:0] A,
    input wire[15:0] B,
    output wire[15:0] S
    );
    wire big_shift;
    wire[15:0] mux_output;

    // any of B[15:4] set means shift >= 16
    or_reduce16 u_big(.A({4'b0000, B[15:4]}), .Y(big_shift));

    mux16bit u_mux(
               .A(A),                    .B({1'b0, A[15:1]}),
               .C({2'b0, A[15:2]}),      .D({3'b0, A[15:3]}),
               .E({4'b0, A[15:4]}),      .F({5'b0, A[15:5]}),
               .G({6'b0, A[15:6]}),      .H({7'b0, A[15:7]}),
               .I({8'b0, A[15:8]}),      .J({9'b0, A[15:9]}),
               .K({10'b0, A[15:10]}),    .L({11'b0, A[15:11]}),
               .M({12'b0, A[15:12]}),    .N({13'b0, A[15:13]}),
               .O({14'b0, A[15:14]}),    .P({15'b0, A[15]}),
               .S0(B[0]), .S1(B[1]), .S2(B[2]), .S3(B[3]),
               .Q(mux_output)
    );
    mux2bit u_2mux(.A(mux_output), .B(16'h0000), .S(big_shift), .Q(S));
endmodule
