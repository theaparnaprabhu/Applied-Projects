//==============================================================================
// File    : display_mux.v
// Name : Aparna Prabhu     USN : NN25ECE031     Question : <your Q no.>
// Purpose : Shows 4 digits on ONE 4-digit display by lighting one digit at a time.
// Ports   : clk, tick_1khz - clock and 1 ms pulse (1 digit per ms -> each digit
//                            refreshed at 1000/4 = 250 Hz, no visible flicker)
//           d3,d2,d1,d0    - codes for the 4 digits (see seg7_decoder)
//           an[3:0]        - digit selects, ACTIVE LOW. an[3] = D3 ... an[0] = D0
//           seg[6:0]       - segment lines {g..a}, ACTIVE LOW (seg[0] = a)
//           dp             - decimal point, kept off
//==============================================================================
module display_mux (
    input  wire       clk,
    input  wire       tick_1khz,
    input  wire [3:0] d3, d2, d1, d0,
    output wire [3:0] an,
    output wire [6:0] seg,
    output wire       dp
);
    reg [1:0] scan = 0;                 // which digit is lit now
    reg [3:0] code;                     // code of that digit
    reg [3:0] sel;                      // one-hot select, 1 = this digit ON
    wire [6:0] seg_on;                  // segment pattern, 1 = ON

    // Moves to the next digit every 1 ms.
    always @(posedge clk)
        if (tick_1khz) scan <= scan + 1;

    // Chooses the digit code and its select line.
    always @(*) begin
        case (scan)
            2'd0:    begin code = d0; sel = 4'b0001; end
            2'd1:    begin code = d1; sel = 4'b0010; end
            2'd2:    begin code = d2; sel = 4'b0100; end
            default: begin code = d3; sel = 4'b1000; end
        endcase
    end

    seg7_decoder dec (.code(code), .seg(seg_on));

    // The board lines are active low, so invert.
    assign seg = ~seg_on;
    assign an  = ~sel;
    assign dp  = 1'b1;
endmodule
