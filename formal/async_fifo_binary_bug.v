`timescale 1ns/1ps
// async_fifo_binary_bug.v : PLANTED CDC BUG, generated from async_fifo.v: the pointers cross the clock domains
//   in BINARY instead of Gray code (full / empty compare in binary). Passes RTL simulation, fails formal.
// async_fifo.v : asynchronous FIFO, write and read in unrelated clock domains (Cummings, SNUG 2002 style)
// Author: Meiyu Kuo
//   pointers are 1 bit wider than the address (to tell full from empty) and cross domains in Gray code
//   through 2-flop synchronizers: only one bit changes per step, so a pointer sampled mid-change is
//   either the old or the new value, never a wrong one
module async_fifo #(
    parameter DW = 8,                      // data width
    parameter AW = 4                       // address width: depth = 2**AW
) (
    input               wclk, wrst_n,
    input               winc,              // write wdata this cycle (ignored while wfull)
    input  [DW-1:0]     wdata,
    output reg          wfull,
    input               rclk, rrst_n,
    input               rinc,              // pop this cycle (ignored while rempty)
    output [DW-1:0]     rdata,             // head of the FIFO (valid while !rempty)
    output reg          rempty
);
    reg [DW-1:0] mem [0:(1<<AW)-1];
    reg [AW:0] wbin, wgray, rbin, rgray;   // own-domain pointers (binary and Gray)
    wire [AW:0] rgray_w2;                  // read pointer synchronized into the write domain
    wire [AW:0] wgray_r2;                  // write pointer synchronized into the read domain
    sync2 #(.W(AW+1)) u_sync_r2w (.clk(wclk), .rst_n(wrst_n), .d(rbin), .q(rgray_w2));
    sync2 #(.W(AW+1)) u_sync_w2r (.clk(rclk), .rst_n(rrst_n), .d(wbin), .q(wgray_r2));

    // ---- write domain ----
    wire [AW:0] wbin_next  = wbin + {{AW{1'b0}}, (winc && !wfull)};
    wire [AW:0] wgray_next = wbin_next ^ (wbin_next >> 1);
    always @(posedge wclk or negedge wrst_n)
        if (!wrst_n) begin wbin <= 0; wgray <= 0; wfull <= 0; end
        else begin
            wbin <= wbin_next; wgray <= wgray_next;
            // One lap ahead in binary flips the top two Gray bits (AW >= 1).
            wfull <= (wbin_next == {~rgray_w2[AW], rgray_w2[AW-1:0]});   // binary: top bit differs, rest equal
        end
    always @(posedge wclk)
        if (winc && !wfull) mem[wbin[AW-1:0]] <= wdata;

    // ---- read domain ----
    wire [AW:0] rbin_next  = rbin + {{AW{1'b0}}, (rinc && !rempty)};
    wire [AW:0] rgray_next = rbin_next ^ (rbin_next >> 1);
    always @(posedge rclk or negedge rrst_n)
        if (!rrst_n) begin rbin <= 0; rgray <= 0; rempty <= 1; end
        else begin
            rbin <= rbin_next; rgray <= rgray_next;
            rempty <= (rbin_next == wgray_r2);   // binary compare // next read pointer has caught up with the synchronized writer
        end
    assign rdata = mem[rbin[AW-1:0]];
`ifdef FORMAL
`include "fifo_props.vh"
`endif
endmodule
