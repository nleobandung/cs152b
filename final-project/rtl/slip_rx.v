`timescale 1ns / 1ps

// SLIP decoder (RFC 1055): byte stream in, whole packets out into a pkt_buf.
//
//   END (C0)          ends a packet. Empty packets (END END) are ignored.
//   ESC (DB) + DC     -> data byte C0
//   ESC (DB) + DD     -> data byte DB
//
// A packet is dropped (never committed) if:
//   * ESC is followed by anything other than DC/DD     -> err_escape
//   * it is longer than MAX_LEN bytes                   -> err_too_long
//   * the packet buffer has no free slot when it starts -> err_no_buf
// After a drop, everything up to the next END is discarded.
// Each err_* and pkt_done is a one-cycle pulse, for counters/LEDs.
module slip_rx #(
    parameter ADDR_W  = 11,
    parameter MAX_LEN = 1500
)(
    input  wire              clk,
    input  wire              rst,

    // Byte stream from the UART (always ready)
    input  wire [7:0]        in_data,
    input  wire              in_valid,
    output wire              in_ready,

    // To pkt_buf write side
    input  wire              wr_ready,
    output reg               wr_en,
    output reg  [ADDR_W-1:0] wr_addr,
    output reg  [7:0]        wr_data,
    output reg               wr_commit,
    output reg  [ADDR_W-1:0] wr_len,

    output reg               pkt_done,
    output reg               err_escape,
    output reg               err_too_long,
    output reg               err_no_buf
);
    localparam [7:0] END = 8'hC0, ESC = 8'hDB, ESC_END = 8'hDC, ESC_ESC = 8'hDD;

    reg [ADDR_W-1:0] len  = 0;      // bytes stored so far in this packet
    reg              esc  = 0;      // previous byte was ESC
    reg              drop = 0;      // discarding until the next END

    assign in_ready = 1'b1;

    // Store one decoded byte, or start dropping if we can't.
    task store(input [7:0] b);
        begin
            if (len == 0 && !wr_ready) begin
                err_no_buf <= 1'b1;
                drop       <= 1'b1;
            end else if (len == MAX_LEN) begin
                err_too_long <= 1'b1;
                drop         <= 1'b1;
            end else begin
                wr_en   <= 1'b1;
                wr_addr <= len;
                wr_data <= b;
                len     <= len + 1'b1;
            end
        end
    endtask

    always @(posedge clk) begin
        wr_en        <= 1'b0;
        wr_commit    <= 1'b0;
        pkt_done     <= 1'b0;
        err_escape   <= 1'b0;
        err_too_long <= 1'b0;
        err_no_buf   <= 1'b0;

        if (rst) begin
            len  <= 0;
            esc  <= 1'b0;
            drop <= 1'b0;
        end else if (in_valid) begin
            if (in_data == END) begin
                // End of packet (or end of a dropped one)
                if (esc && !drop)
                    err_escape <= 1'b1;             // ESC END: malformed
                else if (!drop && len != 0) begin
                    wr_commit <= 1'b1;
                    wr_len    <= len;
                    pkt_done  <= 1'b1;
                end
                len  <= 0;
                esc  <= 1'b0;
                drop <= 1'b0;
            end else if (drop) begin
                // discard until END
            end else if (esc) begin
                esc <= 1'b0;
                if (in_data == ESC_END)      store(END);
                else if (in_data == ESC_ESC) store(ESC);
                else begin
                    err_escape <= 1'b1;
                    drop       <= 1'b1;
                end
            end else if (in_data == ESC) begin
                esc <= 1'b1;
            end else begin
                store(in_data);
            end
        end
    end
endmodule
