`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 11:44:32 AM
// Design Name: 
// Module Name: 4bitmux
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


module mux4bit(
    input wire[15:0] A,
    input wire[15:0] B,
    input wire[15:0] C,
    input wire[15:0] D,
    input wire  S0,
    input wire  S1,
    output wire [15:0] Q
    );
    
    wire [15:0] Q1, Q2; 
    
    mux2bit m1 (.A(A),  .B(B),  .S(S0), .Q(Q1));
    mux2bit m2 (.A(C),  .B(D),  .S(S0), .Q(Q2));
    mux2bit m3 (.A(Q1), .B(Q2), .S(S1), .Q(Q)); 
    
endmodule
