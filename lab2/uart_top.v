`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2026 06:25:36 PM
// Design Name: 
// Module Name: uart_top
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


// Lab 2 top level: Basys3 GPIO UART (8N1, 9600 baud).
//   sw[7:0]  -> byte to transmit
//   btnC     -> send the byte on the switches
//   btnU     -> reset (clears LEDs, cancels any transmission)
//   led[7:0] <- last byte received
//   tx_pin   -> JA1, rx_pin <- JA2
module uart_top #(
    parameter CLK_HZ   = 100_000_000,
    parameter BAUD     = 9600,
    parameter DEBOUNCE = 1_000_000
)(
    input  wire       clk,
    input  wire [7:0] sw,
    input  wire       btnC,
    input  wire       btnU,
    input  wire       rx_pin,

    output wire [7:0] led,
    output wire       tx_pin
);
    localparam BAUD_DIV = (CLK_HZ + BAUD / 2) / BAUD;              // 10417
    localparam OS_DIV   = (CLK_HZ + BAUD * 8) / (BAUD * 16);       // 651

    // Synchronize the reset button
    reg rst_meta, rst;
    always @(posedge clk) begin
        rst_meta <= btnU;
        rst      <= rst_meta;
    end

    wire send_level, send_pulse;
    debounce #(.STABLE_CLKS(DEBOUNCE)) u_send_btn(
        .clk(clk), .rst(rst), .btn(btnC), .level(send_level), .press(send_pulse)
    );

    wire baud_tick, os_tick;
    clk_div #(.DIVISOR(BAUD_DIV)) u_baud_div(.clk(clk), .rst(rst), .tick(baud_tick));
    clk_div #(.DIVISOR(OS_DIV))   u_os_div  (.clk(clk), .rst(rst), .tick(os_tick));

    wire tx_busy;
    tx u_tx(
        .clk(clk), .rst(rst), .baud_tick(baud_tick),
        .data(sw), .send(send_pulse),
        .tx_line(tx_pin), .busy(tx_busy)
    );

    wire rx_valid, rx_frame_err;
    rx u_rx(
        .clk(clk), .rst(rst), .os_tick(os_tick), .rx_line(rx_pin),
        .data(led), .valid(rx_valid), .frame_err(rx_frame_err)
    );
endmodule
