//==============================================================================
// File    : clock_divider.v
// Name : Aparna Prabhu     USN : NN25ECE031     Question : <your Q no.>
// Purpose : Makes enable pulses (1 clock wide) from the 100 MHz clock.
// Ports   : clk       - 100 MHz board clock
//           sec_clr   - 1 = restart the 1 s counter from 0
//           sec_en    - 1 = 1 s counter runs, 0 = it holds (pause)
//           tick_1khz - pulse every 1 ms   (display scan + debounce)
//           tick_1hz  - pulse every 1 s    (stage countdown, only while sec_en = 1)
//           tick_4hz  - pulse every 0.25 s (2 Hz blink = toggle every 0.25 s)
//==============================================================================
module clock_divider (
    input  wire clk,
    input  wire sec_clr,
    input  wire sec_en,
    output reg  tick_1khz = 0,
    output reg  tick_1hz  = 0,
    output reg  tick_4hz  = 0
);
    localparam DIV_1KHZ = 100_000;      // 100 MHz / 1 kHz = 100,000 clocks
    localparam DIV_1HZ  = 100_000_000;  // 100 MHz / 1 Hz  = 100,000,000 clocks
    localparam DIV_4HZ  = 25_000_000;   // 100 MHz / 4 Hz  = 25,000,000 clocks

    reg [26:0] cnt_1khz = 0;            // 27 bits hold up to 134 million
    reg [26:0] cnt_1hz  = 0;
    reg [26:0] cnt_4hz  = 0;

    // Counts 100,000 clocks, then gives one tick_1khz pulse.
    always @(posedge clk) begin
        tick_1khz <= 0;
        if (cnt_1khz == DIV_1KHZ - 1) begin
            cnt_1khz  <= 0;
            tick_1khz <= 1;
        end else
            cnt_1khz <= cnt_1khz + 1;
    end

    // Counts 1 s only while sec_en = 1. Holds when paused, clears when sec_clr = 1.
    always @(posedge clk) begin
        tick_1hz <= 0;
        if (sec_clr)
            cnt_1hz <= 0;
        else if (sec_en) begin
            if (cnt_1hz == DIV_1HZ - 1) begin
                cnt_1hz  <= 0;
                tick_1hz <= 1;
            end else
                cnt_1hz <= cnt_1hz + 1;
        end
    end

    // Counts 25,000,000 clocks, then gives one tick_4hz pulse.
    always @(posedge clk) begin
        tick_4hz <= 0;
        if (cnt_4hz == DIV_4HZ - 1) begin
            cnt_4hz  <= 0;
            tick_4hz <= 1;
        end else
            cnt_4hz <= cnt_4hz + 1;
    end
endmodule
