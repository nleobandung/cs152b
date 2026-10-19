`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/14/2026 10:32:53 AM
// Design Name: 
// Module Name: set_less_equal
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


// S = 1 if A <= B (signed), else 0
// A < B  <=>  sign(A - B) xor overflow(A - B)
// A == B <=>  (A - B) == 0
module set_less_equal(
    input wire[15:0] A,
    input wire[15:0] B,
    output wire S
    );
    wire[15:0] diff;
    wire diff_ov, less, equal;

    subtraction u_sub(.A(A), .B(B), .overflow(diff_ov), .S(diff));
    xor x1(less, diff[15], diff_ov);
    zero_detect u_zero(.A(diff), .zero(equal));
    or o1(S, less, equal);
endmodule
