(* Runs the regression suite from the command line:
       wolfram -script RunTests.wl
   and prints a summary; exits with a nonzero code on failure. *)

SetDirectory[DirectoryName[$InputFileName /. "" -> Directory[]]];
report = TestReport["RootDecomposition.wlt"];
Print["Tests succeeded: ", report["TestsSucceededCount"], ", failed: ", report["TestsFailedCount"],
  ", time: ", report["TimeElapsed"]];
If[report["TestsFailedCount"] > 0,
  Do[If[t["Outcome"] =!= "Success",
      Print["FAILED ", t["TestID"], " | outcome ", t["Outcome"], " | expected ", t["ExpectedOutput"],
        " | actual ", t["ActualOutput"], " | messages ", t["ActualMessages"]]],
    {t, Values[report["TestResults"]]}];
  Exit[1]];
