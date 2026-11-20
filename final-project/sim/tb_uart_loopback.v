`timescale 1ns / 1ps

// Testbench for uart_loopback_top at the real clock (100 MHz) and baud (115200).
// The testbench plays the PC: it drives RsRx and decodes RsTx.
//
// Tests:
//   1. RsTx idles high from power-up (no reset button press)
//   2. Single bytes, including SLIP's special bytes 0xC0 / 0xDB
//   3. A long back-to-back burst at the nominal baud rate
//   4. Bursts from a PC clock that is 2% fast and 2% slow
//   5. TX byte spacing: 10 bit times per byte (lab 2's TX took 11)
//   6. No framing errors or overflows flagged on the LEDs
module tb_uart_loopback;
    localparam real BIT_NS = 1.0e9 / 115200.0;     // 8680.56 ns

    reg  clk = 0, btnU = 0, RsRx = 1;
    wire RsTx;
    wire [15:0] led;

    always #5 clk = ~clk;                          // 100 MHz

    uart_loopback_top dut(.clk(clk), .btnU(btnU), .RsRx(RsRx), .RsTx(RsTx), .led(led));

    integer errors = 0, tests = 0;

    task check(input cond, input [8*64-1:0] name);
        begin
            tests = tests + 1;
            if (cond) $display("PASS %0s", name);
            else begin errors = errors + 1; $display("FAIL %0s", name); end
        end
    endtask

    // ---------------- PC transmitter ----------------
    task pc_send(input [7:0] b, input real bit_ns);
        integer i;
        begin
            RsRx = 0; #(bit_ns);
            for (i = 0; i < 8; i = i + 1) begin RsRx = b[i]; #(bit_ns); end
            RsRx = 1; #(bit_ns);
        end
    endtask

    // ---------------- PC receiver (monitor) ----------------
    reg [7:0] got [0:1023];
    real      start_time [0:1023];
    integer   ngot = 0, mon_frame_err = 0;

    initial begin : monitor
        integer i;
        reg [7:0] b;
        forever begin
            @(negedge RsTx);
            start_time[ngot] = $realtime;
            #(BIT_NS * 1.5);                        // middle of bit 0
            for (i = 0; i < 8; i = i + 1) begin b[i] = RsTx; #(BIT_NS); end
            if (RsTx !== 1'b1) mon_frame_err = mon_frame_err + 1;
            got[ngot] = b;
            ngot = ngot + 1;
            #(BIT_NS * 0.25);                       // stay inside stop bit; next start edge comes later
        end
    end

    // ---------------- Expected bytes ----------------
    reg [7:0] exp [0:1023];
    integer   nexp = 0;

    task send_and_expect(input [7:0] b, input real bit_ns);
        begin
            exp[nexp] = b; nexp = nexp + 1;
            pc_send(b, bit_ns);
        end
    endtask

    task wait_drained;
        integer t;
        begin
            t = 0;
            while (ngot < nexp && t < 200) begin #(BIT_NS * 10); t = t + 1; end
            #(BIT_NS * 12);                         // make sure nothing extra arrives
        end
    endtask

    function integer compare_from(input integer first);
        integer i, bad;
        begin
            bad = 0;
            for (i = first; i < nexp; i = i + 1)
                if (got[i] !== exp[i]) begin
                    if (bad < 5) $display("  byte %0d: sent %02h, echoed %02h", i, exp[i], got[i]);
                    bad = bad + 1;
                end
            compare_from = bad;
        end
    endfunction

    // ---------------- Test sequence ----------------
    integer i, first, seen_low;
    real    gap, min_gap, max_gap;

    initial begin
        $dumpfile("tb_uart_loopback.vcd");
        $dumpvars(0, tb_uart_loopback);

        // 1. Idle line at power-up, no reset press
        seen_low = 0;
        repeat (5000) begin @(posedge clk); if (RsTx !== 1'b1) seen_low = 1; end
        check(!seen_low, "RsTx idles high from power-up");

        // 2. Single bytes
        first = nexp;
        send_and_expect(8'h55, BIT_NS);  wait_drained;
        send_and_expect(8'h00, BIT_NS);  wait_drained;
        send_and_expect(8'hFF, BIT_NS);  wait_drained;
        send_and_expect(8'hC0, BIT_NS);  wait_drained;      // SLIP END
        send_and_expect(8'hDB, BIT_NS);  wait_drained;      // SLIP ESC
        check(ngot == nexp && compare_from(first) == 0, "single bytes 55 00 FF C0 DB echoed");

        // 3. Back-to-back burst, nominal rate
        first = nexp;
        for (i = 0; i < 128; i = i + 1) send_and_expect($random, BIT_NS);
        wait_drained;
        check(ngot == nexp && compare_from(first) == 0, "128-byte back-to-back burst echoed");

        // 5. TX spacing during the burst: start-to-start should be ~10 bits
        min_gap = 1.0e12; max_gap = 0;
        for (i = first + 1; i < nexp; i = i + 1) begin
            gap = start_time[i] - start_time[i-1];
            if (gap < min_gap) min_gap = gap;
            if (gap > max_gap) max_gap = gap;
        end
        $display("  TX start-to-start: %.2f .. %.2f bit times", min_gap / BIT_NS, max_gap / BIT_NS);
        check(min_gap > BIT_NS * 9.9 && max_gap < BIT_NS * 10.1, "TX sends back-to-back at 10 bits/byte");

        // 4. PC clock 2% fast / 2% slow
        first = nexp;
        for (i = 0; i < 32; i = i + 1) send_and_expect($random, BIT_NS * 0.98);
        wait_drained;
        check(ngot == nexp && compare_from(first) == 0, "32-byte burst, PC 2% fast");

        first = nexp;
        for (i = 0; i < 32; i = i + 1) send_and_expect($random, BIT_NS * 1.02);
        wait_drained;
        check(ngot == nexp && compare_from(first) == 0, "32-byte burst, PC 2% slow");

        // 6. Status
        check(mon_frame_err == 0, "no bad stop bits on RsTx");
        check(led[14] == 1'b0, "no framing errors flagged (led[14])");
        check(led[15] == 1'b0, "no RX overflow flagged (led[15])");
        check(ngot == nexp, "no extra bytes echoed");
        check(led[7:0] == exp[nexp-1], "led[7:0] shows last byte");

        $display("tb_uart_loopback: %0d/%0d tests passed (%0d bytes looped)", tests - errors, tests, nexp);
        $finish;
    end
endmodule
