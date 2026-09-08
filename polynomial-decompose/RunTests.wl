(* Native runner: wolfram.exe -script RunTests.wl. *)
SetDirectory[DirectoryName[$InputFileName]];
Print["Wolfram kernel: ", $Version];
{wallSeconds, report} = AbsoluteTiming[TestReport["AlgebraicDecomposition.wlt"]];
If[!IntegerQ[report["TestsSucceededCount"]] || !IntegerQ[report["TestsFailedCount"]] ||
    report["TestsSucceededCount"] + report["TestsFailedCount"] == 0,
  Print["FAILED: no valid nonempty native test report was produced."]; Exit[2]];
Print["Tests succeeded: ", report["TestsSucceededCount"], ", failed: ", report["TestsFailedCount"],
  ", total wall time: ", wallSeconds, " seconds"];
Do[If[t["Outcome"] =!= "Success",
    Print["FAILED ", t["TestID"], " | expected ", t["ExpectedOutput"],
      " | actual ", t["ActualOutput"], " | messages ", t["ActualMessages"]]],
  {t, Values[report["TestResults"]]}];
Exit[If[report["TestsFailedCount"] == 0, 0, 1]];
