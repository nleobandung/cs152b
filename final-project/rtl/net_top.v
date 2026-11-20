`timescale 1ns / 1ps

// Network stack top level.
//
//   RsRx -> uart -> slip_rx -> [RX pkt_buf] -> processor -> [TX pkt_buf] -> slip_tx -> uart -> RsTx
//
// The processor is ip_icmp (answers pings to MY_IP). With ECHO_MODE = 1 it is
// pkt_echo instead, which sends every packet back unchanged: useful for
// testing the UART + SLIP path on the board before involving Linux.
//
//   btnU      -> reset (also automatic at power-up)
//   led[7:0]  <- packets received (low 8 bits)
//   led[8]    <- toggles on each packet sent
//   led[11]   <- sticky: packet dropped by IPv4/ICMP checks
//   led[12]   <- sticky: packet dropped, no free RX buffer slot
//   led[13]   <- sticky: packet dropped, bad SLIP escape or too long
//   led[14]   <- sticky: UART framing error
//   led[15]   <- sticky: UART RX FIFO overflow
module net_top #(
    parameter CLK_HZ  = 100_000_000,
    parameter BAUD    = 115_200,
    parameter ADDR_W  = 11,             // 2 KB per packet slot
    parameter MAX_LEN = 1500,           // match: ip link set sl0 mtu 1500
    parameter [31:0] MY_IP = 32'h0A00_0002,   // 10.0.0.2
    parameter ECHO_MODE = 0
)(
    input  wire        clk,
    input  wire        btnU,
    input  wire        RsRx,
    output wire        RsTx,
    output wire [15:0] led
);
    // ---------------- Reset ----------------
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

    // ---------------- UART ----------------
    wire [7:0] urx_data, utx_data;
    wire       urx_valid, urx_ready, utx_valid, utx_ready;
    wire       uart_overflow, uart_frame_err;

    uart #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart(
        .clk(clk), .rst(rst),
        .rx_pin(RsRx), .tx_pin(RsTx),
        .rx_data(urx_data), .rx_valid(urx_valid), .rx_ready(urx_ready),
        .tx_data(utx_data), .tx_valid(utx_valid), .tx_ready(utx_ready),
        .rx_overflow(uart_overflow), .rx_frame_err(uart_frame_err)
    );

    // ---------------- SLIP RX -> RX buffer ----------------
    wire              rxb_wr_ready, rxb_wr_en, rxb_commit;
    wire [ADDR_W-1:0] rxb_wr_addr, rxb_wr_len;
    wire [7:0]        rxb_wr_data;
    wire              slip_rx_pkt, slip_err_escape, slip_err_too_long, slip_err_no_buf;

    slip_rx #(.ADDR_W(ADDR_W), .MAX_LEN(MAX_LEN)) u_slip_rx(
        .clk(clk), .rst(rst),
        .in_data(urx_data), .in_valid(urx_valid), .in_ready(urx_ready),
        .wr_ready(rxb_wr_ready), .wr_en(rxb_wr_en), .wr_addr(rxb_wr_addr),
        .wr_data(rxb_wr_data), .wr_commit(rxb_commit), .wr_len(rxb_wr_len),
        .pkt_done(slip_rx_pkt), .err_escape(slip_err_escape),
        .err_too_long(slip_err_too_long), .err_no_buf(slip_err_no_buf)
    );

    wire              rxb_rd_valid, rxb_release;
    wire [ADDR_W-1:0] rxb_rd_len, rxb_rd_addr;
    wire [7:0]        rxb_rd_data;

    pkt_buf #(.ADDR_W(ADDR_W), .SLOTS(2)) u_rx_buf(
        .clk(clk), .rst(rst),
        .wr_ready(rxb_wr_ready), .wr_en(rxb_wr_en), .wr_addr(rxb_wr_addr),
        .wr_data(rxb_wr_data), .wr_commit(rxb_commit), .wr_len(rxb_wr_len),
        .rd_valid(rxb_rd_valid), .rd_len(rxb_rd_len), .rd_addr(rxb_rd_addr),
        .rd_data(rxb_rd_data), .rd_release(rxb_release)
    );

    // ---------------- Packet processor ----------------
    wire              txb_wr_ready, txb_wr_en, txb_commit;
    wire [ADDR_W-1:0] txb_wr_addr, txb_wr_len;
    wire [7:0]        txb_wr_data;
    wire              ip_drop_bad, ip_drop_not_me, ip_drop_proto, ip_drop_icmp;

    generate if (ECHO_MODE) begin : g_echo
        pkt_echo #(.ADDR_W(ADDR_W)) u_proc(
            .clk(clk), .rst(rst),
            .rx_valid(rxb_rd_valid), .rx_len(rxb_rd_len), .rx_addr(rxb_rd_addr),
            .rx_data(rxb_rd_data), .rx_release(rxb_release),
            .tx_wr_ready(txb_wr_ready), .tx_wr_en(txb_wr_en), .tx_wr_addr(txb_wr_addr),
            .tx_wr_data(txb_wr_data), .tx_commit(txb_commit), .tx_len(txb_wr_len)
        );
        assign {ip_drop_bad, ip_drop_not_me, ip_drop_proto, ip_drop_icmp} = 4'b0;
    end else begin : g_ip
        wire replied;
        ip_icmp #(.ADDR_W(ADDR_W), .MY_IP(MY_IP)) u_proc(
            .clk(clk), .rst(rst),
            .rx_valid(rxb_rd_valid), .rx_len(rxb_rd_len), .rx_addr(rxb_rd_addr),
            .rx_data(rxb_rd_data), .rx_release(rxb_release),
            .tx_wr_ready(txb_wr_ready), .tx_wr_en(txb_wr_en), .tx_wr_addr(txb_wr_addr),
            .tx_wr_data(txb_wr_data), .tx_commit(txb_commit), .tx_len(txb_wr_len),
            .replied(replied), .drop_bad_ip(ip_drop_bad), .drop_not_me(ip_drop_not_me),
            .drop_proto(ip_drop_proto), .drop_icmp(ip_drop_icmp)
        );
    end endgenerate

    // ---------------- TX buffer -> SLIP TX ----------------
    wire              txb_rd_valid, txb_release;
    wire [ADDR_W-1:0] txb_rd_len, txb_rd_addr;
    wire [7:0]        txb_rd_data;
    wire              slip_tx_pkt;

    pkt_buf #(.ADDR_W(ADDR_W), .SLOTS(2)) u_tx_buf(
        .clk(clk), .rst(rst),
        .wr_ready(txb_wr_ready), .wr_en(txb_wr_en), .wr_addr(txb_wr_addr),
        .wr_data(txb_wr_data), .wr_commit(txb_commit), .wr_len(txb_wr_len),
        .rd_valid(txb_rd_valid), .rd_len(txb_rd_len), .rd_addr(txb_rd_addr),
        .rd_data(txb_rd_data), .rd_release(txb_release)
    );

    slip_tx #(.ADDR_W(ADDR_W)) u_slip_tx(
        .clk(clk), .rst(rst),
        .rd_valid(txb_rd_valid), .rd_len(txb_rd_len), .rd_addr(txb_rd_addr),
        .rd_data(txb_rd_data), .rd_release(txb_release),
        .out_data(utx_data), .out_valid(utx_valid), .out_ready(utx_ready),
        .pkt_done(slip_tx_pkt)
    );

    // ---------------- Status ----------------
    // Counters (rx_pkts, ip_drops etc. will feed the seven-segment display)
    reg [15:0] rx_pkts = 0, tx_pkts = 0;
    reg [15:0] drops_no_buf = 0, drops_bad = 0, ip_drops = 0;
    reg        tx_toggle = 0, saw_no_buf = 0, saw_bad = 0, saw_frame_err = 0, saw_overflow = 0;
    reg        saw_ip_drop = 0;

    wire ip_drop = ip_drop_bad || ip_drop_not_me || ip_drop_proto || ip_drop_icmp;

    always @(posedge clk) begin
        if (rst) begin
            rx_pkts <= 0;  tx_pkts <= 0;  drops_no_buf <= 0;  drops_bad <= 0;  ip_drops <= 0;
            tx_toggle <= 0;  saw_no_buf <= 0;  saw_bad <= 0;  saw_ip_drop <= 0;
            saw_frame_err <= 0;  saw_overflow <= 0;
        end else begin
            if (ip_drop) begin ip_drops <= ip_drops + 1'b1; saw_ip_drop <= 1'b1; end
            if (slip_rx_pkt) rx_pkts <= rx_pkts + 1'b1;
            if (slip_tx_pkt) begin tx_pkts <= tx_pkts + 1'b1; tx_toggle <= ~tx_toggle; end
            if (slip_err_no_buf) begin drops_no_buf <= drops_no_buf + 1'b1; saw_no_buf <= 1'b1; end
            if (slip_err_escape || slip_err_too_long) begin drops_bad <= drops_bad + 1'b1; saw_bad <= 1'b1; end
            if (uart_frame_err) saw_frame_err <= 1'b1;
            if (uart_overflow)  saw_overflow  <= 1'b1;
        end
    end

    assign led = {saw_overflow, saw_frame_err, saw_bad, saw_no_buf, saw_ip_drop, 2'b0, tx_toggle, rx_pkts[7:0]};
endmodule
