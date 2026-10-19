`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 11:11:17 AM
// Design Name: 
// Module Name: adder16
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


// 16-bit ripple-carry adder: S = A + B + Cin
// overflow = carry into MSB xor carry out of MSB (signed overflow)
module adder16(
    input wire[15:0] A,
    input wire[15:0] B,
    input wire Cin,
    output wire overflow,
    output wire[15:0] S
    );
    wire[15:0] c;

    full_adder fa [15:0] (.a(A), .b(B), .cin({c[14:0], Cin}), .s(S), .cout(c));
    xor x1(overflow, c[14], c[15]);
endmodule
