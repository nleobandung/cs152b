`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/14/2026 10:32:53 AM
// Design Name: 
// Module Name: arithmetic_shift_L
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


// S = A <<< B. Same result as a logical left shift;
// overflow is raised when the shift changes the sign bit.
module arithmetic_shift_L(
    input wire[15:0] A,
    input wire[15:0] B,
    output wire overflow,
    output wire[15:0] S
    );

    logical_shift_L u_shift(.A(A), .B(B), .S(S));
    xor x1(overflow, S[15], A[15]);
endmodule
