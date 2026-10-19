`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 11:11:17 AM
// Design Name: 
// Module Name: full_adder
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


// 1-bit full adder built from gates
module full_adder(
    input wire a,
    input wire b,
    input wire cin,
    output wire s,
    output wire cout
    );
    wire axb, ab, c_axb;

    xor x1(axb, a, b);
    xor x2(s, axb, cin);
    and a1(ab, a, b);
    and a2(c_axb, cin, axb);
    or  o1(cout, ab, c_axb);
endmodule
