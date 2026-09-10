#!/bin/bash
# Runs every unified-C experiment sequentially (single Wolfram license seat).
H="C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-C/harness"
T="C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-C/tests"
L="C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-C/logs"
wait_free() { until ! tasklist 2>/dev/null | grep -qi 'WolframKernel.exe'; do sleep 5; done; }
for s in exp_battery3 exp_new2 exp_fuzz3 repro_fuzz_slow probe_gaps3_1 probe_gaps3_2 probe_gaps3_3 probe_gaps3_4 probe_reviews2 differential3; do
  wait_free
  echo "=== $s start $(date +%T)"
  wolframscript -file "$H/$s.wl" > "$L/$s.txt" 2>&1
  echo "=== $s exit $? $(date +%T)"
done
for r in 7 8 9; do
  wait_free
  echo "=== review-$r suite start $(date +%T)"
  wolframscript -file "$H/run_review_suite3.wl" $r > "$L/review${r}_suite.txt" 2>&1
  echo "=== review-$r suite exit $? $(date +%T)"
done
wait_free
echo "=== unified-C suite start $(date +%T)"
wolframscript -file "$T/run_tests.wls" > "$L/regression_suite.txt" 2>&1
echo "=== unified-C suite exit $? $(date +%T)"
wait_free
echo "=== export tables start $(date +%T)"
wolframscript -file "$H/export_tables3.wl" > "$L/export_tables3.txt" 2>&1
echo "=== export tables exit $? $(date +%T)"
echo ALL-DONE
