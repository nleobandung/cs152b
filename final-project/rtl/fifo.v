`timescale 1ns / 1ps

// Synchronous first-word-fall-through FIFO.
// rd_data shows the head entry whenever empty == 0; assert rd_en to pop it.
// Writes while full and reads while empty are ignored.
// DEPTH must be a power of 2. Small depths map to distributed (LUT) RAM.
module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 64
)(
    input  wire             clk,
    input  wire             rst,

    input  wire [WIDTH-1:0] wr_data,
    input  wire             wr_en,
    output wire             full,

    output wire [WIDTH-1:0] rd_data,
    input  wire             rd_en,
    output wire             empty
);
    localparam AW = $clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW:0]      wptr = 0, rptr = 0;     // extra MSB tells full from empty

    assign empty   = (wptr == rptr);
    assign full    = (wptr[AW] != rptr[AW]) && (wptr[AW-1:0] == rptr[AW-1:0]);
    assign rd_data = mem[rptr[AW-1:0]];

    always @(posedge clk) begin
        if (rst) begin
            wptr <= 0;
            rptr <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wptr[AW-1:0]] <= wr_data;
                wptr <= wptr + 1'b1;
            end
            if (rd_en && !empty)
                rptr <= rptr + 1'b1;
        end
    end
endmodule
