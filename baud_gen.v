`timescale 1ns/1ps
//=============================================================================
// baud_gen.v  -  start-bit-synchronised baud tick generator
//
// The bridge's UART receiver samples serial_in once per baud_tick. For that to
// be reliable, the ticks must land in the MIDDLE of each bit. A free-running
// divider cannot guarantee this (its phase is random relative to the start bit,
// so some frames would be sampled right on a bit edge and corrupted).
//
// So: while idle, wait for the falling edge of the start bit, then emit
//   tick #1 after half a bit   (middle of the start bit)
//   tick #2..#11 every full bit (middle of 8 data bits, parity bit, stop bit)
// and go idle again. 11 ticks = one frame of: start + 8 data + parity + stop.
//
// rx MUST be the same (already synchronised) signal the bridge uses as serial_in.
//
// Default: 100 MHz clock, 9600 baud -> 10416 clocks per bit.
//=============================================================================
module baud_gen #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9600,
    parameter integer FRAME_TICKS = 11
)(
    input  wire clk,
    input  wire rst,
    input  wire rx,
    output reg  baud_tick = 1'b0
);

    localparam integer DIV  = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer HALF = DIV / 2;

    reg        busy  = 1'b0;
    reg        rx_d  = 1'b1;
    reg [15:0] cnt   = 16'd0;
    reg [3:0]  ticks = 4'd0;

    always @(posedge clk) begin
        rx_d      <= rx;
        baud_tick <= 1'b0;

        if (rst) begin
            busy  <= 1'b0;
            cnt   <= 16'd0;
            ticks <= 4'd0;
        end
        else if (!busy) begin
            if (rx_d && !rx) begin          // falling edge = start bit begins
                busy  <= 1'b1;
                cnt   <= 16'd0;
                ticks <= 4'd0;
            end
        end
        else begin
            if (cnt == ((ticks == 4'd0) ? (HALF - 1) : (DIV - 1))) begin
                baud_tick <= 1'b1;
                cnt       <= 16'd0;
                ticks     <= ticks + 4'd1;
                if (ticks == FRAME_TICKS - 1)
                    busy <= 1'b0;
            end
            else
                cnt <= cnt + 16'd1;
        end
    end

endmodule
