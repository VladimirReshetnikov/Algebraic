#!/usr/bin/env wolframscript
(* Run this script in a fresh kernel. *)
base = DirectoryName[DirectoryName[$InputFileName]];
Get[FileNameJoin[{base, "Kernel", "AlgebraicDecomposition.wl"}]];
Print["Kernel: ", $Version];
report = TestReport[FileNameJoin[{base, "Tests", "AlgebraicDecomposition.wlt"}]];
Print[report];
props = Quiet[Check[report["Properties"], {}]];
passed = Which[
  MemberQ[props, "ReportSucceeded"], TrueQ[report["ReportSucceeded"]],
  MemberQ[props, "TestsFailedCount"],
    TrueQ[report["TestsFailedCount"] == 0] &&
      TrueQ[report["TestsSucceededCount"] > 0],
  True, False
];
Print["All native tests passed: ", passed];
If[passed, Exit[0], Exit[1]];
