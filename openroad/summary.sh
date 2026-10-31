#!/bin/bash
# summary.sh RESULT_DIR : print the key numbers of an ORFS run (area, timing, power, routing DRC, LEC)
D=$1; R=$D/reports/6_finish.rpt
echo "== design area";             grep -h -m1 "Design area" $R $D/logs/6_report.log 2>/dev/null | head -1
echo "== cells";                   grep -h -A10 "Cell type report" $D/logs/6_report.log 2>/dev/null | head -11
echo "== setup (finish)";          grep -h -E "^(tns|wns|worst slack) max" $R 2>/dev/null
echo "== hold (finish)";           grep -h -E "^(tns|wns|worst slack) min" $R 2>/dev/null
echo "== power (default activity)"; grep -h -m1 "Total power" $D/logs/6_report.log 2>/dev/null
echo "== detailed route DRC";      grep -h -E "Number of violations" $D/logs/5_2_route.log 2>/dev/null | tail -1
echo "== equivalence (ORFS LEC)";  grep -h "passed lec test\|failed lec test" $D/logs/*.log 2>/dev/null
echo "== runtime per step";        for f in $D/logs/*.log; do t=$(grep -h -o "Elapsed time: [0-9:.]*" $f | tail -1); [ -n "$t" ] && echo "  $(basename $f .log): $t"; done
