`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 11:11:17 AM
// Design Name: 
// Module Name: bitwise_and
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


module bitwise_and(
    input wire[15:0] A,
    input wire[15:0] B,
    //input wire[3:0] ALUCtrl,
    //output wire overflow,
    //output wire zero,
    output wire[15:0] S
    );
    
    and a1 [15:0] (S, A, B);
   
    //pulldown p1 (overflow);
      //  pulldown p2 (zero);
    
endmodule

    
