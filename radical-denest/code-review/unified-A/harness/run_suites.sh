#!/bin/bash
# wait for any running kernel (single license seat)
until ! tasklist 2>/dev/null | grep -qi 'wolfram.exe\|WolframKernel.exe'; do sleep 5; done
S="C:/Users/vresh/AppData/Local/Temp/claude/C--RadicalDenest--claude-worktrees-strad-denesting-analysis-6158e6/8331ac58-d8d2-4638-b75d-79549acb84bf/scratchpad"
R="C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review"
cd "$R/review-1" && wolframscript -file run_wolfram_audit.wl > "$S/suite_review1.log" 2>&1; echo "r1 exit $?"
cd "$R/review-2" && wolframscript -code 'Print[$Version]; Get["original.wl"]; tr = TestReport["regression_tests.wlt"]; Print["succeeded: ", tr["TestsSucceededCount"], " failed: ", tr["TestsFailedCount"]]; Do[Print[r["TestID"], " -> ", r["Outcome"], If[r["Outcome"] =!= "Success", "   actual: " <> ToString[r["ActualOutput"], InputForm], ""]], {r, Values[tr["TestResults"]]}]' > "$S/suite_review2.log" 2>&1; echo "r2 exit $?"
cd "$R/review-3/radical_denesting_review" && wolframscript -file run_tests.wl > "$S/suite_review3.log" 2>&1; echo "r3 exit $?"
rm -f "$R/review-3/radical_denesting_review/wolfram_test_report.wl"
echo SUITES-DONE
