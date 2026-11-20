`timescale 1ns / 1ps

// Unit test: slip_rx + pkt_buf, driven directly at the byte-stream level.
// Uses a small buffer (MAX_LEN = 64) so the length limits are quick to test.
module tb_slip_rx;
    localparam ADDR_W = 7, MAX_LEN = 64;
    localparam [7:0] END = 8'hC0, ESC = 8'hDB, ESC_END = 8'hDC, ESC_ESC = 8'hDD;

    reg clk = 0, rst = 1;
    always #5 clk = ~clk;

    reg  [7:0]        in_data = 0;
    reg               in_valid = 0;
    wire              in_ready;

    wire              wr_ready, wr_en, wr_commit;
    wire [ADDR_W-1:0] wr_addr, wr_len;
    wire [7:0]        wr_data;
    wire              pkt_done, err_escape, err_too_long, err_no_buf;

    wire              rd_valid;
    wire [ADDR_W-1:0] rd_len;
    reg  [ADDR_W-1:0] rd_addr = 0;
    wire [7:0]        rd_data;
    reg               rd_release = 0;

    slip_rx #(.ADDR_W(ADDR_W), .MAX_LEN(MAX_LEN)) dut(
        .clk(clk), .rst(rst),
        .in_data(in_data), .in_valid(in_valid), .in_ready(in_ready),
        .wr_ready(wr_ready), .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data),
        .wr_commit(wr_commit), .wr_len(wr_len),
        .pkt_done(pkt_done), .err_escape(err_escape),
        .err_too_long(err_too_long), .err_no_buf(err_no_buf)
    );

    pkt_buf #(.ADDR_W(ADDR_W), .SLOTS(2)) buf0(
        .clk(clk), .rst(rst),
        .wr_ready(wr_ready), .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data),
        .wr_commit(wr_commit), .wr_len(wr_len),
        .rd_valid(rd_valid), .rd_len(rd_len), .rd_addr(rd_addr), .rd_data(rd_data),
        .rd_release(rd_release)
    );

    integer n_pkt = 0, n_esc = 0, n_long = 0, n_nobuf = 0;
    always @(posedge clk) begin
        if (pkt_done)     n_pkt   = n_pkt + 1;
        if (err_escape)   n_esc   = n_esc + 1;
        if (err_too_long) n_long  = n_long + 1;
        if (err_no_buf)   n_nobuf = n_nobuf + 1;
    end

    integer errors = 0, tests = 0;
    task check(input cond, input [8*64-1:0] name);
        begin
            tests = tests + 1;
            if (cond) $display("PASS %0s", name);
            else begin errors = errors + 1; $display("FAIL %0s", name); end
        end
    endtask

    // ---- stimulus helpers ----
    task put(input [7:0] b);
        begin
            @(negedge clk); in_data = b; in_valid = 1;
            @(negedge clk); in_valid = 0;
            repeat (2) @(negedge clk);
        end
    endtask

    // Expected packet, built up byte by byte
    reg [7:0] exp [0:255];
    integer   exp_len;

    task data(input [7:0] b);       // send one data byte, escaped
        begin
            exp[exp_len] = b; exp_len = exp_len + 1;
            if (b == END)      begin put(ESC); put(ESC_END); end
            else if (b == ESC) begin put(ESC); put(ESC_ESC); end
            else put(b);
        end
    endtask

    // Read the head packet out of the buffer and compare with exp[]
    reg [7:0] got [0:255];
    integer   got_len;

    task read_head;
        integer i;
        begin
            got_len = rd_len;
            for (i = 0; i < got_len; i = i + 1) begin
                @(negedge clk); rd_addr = i;
                @(negedge clk); got[i] = rd_data;
            end
        end
    endtask

    task release_head;
        begin
            @(negedge clk); rd_release = 1;
            @(negedge clk); rd_release = 0;
        end
    endtask

    function head_matches(input integer dummy);
        integer i;
        begin
            head_matches = (got_len == exp_len);
            for (i = 0; i < exp_len && i < got_len; i = i + 1)
                if (got[i] !== exp[i]) head_matches = 0;
        end
    endfunction

    task expect_packet(input [8*64-1:0] name);
        begin
            repeat (3) @(negedge clk);
            if (!rd_valid) check(0, name);
            else begin
                read_head;
                check(head_matches(0), name);
                release_head;
            end
        end
    endtask

    integer i, p0;

    initial begin
        $dumpfile("tb_slip_rx.vcd");
        $dumpvars(0, tb_slip_rx);
        repeat (4) @(negedge clk);
        rst = 0;

        // 1. Plain packet
        exp_len = 0;
        put(END); data(8'h01); data(8'h02); data(8'h03); put(END);
        expect_packet("plain packet 01 02 03");

        // 2. Escapes decode to C0 / DB
        exp_len = 0;
        put(END); data(END); data(8'h7E); data(ESC); data(END); put(END);
        expect_packet("escaped C0 7E DB C0");

        // 3. Bare DC / DD (not after ESC) are ordinary data
        exp_len = 0;
        put(END); data(ESC_END); data(ESC_ESC); put(END);
        expect_packet("bare DC DD are data");

        // 4. Empty frames produce nothing
        p0 = n_pkt;
        put(END); put(END); put(END);
        repeat (3) @(negedge clk);
        check(!rd_valid && n_pkt == p0, "empty frames ignored");

        // 5. ESC + invalid code: dropped, then recovers
        put(END); put(8'h11); put(ESC); put(8'h41); put(8'h22); put(END);
        repeat (3) @(negedge clk);
        check(!rd_valid && n_esc == 1, "ESC + 41 dropped, err_escape");
        exp_len = 0; put(END); data(8'h99); put(END);
        expect_packet("packet after bad escape");

        // 6. ESC END: dropped
        put(END); put(8'h11); put(ESC); put(END);
        repeat (3) @(negedge clk);
        check(!rd_valid && n_esc == 2, "ESC END dropped, err_escape");

        // 7. Exactly MAX_LEN is OK, MAX_LEN + 1 is dropped
        exp_len = 0; put(END);
        for (i = 0; i < MAX_LEN; i = i + 1) data(i * 3);
        put(END);
        expect_packet("MAX_LEN-byte packet accepted");

        put(END);
        for (i = 0; i <= MAX_LEN; i = i + 1) put(8'h5A);
        put(END);
        repeat (3) @(negedge clk);
        check(!rd_valid && n_long == 1, "MAX_LEN+1 dropped, err_too_long");

        // 8. Both slots full: third packet dropped, then space frees up
        put(END); put(8'hA1); put(END);
        put(END); put(8'hA2); put(END);
        put(END); put(8'hA3); put(END);              // no slot -> dropped
        check(n_nobuf == 1 && !wr_ready, "3rd packet dropped when both slots full");
        exp_len = 1; exp[0] = 8'hA1;
        read_head; check(head_matches(0), "slot order: A1 first"); release_head;
        exp_len = 0; put(END); data(8'hA4); put(END); // a slot is free again
        exp_len = 1; exp[0] = 8'hA2;
        read_head; check(head_matches(0), "slot order: A2 second"); release_head;
        exp_len = 1; exp[0] = 8'hA4;
        read_head; check(head_matches(0), "A4 accepted after slot freed"); release_head;
        repeat (3) @(negedge clk);
        check(!rd_valid, "buffer empty at end");

        $display("tb_slip_rx: %0d/%0d tests passed", tests - errors, tests);
        $finish;
    end
endmodule
