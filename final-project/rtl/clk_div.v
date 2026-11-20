`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2026 06:15:17 PM
// Design Name: 
// Module Name: clk_div
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


module clk_div #(
    parameter DIVISOR = 10417
)(
    input  wire clk,
    input  wire rst,
    output reg  tick
);
    localparam W = (DIVISOR > 1) ? $clog2(DIVISOR) : 1;

    reg [W-1:0] count;

    always @(posedge clk) begin
        if (rst) begin
            count <= 0;
            tick  <= 1'b0;
        end else if (count == DIVISOR - 1) begin
            count <= 0;
            tick  <= 1'b1;
        end else begin
            count <= count + 1'b1;
            tick  <= 1'b0;
        end
    end
endmodule
