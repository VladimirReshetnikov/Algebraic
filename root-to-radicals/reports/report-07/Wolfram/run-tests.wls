(* Run from a terminal: wolframscript -file Wolfram/run-tests.wls *)
base=DirectoryName[$InputFileName];
Get[FileNameJoin[{base,"SystematicRadicals.wl"}]];
report=TestReport[FileNameJoin[{base,"tests.wlt"}]];
Print[report];
