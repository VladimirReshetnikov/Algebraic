(* Runs the regression suite from the command line:
       wolfram -script RunTests.wl
   and prints a summary; exits with a nonzero code on failure. *)

SetDirectory[DirectoryName[$InputFileName /. "" -> Directory[]]];
{wallSeconds, report} = AbsoluteTiming[TestReport["RootToRadicals.wlt"]];
If[! IntegerQ[report["TestsSucceededCount"]] || ! IntegerQ[report["TestsFailedCount"]] ||
    report["TestsSucceededCount"] + report["TestsFailedCount"] == 0,
  Print["FAILED: no valid test report was produced: ", report]; Exit[1]];
Print["Tests succeeded: ", report["TestsSucceededCount"], ", failed: ", report["TestsFailedCount"],
  ", test time: ", report["TimeElapsed"], ", total wall time: ", wallSeconds, " seconds"];
If[report["TestsFailedCount"] > 0,
  Do[If[t["Outcome"] =!= "Success",
      Print["FAILED ", t["TestID"], " | outcome ", t["Outcome"], " | expected ", t["ExpectedOutput"],
        " | actual ", t["ActualOutput"], " | messages ", t["ActualMessages"]]],
    {t, Values[report["TestResults"]]}];
  Exit[1]];
