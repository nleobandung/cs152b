`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2026 06:12:49 PM
// Design Name: 
// Module Name: uart_rx
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


module uart_rx(
    input  wire       clk,
    input  wire       rst,
    input  wire       os_tick,
    input  wire       rx_line,

    output reg  [7:0] data,
    output reg        valid,
    output reg        frame_err
);
    localparam IDLE      = 4'd0,   // waiting for falling edge
               START     = 4'd1,   // saw falling edge, checking start bit midpoint
               D0        = 4'd2,   // sampling data bit 0 (LSB)
               D1        = 4'd3,
               D2        = 4'd4,
               D3        = 4'd5,
               D4        = 4'd6,
               D5        = 4'd7,
               D6        = 4'd8,
               D7        = 4'd9,   // sampling data bit 7 (MSB)
               STOP      = 4'd10,  // sampling stop bit
               WAIT_IDLE = 4'd11;  // framing error, wait for line to idle

    // Two-flop synchronizer: rx_line is asynchronous to clk
    reg rx_meta, rx_s;
    always @(posedge clk) begin
        if (rst) begin
            rx_meta <= 1'b1;
            rx_s    <= 1'b1;
        end else begin
            rx_meta <= rx_line;
            rx_s    <= rx_meta;
        end
    end

    reg [3:0] state;
    reg [3:0] os_cnt;   // counts oversample ticks within a bit
    reg [7:0] shreg;

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            os_cnt    <= 4'd0;
            shreg     <= 8'h00;
            data      <= 8'h00;
            valid     <= 1'b0;
            frame_err <= 1'b0;
        end else begin
            valid     <= 1'b0;
            frame_err <= 1'b0;

            case (state)
                IDLE: begin
                    os_cnt <= 4'd0;
                    if (!rx_s)
                        state <= START;
                end
                START: if (os_tick) begin
                    if (os_cnt == 4'd7) begin
                        os_cnt <= 4'd0;
                        state  <= rx_s ? IDLE : D0;  // high at midpoint => glitch
                    end else
                        os_cnt <= os_cnt + 1'b1;
                end
                D0, D1, D2, D3, D4, D5, D6, D7: if (os_tick) begin
                    if (os_cnt == 4'd15) begin
                        os_cnt <= 4'd0;
                        shreg  <= {rx_s, shreg[7:1]};  // LSB arrives first
                        state  <= state + 1'b1;
                    end else
                        os_cnt <= os_cnt + 1'b1;
                end
                STOP: if (os_tick) begin
                    if (os_cnt == 4'd15) begin
                        os_cnt <= 4'd0;
                        if (rx_s) begin
                            data  <= shreg;
                            valid <= 1'b1;
                            state <= IDLE;
                        end else begin
                            frame_err <= 1'b1;
                            state     <= WAIT_IDLE;
                        end
                    end else
                        os_cnt <= os_cnt + 1'b1;
                end
                WAIT_IDLE: if (os_tick) begin
                    if (!rx_s)
                        os_cnt <= 4'd0;
                    else if (os_cnt == 4'd15) begin
                        os_cnt <= 4'd0;
                        state  <= IDLE;
                    end else
                        os_cnt <= os_cnt + 1'b1;
                end
                default: begin
                    os_cnt <= 4'd0;
                    state  <= IDLE;
                end
            endcase
        end
    end
endmodule

