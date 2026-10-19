`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 11:13:01 AM
// Design Name: 
// Module Name: addition
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


// S = A + B (signed)
module addition(
    input wire[15:0] A,
    input wire[15:0] B,
    output wire overflow,
    output wire[15:0] S
    );

    adder16 u_add(.A(A), .B(B), .Cin(1'b0), .overflow(overflow), .S(S));
endmodule
