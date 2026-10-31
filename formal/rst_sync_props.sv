// rst_sync_props.sv : properties of rst_sync (wrapper, so rst_sync.v stays plain Verilog)
//   arst_n and clk are free inputs: the reset may change at any time, even next to a clock edge
module rst_sync_props (input clk, input arst_n);
    wire rst_n_sync;
    rst_sync dut (.clk(clk), .arst_n(arst_n), .rst_n_sync(rst_n_sync));
    reg f_init = 1, clk_q = 0, arst_q = 0, out_q = 0;
    always @($global_clock) begin f_init <= 0; clk_q <= clk; arst_q <= arst_n; out_q <= rst_n_sync; end
    always @(*) if (f_init) assume(!arst_n);              // start in reset
    always @(*) if (!f_init) begin
        // asynchronous assertion: while the raw reset is low, the domain is in reset (no clock needed)
        a_assert_async: assert(arst_n || !rst_n_sync);
        // synchronous deassertion: the output only rises on a rising clock edge
        a_release_sync: assert(!(rst_n_sync && !out_q) || (clk && !clk_q));
        // and only after the raw reset was already high before that edge (at least the 2nd flip-flop stage)
        a_release_late: assert(!(rst_n_sync && !out_q) || arst_q);
    end
    always @(*) if (!f_init) begin
        c_release:   cover(rst_n_sync && !out_q);
        c_reassert:  cover(out_q && !rst_n_sync && !clk && !clk_q);   // back into reset with the clock stopped
    end
endmodule
