(* The round-3 cases (cases_new.wl) run against the SECOND corrected version
   StradFixed2.wl, for the side-by-side comparison in unified-C. *)
Get["C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-B/harness/runner2.wl"];
rows = {};
add[r_] := AppendTo[rows, r];
Get["C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-C/harness/cases_new.wl"];
Put[rows, "C:/Users/vresh/AppData/Local/Temp/claude/C--RadicalDenest--claude-worktrees-strad-denesting-analysis-6158e6/8331ac58-d8d2-4638-b75d-79549acb84bf/scratchpad/exp_new2_rows.m"];
Print["DONE"];
