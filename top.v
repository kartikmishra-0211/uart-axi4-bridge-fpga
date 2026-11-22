`timescale 1ns/1ps
//=============================================================================
// top.v  -  Nexys 4 DDR top level for the UART -> FIFO -> AXI bridge
//
//   PC (PuTTY) --USB-UART--> RsRx --2FF sync--> baud_gen + bridge --AXI--> axi_mem_slave (64x32)
//
// Clocks (from the Clocking Wizard IP "clk_wiz_0", input 100 MHz):
//   clkA = 100.0 MHz   UART side
//   clkB =  62.5 MHz   AXI side      (unrelated clocks -> the async FIFO is really used)
//
// Switches
//   sw[0]     wrap_en    1 = WRAP bursts, 0 = INCR bursts
//   sw[7:2]   word index of the memory word to display (0..63)
//   sw[8]     (unused)    The 8-digit display shows the whole 32-bit word at once.
//   sw[9]     start offset inside each 16-byte block: 0 -> +0x0, 1 -> +0x8 (shows WRAP clearly)
//   NOTE: sw[0] and sw[9] are captured by the master at the START of a burst, i.e. right
//         after the previous burst finished. Set them BEFORE pressing reset (btnC).
//
// Buttons
//   btnC      reset (everything, including the FIFO pointers and the burst address)
//
// 7-segment display: the full 32-bit word selected by sw[7:2], as 8 hex digits.
//
// LEDs
//   led[0]    parity error seen (sticky until reset)
//   led[1]    FIFO full        led[2]  FIFO empty      led[3]  clock wizard locked
//   led[7:4]  number of completed AXI bursts (low 4 bits)
//   led[13:8] write pointer (bytes received, mod 64)
//
// Each completed burst is written to the next 16-byte block: 0x00, 0x10, 0x20, ... (wraps at 0x100)
//=============================================================================
module top #(
    parameter integer BAUD_RATE = 9600
)(
    input  wire        clk,        // 100 MHz board oscillator (E3)
    input  wire        btnC,
    input  wire        RsRx,
    input  wire [15:0] sw,
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [7:0]  an
);

    // ---------------- clocks ----------------
    wire clkA, clkB, locked;
    clk_wiz_0 u_clk_wiz (
        .clk_in1 (clk),
        .clk_out1(clkA),
        .clk_out2(clkB),
        .locked  (locked)
    );

    // ---------------- resets (async assert, sync release, per domain) ----------------
    wire rst_req = btnC | ~locked;
    (* ASYNC_REG = "TRUE" *) reg [2:0] rstA_sr = 3'b111;
    (* ASYNC_REG = "TRUE" *) reg [2:0] rstB_sr = 3'b111;
    always @(posedge clkA) rstA_sr <= {rstA_sr[1:0], rst_req};
    always @(posedge clkB) rstB_sr <= {rstB_sr[1:0], rst_req};
    wire rstA = rstA_sr[2];
    wire rstB = rstB_sr[2];

    // ---------------- RX synchroniser (RsRx is asynchronous to clkA) ----------------
    (* ASYNC_REG = "TRUE" *) reg rx_s1 = 1'b1, rx_s2 = 1'b1;
    always @(posedge clkA) begin
        rx_s1 <= RsRx;
        rx_s2 <= rx_s1;
    end

    wire baud_tick;
    baud_gen #(.CLK_FREQ_HZ(100_000_000), .BAUD_RATE(BAUD_RATE)) u_baud (
        .clk(clkA), .rst(rstA), .rx(rx_s2), .baud_tick(baud_tick)
    );

    // ---------------- bridge ----------------
    wire        parity_error, done, full, empty, rd_en;
    wire [5:0]  wr_ptr, rd_ptr;
    wire [31:0] awaddr, wdata;
    wire [3:0]  awlen;
    wire [2:0]  awsize;
    wire [1:0]  awburst;
    wire        awvalid, wlast, wvalid, Bready, transfer_done;
    wire        awready, wready, Bvalid;
    wire [1:0]  Bresp;

    // burst start address: next 16-byte block, plus optional +8 offset (sw[9])
    reg  [3:0]  blk       = 4'd0;
    reg  [3:0]  burst_cnt = 4'd0;
    wire [31:0] addr_top  = {24'd0, blk, (sw[9] ? 4'h8 : 4'h0)};

    // advance on the AXI B-channel handshake: this happens one edge BEFORE the
    // master re-latches addr_top for the next burst, so the next burst sees the new value
    always @(posedge clkB) begin
        if (rstB) begin
            blk       <= 4'd0;
            burst_cnt <= 4'd0;
        end
        else if (Bvalid && Bready) begin
            blk       <= blk + 4'd1;
            burst_cnt <= burst_cnt + 4'd1;
        end
    end

    bridge u_bridge (
        .clkA(clkA), .clkB(clkB),
        .serial_in(rx_s2), .wr_en(1'b1), .baud_tick(baud_tick),
        .parity_error(parity_error), .done(done),
        .wr_ptr(wr_ptr), .full(full), .empty(empty), .rd_ptr(rd_ptr),
        .reset_ptr(rstA), .rd_en(rd_en),
        .addr_top(addr_top), .wrap_en(sw[0]),
        .awready(awready), .wready(wready), .Bvalid(Bvalid), .Bresp(Bresp),
        .rst(rstB),
        .awaddr(awaddr), .awlen(awlen), .awsize(awsize), .awburst(awburst), .awvalid(awvalid),
        .wdata(wdata), .wlast(wlast), .wvalid(wvalid), .Bready(Bready),
        .transfer_done(transfer_done)
    );

    // ---------------- AXI memory ----------------
    wire [31:0] mem_word;
    axi_mem_slave #(.ADDR_BITS(6)) u_slave (
        .clk(clkB), .rst(rstB),
        .awaddr(awaddr), .awburst(awburst), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wvalid(wvalid), .wlast(wlast), .wready(wready),
        .bvalid(Bvalid), .bresp(Bresp), .bready(Bready),
        .rd_addr(sw[7:2]), .rd_data(mem_word)
    );

    // ---------------- display ----------------
    seg7_driver u_seg (.clk(clkA), .value(mem_word), .seg(seg), .an(an));   // clkA = buffered 100 MHz from the MMCM
    assign dp = 1'b1;                        // decimal points off (active low)

    // ---------------- LEDs ----------------
    reg perr_sticky = 1'b0;
    always @(posedge clkA) begin
        if (rstA)              perr_sticky <= 1'b0;
        else if (parity_error) perr_sticky <= 1'b1;
    end

    assign led[0]    = perr_sticky;
    assign led[1]    = full;
    assign led[2]    = empty;
    assign led[3]    = locked;
    assign led[7:4]  = burst_cnt;
    assign led[13:8] = wr_ptr;
    assign led[15:14]= 2'b00;

endmodule
