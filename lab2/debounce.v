`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2026 06:24:39 PM
// Design Name: 
// Module Name: debounce
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


// Synchronizes and debounces a push button, and emits a one-cycle pulse on press.
// The output only changes after the input has been stable for STABLE_CLKS cycles.
module debounce #(
    parameter STABLE_CLKS = 1_000_000   // 10 ms at 100 MHz
)(
    input  wire clk,
    input  wire rst,
    input  wire btn,

    output reg  level,
    output wire press
);
    localparam W = $clog2(STABLE_CLKS + 1);

    reg         b_meta, b_s;
    reg [W-1:0] count;
    reg         level_d;

    always @(posedge clk) begin
        b_meta <= btn;
        b_s    <= b_meta;
    end

    always @(posedge clk) begin
        if (rst) begin
            count   <= 0;
            level   <= 1'b0;
            level_d <= 1'b0;
        end else begin
            level_d <= level;
            if (b_s == level)
                count <= 0;
            else if (count == STABLE_CLKS - 1) begin
                count <= 0;
                level <= b_s;
            end else
                count <= count + 1'b1;
        end
    end

    assign press = level & ~level_d;
endmodule

