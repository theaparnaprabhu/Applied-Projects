//==============================================================================
// File    : tb_wash_ctrl.v
// Name : Aparna Prabhu     USN : NN25ECE031     Question : <your Q no.>
// Purpose : Testbench for wash_ctrl. The divider is replaced by a fast model:
//           1 "second" = 20 clocks, 0.25 s = 5 clocks.
//==============================================================================
`timescale 1ns/1ps
module tb_wash_ctrl;
    reg clk = 0, btn_start = 0, btn_reset = 0, sw_door = 0;
    reg tick_1hz = 0, tick_4hz = 0;
    wire sec_clr, sec_en;
    wire [3:0] d3, d2, d1, d0, led;
    reg [3:0] saved;
    integer c1 = 0, c4 = 0;

    wash_ctrl dut (.clk(clk), .tick_1hz(tick_1hz), .tick_4hz(tick_4hz),
                   .btn_start(btn_start), .btn_reset(btn_reset), .sw_door(sw_door),
                   .sec_clr(sec_clr), .sec_en(sec_en),
                   .d3(d3), .d2(d2), .d1(d1), .d0(d0), .led(led));

    always #5 clk = ~clk;                         // 100 MHz

    // Fast model of the 1 s counter: clears, holds and counts like the real divider.
    always @(posedge clk) begin
        tick_1hz <= 0;
        if (sec_clr) c1 <= 0;
        else if (sec_en) begin
            if (c1 == 19) begin c1 <= 0; tick_1hz <= 1; end
            else c1 <= c1 + 1;
        end
    end
    // Fast model of the 0.25 s tick.
    always @(posedge clk) begin
        tick_4hz <= 0;
        if (c4 == 4) begin c4 <= 0; tick_4hz <= 1; end
        else c4 <= c4 + 1;
    end

    task press_start; begin btn_start = 1; @(posedge clk); btn_start = 0; repeat (3) @(posedge clk); end endtask
    task press_reset; begin btn_reset = 1; @(posedge clk); btn_reset = 0; repeat (3) @(posedge clk); end endtask
    task wait_sec(input integer n); begin repeat (n*20 + 6) @(posedge clk); end endtask   // n "seconds"

    initial begin
        $dumpfile("tb_wash_ctrl.vcd"); $dumpvars(0, tb_wash_ctrl);
        repeat (5) @(posedge clk);
        $display("%s power-on idle", (dut.state == 0 && d0 == 4'hB) ? "PASS" : "FAIL");

        sw_door = 1; repeat (4) @(posedge clk); press_start;      // door open: ignored
        $display("%s start ignored, door open", (dut.state == 0) ? "PASS" : "FAIL");

        sw_door = 0; repeat (4) @(posedge clk); press_start;      // real start
        $display("%s fill: 1 05, LED0", (d3 == 1 && d1 == 0 && d0 == 5 && led == 4'b0001) ? "PASS" : "FAIL");
        press_start;                                              // ignored while running
        $display("%s start ignored while running", (dut.state == 1) ? "PASS" : "FAIL");

        wait_sec(5);
        $display("%s wash: 2 10, LED1", (d3 == 2 && d1 == 1 && d0 == 0 && led == 4'b0010) ? "PASS" : "FAIL");

        wait_sec(3);                                              // 3 s of wash done
        sw_door = 1; repeat (4) @(posedge clk); saved = dut.secs;
        wait_sec(5);
        $display("%s paused with door open", (dut.secs == saved && dut.state == 2) ? "PASS" : "FAIL");

        sw_door = 0; wait_sec(7);
        $display("%s resumed, now rinse", (dut.state == 3) ? "PASS" : "FAIL");

        wait_sec(14);                                             // rinse 8 + spin 6
        $display("%s End shown", (dut.state == 5 && d3 == 4'hC && d2 == 4'hD && d1 == 4'hE) ? "PASS" : "FAIL");
        saved[0] = led[0]; repeat (5) @(posedge clk);
        $display("%s LEDs blink", (led[0] != saved[0]) ? "PASS" : "FAIL");

        press_reset;
        $display("%s reset to idle", (dut.state == 0 && led == 0) ? "PASS" : "FAIL");
        $finish;
    end
endmodule
