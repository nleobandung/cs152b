`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 11:44:32 AM
// Design Name: 
// Module Name: 16bitmux
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


module mux16bit(
    input wire [15:0] A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P,
    input wire S0,S1,S2,S3,
    
    output wire [15:0] Q
    );
    wire [15:0] Q1, Q2, Q3, Q4;
    mux4bit m1 (.A(A), .B(B), .C(C), .D(D), .S0(S0), .S1(S1), .Q(Q1));
    mux4bit m2 (.A(E), .B(F), .C(G), .D(H), .S0(S0), .S1(S1), .Q(Q2));
    mux4bit m3 (.A(I), .B(J), .C(K), .D(L), .S0(S0), .S1(S1), .Q(Q3));
    mux4bit m4 (.A(M), .B(N), .C(O), .D(P), .S0(S0), .S1(S1), .Q(Q4));

    // Second Stage: Use S2 and S3 to pick the final winner from the 4 results
    mux4bit m_final (.A(Q1), .B(Q2), .C(Q3), .D(Q4), .S0(S2), .S1(S3), .Q(Q));
endmodule
