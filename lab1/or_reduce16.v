`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 11:44:32 AM
// Design Name: 
// Module Name: or_reduce16
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


// Y = OR of all 16 bits of A (gate tree)
module or_reduce16(
    input wire[15:0] A,
    output wire Y
    );
    wire[7:0] l1;
    wire[3:0] l2;
    wire[1:0] l3;

    or o1 [7:0] (l1, A[15:8], A[7:0]);
    or o2 [3:0] (l2, l1[7:4], l1[3:0]);
    or o3 [1:0] (l3, l2[3:2], l2[1:0]);
    or o4 (Y, l3[1], l3[0]);
endmodule
