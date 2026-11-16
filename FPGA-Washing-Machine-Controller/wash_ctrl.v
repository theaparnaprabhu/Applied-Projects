//==============================================================================
// File    : wash_ctrl.v
// Name : Aparna Prabhu     USN : NN25ECE031     Question : <your Q no.>
// Purpose : Washing machine controller (state machine).
//           IDLE -> FILL -> WASH -> RINSE -> SPIN -> DONE
// Ports   : clk        - 100 MHz clock
//           tick_1hz   - 1 s pulse (only arrives while running and door closed)
//           tick_4hz   - 0.25 s pulse, used for blinking
//           btn_start  - BTN0 press pulse (debounced)
//           btn_reset  - BTN1 press pulse (debounced)
//           sw_door    - SW0, 1 = door open
//           sec_clr    - tells the divider to restart its 1 s counter
//           sec_en     - tells the divider to count (0 = paused)
//           d3..d0     - display codes
//           led[3:0]   - LED0 fill, LED1 wash, LED2 rinse, LED3 spin
//==============================================================================
module wash_ctrl (
    input  wire       clk,
    input  wire       tick_1hz,
    input  wire       tick_4hz,
    input  wire       btn_start,
    input  wire       btn_reset,
    input  wire       sw_door,
    output wire       sec_clr,
    output wire       sec_en,
    output reg  [3:0] d3, d2, d1, d0,
    output wire [3:0] led
);
    // States. Values 1..4 are also the stage number shown on D3.
    localparam [2:0] IDLE = 0, FILL = 1, WASH = 2, RINSE = 3, SPIN = 4, DONE = 5;

    // Stage times in seconds.
    localparam [3:0] T_FILL = 5, T_WASH = 10, T_RINSE = 8, T_SPIN = 6;

    // Display codes (same as in seg7_decoder).
    localparam [3:0] BLANK = 4'hA, DASH = 4'hB, CH_E = 4'hC, CH_N = 4'hD, CH_D = 4'hE;

    reg [2:0] state = IDLE;             // power-on state = idle
    reg [3:0] secs  = 0;                // seconds left in this stage
    reg       door1 = 0, door = 0;      // SW0 passed through 2 flip-flops
    reg       blink = 1;                // blink phase for DONE

    wire running = (state >= FILL) && (state <= SPIN);

    // Counting is allowed only while running with the door closed.
    // When the door opens the divider just holds, so closing it resumes
    // from exactly the same point.
    assign sec_en  = running && !door;
    assign sec_clr = (state == IDLE) || (state == DONE);

    // Synchronise the door switch.
    always @(posedge clk) begin
        door1 <= sw_door;
        door  <= door1;
    end

    // State machine. Each stage counts secs down to 1, then loads the next stage.
    always @(posedge clk) begin
        if (btn_reset)
            state <= IDLE;                         // BTN1 works from any state
        else begin
            case (state)
                IDLE:  if (btn_start && !door) begin   // start only if door closed
                           state <= FILL;
                           secs  <= T_FILL;
                       end
                FILL:  if (tick_1hz) begin
                           if (secs == 1) begin state <= WASH;  secs <= T_WASH;  end
                           else secs <= secs - 1;
                       end
                WASH:  if (tick_1hz) begin
                           if (secs == 1) begin state <= RINSE; secs <= T_RINSE; end
                           else secs <= secs - 1;
                       end
                RINSE: if (tick_1hz) begin
                           if (secs == 1) begin state <= SPIN;  secs <= T_SPIN;  end
                           else secs <= secs - 1;
                       end
                SPIN:  if (tick_1hz) begin
                           if (secs == 1) state <= DONE;
                           else secs <= secs - 1;
                       end
                DONE:  ;                           // stay until BTN1
                default: state <= IDLE;
            endcase
        end
    end

    // Blink phase: toggles every 0.25 s in DONE, so LEDs blink at 2 Hz.
    always @(posedge clk) begin
        if (state != DONE)  blink <= 1;
        else if (tick_4hz)  blink <= ~blink;
    end

    // Seconds left (max 10) split into tens and ones digits.
    wire [3:0] tens = (secs >= 10) ? 4'd1 : 4'd0;
    wire [3:0] ones = (secs >= 10) ? secs - 4'd10 : secs;

    // Display for each state (defaults first so no latch is inferred).
    always @(*) begin
        d3 = BLANK; d2 = BLANK; d1 = BLANK; d0 = BLANK;
        case (state)
            IDLE: begin
                d3 = DASH; d2 = DASH; d1 = DASH; d0 = DASH;     // "----"
            end
            DONE: begin
                d3 = CH_E; d2 = CH_N; d1 = CH_D;                 // "End", D0 blank
            end
            default: begin
                d3 = {1'b0, state};                              // stage number
                d1 = tens;
                d0 = ones;
            end
        endcase
    end

    // LEDs: one per stage; all four blink in DONE.
    wire done = (state == DONE);
    assign led[0] = (state == FILL)  | (done & blink);
    assign led[1] = (state == WASH)  | (done & blink);
    assign led[2] = (state == RINSE) | (done & blink);
    assign led[3] = (state == SPIN)  | (done & blink);
endmodule
