`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/14/2026 10:37:33 AM
// Design Name: 
// Module Name: invert
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


// Two's complement invert: S = -A = ~A + 1
// overflow is raised only for A = INT_MIN (16'h8000)
module invert(
    input wire[15:0] A,
    output wire overflow,
    output wire[15:0] S
    );
    wire[15:0] A_not;

    not n1 [15:0] (A_not, A);
    adder16 u_add(.A(A_not), .B(16'h0000), .Cin(1'b1), .overflow(overflow), .S(S));
endmodule
