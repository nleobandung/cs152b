`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/28/2026 10:51:50 AM
// Design Name: 
// Module Name: counter_4bit
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


module counter_4bit #(parameter integer DIV_LIMIT=26'd49_999_999)(
    input wire clk,
    input wire rst,
    output wire [3:0] count
);
    reg [25:0] clk_div = 0;
    reg clk_1Hz;
    reg [3:0] count_reg;
    
    assign count = count_reg;
    
    always @(posedge clk) begin
        if (rst) begin
            clk_div <= 26'b0;
            clk_1Hz <= 1'b0;
        end else begin
            if (clk_div == DIV_LIMIT) begin
                clk_div <= 26'b0;
                clk_1Hz <= ~clk_1Hz;
            end else begin
                clk_div <= clk_div + 1'b1;
            end
        end   
    end
    
    always @(posedge clk_1Hz or posedge rst) begin
        if (rst) begin
            count_reg <= 4'b0;
        end else begin
            count_reg <= count_reg + 1'b1;
        end
    end
endmodule
