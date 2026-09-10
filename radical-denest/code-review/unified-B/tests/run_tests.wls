#!/usr/bin/env wolframscript
(* Runs tests/StradFixed2.wlt against src/corrected/StradFixed2.wl in a fresh
   kernel and prints one line per test plus a summary. Exit code 1 on failure. *)
Module[{here, package, report, results, failed},
  here = DirectoryName[$InputFileName];
  package = FileNameJoin[{here, "..", "..", "..", "corrected", "StradFixed2.wl"}];
  Get[package];
  Print["Kernel: ", $Version];
  Print["Package: ", package, "  SHA-256 ", Hash[File[package], "SHA256", "HexString"]];
  report = TestReport[FileNameJoin[{here, "StradFixed2.wlt"}]];
  results = Values[report["TestResults"]];
  Do[Print[r["TestID"], " -> ", r["Outcome"],
     If[r["Outcome"] =!= "Success", "   actual: " <> ToString[r["ActualOutput"], InputForm], ""],
     "   (", Round[r["AbsoluteTimeUsed"], 0.01], " s)"], {r, results}];
  failed = Select[results, #["Outcome"] =!= "Success" &];
  Print["tests: ", Length[results], "  succeeded: ", report["TestsSucceededCount"],
    "  failed: ", report["TestsFailedCount"], "  time: ", Round[report["TimeElapsed"], 0.1]];
  If[Length[failed] > 0, Exit[1]]];
