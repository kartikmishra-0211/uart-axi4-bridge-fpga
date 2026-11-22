`timescale 1ns/1ps
//=============================================================================
// bridge.v  -  UART receiver -> async FIFO -> AXI4 write master
//
// Based on the original design. Changes vs. the original (all marked "CHG"):
//   CHG1  wvalid<=1 added in the incremental-burst branch (the hang bug).
//   CHG2  Internal fake AXI_slave removed. awready/wready/Bvalid/Bresp are now
//         genuine inputs driven by axi_mem_slave (or any AXI target).
//   CHG3  Gray pointers are REGISTERED in their own domain before being
//         synchronised into the other domain (no combinational glitches
//         crossing the clock boundary).
//   CHG4  empty is computed in clkB from the OWN read pointer, full in clkA
//         from the OWN write pointer (each flag now compares own pointer with
//         the synchronised pointer of the other domain).
//   CHG5  Reset hooks:  reset_ptr  = reset for the clkA side (UART, wr_ptr,
//         clkA sync flops).   rst  = reset for the clkB side (AXI FSM, rd_ptr,
//         clkB sync flops).  Assert both together.
//   CHG6  ASYNC_REG attributes on the synchroniser flops, init values on
//         done / parity_error.
//
// A burst is 4 beats x 4 bytes = 16 bytes. rd_en is only high when the
// synchronised write pointer is at 0/16/32/48, so a burst starts each time
// another 16 bytes have been received.
//=============================================================================
module bridge(

input clkA,
input clkB,
input serial_in,
input wr_en,
input baud_tick,
output reg parity_error=0,
output reg done=0,
output reg [5:0]wr_ptr=0,
output full,
output empty,
output reg [5:0]rd_ptr=0,
input reset_ptr,
output rd_en,

input [31:0]addr_top,
input wrap_en,
input awready,
input wready,
input Bvalid,
input [1:0]Bresp,
input rst,
output reg [31:0]awaddr,
output reg [3:0]awlen,
output reg [2:0]awsize,
output reg [1:0]awburst,
output reg awvalid,
output reg [31:0]wdata,
output reg wlast,
output reg wvalid,
output reg Bready,
output reg transfer_done
);

reg [7:0]fifo[0:31];
reg [2:0]countA;
reg [7:0]shift_regA;

//-------------------UART Receiver and writing data into the fifo-----------------

reg [1:0]stateA=0;
parameter s0=0,s1=1,s2=2,s3=3;

always@(posedge clkA)
if(reset_ptr)                                  // CHG5
begin
stateA<=s0;
wr_ptr<=0;
done<=0;
parity_error<=0;
countA<=0;
shift_regA<=0;
end
else
case(stateA)
s0: if(baud_tick && !serial_in)          // initialising all the values
       begin
       shift_regA<=0;
       countA<=0;
       done<=0;
       parity_error<=0;
       stateA<=s1;
       end
s1: if(baud_tick)
       begin
       shift_regA[countA]<=serial_in;
       countA<=countA+1;
       if(countA==7)
       begin
       countA<=0;
       stateA<=s2;
       end
       end
s2: if(baud_tick)
       begin
       if(serial_in!=^shift_regA)
       parity_error<=1;
       else
       parity_error<=0;
       stateA<=s3;
       end
s3: if(baud_tick)
       if(serial_in)
       begin
       done<=1;
       if(wr_en && !full)
       begin
       fifo[wr_ptr[4:0]]<=shift_regA;
       wr_ptr<=wr_ptr+1;
       end
       stateA<=s0;
       end

endcase

// ---------- binary to gray conversion----------------------------------

wire [5:0]wr_ptr_g,rd_ptr_g;

assign wr_ptr_g=(wr_ptr)^(wr_ptr>>1);
assign rd_ptr_g=(rd_ptr)^(rd_ptr>>1);

// CHG3: register the Gray value in its own domain; only these registered,
// one-bit-at-a-time values cross into the other clock domain.
reg [5:0]wr_ptr_gr=0;      // clkA domain
reg [5:0]rd_ptr_gr=0;      // clkB domain
always@(posedge clkA) wr_ptr_gr<=wr_ptr_g;
always@(posedge clkB) rd_ptr_gr<=rd_ptr_g;

//------------dual synchroniser--------------------------------------------

(* ASYNC_REG = "TRUE" *) reg [5:0]wr_ptr_g1=0,wr_ptr_g2=0;   // write ptr seen in clkB
(* ASYNC_REG = "TRUE" *) reg [5:0]rd_ptr_g1=0,rd_ptr_g2=0;   // read  ptr seen in clkA

always@(posedge clkB)
if(rst)                                         // CHG5 (was reset_ptr)
begin
wr_ptr_g1<=0;
wr_ptr_g2<=0;
end
else
begin
wr_ptr_g1<=wr_ptr_gr;
wr_ptr_g2<=wr_ptr_g1;
end

always@(posedge clkA)
if(reset_ptr)
begin
rd_ptr_g1<=0;
rd_ptr_g2<=0;
end
else
begin
rd_ptr_g1<=rd_ptr_gr;
rd_ptr_g2<=rd_ptr_g1;
end

//--------------------empty and full conditions assignment-----------------
// CHG4: each flag compares the OWN pointer with the synchronised other one.
//   empty (clkB):  synchronised write ptr == own read ptr
//   full  (clkA):  own write ptr is exactly one lap ahead of synchronised read ptr
//                  (Gray code: top two bits inverted, rest equal)

assign empty=(wr_ptr_g2==rd_ptr_g);
assign full=((rd_ptr_g2[5]==~wr_ptr_g[5]) && (rd_ptr_g2[4]==~wr_ptr_g[4]) && (rd_ptr_g2[3:0]==wr_ptr_g[3:0]));

assign rd_en=(wr_ptr_g2==6'b000000||wr_ptr_g2==6'b011000||wr_ptr_g2==6'b110000||wr_ptr_g2==6'b101000)?1:0;


//------------------AXI master and reading data from fifo--------------------

reg [31:0]shift_regB;
reg [1:0]countB;
reg [1:0]cycleB;
reg [31:0]wrap_base;

reg [2:0]stateB;
parameter sB0=0,sB1=1,sB2=2,sB3=3;

always@(posedge clkB)
if(rst)
begin
awvalid<=0;
wvalid<=0;
Bready<=0;
wlast<=0;
shift_regB<=0;
countB<=0;
cycleB<=0;
transfer_done<=0;
rd_ptr<=0;                                      // CHG5
stateB<=sB0;
end
else
begin
case(stateB)
sB0: begin
     awaddr<=addr_top;
     awlen<=4'b0011;     // 4 number of data transfers at a time
     awsize<=3'b010;     // each data packet of 4 byte size
     transfer_done<=0;
     if(wrap_en)
     begin
     awburst<=2'b10;     // represents wrapping burst
     wrap_base<=addr_top & ~(32'h00000010-1);   // 16 byte wrap boundary
     end
     else
     awburst<=2'b01;      // incremental burst
     awvalid<=1;          // indicates all my address and control signals are valid
     stateB<=sB1;
     end
sB1: if(awready)
     begin
     awvalid<=0;
     wvalid<=0;
     if(wrap_en && rd_en && !empty)   // reading data from fifo in wrapping burst
     begin
     shift_regB<={fifo[rd_ptr[4:0]],shift_regB[31:8]};
     rd_ptr<=rd_ptr+1;
     countB<=countB+1;
     if(countB==3)
     begin
     countB<=0;
     wvalid<=1;
     rd_ptr<=rd_ptr+1;
     wdata<={fifo[rd_ptr[4:0]],shift_regB[31:8]};
     if(awaddr==wrap_base+12)      // e.g. awaddr==12 and wrap base 0 -> next addr wraps to 0
        awaddr<=wrap_base;
     else
        awaddr<=awaddr+4;
     cycleB<=cycleB+1;
     if(cycleB==3)
     begin
     wlast<=1;
     cycleB<=0;
     stateB<=sB2;
     end
     end
     end
     else if(!wrap_en && rd_en && !empty)  // reading data from fifo in incremental burst
     begin
     shift_regB<={fifo[rd_ptr[4:0]],shift_regB[31:8]};
     rd_ptr<=rd_ptr+1;
     countB<=countB+1;
     if(countB==3)
     begin
     countB<=0;
     wvalid<=1;                        // CHG1  (missing in the original -> hang)
     rd_ptr<=rd_ptr+1;
     wdata<={fifo[rd_ptr[4:0]],shift_regB[31:8]};
     awaddr<=awaddr+4;
     cycleB<=cycleB+1;
     if(cycleB==3)
     begin
     wlast<=1;
     cycleB<=0;
     stateB<=sB2;
     end
     end
     end
     end
sB2: if(wready)
     begin
     wvalid<=0;
     wlast<=0;
     Bready<=1;
     stateB<=sB3;
     end
sB3: if(Bvalid && Bresp==2'b00)     // BRESP = 2'b00 : OKAY
     begin
     Bready<=0;
     transfer_done<=1;
     stateB<=sB0;
     end
endcase
end

// CHG2: AXI_slave instantiation removed. Connect awready/wready/Bvalid/Bresp
//       to a real AXI target (axi_mem_slave.v) from outside this module.

endmodule
