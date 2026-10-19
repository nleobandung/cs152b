`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 10:43:14 AM
// Design Name: 
// Module Name: tb_top_module
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


// Testbench for top_module (16-bit ALU).
// Directed edge cases for every opcode, each with a hand-specified expected
// result, overflow flag, and zero flag.
module tb_top_module;
    reg  [15:0] A, B;
    reg  [3:0]  ALUCtrl;
    wire [15:0] S;
    wire overflow, zero;

    integer errors = 0, tests = 0;

    top_module dut(.A(A), .B(B), .ALUCtrl(ALUCtrl), .overflow(overflow), .zero(zero), .S(S));

    task check(input [3:0] op_in, input [15:0] a_in, input [15:0] b_in,
               input [15:0] exp_s, input exp_ov, input exp_z);
        begin
            ALUCtrl = op_in; A = a_in; B = b_in;
            #10;
            tests = tests + 1;
            if (S !== exp_s || overflow !== exp_ov || zero !== exp_z) begin
                errors = errors + 1;
                $display("FAIL op=%b A=%h B=%h | S=%h ov=%b z=%b | expected S=%h ov=%b z=%b",
                         op_in, a_in, b_in, S, overflow, zero, exp_s, exp_ov, exp_z);
            end
        end
    endtask

    initial begin
        // 0000 subtraction (signed)
        check(4'b0000, 16'h000A, 16'h0003, 16'h0007, 1'b0, 1'b0);  // 10 - 3 = 7
        check(4'b0000, 16'h0005, 16'h0005, 16'h0000, 1'b0, 1'b1);  // equal: zero
        check(4'b0000, 16'h0003, 16'h000A, 16'hFFF9, 1'b0, 1'b0);  // 3 - 10 = -7
        check(4'b0000, 16'h8000, 16'h0001, 16'h7FFF, 1'b1, 1'b0);  // INT_MIN - 1: underflow
        check(4'b0000, 16'h7FFF, 16'hFFFF, 16'h8000, 1'b1, 1'b0);  // INT_MAX - (-1): overflow
        check(4'b0000, 16'h0000, 16'h8000, 16'h8000, 1'b1, 1'b0);  // 0 - INT_MIN: overflow
        check(4'b0000, 16'hFFFF, 16'h7FFF, 16'h8000, 1'b0, 1'b0);  // -1 - INT_MAX = INT_MIN, no overflow

        // 0001 addition (signed)
        check(4'b0001, 16'h0064, 16'h00C8, 16'h012C, 1'b0, 1'b0);  // 100 + 200 = 300
        check(4'b0001, 16'h7FFF, 16'h0001, 16'h8000, 1'b1, 1'b0);  // INT_MAX + 1: overflow
        check(4'b0001, 16'h8000, 16'hFFFF, 16'h7FFF, 1'b1, 1'b0);  // INT_MIN + (-1): underflow
        check(4'b0001, 16'h8000, 16'h8000, 16'h0000, 1'b1, 1'b1);  // INT_MIN + INT_MIN: underflow, zero
        check(4'b0001, 16'hFFFF, 16'h0001, 16'h0000, 1'b0, 1'b1);  // -1 + 1 = 0, carry out is not overflow
        check(4'b0001, 16'h7FFF, 16'h8000, 16'hFFFF, 1'b0, 1'b0);  // mixed signs never overflow

        // 0010 bitwise OR
        check(4'b0010, 16'hF0F0, 16'h0F0F, 16'hFFFF, 1'b0, 1'b0);  // complementary
        check(4'b0010, 16'hA5A5, 16'h0000, 16'hA5A5, 1'b0, 1'b0);  // identity
        check(4'b0010, 16'h0000, 16'h0000, 16'h0000, 1'b0, 1'b1);  // zero

        // 0011 bitwise AND
        check(4'b0011, 16'hFF00, 16'h0FF0, 16'h0F00, 1'b0, 1'b0);  // overlap
        check(4'b0011, 16'hFFFF, 16'h1234, 16'h1234, 1'b0, 1'b0);  // identity
        check(4'b0011, 16'hF0F0, 16'h0F0F, 16'h0000, 1'b0, 1'b1);  // disjoint: zero

        // 0100 decrement (B ignored)
        check(4'b0100, 16'h0001, 16'h1234, 16'h0000, 1'b0, 1'b1);  // 1 - 1 = 0
        check(4'b0100, 16'h0000, 16'hFFFF, 16'hFFFF, 1'b0, 1'b0);  // 0 - 1 = -1
        check(4'b0100, 16'h7FFF, 16'h0000, 16'h7FFE, 1'b0, 1'b0);  // INT_MAX - 1
        check(4'b0100, 16'h8000, 16'h0000, 16'h7FFF, 1'b1, 1'b0);  // INT_MIN - 1: underflow

        // 0101 increment (B ignored)
        check(4'b0101, 16'h0000, 16'hFFFF, 16'h0001, 1'b0, 1'b0);  // 0 + 1
        check(4'b0101, 16'hFFFF, 16'h0000, 16'h0000, 1'b0, 1'b1);  // -1 + 1 = 0
        check(4'b0101, 16'h8000, 16'h0000, 16'h8001, 1'b0, 1'b0);  // INT_MIN + 1
        check(4'b0101, 16'h7FFF, 16'h0000, 16'h8000, 1'b1, 1'b0);  // INT_MAX + 1: overflow

        // 0110 two's complement invert (B ignored)
        check(4'b0110, 16'h0005, 16'h1234, 16'hFFFB, 1'b0, 1'b0);  // -(5) = -5
        check(4'b0110, 16'hFFFB, 16'h0000, 16'h0005, 1'b0, 1'b0);  // -(-5) = 5
        check(4'b0110, 16'hFFFF, 16'h0000, 16'h0001, 1'b0, 1'b0);  // -(-1) = 1
        check(4'b0110, 16'h7FFF, 16'h0000, 16'h8001, 1'b0, 1'b0);  // -(INT_MAX)
        check(4'b0110, 16'h0000, 16'h0000, 16'h0000, 1'b0, 1'b1);  // -(0) = 0
        check(4'b0110, 16'h8000, 16'h0000, 16'h8000, 1'b1, 1'b0);  // -(INT_MIN): overflow

        // 1000 logical shift left
        check(4'b1000, 16'h0001, 16'h0004, 16'h0010, 1'b0, 1'b0);  // basic
        check(4'b1000, 16'hA5A5, 16'h0000, 16'hA5A5, 1'b0, 1'b0);  // shift 0
        check(4'b1000, 16'h8001, 16'h0001, 16'h0002, 1'b0, 1'b0);  // MSB shifted out
        check(4'b1000, 16'h0001, 16'h000F, 16'h8000, 1'b0, 1'b0);  // max shift
        check(4'b1000, 16'hFFFF, 16'h0010, 16'h0000, 1'b0, 1'b1);  // shift = 16
        check(4'b1000, 16'hFFFF, 16'h0011, 16'h0000, 1'b0, 1'b1);  // shift = 17, not 1

        // 1001 set less than or equal (signed)
        check(4'b1001, 16'h0003, 16'h0005, 16'h0001, 1'b0, 1'b0);  // 3 <= 5
        check(4'b1001, 16'h0005, 16'h0005, 16'h0001, 1'b0, 1'b0);  // equal
        check(4'b1001, 16'h0006, 16'h0005, 16'h0000, 1'b0, 1'b1);  // 6 <= 5 false
        check(4'b1001, 16'hFFFF, 16'h0000, 16'h0001, 1'b0, 1'b0);  // -1 <= 0 (unsigned would be false)
        check(4'b1001, 16'h0000, 16'hFFFF, 16'h0000, 1'b0, 1'b1);  // 0 <= -1 false
        check(4'b1001, 16'h8000, 16'h7FFF, 16'h0001, 1'b0, 1'b0);  // INT_MIN <= INT_MAX (A-B overflows)
        check(4'b1001, 16'h7FFF, 16'h8000, 16'h0000, 1'b0, 1'b1);  // INT_MAX <= INT_MIN false
        check(4'b1001, 16'h8000, 16'h8000, 16'h0001, 1'b0, 1'b0);  // INT_MIN == INT_MIN

        // 1010 logical shift right
        check(4'b1010, 16'hF000, 16'h0004, 16'h0F00, 1'b0, 1'b0);  // basic
        check(4'b1010, 16'h8000, 16'h0001, 16'h4000, 1'b0, 1'b0);  // zero-fill, not sign-fill
        check(4'b1010, 16'hFFFF, 16'h000F, 16'h0001, 1'b0, 1'b0);  // max shift
        check(4'b1010, 16'h0001, 16'h0001, 16'h0000, 1'b0, 1'b1);  // shifted out: zero
        check(4'b1010, 16'hFFFF, 16'h0010, 16'h0000, 1'b0, 1'b1);  // shift = 16
        check(4'b1010, 16'hFFFF, 16'h8000, 16'h0000, 1'b0, 1'b1);  // huge shift (B[15] only)

        // 1100 arithmetic shift left (overflow when the sign changes)
        check(4'b1100, 16'h0003, 16'h0002, 16'h000C, 1'b0, 1'b0);  // basic
        check(4'b1100, 16'hC000, 16'h0001, 16'h8000, 1'b0, 1'b0);  // stays negative
        check(4'b1100, 16'hFFFF, 16'h000F, 16'h8000, 1'b0, 1'b0);  // -1 -> INT_MIN, stays negative
        check(4'b1100, 16'h4000, 16'h0001, 16'h8000, 1'b1, 1'b0);  // positive -> negative: overflow
        check(4'b1100, 16'h8000, 16'h0001, 16'h0000, 1'b1, 1'b1);  // negative -> 0: overflow, zero
        check(4'b1100, 16'h7FFF, 16'h0010, 16'h0000, 1'b0, 1'b1);  // shift = 16, sign unchanged
        check(4'b1100, 16'h8000, 16'h0011, 16'h0000, 1'b1, 1'b1);  // shift = 17, sign lost

        // 1110 arithmetic shift right (sign-fill)
        check(4'b1110, 16'h7000, 16'h0004, 16'h0700, 1'b0, 1'b0);  // positive
        check(4'b1110, 16'h8000, 16'h0004, 16'hF800, 1'b0, 1'b0);  // sign-fill
        check(4'b1110, 16'h8000, 16'h000F, 16'hFFFF, 1'b0, 1'b0);  // max shift, negative
        check(4'b1110, 16'hFFFD, 16'h0001, 16'hFFFE, 1'b0, 1'b0);  // -3 >> 1 = -2 (rounds down)
        check(4'b1110, 16'h0001, 16'h0001, 16'h0000, 1'b0, 1'b1);  // shifted out: zero
        check(4'b1110, 16'h8000, 16'h0010, 16'hFFFF, 1'b0, 1'b0);  // shift = 16, negative
        check(4'b1110, 16'h7FFF, 16'h0011, 16'h0000, 1'b0, 1'b1);  // shift = 17, positive

        $display("%0d tests, %0d errors", tests, errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        $finish;
    end
endmodule
