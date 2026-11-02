`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2026 06:26:34 PM
// Design Name: 
// Module Name: tb_uart_top
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


// Loopback test of the full top level: tx_pin is jumpered to rx_pin, exactly
// like the on-board self test. Uses a slow fake clock so frames are short.
module tb_uart_top;
    // CLK_HZ chosen so BAUD_DIV = 64 and OS_DIV = 4 (exactly 16x)
    localparam CLK_HZ = 9600 * 64;

    reg        clk = 0, btnC = 0, btnU = 1;
    reg  [7:0] sw = 8'h00;
    wire [7:0] led;
    wire       tx_pin;

    integer errors = 0, tests = 0;

    always #5 clk = ~clk;

    uart_top #(.CLK_HZ(CLK_HZ), .BAUD(9600), .DEBOUNCE(8)) dut(
        .clk(clk), .sw(sw), .btnC(btnC), .btnU(btnU), .rx_pin(tx_pin),
        .led(led), .tx_pin(tx_pin)
    );

    localparam FRAME = 64 * 12;   // a bit more than one frame in clocks

    task press_send;
        begin
            btnC = 1; repeat (20) @(posedge clk);
            btnC = 0; repeat (20) @(posedge clk);
        end
    endtask

    task check(input [7:0] exp, input [8*40-1:0] msg);
        begin
            tests = tests + 1;
            if (led !== exp) begin
                errors = errors + 1;
                $display("FAIL %0s: led=%h expected %h", msg, led, exp);
            end else
                $display("PASS %0s (led=%h)", msg, led);
        end
    endtask

    initial begin
        repeat (10) @(posedge clk); btnU = 0;
        repeat (10) @(posedge clk);
        check(8'h00, "LEDs off after reset");

        sw = 8'hA5; press_send; repeat (FRAME) @(posedge clk);
        check(8'hA5, "loopback A5");

        sw = 8'h3C; press_send; repeat (FRAME) @(posedge clk);
        check(8'h3C, "loopback 3C");

        // Bouncy button: chatter shorter than the debounce window sends one byte
        sw = 8'h81;
        repeat (3) begin btnC = 1; repeat (3) @(posedge clk); btnC = 0; repeat (3) @(posedge clk); end
        press_send; repeat (FRAME) @(posedge clk);
        check(8'h81, "bouncy button");

        // Reset mid-transmission: LEDs clear, transmission cancelled
        sw = 8'h00; press_send; repeat (64 * 3) @(posedge clk);
        btnU = 1; repeat (10) @(posedge clk);
        check(8'h00, "reset clears LEDs");
        tests = tests + 1;
        if (tx_pin !== 1'b1) begin errors = errors + 1; $display("FAIL tx not idle in reset"); end
        else $display("PASS tx line idle during reset");
        btnU = 0; repeat (FRAME) @(posedge clk);
        check(8'h00, "cancelled frame not received");

        sw = 8'h7E; press_send; repeat (FRAME) @(posedge clk);
        check(8'h7E, "loopback after reset");

        $display("tb_uart_top: %0d/%0d tests passed", tests - errors, tests);
        $finish;
    end
endmodule

