//==============================================================================
// File    : debouncer.v
// Name : Aparna Prabhu     USN : NN25ECE031     Question : <your Q no.>
// Purpose : Debounces a push button and gives ONE pulse per press.
// Ports   : clk       - 100 MHz clock
//           tick_1khz - 1 ms enable pulse
//           btn_in    - raw button (bounces when pressed)
//           press     - 1 clock wide pulse at the press edge
//==============================================================================
module debouncer (
    input  wire clk,
    input  wire tick_1khz,
    input  wire btn_in,
    output wire press
);
    localparam DEB_MS = 15;             // 15 ticks x 1 ms = 15 ms (limit 10-20 ms)

    reg       sync1 = 0, sync2 = 0;     // 2 flip-flops: bring the button into the clock domain
    reg       stable = 0;               // debounced button level
    reg       prev   = 0;               // stable one clock ago (for edge detection)
    reg [4:0] cnt    = 0;               // ms for which the input has differed from 'stable'

    // Synchroniser: avoids metastability from the asynchronous button.
    always @(posedge clk) begin
        sync1 <= btn_in;
        sync2 <= sync1;
    end

    // Debounce: 'stable' follows the input only after it has held 15 ms.
    always @(posedge clk) begin
        if (tick_1khz) begin
            if (sync2 == stable)
                cnt <= 0;
            else if (cnt == DEB_MS - 1) begin
                stable <= sync2;
                cnt    <= 0;
            end else
                cnt <= cnt + 1;
        end
    end

    // Edge detector: remember the old level, pulse when it goes 0 -> 1.
    always @(posedge clk)
        prev <= stable;

    assign press = stable & ~prev;
endmodule
