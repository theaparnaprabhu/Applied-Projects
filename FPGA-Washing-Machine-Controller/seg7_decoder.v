//==============================================================================
// File    : seg7_decoder.v
// Name : Aparna Prabhu     USN : NN25ECE031     Question : <your Q no.>
// Purpose : Converts a code to seven-segment pattern (1 = segment ON).
// Ports   : code - 0..9 = digits, A = blank, B = '-', C = 'E', D = 'n', E = 'd'
//           seg  - {g,f,e,d,c,b,a}
//==============================================================================
module seg7_decoder (
    input  wire [3:0] code,
    output reg  [6:0] seg
);
    // Look-up table. 'default' covers every other code, so no latch is inferred.
    always @(*) begin
        case (code)
            4'd0:    seg = 7'b0111111;
            4'd1:    seg = 7'b0000110;
            4'd2:    seg = 7'b1011011;
            4'd3:    seg = 7'b1001111;
            4'd4:    seg = 7'b1100110;
            4'd5:    seg = 7'b1101101;
            4'd6:    seg = 7'b1111101;
            4'd7:    seg = 7'b0000111;
            4'd8:    seg = 7'b1111111;
            4'd9:    seg = 7'b1101111;
            4'hB:    seg = 7'b1000000;   // '-'
            4'hC:    seg = 7'b1111001;   // E
            4'hD:    seg = 7'b1010100;   // n
            4'hE:    seg = 7'b1011110;   // d
            default: seg = 7'b0000000;   // blank
        endcase
    end
endmodule
