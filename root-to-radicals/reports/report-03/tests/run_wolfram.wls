(* Run: wolframscript -file tests/run_wolfram.wls *)
report=TestReport[FileNameJoin[{DirectoryName[$InputFileName],"RadicalRoots.wlt"}]];
Print[report];
Export[FileNameJoin[{DirectoryName[$InputFileName],"..","test-results","wolfram-local-report.txt"}],
 ToString[report,InputForm],"Text"];
