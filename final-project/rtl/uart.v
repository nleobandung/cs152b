`timescale 1ns / 1ps

// UART with RX and TX FIFOs and valid/ready byte streams.
// This is the interface the SLIP layer will connect to.
//
//   RX stream (out): rx_data is valid while rx_valid; a byte is consumed on
//                    any cycle where rx_valid && rx_ready.
//   TX stream (in):  a byte is accepted on any cycle where tx_valid && tx_ready.
//
//   rx_overflow  pulses when a byte arrives and the RX FIFO is full (byte lost).
//   rx_frame_err pulses on a bad stop bit.
module uart #(
    parameter CLK_HZ        = 100_000_000,
    parameter BAUD          = 115_200,
    parameter RX_FIFO_DEPTH = 64,
    parameter TX_FIFO_DEPTH = 64
)(
    input  wire       clk,
    input  wire       rst,

    input  wire       rx_pin,
    output wire       tx_pin,

    output wire [7:0] rx_data,
    output wire       rx_valid,
    input  wire       rx_ready,

    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output wire       tx_ready,

    output wire       rx_overflow,
    output wire       rx_frame_err
);
    localparam CLKS_PER_BIT = (CLK_HZ + BAUD / 2) / BAUD;              // 868
    localparam OS_DIV       = (CLK_HZ + BAUD * 8) / (BAUD * 16);       // 54

    // ---------------- RX ----------------
    wire       os_tick;
    wire [7:0] rx_byte;
    wire       rx_byte_valid;
    wire       rx_full, rx_empty;

    clk_div #(.DIVISOR(OS_DIV)) u_os_div(.clk(clk), .rst(rst), .tick(os_tick));

    uart_rx u_rx(
        .clk(clk), .rst(rst), .os_tick(os_tick), .rx_line(rx_pin),
        .data(rx_byte), .valid(rx_byte_valid), .frame_err(rx_frame_err)
    );

    fifo #(.WIDTH(8), .DEPTH(RX_FIFO_DEPTH)) u_rx_fifo(
        .clk(clk), .rst(rst),
        .wr_data(rx_byte), .wr_en(rx_byte_valid), .full(rx_full),
        .rd_data(rx_data), .rd_en(rx_valid && rx_ready), .empty(rx_empty)
    );

    assign rx_valid    = !rx_empty;
    assign rx_overflow = rx_byte_valid && rx_full;

    // ---------------- TX ----------------
    wire [7:0] tx_byte;
    wire       tx_full, tx_empty, tx_busy;
    wire       tx_send = !tx_empty && !tx_busy;

    fifo #(.WIDTH(8), .DEPTH(TX_FIFO_DEPTH)) u_tx_fifo(
        .clk(clk), .rst(rst),
        .wr_data(tx_data), .wr_en(tx_valid), .full(tx_full),
        .rd_data(tx_byte), .rd_en(tx_send), .empty(tx_empty)
    );

    assign tx_ready = !tx_full;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx(
        .clk(clk), .rst(rst), .data(tx_byte), .send(tx_send),
        .tx_line(tx_pin), .busy(tx_busy)
    );
endmodule
