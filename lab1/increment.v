`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 11:11:17 AM
// Design Name: 
// Module Name: increment
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


// S = A + 1 (signed), overflow when A = 16'h7FFF
module increment(
    input wire[15:0] A,
    output wire overflow,
    output wire[15:0] S
    );

    adder16 u_add(.A(A), .B(16'h0000), .Cin(1'b1), .overflow(overflow), .S(S));
endmodule
