(* Execute: wolframscript -file Tests/RunTests.wls
   Fail closed if the report is unsuccessful or the expected 53 tests
   were not observed. Property names are detected for newer/older kernels. *)
base = DirectoryName[$InputFileName];
report = TestReport[FileNameJoin[{base, "AlgebraicDecomposition.wlt"}]];
Print[report];
Print["Wolfram version: ", $Version];
If[Head[report] =!= TestReportObject,
 Print["No TestReportObject was produced."]; Exit[2]];
properties = Quiet[Check[report["Properties"], {}]];
If[!ListQ[properties], properties = {}];
observed = Which[
 MemberQ[properties, "Results"], Length[report["Results"]],
 MemberQ[properties, "TestResults"], Length[report["TestResults"]],
 MemberQ[properties, "TestsSucceededCount"] &&
  MemberQ[properties, "TestsFailedCount"],
   report["TestsSucceededCount"] + report["TestsFailedCount"],
 True, Missing["Unavailable"]];
succeeded = Which[
 MemberQ[properties, "ReportSucceeded"], TrueQ[report["ReportSucceeded"]],
 MemberQ[properties, "TestsFailedCount"], TrueQ[report["TestsFailedCount"] == 0],
 True, False];
Print["Tests observed: ", observed, " (expected: 53)"];
Print["Report succeeded: ", succeeded];
Export[FileNameJoin[{base, "LastTestReport.wxf"}], report, "WXF"];
Exit[If[succeeded && observed === 53, 0, 1]];
