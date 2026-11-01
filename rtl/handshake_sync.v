`timescale 1ns/1ps
// handshake_sync.v : multi-bit data across clock domains with a 2-phase (toggle) req / ack handshake
// Author: Meiyu Kuo
//   Source: when ready, store the word in sbuf and flip sreq. sbuf then stays still until the handshake ends.
//   Destination: sreq arrives through sync2; when it differs from dack, a new word is waiting: load sbuf
//   (async_capture), raise dvalid for one cycle, and flip dack to match.
//   Source: dack arrives through sync2 as sack; when sack == sreq, the word was taken: ready again.
//   Only sreq and dack are synchronized (1 bit each). The data bus is never sampled while it changes.
module handshake_sync #(parameter W = 8) (
    input              sclk, srst_n,
    input              send,
    input      [W-1:0] sdata,
    output             sready,
    input              dclk, drst_n,
    output reg         dvalid,
    output     [W-1:0] ddata
);
    reg sreq; reg [W-1:0] sbuf;          // source side
    wire sack;                           // dack synchronized into the source domain
    wire dreq; reg dack;                 // destination side
    wire dnew;                           // a new word is waiting in sbuf

    // TODO 3: source
    //   sready = (sreq == sack)
    //   on send && sready: flip sreq and load sbuf <= sdata (reset both to 0)
    assign sready = (sreq == sack);
    always @(posedge sclk or negedge srst_n)
        if (!srst_n) begin sreq <= 0; sbuf <= 0; end
        else if (send && sready) begin sreq <= ~sreq; sbuf <= sdata; end

    sync2 #(.W(1)) u_req (.clk(dclk), .rst_n(drst_n), .d(sreq), .q(dreq));
    sync2 #(.W(1)) u_ack (.clk(sclk), .rst_n(srst_n), .d(dack), .q(sack));

    // TODO 4: destination
    //   dnew = (dreq != dack)
    //   every dclk edge: dvalid <= dnew; and when dnew, dack <= dreq (reset both to 0)
    assign dnew = (dreq != dack);
    always @(posedge dclk or negedge drst_n)
        if (!drst_n) begin dvalid <= 0; dack <= 0; end
        else begin
            dvalid <= dnew;
            if (dnew) dack <= dreq;
        end

    async_capture #(.W(W)) u_data (.clk(dclk), .rst_n(drst_n), .en(dnew), .d(sbuf), .q(ddata));
endmodule
