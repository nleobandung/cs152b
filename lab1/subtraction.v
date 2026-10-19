`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 11:11:17 AM
// Design Name: 
// Module Name: subtraction
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


// S = A - B = A + ~B + 1 (signed)
module subtraction(
    input wire[15:0] A,
    input wire[15:0] B,
    output wire overflow,
    output wire[15:0] S
    );
    wire[15:0] B_not;

    not n1 [15:0] (B_not, B);
    adder16 u_add(.A(A), .B(B_not), .Cin(1'b1), .overflow(overflow), .S(S));
endmodule
