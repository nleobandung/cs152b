`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 10:32:53 AM
// Design Name: 
// Module Name: top_module
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


module top_module(
    input wire[15:0] A,
    input wire[15:0] B,
    input wire[3:0] ALUCtrl,
    output wire overflow,
    output wire zero,
    output wire[15:0] S
    );

    wire[15:0] out_sub, out_add, out_or, out_and, out_dec, out_inc, out_inv;
    wire[15:0] out_lsl, out_lsr, out_asl, out_asr;
    wire out_sle;
    wire ov_sub, ov_add, ov_dec, ov_inc, ov_inv, ov_asl;
    wire[15:0] ov_bus;

    subtraction        u_sub   (.A(A), .B(B), .overflow(ov_sub), .S(out_sub));  // 0000
    addition           u_add   (.A(A), .B(B), .overflow(ov_add), .S(out_add));  // 0001
    bitwise_or         u_or    (.A(A), .B(B), .S(out_or));                      // 0010
    bitwise_and        u_and   (.A(A), .B(B), .S(out_and));                     // 0011
    decrement          u_dec   (.A(A), .overflow(ov_dec), .S(out_dec));         // 0100
    increment          u_inc   (.A(A), .overflow(ov_inc), .S(out_inc));         // 0101
    invert             u_inv   (.A(A), .overflow(ov_inv), .S(out_inv));         // 0110
    logical_shift_L    u_lsl   (.A(A), .B(B), .S(out_lsl));                     // 1000
    set_less_equal     u_sle   (.A(A), .B(B), .S(out_sle));                     // 1001
    logical_shift_R    u_lsr   (.A(A), .B(B), .S(out_lsr));                     // 1010
    arithmetic_shift_L u_asl   (.A(A), .B(B), .overflow(ov_asl), .S(out_asl));  // 1100
    arithmetic_shift_R u_asr   (.A(A), .B(B), .S(out_asr));                     // 1110

    // Result select (unused opcodes output 0)
    mux16bit u_mux(
        .A(out_sub),  .B(out_add),           .C(out_or),   .D(out_and),
        .E(out_dec),  .F(out_inc),           .G(out_inv),  .H(16'h0000),
        .I(out_lsl),  .J({15'b0, out_sle}),  .K(out_lsr),  .L(16'h0000),
        .M(out_asl),  .N(16'h0000),          .O(out_asr),  .P(16'h0000),
        .S0(ALUCtrl[0]), .S1(ALUCtrl[1]), .S2(ALUCtrl[2]), .S3(ALUCtrl[3]),
        .Q(S)
    );

    // Overflow select: each opcode's own overflow, carried on bit 0
    mux16bit u_ovmux(
        .A({15'b0, ov_sub}),  .B({15'b0, ov_add}),  .C(16'h0000),          .D(16'h0000),
        .E({15'b0, ov_dec}),  .F({15'b0, ov_inc}),  .G({15'b0, ov_inv}),  .H(16'h0000),
        .I(16'h0000),         .J(16'h0000),         .K(16'h0000),          .L(16'h0000),
        .M({15'b0, ov_asl}),  .N(16'h0000),         .O(16'h0000),          .P(16'h0000),
        .S0(ALUCtrl[0]), .S1(ALUCtrl[1]), .S2(ALUCtrl[2]), .S3(ALUCtrl[3]),
        .Q(ov_bus)
    );
    buf b_ov(overflow, ov_bus[0]);

    // Zero flag from the final result
    zero_detect u_zero(.A(S), .zero(zero));
endmodule
