(* Run with: wolframscript -file Tests/RunTests.wl
   In a notebook use TestReport[".../AlgebraicDecomposition.wlt"] instead. *)
Module[{report, props, ok},
  Print["Wolfram kernel: ", $Version];
  report = TestReport[FileNameJoin[{DirectoryName[$InputFileName],
    "AlgebraicDecomposition.wlt"}]];
  Print[report];
  props = report["Properties"];
  ok = Which[
    ListQ[props] && MemberQ[props, "ReportSucceeded"],
      TrueQ[report["ReportSucceeded"]],
    ListQ[props] && MemberQ[props, "AllTestsSucceeded"],
      TrueQ[report["AllTestsSucceeded"]],
    True, Print["This kernel exposes different test-report properties. ",
      "Inspect the printed report manually."]; False];
  Exit[If[ok, 0, 1]]
];
