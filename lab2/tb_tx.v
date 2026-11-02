`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2026 06:17:32 PM
// Design Name: 
// Module Name: tb_tx
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


module tb_tx;
    localparam BIT = 4;   // clocks per bit (baud divider) to keep frames short

    reg        clk = 0, rst = 1, send = 0;
    reg  [7:0] data = 8'h00;
    wire       baud_tick, tx_line, busy;

    integer errors = 0, tests = 0;

    always #5 clk = ~clk;

    clk_div #(.DIVISOR(BIT)) u_div(.clk(clk), .rst(rst), .tick(baud_tick));
    tx dut(.clk(clk), .rst(rst), .baud_tick(baud_tick), .data(data), .send(send),
           .tx_line(tx_line), .busy(busy));

    task pulse_send(input [7:0] b);
        begin
            @(negedge clk); data = b; send = 1;
            @(negedge clk); send = 0;
        end
    endtask

    // Wait for a start bit, then sample each bit in its middle and compare
    task expect_frame(input [7:0] exp);
        reg [7:0] got;
        reg       start_b, stop_b;
        integer   i, bit_len;
        begin
            @(negedge tx_line);
            repeat (BIT / 2) @(posedge clk);
            start_b = tx_line;
            for (i = 0; i < 8; i = i + 1) begin
                repeat (BIT) @(posedge clk);
                got[i] = tx_line;
            end
            repeat (BIT) @(posedge clk);
            stop_b = tx_line;
            tests = tests + 1;
            if (start_b !== 1'b0 || got !== exp || stop_b !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL frame: start=%b data=%h stop=%b | expected start=0 data=%h stop=1",
                         start_b, got, stop_b, exp);
            end else
                $display("PASS frame %h", exp);
        end
    endtask

    task check(input cond, input [8*48-1:0] msg);
        begin
            tests = tests + 1;
            if (!cond) begin
                errors = errors + 1;
                $display("FAIL %0s", msg);
            end else
                $display("PASS %0s", msg);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        check(tx_line === 1'b1, "line high during reset");
        @(negedge clk); rst = 0;
        repeat (10) @(posedge clk);
        check(tx_line === 1'b1 && !busy, "idle line high, not busy");

        // Basic frames
        fork pulse_send(8'hA5); expect_frame(8'hA5); join
        wait (!busy);
        fork pulse_send(8'h00); expect_frame(8'h00); join
        wait (!busy);
        fork pulse_send(8'hFF); expect_frame(8'hFF); join
        wait (!busy);
        fork pulse_send(8'h61); expect_frame(8'h61); join   // ASCII 'a'
        wait (!busy);

        // Changing data mid-frame must not affect the frame in flight
        fork
            begin
                pulse_send(8'h3C);
                repeat (3 * BIT) @(posedge clk);
                data = 8'hC3;
            end
            expect_frame(8'h3C);
        join
        wait (!busy);

        // Extra send pulses mid-frame are ignored (no second frame follows)
        repeat (2 * BIT) @(posedge clk);
        fork
            begin
                pulse_send(8'h12);
                repeat (4 * BIT) @(posedge clk);
                pulse_send(8'hEE);
            end
            expect_frame(8'h12);
        join
        repeat (4 * BIT) @(posedge clk);
        check(tx_line === 1'b1 && !busy, "send during frame ignored");

        // Reset mid-frame: line returns high immediately and frame is cancelled
        pulse_send(8'h00);
        repeat (5 * BIT) @(posedge clk);
        @(negedge clk); rst = 1;
        @(negedge clk);
        check(tx_line === 1'b1 && !busy, "reset mid-frame -> idle, line high");
        @(negedge clk); rst = 0;
        repeat (12 * BIT) @(posedge clk);
        check(tx_line === 1'b1, "no frame resumes after reset");

        // Works normally after reset
        fork pulse_send(8'h5A); expect_frame(8'h5A); join
        wait (!busy);

        // Back-to-back frames: second send issued as soon as tx is idle
        fork
            begin
                pulse_send(8'h81);
                wait (!busy);
                pulse_send(8'h7E);
            end
            begin
                expect_frame(8'h81);
                expect_frame(8'h7E);
            end
        join

        repeat (4 * BIT) @(posedge clk);
        $display("tb_tx: %0d/%0d tests passed", tests - errors, tests);
        $finish;
    end
endmodule
