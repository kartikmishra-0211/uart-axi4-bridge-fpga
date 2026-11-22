`timescale 1ns/1ps
//=============================================================================
// axi_mem_slave.v  -  small synthesizable AXI4 write-only memory (64 x 32 bit)
//
// Replaces the old simulation-only AXI_slave and is ALSO what you synthesize.
// It is written to match how the bridge's master behaves:
//   * awready is held high for the whole data phase (master only moves data
//     while awready is high) and dropped after the write response.
//   * wready is high during the data phase (master never stalls on it).
//   * Supports INCR (awburst=01) and WRAP (awburst=10, 16-byte boundary,
//     i.e. awlen=3 x 4-byte beats).
//   * Bvalid is held until Bready; Bresp is always OKAY (00).
//
// Extra read port (rd_addr/rd_data) is only for displaying memory on the board.
//=============================================================================
module axi_mem_slave #(
    parameter ADDR_BITS = 6                 // number of WORD address bits (64 words = 256 bytes)
)(
    input  wire                 clk,
    input  wire                 rst,

    input  wire [31:0]          awaddr,
    input  wire [1:0]           awburst,
    input  wire                 awvalid,
    output reg                  awready,

    input  wire [31:0]          wdata,
    input  wire                 wvalid,
    input  wire                 wlast,
    output reg                  wready,

    output reg                  bvalid,
    output wire [1:0]           bresp,
    input  wire                 bready,

    input  wire [ADDR_BITS-1:0] rd_addr,
    output reg  [31:0]          rd_data
);

    reg [31:0] mem [0:(1<<ADDR_BITS)-1];
    integer k;
    initial begin
        for (k = 0; k < (1<<ADDR_BITS); k = k + 1)
            mem[k] = 32'd0;
        rd_data = 32'd0;
    end

    assign bresp = 2'b00;

    localparam S_IDLE = 2'd0, S_DATA = 2'd1, S_RESP = 2'd2;
    reg [1:0]  st = S_IDLE;
    reg [31:0] cur_addr = 32'd0;
    reg [1:0]  burst    = 2'b01;

    wire [31:0] incr_addr = cur_addr + 32'd4;
    wire [31:0] wrap_addr = {cur_addr[31:4], incr_addr[3:0]};      // stay inside the 16-byte block
    wire [31:0] next_addr = (burst == 2'b10) ? wrap_addr : incr_addr;

    initial begin
        awready = 1'b0;
        wready  = 1'b0;
        bvalid  = 1'b0;
    end

    always @(posedge clk) begin
        if (rst) begin
            st      <= S_IDLE;
            awready <= 1'b0;
            wready  <= 1'b0;
            bvalid  <= 1'b0;
        end
        else begin
            case (st)
            S_IDLE: if (awvalid) begin
                cur_addr <= awaddr;
                burst    <= awburst;
                awready  <= 1'b1;
                wready   <= 1'b1;
                st       <= S_DATA;
            end
            S_DATA: if (wvalid) begin
                mem[cur_addr[ADDR_BITS+1:2]] <= wdata;
                cur_addr <= next_addr;
                if (wlast) begin
                    wready <= 1'b0;
                    bvalid <= 1'b1;
                    st     <= S_RESP;
                end
            end
            S_RESP: if (bready) begin
                bvalid  <= 1'b0;
                awready <= 1'b0;
                st      <= S_IDLE;
            end
            default: st <= S_IDLE;
            endcase
        end
    end

    // synchronous read port (lets Vivado infer RAM)
    always @(posedge clk)
        rd_data <= mem[rd_addr];

endmodule
