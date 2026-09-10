#!/bin/bash
H="C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-B/harness"
L="C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-B/logs"
until grep -q 'ALL-DONE-2' "$L/run_all2.txt" 2>/dev/null; do sleep 15; done
until ! tasklist 2>/dev/null | grep -qi 'wolfram.exe\|WolframKernel.exe'; do sleep 5; done
echo "=== probe_reviews_fixed start $(date +%T)"
wolframscript -file "$H/probe_reviews_fixed.wl" > "$L/probe_reviews_fixed.txt" 2>&1
echo "=== probe_reviews_fixed exit $? $(date +%T)"
echo ALL-DONE-3
