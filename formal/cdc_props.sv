// cdc_props.sv : formal harnesses for the CDC library, with the metastability model of sync2.v / async_capture.v
//   clocks and data are free inputs (multiclock): any frequency ratio, any phase; resets in the first step only

// ---- pulse synchronizer: every source pulse gives exactly one destination pulse ----
module pulse_props (input sclk, dclk, spulse);
    reg f_init = 1;
    always @($global_clock) f_init <= 0;
    wire rst_n = !f_init;
    wire dpulse;
    pulse_sync dut (.sclk(sclk), .srst_n(rst_n), .spulse(spulse), .dclk(dclk), .drst_n(rst_n), .dpulse(dpulse));

    reg [3:0] f_sc = 0, f_dc = 0;                 // pulses sent / received (mod 16)
    always @(posedge sclk) if (rst_n && spulse) f_sc <= f_sc + 1;
    always @(posedge dclk) if (rst_n && dpulse) f_dc <= f_dc + 1;
    wire [3:0] f_inflight = f_sc - f_dc;
    // usage rule: a new pulse only after the previous one has arrived (e.g. pulses far enough apart)
    always @(*) if (f_inflight != 0) assume(!spulse);
    always @(*) if (!f_init) begin
        a_no_dup_no_loss: assert(f_inflight <= 1);  // never more pulses out than in, never two in flight
    end
    always @(*) if (!f_init) begin
        c_three: cover(f_dc == 3);                  // three pulses delivered
    end
endmodule

// ---- bus synchronizer (handshake_sync, or the planted bug bus_sync_bug) ----
module bus_props #(parameter W = 4) (input sclk, dclk, send, input [W-1:0] sdata);
    reg f_init = 1;
    always @($global_clock) f_init <= 0;
    wire rst_n = !f_init;
    wire sready, dvalid;
    wire [W-1:0] ddata;
`ifdef BUG
    bus_sync_bug #(.W(W)) dut (
`else
    handshake_sync #(.W(W)) dut (
`endif
        .sclk(sclk), .srst_n(rst_n), .send(send), .sdata(sdata), .sready(sready),
        .dclk(dclk), .drst_n(rst_n), .dvalid(dvalid), .ddata(ddata));

    reg [W-1:0] f_last = 0, f_prev = 0;           // the last two values handed to the synchronizer
    reg [3:0]   f_sc = 0, f_dc = 0;
    always @(posedge sclk) if (rst_n && send && sready) begin f_prev <= f_last; f_last <= sdata; f_sc <= f_sc + 1; end
    always @(posedge dclk) if (rst_n && dvalid) f_dc <= f_dc + 1;
    wire [3:0] f_pend = f_sc - f_dc;              // words handed over but not yet delivered (4 bits: wraps cleanly)
`ifdef BUG
    // the naive bus has no ready: give it every chance by sending slowly (8 destination clock edges between
    // changes), so without metastability it would always show a real value
    reg f_sclk_q = 0, f_dclk_q = 0; reg [3:0] f_gap = 0;
    always @($global_clock) begin
        f_sclk_q <= sclk; f_dclk_q <= dclk;
        if (sclk && !f_sclk_q && send) f_gap <= 0;
        else if (dclk && !f_dclk_q && f_gap != 4'hf) f_gap <= f_gap + 1;
    end
    always @(*) if (f_gap < 8) assume(!send);
`endif
    always @(*) if (!f_init) begin
        // the destination only ever shows a value that was really sent (never a mix of two values)
        a_real_value: assert(!dvalid || ddata == f_last || ddata == f_prev);
`ifndef BUG
        // and it is exactly the next word in order: the destination may still be showing word n while the
        // source, already acknowledged, has handed over word n+1 (then word n is f_prev)
        a_in_order:   assert(!dvalid || (f_pend == 1 && ddata == f_last) || (f_pend == 2 && ddata == f_prev));
        a_no_loss:    assert(f_pend <= 2);                       // never a word overtaken
        a_no_dup:     assert(!dvalid || f_pend != 0);                // never a word delivered twice
`endif
    end
    always @(*) if (!f_init) begin
        c_three: cover(f_dc == 3 && dvalid);
    end
endmodule
