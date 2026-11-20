`timescale 1ns / 1ps

// 8N1 UART transmitter.
//
// Changes from lab 2's tx.v:
//   * Owns its bit-period counter instead of using a free-running baud_tick,
//     so the start bit begins on the cycle after `send` (lab 2 waited up to a
//     full bit in LOAD, costing ~9% throughput: 11 bit times per byte).
//     Back-to-back bytes now take 10 bit times + 1 clock.
//   * tx_line initializes high, so the line idles correctly at power-up
//     instead of sitting low (a "break") until the first reset.
//
// Handshake: pulse `send` for one cycle while busy == 0. `data` is latched on
// that cycle. `send` while busy is ignored.
module uart_tx #(
    parameter CLKS_PER_BIT = 868            // 100 MHz / 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data,
    input  wire       send,

    output wire       tx_line,
    output wire       busy
);
    localparam IDLE  = 2'd0,
               START = 2'd1,
               DATA  = 2'd2,
               STOP  = 2'd3;

    localparam CW = $clog2(CLKS_PER_BIT);

    reg [1:0]    state   = IDLE;
    reg [CW-1:0] cnt     = 0;
    reg [2:0]    bit_idx = 0;
    reg [7:0]    shreg   = 0;
    reg          line    = 1'b1;

    assign tx_line = line;
    assign busy    = (state != IDLE);

    wire bit_done = (cnt == CLKS_PER_BIT - 1);

    always @(posedge clk) begin
        if (rst) begin
            state   <= IDLE;
            cnt     <= 0;
            bit_idx <= 0;
            line    <= 1'b1;
        end else begin
            cnt <= bit_done ? 0 : cnt + 1'b1;

            case (state)
                IDLE: begin
                    cnt  <= 0;
                    line <= 1'b1;
                    if (send) begin
                        shreg <= data;
                        line  <= 1'b0;          // start bit begins now
                        state <= START;
                    end
                end
                START: if (bit_done) begin
                    line    <= shreg[0];        // LSB first
                    shreg   <= {1'b0, shreg[7:1]};
                    bit_idx <= 0;
                    state   <= DATA;
                end
                DATA: if (bit_done) begin
                    if (bit_idx == 3'd7) begin
                        line  <= 1'b1;          // stop bit
                        state <= STOP;
                    end else begin
                        line    <= shreg[0];
                        shreg   <= {1'b0, shreg[7:1]};
                        bit_idx <= bit_idx + 1'b1;
                    end
                end
                STOP: if (bit_done) begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
