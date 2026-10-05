`timescale 1ns / 1ps

module tb_counter_4bit();

    reg clk;
    reg rst;

    wire [3:0] count;

    counter_4bit #(
        .DIV_LIMIT(26'd4)
    ) uut (
        .clk(clk),
        .rst(rst),
        .count(count)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;

        #40;
        rst = 0;

        #8578;

        rst = 1;
        #3000;
        rst = 0;

        #4000;

        $finish;
    end

endmodule