(* Run: wolframscript -file tests/run_tests.wls from the extracted archive. *)
root = DirectoryName[DirectoryName[$InputFileName]];
Get[FileNameJoin[{root,"code","StradFixed3.wl"}]];
report = TestReport[FileNameJoin[{root,"tests","StradFixed3.wlt"}]];
Print[$Version];
Print[report];
Export[FileNameJoin[{root,"evidence","native_test_report.txt"}],
 ToString[{$Version, report}, InputForm],"Text"];
If[report["TestsFailedCount"] === 0, Exit[0], Exit[1]];
