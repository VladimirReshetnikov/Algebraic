(* Run with wolframscript -file tests/RunWolframTests.wls. *)
base = DirectoryName[DirectoryName[$InputFileName]];
Get[FileNameJoin[{base,"wolfram","RootRadicals.wl"}]];
report = TestReport[FileNameJoin[{base,"tests","RootRadicals.wlt"}]];
Print[report];
Exit[If[TrueQ[report["ReportSucceeded"]], 0, 1]];
