`timescale 1ns/1ps
module tb;
    reg clk = 0;
    always #20 clk = ~clk;

    reg btn = 0;

    initial begin
        #1000000;
        btn = 1; #100000; btn = 0;
        #20000000;
        btn = 1; #100000; btn = 0;
        #50000000;
        $finish;
    end

    random_second dut (
        .clk(clk),
        .btn_raw(btn),
        .led_onboard(),
        .led_ext()
    );
endmodule
