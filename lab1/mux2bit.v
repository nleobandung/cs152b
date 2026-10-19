`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 11:44:32 AM
// Design Name: 
// Module Name: 2bitmux
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


module mux2bit(
    input  wire[15:0] A,
    input wire[15:0] B,
    input wire  S,
    output wire [15:0]Q
    );
    wire Snot;
    wire[15:0] Q1,Q2;
    
    not(Snot, S);
    and a0 [15:0] (Q1, A, Snot);
        
    // Verilog automatically applies the scalar 'S' to every bit of 'B'
    and a1 [15:0] (Q2, B, S);

    // 3. Final OR gate to combine the 16-bit results
    or  o1 [15:0] (Q, Q1, Q2);

endmodule
