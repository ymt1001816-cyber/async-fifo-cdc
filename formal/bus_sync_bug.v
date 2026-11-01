`timescale 1ns/1ps
// bus_sync_bug.v : PLANTED CDC BUG: a multi-bit bus where every bit has its own 2-flop synchronizer.
//   Each bit is safe on its own, but the bits can settle in different cycles, so the destination can see a
//   value the source never had. Passes RTL simulation (no metastability there), fails formal.
module bus_sync_bug #(parameter W = 8) (
    input              sclk, srst_n,
    input              send,
    input      [W-1:0] sdata,
    output             sready,
    input              dclk, drst_n,
    output reg         dvalid,
    output     [W-1:0] ddata
);
    reg [W-1:0] sbuf;
    assign sready = 1'b1;
    always @(posedge sclk or negedge srst_n)
        if (!srst_n) sbuf <= 0;
        else if (send) sbuf <= sdata;
    sync2 #(.W(W)) u_bus (.clk(dclk), .rst_n(drst_n), .d(sbuf), .q(ddata));
    reg [W-1:0] ddata_q;
    always @(posedge dclk or negedge drst_n)
        if (!drst_n) begin ddata_q <= 0; dvalid <= 1'b0; end
        else begin ddata_q <= ddata; dvalid <= (ddata != ddata_q); end
endmodule
