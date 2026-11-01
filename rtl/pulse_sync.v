`timescale 1ns/1ps
// pulse_sync.v : a 1-cycle pulse in the source clock domain -> a 1-cycle pulse in the destination domain
// Author: Meiyu Kuo
//   A 1-cycle pulse from a fast clock can fall between two edges of a slow clock and be missed by a plain
//   2-flop synchronizer. So the source turns each pulse into a TOGGLE (a level that stays), the level crosses
//   through sync2, and the destination turns each change of the level back into a 1-cycle pulse.
//   Usage rule: the next source pulse only after the previous one has arrived (about 3 destination cycles).
module pulse_sync (
    input  sclk, srst_n,
    input  spulse,
    input  dclk, drst_n,
    output dpulse
);
    reg stog;                 // source: flips on every pulse
    wire dtog;                // stog synchronized into the destination domain
    reg dtog_q;               // dtog one destination cycle ago

    // TODO 1: source toggle: reset to 0; on every sclk edge with spulse = 1, stog flips
    always @(posedge sclk or negedge srst_n)
        if (!srst_n) stog <= 0;
        else if (spulse) stog <= ~stog;

    sync2 #(.W(1)) u_sync (.clk(dclk), .rst_n(drst_n), .d(stog), .q(dtog));

    // TODO 2: destination edge detect: dtog_q follows dtog (reset 0), and dpulse = 1 when they differ
    always @(posedge dclk or negedge drst_n)
        if (!drst_n) dtog_q <= 0;
        else dtog_q <= dtog;
    assign dpulse = dtog ^ dtog_q;
endmodule
