`timescale 1ns/1ps
//=============================================================================
// seg7_driver.v  -  shows a 32-bit value as 8 hex digits on the Nexys 4 DDR display
// Segments and digit-enables are ACTIVE LOW (common-anode display).
// seg[0]=CA ... seg[6]=CG.   an[0] = right-most digit, an[7] = left-most.
// clk = 100 MHz -> each digit refreshed at ~190 Hz (no visible flicker).
//=============================================================================
module seg7_driver (
    input  wire        clk,
    input  wire [31:0] value,
    output reg  [6:0]  seg,
    output reg  [7:0]  an
);
    reg [18:0] refresh = 19'd0;
    always @(posedge clk) refresh <= refresh + 19'd1;

    wire [2:0] sel = refresh[18:16];
    reg  [3:0] nib;

    always @* begin
        an  = 8'b1111_1111;
        case (sel)
            3'd0: begin nib = value[3:0];   an[0] = 1'b0; end
            3'd1: begin nib = value[7:4];   an[1] = 1'b0; end
            3'd2: begin nib = value[11:8];  an[2] = 1'b0; end
            3'd3: begin nib = value[15:12]; an[3] = 1'b0; end
            3'd4: begin nib = value[19:16]; an[4] = 1'b0; end
            3'd5: begin nib = value[23:20]; an[5] = 1'b0; end
            3'd6: begin nib = value[27:24]; an[6] = 1'b0; end
            default: begin nib = value[31:28]; an[7] = 1'b0; end
        endcase
    end

    always @* begin
        case (nib)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            default: seg = 7'b0001110;   // F
        endcase
    end
endmodule
