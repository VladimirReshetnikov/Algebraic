#!/bin/bash
# Second chain: waits for run_all.sh to finish, then runs the reviews' own native
# suites against their proposals, the unified-B regression suite, and the table export.
H="C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-B/harness"
T="C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-B/tests"
L="C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-B/logs"
until grep -q 'ALL-DONE' "$L/run_all.txt" 2>/dev/null; do sleep 15; done
until ! tasklist 2>/dev/null | grep -qi 'wolfram.exe\|WolframKernel.exe'; do sleep 5; done
for r in 4 5 6; do
  echo "=== review-$r suite start $(date +%T)"
  wolframscript -file "$H/run_review_suite.wl" $r > "$L/review${r}_suite.txt" 2>&1
  echo "=== review-$r suite exit $? $(date +%T)"
done
echo "=== unified-B suite start $(date +%T)"
wolframscript -file "$T/run_tests.wls" > "$L/regression_suite.txt" 2>&1
echo "=== unified-B suite exit $? $(date +%T)"
echo "=== export tables start $(date +%T)"
wolframscript -file "$H/export_tables2.wl" > "$L/export_tables2.txt" 2>&1
echo "=== export tables exit $? $(date +%T)"
echo ALL-DONE-2
