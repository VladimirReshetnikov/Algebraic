(* Runs the native regression suite that one of the three reviews supplied for
   ITS OWN proposed StradImproved.wl, in a fresh kernel, without writing into the
   review's directory.  Usage: wolframscript -file run_review_suite.wl 4|5|6   *)
review = Last[$ScriptCommandLine];
base = "C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/";
{package, suite} = Switch[review,
  "4", {base <> "review-4/StradImproved.wl", base <> "review-4/tests/Regression.wlt"},
  "5", {base <> "review-5/code/StradImproved.wl", base <> "review-5/tests/regression.wlt"},
  "6", {base <> "review-6/radical_denesting_review/code/StradImproved.wl", base <> "review-6/radical_denesting_review/tests/StradImproved.wlt"},
  _, Print["argument must be 4, 5 or 6"]; Exit[2]];
Print["Kernel: ", $Version];
Print["Review ", review, "  package ", package];
loadMessages = {};
loaded = Internal`HandlerBlock[{"Message", Function[m, If[TrueQ[m[[2]]], AppendTo[loadMessages, ToString[Extract[m, {1, 1}, HoldForm]]]]]},
  Quiet[Check[Get[package]; "loaded", $Failed]]];
Print["load: ", loaded, "  messages while loading: ", DeleteDuplicates[loadMessages]];
Print["public symbols: ", Names["RadicalDenestImproved`*"]];
report = TimeConstrained[TestReport[suite], 1800, $TimedOut];
If[report === $TimedOut, Print["SUITE TIMED OUT after 1800 s"]; Exit[3]];
results = Values[report["TestResults"]];
Do[Print[r["TestID"], " -> ", r["Outcome"],
   If[r["Outcome"] =!= "Success", "   actual: " <> StringTake[ToString[r["ActualOutput"], InputForm], UpTo[300]], ""],
   "   (", Round[r["AbsoluteTimeUsed"], 0.01], " s)"], {r, results}];
Print["tests: ", Length[results], "  succeeded: ", report["TestsSucceededCount"], "  failed: ", report["TestsFailedCount"],
  "  time: ", Round[report["TimeElapsed"], 0.1]];
Print["DONE"];
