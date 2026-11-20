`timescale 1ns / 1ps

// Milestone 11/20: UART loopback over the Basys3 USB-UART bridge.
// Every byte received from the PC is echoed back.
//
//   btnU      -> reset (also reset automatically at power-up)
//   led[7:0]  <- last byte received
//   led[8]    <- toggles on every byte (activity)
//   led[14]   <- sticky: framing error seen
//   led[15]   <- sticky: RX FIFO overflow seen (byte dropped)
module uart_loopback_top #(
    parameter CLK_HZ = 100_000_000,
    parameter BAUD   = 115_200
)(
    input  wire        clk,
    input  wire        btnU,
    input  wire        RsRx,        // PC -> FPGA
    output wire        RsTx,        // FPGA -> PC
    output wire [15:0] led
);
    // Power-on reset: hold reset for 256 cycles after configuration,
    // then follow the (synchronized) reset button.
    reg [7:0] por_cnt = 0;
    reg       btn_meta = 0, btn_sync = 0;
    reg       rst = 1'b1;

    always @(posedge clk) begin
        btn_meta <= btnU;
        btn_sync <= btn_meta;
        if (por_cnt != 8'hFF)
            por_cnt <= por_cnt + 1'b1;
        rst <= (por_cnt != 8'hFF) || btn_sync;
    end

    wire [7:0] rx_data;
    wire       rx_valid, rx_ready, tx_ready;
    wire       rx_overflow, rx_frame_err;

    uart #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart(
        .clk(clk), .rst(rst),
        .rx_pin(RsRx), .tx_pin(RsTx),
        .rx_data(rx_data), .rx_valid(rx_valid), .rx_ready(rx_ready),
        .tx_data(rx_data), .tx_valid(rx_valid), .tx_ready(tx_ready),
        .rx_overflow(rx_overflow), .rx_frame_err(rx_frame_err)
    );

    // Loopback: RX stream feeds the TX stream directly.
    assign rx_ready = tx_ready;

    // Status LEDs
    reg [7:0] last_byte = 0;
    reg       activity = 0, saw_frame_err = 0, saw_overflow = 0;

    always @(posedge clk) begin
        if (rst) begin
            last_byte     <= 0;
            activity      <= 0;
            saw_frame_err <= 0;
            saw_overflow  <= 0;
        end else begin
            if (rx_valid && rx_ready) begin
                last_byte <= rx_data;
                activity  <= ~activity;
            end
            if (rx_frame_err) saw_frame_err <= 1'b1;
            if (rx_overflow)  saw_overflow  <= 1'b1;
        end
    end

    assign led = {saw_overflow, saw_frame_err, 5'b0, activity, last_byte};
endmodule
