`timescale 1ns / 1ps

// SLIP encoder (RFC 1055): whole packets from a pkt_buf in, byte stream out.
//
// Each packet goes out as  END, escaped bytes, END.  The leading END flushes
// any line noise the receiver has accumulated (RFC 1055 recommends it).
//   C0 -> DB DC,   DB -> DB DD
module slip_tx #(
    parameter ADDR_W = 11
)(
    input  wire              clk,
    input  wire              rst,

    // From pkt_buf read side
    input  wire              rd_valid,
    input  wire [ADDR_W-1:0] rd_len,
    output wire [ADDR_W-1:0] rd_addr,
    input  wire [7:0]        rd_data,       // mem[rd_addr], one cycle later
    output wire              rd_release,

    // Byte stream to the UART
    output reg  [7:0]        out_data,
    output reg               out_valid,
    input  wire              out_ready,

    output reg               pkt_done
);
    localparam [7:0] END = 8'hC0, ESC = 8'hDB, ESC_END = 8'hDC, ESC_ESC = 8'hDD;

    localparam IDLE  = 3'd0,
               FETCH = 3'd1,    // rd_addr = idx is set; wait for rd_data
               BYTE  = 3'd2,    // rd_data = packet[idx]
               ESC2  = 3'd3,    // second byte of an escape sequence
               NEXT  = 3'd4,
               DONE  = 3'd5;

    reg [2:0]        state = IDLE;
    reg [ADDR_W-1:0] idx   = 0;
    reg [7:0]        esc_code = 0;

    assign rd_addr    = idx;
    // Combinational so the buffer advances before we look at rd_valid again
    assign rd_release = (state == DONE) && !out_valid;

    always @(posedge clk) begin
        pkt_done <= 1'b0;

        if (rst) begin
            state     <= IDLE;
            idx       <= 0;
            out_valid <= 1'b0;
        end else if (out_valid) begin
            // Wait for the UART to take the byte before doing anything else
            if (out_ready) out_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: if (rd_valid) begin
                    out_data  <= END;
                    out_valid <= 1'b1;
                    idx       <= 0;
                    state     <= FETCH;
                end
                FETCH: state <= BYTE;
                BYTE: begin
                    out_valid <= 1'b1;
                    if (rd_data == END) begin
                        out_data <= ESC;  esc_code <= ESC_END;  state <= ESC2;
                    end else if (rd_data == ESC) begin
                        out_data <= ESC;  esc_code <= ESC_ESC;  state <= ESC2;
                    end else begin
                        out_data <= rd_data;                    state <= NEXT;
                    end
                end
                ESC2: begin
                    out_data  <= esc_code;
                    out_valid <= 1'b1;
                    state     <= NEXT;
                end
                NEXT: if (idx == rd_len - 1'b1) begin
                    out_data  <= END;
                    out_valid <= 1'b1;
                    state     <= DONE;
                end else begin
                    idx   <= idx + 1'b1;
                    state <= FETCH;
                end
                DONE: begin                 // rd_release is high this cycle
                    pkt_done <= 1'b1;
                    state    <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
