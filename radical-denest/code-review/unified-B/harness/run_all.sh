#!/bin/bash
# Runs every unified-B experiment sequentially (single Wolfram license seat).
H="C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-B/harness"
L="C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-B/logs"
for s in exp_battery2 exp_fuzz2 probe_gaps2_1 probe_gaps2_2 probe_gaps2_3 probe_gaps2_4; do
  until ! tasklist 2>/dev/null | grep -qi 'wolfram.exe\|WolframKernel.exe'; do sleep 5; done
  echo "=== $s start $(date +%T)"
  wolframscript -file "$H/$s.wl" > "$L/$s.txt" 2>&1
  echo "=== $s exit $? $(date +%T)"
done
echo ALL-DONE
