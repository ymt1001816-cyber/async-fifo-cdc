`timescale 1ns/1ps
// async_capture.v : a register in the clk domain that loads a bus from ANOTHER clock domain when en = 1.
//   Safe only if the bus has been stable for a while when en is 1 (a handshake guarantees it).
//   Under FORMAL, a bit that changed in this or the previous solver step may be loaded as its old or new
//   value (the same metastability model as sync2.v), so the formal check proves the bus really is stable.
module async_capture #(parameter W = 8) (
    input              clk, rst_n,
    input              en,
    input      [W-1:0] d,
    output reg [W-1:0] q
);
`ifndef FORMAL
    always @(posedge clk or negedge rst_n)
        if (!rst_n) q <= 0;
        else if (en) q <= d;
`else
    reg  [W-1:0] d_q = 0, d_qq = 0;
    always @($global_clock) begin d_q <= d; d_qq <= d_q; end
    wire [W-1:0] d_old = (d != d_q) ? d_q : d_qq;
    wire [W-1:0] late  = $anyseq;
    wire [W-1:0] seen  = (late & d_old) | (~late & d);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) q <= 0;
        else if (en) q <= seen;
`endif
endmodule
