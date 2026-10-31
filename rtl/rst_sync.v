`timescale 1ns/1ps
// rst_sync.v : reset synchronizer, asynchronous assertion, synchronous deassertion
// Author: Meiyu Kuo
//   assertion  : rst_n_sync goes low immediately when arst_n goes low (even with no clock running)
//   deassertion: rst_n_sync goes high only on a clk edge, 2 edges after arst_n goes high, so every
//                flip-flop in the domain leaves reset in the same cycle (no recovery / removal violation)
module rst_sync (
    input  clk,
    input  arst_n,           // raw asynchronous reset, active low, from outside this clock domain
    output rst_n_sync        // reset for this clock domain, active low
);
    // ff[1] drives the domain's asynchronous resets while ff is clocked: intended in a reset synchronizer
    /* verilator lint_off SYNCASYNCNET */
    reg [1:0] ff;
    /* verilator lint_on SYNCASYNCNET */

    always @(posedge clk or negedge arst_n)
        if (!arst_n) ff <= 2'b00;
        else ff <= {ff[0], 1'b1}; // release reset only after two local rising edges

    assign rst_n_sync = ff[1];
`ifdef FORMAL
    // induction invariant: the 1 enters at ff[0] first, so ff = 2'b10 can never happen
    always @(*) if (arst_n) a_ff_order: assert(!ff[1] || ff[0]);
`endif
endmodule
