`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2026 06:16:25 PM
// Design Name: 
// Module Name: tx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tx(
    input  wire       clk,
    input  wire       rst,
    input  wire       baud_tick,
    input  wire [7:0] data,
    input  wire       send,

    output wire       tx_line,
    output wire       busy
);
    localparam IDLE  = 4'd0,   // line high, waiting for send
               LOAD  = 4'd1,   // byte latched, waiting for next baud boundary
               START = 4'd2,   // driving start bit (0)
               D0    = 4'd3,   // driving data bit 0 (LSB)
               D1    = 4'd4,
               D2    = 4'd5,
               D3    = 4'd6,
               D4    = 4'd7,
               D5    = 4'd8,
               D6    = 4'd9,
               D7    = 4'd10,  // driving data bit 7 (MSB)
               STOP  = 4'd11;  // driving stop bit (1)

    reg [3:0] state;
    reg [7:0] shreg;
    reg       line;

    assign tx_line = line;
    assign busy    = (state != IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            shreg <= 8'h00;
            line  <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    line <= 1'b1;
                    if (send) begin
                        shreg <= data;
                        state <= LOAD;
                    end
                end
                LOAD: if (baud_tick) begin
                    line  <= 1'b0;
                    state <= START;
                end
                START, D0, D1, D2, D3, D4, D5, D6: if (baud_tick) begin
                    line  <= shreg[0];
                    shreg <= {1'b0, shreg[7:1]};
                    state <= state + 1'b1;
                end
                D7: if (baud_tick) begin
                    line  <= 1'b1;
                    state <= STOP;
                end
                STOP: if (baud_tick) begin
                    state <= IDLE;
                end
                default: begin
                    line  <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
