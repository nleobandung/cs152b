`timescale 1ns / 1ps

// Packet buffer: a FIFO of whole packets, stored in block RAM.
//
// SLOTS slots of 2**ADDR_W bytes each (default 2 x 2 KB = one 36 Kb BRAM).
// The writer fills a slot by address and commits it; the reader sees committed
// packets in order, reads them by address, and releases them. With 2+ slots a
// new packet can be received while the previous one is still being processed.
//
// Write side (e.g. slip_rx, or the packet processor building a reply):
//   wr_ready     a free slot exists. Check it before starting a packet; it can
//                only go 0 -> 1 while you are writing, never 1 -> 0.
//   wr_en/wr_addr/wr_data   write one byte into the current slot
//   wr_commit/wr_len        publish the slot as a packet of wr_len bytes.
//                           To abandon a packet, just don't commit; the next
//                           packet overwrites the slot.
//
// Read side (e.g. the packet processor, or slip_tx):
//   rd_valid     a packet is available; rd_len is its length
//   rd_addr      byte address; rd_data shows mem[rd_addr] ONE CYCLE LATER
//   rd_release   done with this packet (pulse for one cycle while rd_valid)
module pkt_buf #(
    parameter ADDR_W = 11,      // 2**ADDR_W bytes per slot; max packet 2**ADDR_W - 1
    parameter SLOTS  = 2        // power of 2, >= 2
)(
    input  wire              clk,
    input  wire              rst,

    output wire              wr_ready,
    input  wire              wr_en,
    input  wire [ADDR_W-1:0] wr_addr,
    input  wire [7:0]        wr_data,
    input  wire              wr_commit,
    input  wire [ADDR_W-1:0] wr_len,

    output wire              rd_valid,
    output wire [ADDR_W-1:0] rd_len,
    input  wire [ADDR_W-1:0] rd_addr,
    output reg  [7:0]        rd_data,
    input  wire              rd_release
);
    localparam SW = $clog2(SLOTS);

    reg [7:0]        mem  [0:SLOTS*(2**ADDR_W)-1];
    reg [ADDR_W-1:0] lens [0:SLOTS-1];
    reg [SW:0]       wslot = 0, rslot = 0;      // extra MSB tells full from empty

    wire full = (wslot[SW] != rslot[SW]) && (wslot[SW-1:0] == rslot[SW-1:0]);

    assign wr_ready = !full;
    assign rd_valid = (wslot != rslot);
    assign rd_len   = lens[rslot[SW-1:0]];

    // Simple dual-port RAM (no reset, so Vivado infers block RAM)
    always @(posedge clk) begin
        if (wr_en && !full)
            mem[{wslot[SW-1:0], wr_addr}] <= wr_data;
        rd_data <= mem[{rslot[SW-1:0], rd_addr}];
    end

    always @(posedge clk) begin
        if (rst) begin
            wslot <= 0;
            rslot <= 0;
        end else begin
            if (wr_commit && !full) begin
                lens[wslot[SW-1:0]] <= wr_len;
                wslot <= wslot + 1'b1;
            end
            if (rd_release && rd_valid)
                rslot <= rslot + 1'b1;
        end
    end
endmodule
