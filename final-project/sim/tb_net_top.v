`timescale 1ns / 1ps

// Full-stack test of net_top through the real UART pins:
//   testbench "PC" --RsRx--> uart -> slip_rx -> buffers -> processor -> slip_tx -> uart --RsTx--> testbench
//
// Default: processor = ip_icmp, vectors build/ping_*  (the ping milestone)
// -DECHO_MODE: processor = pkt_echo, vectors build/echo_*  (SLIP edge cases)
//
// Stimulus comes from tools/gen_net_vectors.py.
// Runs at 3.125 Mbaud (32 clocks per bit) instead of 115200 to keep the
// simulation fast; the logic is identical, only the divider constants change.
module tb_net_top;
    localparam integer CLK_HZ = 100_000_000;
    localparam integer BAUD   = 3_125_000;
    localparam real    BIT_NS = 1.0e9 / BAUD;      // 320 ns
`ifdef ECHO_MODE
    localparam ECHO = 1;
    localparam [8*16-1:0] F_IN = "echo_in.hex", F_EXP = "echo_exp.hex", F_META = "echo_meta.txt";
`else
    localparam ECHO = 0;
    localparam [8*16-1:0] F_IN = "ping_in.hex", F_EXP = "ping_exp.hex", F_META = "ping_meta.txt";
`endif

    reg  clk = 0, btnU = 0, RsRx = 1;
    wire RsTx;
    wire [15:0] led;

    always #5 clk = ~clk;

    net_top #(.CLK_HZ(CLK_HZ), .BAUD(BAUD), .ECHO_MODE(ECHO)) dut(
        .clk(clk), .btnU(btnU), .RsRx(RsRx), .RsTx(RsTx), .led(led)
    );

    integer errors = 0, tests = 0;
    task check(input cond, input [8*64-1:0] name);
        begin
            tests = tests + 1;
            if (cond) $display("PASS %0s", name);
            else begin errors = errors + 1; $display("FAIL %0s", name); end
        end
    endtask

    // ---------------- PC side ----------------
    task pc_send(input [7:0] b);
        integer i;
        begin
            RsRx = 0; #(BIT_NS);
            for (i = 0; i < 8; i = i + 1) begin RsRx = b[i]; #(BIT_NS); end
            RsRx = 1; #(BIT_NS);
        end
    endtask

    reg [7:0] got [0:65535];
    integer   ngot = 0, bad_stop = 0;

    initial begin : monitor
        integer i;
        reg [7:0] b;
        forever begin
            @(negedge RsTx);
            #(BIT_NS * 1.5);
            for (i = 0; i < 8; i = i + 1) begin b[i] = RsTx; #(BIT_NS); end
            if (RsTx !== 1'b1) bad_stop = bad_stop + 1;
            got[ngot] = b;
            ngot = ngot + 1;
            #(BIT_NS * 0.25);
        end
    end

    // ---------------- Expected output ----------------
    reg [7:0] exp [0:65535];
    integer   nexp = 0;
    integer   n_rx, n_tx, n_slip_bad, n_ip_drop;

    task load_expected;
        integer fd, r;
        reg [8:0] v;
        begin
            fd = $fopen(F_EXP, "r");
            if (fd == 0) begin $display("ERROR: run tools/gen_net_vectors.py first"); $finish; end
            while (!$feof(fd)) begin
                r = $fscanf(fd, "%h\n", v);
                if (r == 1) begin exp[nexp] = v[7:0]; nexp = nexp + 1; end
            end
            $fclose(fd);
            fd = $fopen(F_META, "r");
            r = $fscanf(fd, "%d %d %d %d", n_rx, n_tx, n_slip_bad, n_ip_drop);
            $fclose(fd);
        end
    endtask

    // Wait until the FPGA has finished replying (output quiet for 40 byte times)
    task wait_quiet;
        integer last, idle;
        begin
            last = -1; idle = 0;
            while (idle < 40) begin                // 40 byte times with no output
                #(BIT_NS * 10);
                if (ngot == last) idle = idle + 1;
                else begin idle = 0; last = ngot; end
            end
        end
    endtask

    integer fd, r, i, first_bad, nin;
    reg [8:0] tok;

    initial begin
        load_expected;

        #(BIT_NS * 20);                             // power-on reset

        fd = $fopen(F_IN, "r");
        nin = 0;
        while (!$feof(fd)) begin
            r = $fscanf(fd, "%h\n", tok);
            if (r == 1) begin
                if (tok == 9'h100) wait_quiet;
                else begin pc_send(tok[7:0]); nin = nin + 1; end
            end
        end
        $fclose(fd);
        wait_quiet;

        // Compare the output stream
        first_bad = -1;
        for (i = 0; i < nexp && i < ngot; i = i + 1)
            if (got[i] !== exp[i] && first_bad < 0) first_bad = i;
        if (first_bad >= 0)
            $display("  first mismatch at output byte %0d: expected %02h, got %02h",
                     first_bad, exp[first_bad], got[first_bad]);
        if (ngot != nexp)
            $display("  expected %0d output bytes, got %0d", nexp, ngot);

        check(ngot == nexp && first_bad < 0, "output stream matches byte for byte");
        check(dut.rx_pkts == n_rx, "frames received");
        check(dut.tx_pkts == n_tx, "packets sent");
        check(dut.drops_bad == n_slip_bad, "malformed SLIP frames dropped");
        check(dut.ip_drops == n_ip_drop, "packets dropped by IPv4/ICMP checks");
        check(dut.drops_no_buf == 0, "no drops for lack of buffer space");
        check(led[15:14] == 2'b00 && bad_stop == 0, "no UART framing errors / overflows");

        $display("  %0d bytes in, %0d bytes out; %0d frames in, %0d packets out, %0d SLIP drops, %0d IP drops",
                 nin, ngot, dut.rx_pkts, dut.tx_pkts, dut.drops_bad, dut.ip_drops);
        $display("tb_net_top (%0s): %0d/%0d tests passed", ECHO ? "echo" : "ping", tests - errors, tests);
        $finish;
    end
endmodule
