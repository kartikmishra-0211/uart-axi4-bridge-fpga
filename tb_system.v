`timescale 1ns/1ps
//=============================================================================
// tb_system.v  -  self-checking testbench (set this as the SIMULATION top)
//
// Exercises exactly the modules that go on the FPGA:
//     baud_gen  ->  bridge  ->  axi_mem_slave
// with   clkA = 100 MHz,  clkB = 62.5 MHz   (unrelated clocks)
//
// What it checks (prints PASS/FAIL and a final summary):
//   * 5 bursts x 16 bytes sent as real UART frames (start, 8 data LSB first,
//     even parity, stop) with random phase and random idle gaps
//   * UART bit time deliberately off by -2%..+2% on some bursts
//   * burst 1: INCR  @0x00      burst 2: WRAP @0x18 (unaligned!)  + one frame with BAD parity
//   * burst 3: INCR  @0x40      burst 4: INCR  @0x80              burst 5: WRAP @0xC4
//   * FIFO pointers wrap past 63
//   * every one of the 64 memory words is compared with the expected value
//   * transfer_done count, AXI beat count, parity flag behaviour, FIFO never full
//
// The testbench uses a 1 Mbaud UART (100 clocks per bit) instead of 9600 baud
// purely to keep the simulation short. Hardware uses 9600 (see top.v).
//
// NOTE on addr_top / wrap_en: the master latches them at the START of each
// burst, i.e. right after the previous burst finished. So the settings for
// burst N+1 must be applied while burst N is still being sent. The loop below
// does exactly that.
//=============================================================================
module tb_system;

    reg clkA = 0, clkB = 0;
    always #5 clkA = ~clkA;          // 100 MHz
    always #8 clkB = ~clkB;          // 62.5 MHz

    reg rst = 1'b1;

    // serial line + 2-flop synchroniser (same as top.v)
    reg serial_raw = 1'b1;
    reg rx_s1 = 1'b1, rx_s2 = 1'b1;
    always @(posedge clkA) begin
        rx_s1 <= serial_raw;
        rx_s2 <= rx_s1;
    end

    reg         wrap_en  = 1'b0;
    reg  [31:0] addr_top = 32'd0;

    wire        baud_tick;
    wire        parity_error, done, full, empty, rd_en;
    wire [5:0]  wr_ptr, rd_ptr;
    wire [31:0] awaddr, wdata;
    wire [3:0]  awlen;
    wire [2:0]  awsize;
    wire [1:0]  awburst;
    wire        awvalid, wlast, wvalid, Bready, transfer_done;
    wire        awready, wready, Bvalid;
    wire [1:0]  Bresp;
    reg  [5:0]  rd_addr = 6'd0;
    wire [31:0] rd_data;

    baud_gen #(.CLK_FREQ_HZ(100_000_000), .BAUD_RATE(1_000_000)) u_baud (
        .clk(clkA), .rst(rst), .rx(rx_s2), .baud_tick(baud_tick));

    bridge dut (
        .clkA(clkA), .clkB(clkB), .serial_in(rx_s2), .wr_en(1'b1), .baud_tick(baud_tick),
        .parity_error(parity_error), .done(done),
        .wr_ptr(wr_ptr), .full(full), .empty(empty), .rd_ptr(rd_ptr),
        .reset_ptr(rst), .rd_en(rd_en),
        .addr_top(addr_top), .wrap_en(wrap_en),
        .awready(awready), .wready(wready), .Bvalid(Bvalid), .Bresp(Bresp),
        .rst(rst),
        .awaddr(awaddr), .awlen(awlen), .awsize(awsize), .awburst(awburst), .awvalid(awvalid),
        .wdata(wdata), .wlast(wlast), .wvalid(wvalid), .Bready(Bready), .transfer_done(transfer_done));

    axi_mem_slave #(.ADDR_BITS(6)) u_slave (
        .clk(clkB), .rst(rst),
        .awaddr(awaddr), .awburst(awburst), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wvalid(wvalid), .wlast(wlast), .wready(wready),
        .bvalid(Bvalid), .bresp(Bresp), .bready(Bready),
        .rd_addr(rd_addr), .rd_data(rd_data));

    // ---------------- monitors ----------------
    integer td_count   = 0;
    integer beat_count = 0;
    reg     saw_perr   = 1'b0;
    reg     saw_full   = 1'b0;

    always @(posedge clkB) begin
        if (transfer_done) td_count <= td_count + 1;
        if (wvalid && wready) beat_count <= beat_count + 1;
    end
    always @(posedge clkA) begin
        if (parity_error) saw_perr <= 1'b1;
        if (full)         saw_full <= 1'b1;
    end
    always @(posedge transfer_done)
        $display("[%0d ns] AXI burst complete (#%0d)  awaddr=%h", $time, td_count + 1, awaddr);

    // ---------------- UART transmitter model ----------------
    integer bit_cycles = 100;
    integer seed = 32'h1BADB002;

    task send_bit(input b);
        begin
            serial_raw = b;
            repeat (bit_cycles) @(posedge clkA);
        end
    endtask

    // start(0) + 8 data bits LSB first + parity (even) + stop(1)
    task send_byte(input [7:0] d, input bad_par);
        integer i;
        reg p;
        begin
            p = ^d;
            if (bad_par) p = ~p;
            send_bit(1'b0);
            for (i = 0; i < 8; i = i + 1)
                send_bit(d[i]);
            send_bit(p);
            send_bit(1'b1);
        end
    endtask

    // ---------------- test data / configuration ----------------
    reg  [7:0]  sent     [0:79];
    reg  [31:0] cfg_addr [0:4];
    reg         cfg_wrap [0:4];
    integer     cfg_bits [0:4];
    reg  [31:0] exp_mem  [0:63];

    integer errors = 0;
    integer b, i, w, k2;
    integer t0;
    reg [31:0] a, word;

    initial begin
        cfg_addr[0] = 32'h00; cfg_wrap[0] = 0; cfg_bits[0] = 100;
        cfg_addr[1] = 32'h18; cfg_wrap[1] = 1; cfg_bits[1] = 101;   // +1 %
        cfg_addr[2] = 32'h40; cfg_wrap[2] = 0; cfg_bits[2] = 99;    // -1 %
        cfg_addr[3] = 32'h80; cfg_wrap[3] = 0; cfg_bits[3] = 102;   // +2 %
        cfg_addr[4] = 32'hC4; cfg_wrap[4] = 1; cfg_bits[4] = 98;    // -2 %

        for (b = 0; b < 5; b = b + 1)
            for (i = 0; i < 16; i = i + 1)
                if (b == 0)      sent[16*b+i] = 8'h10 + i;
                else if (b == 1) sent[16*b+i] = 8'h20 + i;
                else             sent[16*b+i] = $random(seed);

        // configuration for burst 0 must be in place BEFORE reset is released
        wrap_en  = cfg_wrap[0];
        addr_top = cfg_addr[0];
        repeat (10) @(posedge clkA);
        @(negedge clkB);
        rst = 1'b0;
        repeat (20) @(posedge clkA);

        for (b = 0; b < 5; b = b + 1) begin
            // settings for the NEXT burst (latched by the master when this one ends)
            if (b < 4) begin
                wrap_en  = cfg_wrap[b+1];
                addr_top = cfg_addr[b+1];
            end
            bit_cycles = cfg_bits[b];

            for (i = 0; i < 16; i = i + 1) begin
                #({$random(seed)} % 10);                         // random sub-clock phase
                send_byte(sent[16*b+i], (b == 1 && i == 5));    // burst 1, byte 5: bad parity
                repeat ({$random(seed)} % 8) @(posedge clkA);   // 0..7 idle clocks
            end

            t0 = $time;
            while (td_count < b + 1 && ($time - t0) < 200000) #100;
            if (td_count < b + 1) begin
                $display("FAIL: burst %0d never completed", b + 1);
                errors = errors + 1;
            end
            repeat (200) @(posedge clkB);

            if (b == 0 && saw_perr) begin
                $display("FAIL: parity_error flagged although all frames so far were good");
                errors = errors + 1;
            end
            if (b == 1 && !saw_perr) begin
                $display("FAIL: parity_error NOT flagged for the bad-parity frame");
                errors = errors + 1;
            end
            if (b == 1 && saw_perr)
                $display("PASS: bad-parity frame was flagged");
        end

        // ---- expected memory image ----
        for (w = 0; w < 64; w = w + 1) exp_mem[w] = 32'd0;
        for (b = 0; b < 5; b = b + 1) begin
            a = cfg_addr[b];
            for (k2 = 0; k2 < 4; k2 = k2 + 1) begin
                word = {sent[16*b+4*k2+3], sent[16*b+4*k2+2], sent[16*b+4*k2+1], sent[16*b+4*k2]};
                exp_mem[a[7:2]] = word;
                if (cfg_wrap[b]) a = {a[31:4], a[3:0] + 4'd4};
                else             a = a + 32'd4;
            end
        end

        for (w = 0; w < 64; w = w + 1)
            if (u_slave.mem[w] !== exp_mem[w]) begin
                $display("FAIL: mem[%0d] (byte addr 0x%02h) = %h, expected %h", w, w*4, u_slave.mem[w], exp_mem[w]);
                errors = errors + 1;
            end

        if (td_count !== 5) begin
            $display("FAIL: expected 5 transfer_done pulses, got %0d", td_count); errors = errors + 1;
        end
        if (beat_count !== 20) begin
            $display("FAIL: expected 20 AXI data beats, got %0d", beat_count); errors = errors + 1;
        end
        if (saw_full) begin
            $display("FAIL: FIFO reported full during test"); errors = errors + 1;
        end
        if (wr_ptr !== 6'd16 || rd_ptr !== 6'd16) begin
            $display("FAIL: pointers wr=%0d rd=%0d, expected 16/16 (80 bytes, wrapped past 63)", wr_ptr, rd_ptr);
            errors = errors + 1;
        end

        $display("--------------------------------------------------");
        if (errors == 0) $display("ALL TESTS PASSED  (80 bytes, 5 AXI bursts, memory image matches)");
        else             $display("TESTS FAILED: %0d error(s)", errors);
        $display("--------------------------------------------------");
        $finish;
    end

    // global watchdog
    initial begin
        #5_000_000;
        $display("FAIL: global timeout");
        $finish;
    end

endmodule
