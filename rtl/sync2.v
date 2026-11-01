`timescale 1ns/1ps
// sync2.v : 2-flop synchronizer for a bus crossing into the clk domain
//   Safe only if at most one bit of d changes at a time (Gray code): each bit may settle a cycle late,
//   and with one changing bit the result is still either the old or the new value.
module sync2 #(
    parameter W = 5,
    /* verilator lint_off UNUSEDPARAM */  // used only under `ifdef FORMAL
    parameter F_GRAY = 0                  // formal only: 1 = d is a Gray-coded counter (adds induction invariants)
    /* verilator lint_on UNUSEDPARAM */
) (
    input              clk, rst_n,
    input      [W-1:0] d,
    output reg [W-1:0] q
);
    reg [W-1:0] meta;                     // first stage: may go metastable, never used directly
`ifndef FORMAL
    always @(posedge clk or negedge rst_n)
        if (!rst_n) {q, meta} <= 0;
        else        {q, meta} <= {meta, d};
`else
    // formal model of metastability: a bit that changed just before the sampling edge may settle to its
    // old or its new value (chosen freely by the solver), independently of the other bits.
    // "Just before" = in this or the previous solver step; older changes have settled.
    reg  [W-1:0] d_q = 0, d_qq = 0;       // d one and two solver steps ago
    always @($global_clock) begin
        d_q  <= d;
        d_qq <= d_q;
    end
    wire [W-1:0] d_old = (d != d_q) ? d_q : d_qq;   // value before the most recent change
    wire [W-1:0] late  = $anyseq;                   // 1 = this bit still shows its old value
    wire [W-1:0] seen  = (late & d_old) | (~late & d);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) {q, meta} <= 0;
        else        {q, meta} <= {meta, seen};

    // invariants for the unbounded proof (k-induction): d counts up by at most 1 per solver step, and the
    // chain d -> meta -> q only lags, never runs ahead (all differences are W bits wide = modulo 2**W)
    function [W-1:0] g2b(input [W-1:0] g);
        integer i;
        begin
            g2b[W-1] = g[W-1];
            for (i = W - 2; i >= 0; i = i - 1) g2b[i] = g2b[i + 1] ^ g[i];
        end
    endfunction
    wire [W-1:0] step1    = g2b(d)    - g2b(d_q);
    wire [W-1:0] step2    = g2b(d_q)  - g2b(d_qq);
    wire [W-1:0] lag_meta = g2b(d)    - g2b(meta);
    wire [W-1:0] lag_q    = g2b(d)    - g2b(q);
    generate if (F_GRAY) begin : g_inv
        // d keeps counting while this domain is still in reset (the other domain may already run),
        // so the step asserts are not gated by rst_n, only skipped for the first 2 steps (history not filled)
        reg [1:0] f_age = 0;
        always @($global_clock) if (f_age != 2'd3) f_age <= f_age + 1'b1;
        always @(*) if (f_age >= 2) begin
            a_step1: assert(step1 <= 1);
            a_step2: assert(step2 <= 1);
        end
        always @(*) if (rst_n) a_chain: assert(lag_meta <= lag_q);     // meta is between q and d
    end endgenerate
`endif
endmodule
