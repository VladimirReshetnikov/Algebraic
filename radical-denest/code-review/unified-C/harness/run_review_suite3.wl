(* Runs the native regression suite that one of the three round-3 reviews supplied
   for ITS OWN proposed StradFixed3.wl, in a fresh kernel, without writing into the
   review directory.  Usage: wolframscript -file run_review_suite3.wl 7|8|9   *)
review = Last[$ScriptCommandLine];
base = "C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/";
{package, suite} = Switch[review,
  "7", {base <> "review-7/code/StradFixed3.wl", base <> "review-7/tests/StradFixed3.wlt"},
  "8", {base <> "review-8/code/StradFixed3.wl", base <> "review-8/tests/StradFixed3.wlt"},
  "9", {base <> "review-9/StradFixed3.wl", base <> "review-9/StradFixed3Tests.wlt"},
  _, Print["argument must be 7, 8 or 9"]; Exit[2]];
Print["Kernel: ", $Version];
Print["Review ", review, "  package ", package, "  SHA-256 ", Hash[File[package], "SHA256", "HexString"]];
loadMessages = {};
loaded = Internal`HandlerBlock[{"Message", Function[m, If[TrueQ[m[[2]]], AppendTo[loadMessages, ToString[Extract[m, {1, 1}, HoldForm]]]]]},
  Quiet[Check[Get[package]; "loaded", $Failed]]];
Print["load: ", loaded, "  messages while loading: ", DeleteDuplicates[loadMessages]];
Print["public symbols: ", Names["RadicalDenest3`*"]];
report = TimeConstrained[TestReport[suite], 2400, $TimedOut];
If[report === $TimedOut, Print["SUITE TIMED OUT after 2400 s"]; Exit[3]];
results = Values[report["TestResults"]];
Do[Print[r["TestID"], " -> ", r["Outcome"],
   If[r["Outcome"] =!= "Success", "   actual: " <> StringTake[ToString[r["ActualOutput"], InputForm], UpTo[300]], ""],
   "   (", Round[r["AbsoluteTimeUsed"], 0.01], " s)"], {r, results}];
Print["tests: ", Length[results], "  succeeded: ", report["TestsSucceededCount"], "  failed: ", report["TestsFailedCount"],
  "  time: ", Round[report["TimeElapsed"], 0.1]];
Print["DONE"];
