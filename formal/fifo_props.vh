// fifo_props.vh : formal properties of async_fifo (included inside the module under `ifdef FORMAL)
//   clocks are free inputs (multiclock): any frequency ratio, any phase, even stopped clocks
//   both resets are asserted in the first step only
//   bmc and prove share these asserts; prove (k-induction) shows they hold forever, not just for N steps
    reg f_init = 1;
    always @($global_clock) f_init <= 0;
    always @(*) begin
        if (f_init) assume(!wrst_n && !rrst_n);
        else        assume(wrst_n && rrst_n);
    end
    function [AW:0] f_g2b(input [AW:0] g);    // Gray -> binary
        integer i;
        begin
            f_g2b[AW] = g[AW];
            for (i = AW - 1; i >= 0; i = i - 1) f_g2b[i] = f_g2b[i + 1] ^ g[i];
        end
    endfunction
`ifdef BUG_BINARY
    wire [AW:0] f_seen_r = rgray_w2, f_seen_w = wgray_r2;               // pointers crossed in binary
`else
    wire [AW:0] f_seen_r = f_g2b(rgray_w2), f_seen_w = f_g2b(wgray_r2);
`endif
    // differences are kept AW+1 bits wide: "a - b <= c" with a 32-bit c would be computed in 32 bits,
    // and 0 - 4 would be a huge number instead of 4 (wrap-around)
    wire [AW:0] f_occ   = wbin - rbin;          // words in the FIFO
    wire [AW:0] f_lag_r = rbin - f_seen_r;      // how far the write domain's view of rbin lags behind
    wire [AW:0] f_lag_w = wbin - f_seen_w;      // how far the read domain's view of wbin lags behind
    always @(*) if (!f_init) begin
        // CDC: a synchronized pointer may lag behind the real one, but must never be ahead of it
        a_rptr_not_ahead: assert(f_lag_r <= (1 << AW));
        a_wptr_not_ahead: assert(f_lag_w <= (1 << AW));
        // consequence: never more than DEPTH words, never a read from an empty FIFO
        a_no_overflow:    assert(f_occ <= (1 << AW));
    end
`ifndef BUG_BINARY
    // invariants for the unbounded proof (k-induction). bmc only checks the first N steps from reset;
    // induction also starts from ANY state that satisfies the asserts, so the asserts must be strong
    // enough to rule out unreachable states (e.g. wgray not matching wbin)
    // computed 1 bit wider: occupancy 4 + lag 4 = 8 would wrap to 0 in AW+1 bits and look like an empty FIFO
    wire [AW+1:0] f_wview = {1'b0, f_occ} + {1'b0, f_lag_r};
    always @(*) if (!f_init) begin
        a_wgray:  assert(wgray == (wbin ^ (wbin >> 1)));
        a_rgray:  assert(rgray == (rbin ^ (rbin >> 1)));
        a_wview:  assert(f_wview <= (1 << AW));                // words in the FIFO + read-pointer lag: never above DEPTH
        a_rview:  assert(f_lag_w <= f_occ);                    // the reader never sees words that are not there
        a_wfull:  assert(!(f_wview == (1 << AW)) || wfull);       // full as far as the writer can see -> wfull
        a_rempty: assert(!(f_seen_w == rbin) || rempty);              // empty as far as the reader can see -> rempty
    end
`endif
    // reachability: without these, a passing assert could be vacuous (e.g. the FIFO never fills)
    always @(*) if (!f_init) begin
        c_full:      cover(wfull);
        c_occ_max:   cover(f_occ == (1 << AW));
        c_wrap:      cover(wbin[AW] && rbin[AW]);         // both pointers wrapped once
    end
