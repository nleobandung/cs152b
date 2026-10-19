`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 10:34:22 AM
// Design Name: 
// Module Name: zero_detect
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


// zero = 1 iff A == 16'b0
module zero_detect(
    input wire[15:0] A,
    output wire zero
    );
    wire any_one;

    or_reduce16 u_or(.A(A), .Y(any_one));
    not n1(zero, any_one);
endmodule
