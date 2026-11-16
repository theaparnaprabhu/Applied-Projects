//==============================================================================
// File    : washer_top.v
// Name : Aparna Prabhu     USN : NN25ECE031     Question : <your Q no.>
// Purpose : Top module - only connects the other modules.
// Ports   : clk        - 100 MHz clock
//           btn[1:0]   - BTN1 (reset), BTN0 (start)
//           sw0        - SW0 door (1 = open)
//           led[15:0]  - LED0..3 stages, LED15 door open, others off
//           an[3:0], seg[6:0], dp - the display that is USED (digit selects,
//                         segments, decimal point; all active low)
//           an_off[3:0], seg_off[6:0], dp_off - the OTHER display, held blank
//==============================================================================
module washer_top (
    input  wire        clk,
    input  wire [1:0]  btn,
    input  wire        sw0,
    output wire [15:0] led,
    output wire [3:0]  an,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [3:0]  an_off,
    output wire [6:0]  seg_off,
    output wire        dp_off
);
    wire tick_1khz, tick_1hz, tick_4hz;
    wire start_p, reset_p;
    wire sec_clr, sec_en;
    wire [3:0] d3, d2, d1, d0;
    wire [3:0] led_stage;

    clock_divider u_div (.clk(clk), .sec_clr(sec_clr), .sec_en(sec_en),
                         .tick_1khz(tick_1khz), .tick_1hz(tick_1hz), .tick_4hz(tick_4hz));

    debouncer u_db0 (.clk(clk), .tick_1khz(tick_1khz), .btn_in(btn[0]), .press(start_p));
    debouncer u_db1 (.clk(clk), .tick_1khz(tick_1khz), .btn_in(btn[1]), .press(reset_p));

    wash_ctrl u_core (.clk(clk), .tick_1hz(tick_1hz), .tick_4hz(tick_4hz),
                      .btn_start(start_p), .btn_reset(reset_p), .sw_door(sw0),
                      .sec_clr(sec_clr), .sec_en(sec_en),
                      .d3(d3), .d2(d2), .d1(d1), .d0(d0), .led(led_stage));

    display_mux u_disp (.clk(clk), .tick_1khz(tick_1khz),
                        .d3(d3), .d2(d2), .d1(d1), .d0(d0),
                        .an(an), .seg(seg), .dp(dp));

    assign led = {sw0, 11'b0, led_stage};     // LED15 = door open

    // The unused display: all digit selects and segments OFF (active low -> 1).
    assign an_off  = 4'b1111;
    assign seg_off = 7'b1111111;
    assign dp_off  = 1'b1;
endmodule
