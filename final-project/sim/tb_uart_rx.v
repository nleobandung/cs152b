`timescale 1ns / 1ps

// Testbench for rx: drives serial frames onto rx_line and checks the
// parallelized byte, plus edge cases (bad stop bit, glitches, wrong frame
// length, break, reset mid-frame, baud mismatch).
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2026 06:14:05 PM
// Design Name: 
// Module Name: tb_rx
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


module tb_uart_rx;
    localparam OS_DIV = 2;              // clocks per oversample tick
    localparam BIT    = 16 * OS_DIV;    // clocks per bit

    reg        clk = 0, rst = 1, rx_line = 1;
    wire       os_tick;
    wire [7:0] data;
    wire       valid, frame_err;

    integer errors = 0, tests = 0;
    integer n_valid = 0, n_err = 0;

    always #5 clk = ~clk;

    clk_div #(.DIVISOR(OS_DIV)) u_div(.clk(clk), .rst(rst), .tick(os_tick));
    uart_rx dut(.clk(clk), .rst(rst), .os_tick(os_tick), .rx_line(rx_line),
           .data(data), .valid(valid), .frame_err(frame_err));

    always @(posedge clk) begin
        if (valid)     n_valid = n_valid + 1;
        if (frame_err) n_err   = n_err + 1;
    end

    // Drive one frame: start bit, nbits data bits (LSB first), stop bit.
    // bit_len lets us test a transmitter whose baud rate is slightly off.
    task send_frame(input [15:0] bits, input integer nbits, input stop, input integer bit_len);
        integer i;
        begin
            rx_line = 0; repeat (bit_len) @(posedge clk);
            for (i = 0; i < nbits; i = i + 1) begin
                rx_line = bits[i]; repeat (bit_len) @(posedge clk);
            end
            rx_line = stop; repeat (bit_len) @(posedge clk);
            rx_line = 1;    repeat (2 * BIT) @(posedge clk);   // idle gap
        end
    endtask

    task check(input [7:0] exp_data, input integer exp_valid, input integer exp_err,
               input [8*40-1:0] msg);
        begin
            tests = tests + 1;
            if (data !== exp_data || n_valid !== exp_valid || n_err !== exp_err) begin
                errors = errors + 1;
                $display("FAIL %0s: data=%h valid#=%0d err#=%0d | expected data=%h valid#=%0d err#=%0d",
                         msg, data, n_valid, n_err, exp_data, exp_valid, exp_err);
            end else
                $display("PASS %0s (data=%h)", msg, data);
            n_valid = 0; n_err = 0;
        end
    endtask

    initial begin
        repeat (3) @(negedge clk); rst = 0;
        repeat (BIT) @(posedge clk);
        check(8'h00, 0, 0, "idle after reset");

        // Basic frames
        send_frame(8'hA5, 8, 1, BIT); check(8'hA5, 1, 0, "frame A5");
        send_frame(8'h00, 8, 1, BIT); check(8'h00, 1, 0, "frame 00");
        send_frame(8'hFF, 8, 1, BIT); check(8'hFF, 1, 0, "frame FF");
        send_frame(8'h61, 8, 1, BIT); check(8'h61, 1, 0, "frame 61 ('a')");

        // Invalid stop bit: byte is discarded, previous data kept
        send_frame(8'h3C, 8, 0, BIT); check(8'h61, 0, 1, "bad stop bit rejected");
        send_frame(8'h3C, 8, 1, BIT); check(8'h3C, 1, 0, "recovers after bad stop");

        // Glitch on idle line shorter than half a bit: not a start bit
        rx_line = 0; repeat (BIT / 4) @(posedge clk); rx_line = 1;
        repeat (2 * BIT) @(posedge clk);
        check(8'h3C, 0, 0, "short glitch ignored");

        // Frame longer than 8 bits (9th bit is 0, lands on stop position)
        send_frame(16'h0055, 9, 1, BIT); check(8'h3C, 0, 1, "9-bit frame rejected");
        send_frame(8'h96, 8, 1, BIT);    check(8'h96, 1, 0, "recovers after long frame");

        // Frame shorter than 8 bits: missing bits read as idle-high (1).
        // 8N1 can't detect this, so the byte is accepted with high MSBs set.
        send_frame(16'h0015, 7, 1, BIT); check(8'h95, 1, 0, "7-bit frame -> MSB reads 1");

        // Break: line held low for many bit times -> one error, then waits for idle
        rx_line = 0; repeat (25 * BIT) @(posedge clk);
        rx_line = 1; repeat (2 * BIT) @(posedge clk);
        check(8'h95, 0, 1, "break -> single framing error");
        send_frame(8'h42, 8, 1, BIT); check(8'h42, 1, 0, "recovers after break");

        // Reset mid-frame (sender is reset too, as in loopback): data cleared,
        // partial frame dropped
        rx_line = 0; repeat (BIT) @(posedge clk);       // start bit
        rx_line = 1; repeat (3 * BIT) @(posedge clk);   // d0..d2
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        repeat (2 * BIT) @(posedge clk);
        check(8'h00, 0, 0, "reset mid-frame clears data");
        send_frame(8'h0F, 8, 1, BIT); check(8'h0F, 1, 0, "frame after reset");

        // Back-to-back frames with minimum (1 stop bit) gap
        send_frame(8'h11, 8, 1, BIT);
        send_frame(8'h22, 8, 1, BIT); check(8'h22, 2, 0, "back-to-back frames");

        // Baud mismatch tolerance: sender ~3% fast and ~3% slow
        send_frame(8'hC9, 8, 1, BIT - 1); check(8'hC9, 1, 0, "sender 3% fast");
        send_frame(8'h37, 8, 1, BIT + 1); check(8'h37, 1, 0, "sender 3% slow");

        $display("tb_rx: %0d/%0d tests passed", tests - errors, tests);
        $finish;
    end
endmodule

