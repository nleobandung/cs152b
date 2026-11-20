`timescale 1ns / 1ps

// Placeholder packet processor: copies each received packet, unchanged, into
// the TX buffer. It exists so the SLIP + buffer path can be tested end to end
// before IPv4/ICMP is ready.
//
// The IPv4/ICMP block replaces this module and uses the same ports:
//   * read the request from the RX buffer (rx_*)
//   * write the reply into the TX buffer (tx_*) and commit it
//   * release the RX packet
// Wait for tx_wr_ready before starting, so a reply always has somewhere to go.
module pkt_echo #(
    parameter ADDR_W = 11
)(
    input  wire              clk,
    input  wire              rst,

    // RX buffer read side
    input  wire              rx_valid,
    input  wire [ADDR_W-1:0] rx_len,
    output wire [ADDR_W-1:0] rx_addr,
    input  wire [7:0]        rx_data,       // mem[rx_addr], one cycle later
    output wire              rx_release,

    // TX buffer write side
    input  wire              tx_wr_ready,
    output reg               tx_wr_en,
    output reg  [ADDR_W-1:0] tx_wr_addr,
    output wire [7:0]        tx_wr_data,
    output wire              tx_commit,
    output wire [ADDR_W-1:0] tx_len
);
    localparam IDLE = 2'd0, COPY = 2'd1, FINISH = 2'd2;

    reg [1:0]        state = IDLE;
    reg [ADDR_W-1:0] idx   = 0;

    assign rx_addr    = idx;
    assign tx_wr_data = rx_data;            // byte read last cycle
    assign tx_len     = rx_len;
    assign tx_commit  = (state == FINISH) && !tx_wr_en;
    assign rx_release = tx_commit;

    always @(posedge clk) begin
        tx_wr_en <= 1'b0;

        if (rst) begin
            state <= IDLE;
            idx   <= 0;
        end else begin
            case (state)
                IDLE: if (rx_valid && tx_wr_ready) begin
                    idx   <= 0;
                    state <= COPY;
                end
                COPY: begin
                    // Read address idx now; write it to the TX buffer next cycle
                    tx_wr_en   <= 1'b1;
                    tx_wr_addr <= idx;
                    if (idx == rx_len - 1'b1) state <= FINISH;
                    else                      idx   <= idx + 1'b1;
                end
                FINISH: if (!tx_wr_en)       // last byte written
                    state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
