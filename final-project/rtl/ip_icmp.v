`timescale 1ns / 1ps

// IPv4 (RFC 791) + ICMP echo (RFC 792) packet processor.
// Drop-in replacement for pkt_echo: same buffer ports, plus status pulses.
//
// For each packet in the RX buffer:
//   1. READ    one pass over the packet. Bytes 0-19 are parsed into fields
//              and summed (IP header checksum). Bytes 20+ (ICMP) are copied
//              into the TX buffer as the reply body and summed twice: once as
//              received (to verify), once as rewritten (for the reply).
//   2. CHECK   drop unless: IPv4, no options (IHL = 5), total length matches
//              the SLIP frame, header checksum OK, not a fragment,
//              destination = MY_IP, protocol = ICMP, type 8 code 0,
//              ICMP checksum OK.
//   3. HDR     write the 20-byte reply IP header (addresses swapped, TTL 64).
//   4. CSUM    write the IP and ICMP checksums into their slots.
//   5. COMMIT  publish the reply, release the request.
//
// Checksums are 16-bit ones' complement sums. Bytes at even offsets are the
// high half of a word, odd offsets the low half (the ICMP part starts at 20,
// so offset parity works for both). Sums accumulate in 32 bits and are folded
// to 16 bits at the end. A received header/message is valid when its folded
// sum is FFFF.
module ip_icmp #(
    parameter        ADDR_W = 11,
    parameter [31:0] MY_IP  = 32'h0A00_0002          // 10.0.0.2
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
    output reg  [7:0]        tx_wr_data,
    output wire              tx_commit,
    output wire [ADDR_W-1:0] tx_len,

    // Status pulses (one cycle each)
    output reg               replied,       // echo reply queued
    output reg               drop_bad_ip,   // malformed / bad checksum / options / fragment
    output reg               drop_not_me,   // destination is not MY_IP
    output reg               drop_proto,    // not ICMP (e.g. TCP before it exists)
    output reg               drop_icmp      // not an echo request, or bad ICMP checksum
);
    localparam IDLE   = 4'd0,
               READ   = 4'd1,
               DRAIN  = 4'd2,
               FOLD1  = 4'd3,
               FOLD2  = 4'd4,
               CHECK  = 4'd5,
               HDR    = 4'd6,
               HFOLD1 = 4'd7,
               HFOLD2 = 4'd8,
               CSUM   = 4'd9,
               COMMIT = 4'd10,
               DROP   = 4'd11;

    localparam MIN_LEN = 28;                // 20-byte IP header + 8-byte ICMP header

    reg [3:0]        state = IDLE;
    reg [ADDR_W-1:0] ridx  = 0;             // read address
    reg [4:0]        widx  = 0;             // header / checksum write index

    // Read pipeline: address issued last cycle, byte arrives now
    reg              pend  = 0;
    reg [ADDR_W-1:0] paddr = 0;

    // Parsed request fields
    reg [7:0]  ver_ihl;
    reg [15:0] tot_len, ident, flags_frag;
    reg [7:0]  proto, icmp_type, icmp_code;
    reg [31:0] src_ip, dst_ip;

    // Ones' complement sums
    reg [31:0] ip_sum;      // request IP header, as received
    reg [31:0] icmp_sum;    // request ICMP message, as received
    reg [31:0] rep_sum;     // reply ICMP message, checksum field = 0
    reg [31:0] hdr_sum;     // reply IP header, checksum field = 0

    function [31:0] word_part(input lsb, input [7:0] b);
        word_part = lsb ? {24'b0, b} : {16'b0, b, 8'b0};
    endfunction

    function [31:0] fold(input [31:0] s);
        fold = {16'b0, s[15:0]} + {16'b0, s[31:16]};
    endfunction

    // Reply IP header byte i
    function [7:0] hdr_byte(input [4:0] i);
        case (i)
            5'd0:  hdr_byte = 8'h45;                // IPv4, 20-byte header
            5'd1:  hdr_byte = 8'h00;                // TOS
            5'd2:  hdr_byte = tot_len[15:8];
            5'd3:  hdr_byte = tot_len[7:0];
            5'd4:  hdr_byte = ident[15:8];          // reuse request's ID
            5'd5:  hdr_byte = ident[7:0];
            5'd6:  hdr_byte = flags_frag[15:8];     // keep DF; MF/offset known 0
            5'd7:  hdr_byte = 8'h00;
            5'd8:  hdr_byte = 8'd64;                // TTL
            5'd9:  hdr_byte = 8'd1;                 // ICMP
            5'd12: hdr_byte = MY_IP[31:24];
            5'd13: hdr_byte = MY_IP[23:16];
            5'd14: hdr_byte = MY_IP[15:8];
            5'd15: hdr_byte = MY_IP[7:0];
            5'd16: hdr_byte = src_ip[31:24];
            5'd17: hdr_byte = src_ip[23:16];
            5'd18: hdr_byte = src_ip[15:8];
            5'd19: hdr_byte = src_ip[7:0];
            default: hdr_byte = 8'h00;              // 10, 11: checksum, filled in later
        endcase
    endfunction

    // ---- CHECK conditions (sums are folded by then) ----
    wire ip_ok    = (ver_ihl == 8'h45)
                 && (tot_len == {{(16-ADDR_W){1'b0}}, rx_len})
                 && (ip_sum[15:0] == 16'hFFFF)
                 && (flags_frag[13:0] == 14'd0);    // MF = 0, offset = 0
    wire me_ok    = (dst_ip == MY_IP);
    wire proto_ok = (proto == 8'd1);
    wire icmp_ok  = (icmp_type == 8'd8) && (icmp_code == 8'd0)
                 && (icmp_sum[15:0] == 16'hFFFF);

    assign rx_addr    = ridx;
    assign tx_len     = rx_len;
    assign tx_commit  = (state == COMMIT) && !tx_wr_en;
    assign rx_release = tx_commit || (state == DROP);

    wire [7:0] b = rx_data;

    always @(posedge clk) begin
        tx_wr_en    <= 1'b0;
        pend        <= 1'b0;
        replied     <= 1'b0;
        drop_bad_ip <= 1'b0;
        drop_not_me <= 1'b0;
        drop_proto  <= 1'b0;
        drop_icmp   <= 1'b0;

        if (rst) begin
            state <= IDLE;
            ridx  <= 0;
        end else begin
            // ---------- Byte processing (READ pipeline stage 2) ----------
            if (pend) begin
                if (paddr < 20) begin
                    ip_sum <= ip_sum + word_part(paddr[0], b);
                    case (paddr[4:0])
                        5'd0:  ver_ihl           <= b;
                        5'd2:  tot_len[15:8]     <= b;
                        5'd3:  tot_len[7:0]      <= b;
                        5'd4:  ident[15:8]       <= b;
                        5'd5:  ident[7:0]        <= b;
                        5'd6:  flags_frag[15:8]  <= b;
                        5'd7:  flags_frag[7:0]   <= b;
                        5'd9:  proto             <= b;
                        5'd12: src_ip[31:24]     <= b;
                        5'd13: src_ip[23:16]     <= b;
                        5'd14: src_ip[15:8]      <= b;
                        5'd15: src_ip[7:0]       <= b;
                        5'd16: dst_ip[31:24]     <= b;
                        5'd17: dst_ip[23:16]     <= b;
                        5'd18: dst_ip[15:8]      <= b;
                        5'd19: dst_ip[7:0]       <= b;
                        default: ;
                    endcase
                end else begin
                    // ICMP: copy to the reply, type 8 -> 0, checksum -> 0 for now
                    icmp_sum   <= icmp_sum + word_part(paddr[0], b);
                    tx_wr_en   <= 1'b1;
                    tx_wr_addr <= paddr;
                    if (paddr == 20) begin
                        icmp_type  <= b;
                        tx_wr_data <= 8'h00;
                    end else if (paddr == 22 || paddr == 23) begin
                        tx_wr_data <= 8'h00;
                    end else begin
                        if (paddr == 21) icmp_code <= b;
                        tx_wr_data <= b;
                        rep_sum    <= rep_sum + word_part(paddr[0], b);
                    end
                end
            end

            // ---------- Control ----------
            case (state)
                IDLE: if (rx_valid && tx_wr_ready) begin
                    if (rx_len < MIN_LEN) begin
                        drop_bad_ip <= 1'b1;
                        state       <= DROP;
                    end else begin
                        ridx     <= 0;
                        ip_sum   <= 0;
                        icmp_sum <= 0;
                        rep_sum  <= 0;
                        state    <= READ;
                    end
                end

                READ: begin
                    pend  <= 1'b1;
                    paddr <= ridx;
                    if (ridx == rx_len - 1'b1) state <= DRAIN;
                    else                       ridx  <= ridx + 1'b1;
                end

                DRAIN: state <= FOLD1;              // last byte is processed this cycle

                FOLD1, FOLD2: begin
                    ip_sum   <= fold(ip_sum);
                    icmp_sum <= fold(icmp_sum);
                    rep_sum  <= fold(rep_sum);
                    state    <= (state == FOLD1) ? FOLD2 : CHECK;
                end

                CHECK: begin
                    if (!ip_ok)         begin drop_bad_ip <= 1'b1; state <= DROP; end
                    else if (!me_ok)    begin drop_not_me <= 1'b1; state <= DROP; end
                    else if (!proto_ok) begin drop_proto  <= 1'b1; state <= DROP; end
                    else if (!icmp_ok)  begin drop_icmp   <= 1'b1; state <= DROP; end
                    else begin
                        widx    <= 0;
                        hdr_sum <= 0;
                        state   <= HDR;
                    end
                end

                HDR: begin
                    tx_wr_en   <= 1'b1;
                    tx_wr_addr <= widx;
                    tx_wr_data <= hdr_byte(widx);
                    hdr_sum    <= hdr_sum + word_part(widx[0], hdr_byte(widx));
                    if (widx == 5'd19) state <= HFOLD1;
                    else               widx  <= widx + 1'b1;
                end

                HFOLD1, HFOLD2: begin
                    hdr_sum <= fold(hdr_sum);
                    widx    <= 0;
                    state   <= (state == HFOLD1) ? HFOLD2 : CSUM;
                end

                CSUM: begin
                    tx_wr_en <= 1'b1;
                    case (widx[1:0])
                        2'd0: begin tx_wr_addr <= 10; tx_wr_data <= ~hdr_sum[15:8]; end
                        2'd1: begin tx_wr_addr <= 11; tx_wr_data <= ~hdr_sum[7:0];  end
                        2'd2: begin tx_wr_addr <= 22; tx_wr_data <= ~rep_sum[15:8]; end
                        2'd3: begin tx_wr_addr <= 23; tx_wr_data <= ~rep_sum[7:0];  end
                    endcase
                    if (widx[1:0] == 2'd3) state <= COMMIT;
                    else                   widx  <= widx + 1'b1;
                end

                COMMIT: if (!tx_wr_en) begin        // last write has landed
                    replied <= 1'b1;
                    state   <= IDLE;
                end

                DROP: state <= IDLE;                // rx_release is high this cycle

                default: state <= IDLE;
            endcase
        end
    end
endmodule
