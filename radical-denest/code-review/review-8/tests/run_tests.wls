(* Run from any directory: wolframscript -file tests/run_tests.wls *)
base = DirectoryName[DirectoryName[$InputFileName]];
Get[FileNameJoin[{base, "code", "StradFixed3.wl"}]];
Print["Kernel: ", $Version];
report = TestReport[FileNameJoin[{base, "tests", "StradFixed3.wlt"}]];
Print[report];
Export[FileNameJoin[{base, "tests", "native_test_report.txt"}], ToString[report, InputForm], "Text"];
If[report["TestsFailedCount"] > 0, Exit[1], Exit[0]];
