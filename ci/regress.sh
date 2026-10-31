#!/bin/bash
# regress.sh : open-source regression (Verilator lint, cocotb + Icarus, SymbiYosys); exits non-zero if any check fails
#   usage: ci/regress.sh [lint|sim|formal|all]      (default all)
cd "$(dirname "$0")/.."; mkdir -p build; fails=0
check() {   # check <name> <log> <pattern that must appear>
  if grep -q "$3" "$2"; then echo "PASS  $1"; else echo "FAIL  $1  (see $2)"; fails=$((fails+1)); fi
}
what=${1:-all}
if [[ $what == lint || $what == all ]]; then
  verilator --lint-only -Wall --top-module async_fifo rtl/async_fifo.v rtl/sync2.v rtl/rst_sync.v > build/lint.log 2>&1 && echo LINT_CLEAN >> build/lint.log
  check "lint: Verilator -Wall clean" build/lint.log LINT_CLEAN
fi
if [[ $what == sim || $what == all ]]; then   # 3 seeds x 3 tests (fast writer, fast reader, random clock ratios)
  for s in 1 2 3; do
    (cd tb && rm -rf sim_build && make COCOTB_RANDOM_SEED=$s > ../build/sim_$s.log 2>&1)
    check "sim seed $s: scoreboard, full/empty and almost-full/empty safety, coverage" build/sim_$s.log "FAIL=0 SKIP="
  done
  # the planted binary-crossing bug: RTL simulation has no metastability, so it is NOT caught here
  (cd tb && rm -rf sim_build_bug && make BUG=binary COCOTB_RANDOM_SEED=1 > ../build/sim_bug.log 2>&1)
  check "sim bug: binary-crossing bug passes simulation (expected: simulation cannot see it)" build/sim_bug.log "FAIL=0 SKIP="
fi
if [[ $what == formal || $what == all ]]; then
  (cd formal && for t in bmc prove cover bug; do sby -f fifo.sby $t > ../build/formal_$t.log 2>&1; done)
  check "formal bmc: CDC and overflow properties hold for 30 steps, any clock ratio and phase" build/formal_bmc.log "DONE (PASS"
  check "formal prove: k-induction, the properties hold in every reachable state (unbounded), depth 16" build/formal_prove.log "DONE (PASS"
  check "formal cover: full, max occupancy and pointer wrap are reachable (bmc is not vacuous)" build/formal_cover.log "DONE (PASS"
  check "formal bug: binary-crossing bug is caught (must FAIL)" build/formal_bug.log "DONE (FAIL"
  (cd formal && for t in prove cover; do sby -f rst_sync.sby $t > ../build/formal_rst_$t.log 2>&1; done)
  check "formal rst_sync prove: asynchronous assertion, deassertion only on a clock edge" build/formal_rst_prove.log "DONE (PASS"
  check "formal rst_sync cover: release, re-assert with the clock stopped" build/formal_rst_cover.log "DONE (PASS"
fi
echo "---- $fails failing check(s)"; exit $fails
