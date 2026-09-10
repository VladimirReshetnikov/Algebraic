(* Run: wolframscript -file run_tests.wls
   Native execution is required; these tests were NOT run during the review. *)
base = DirectoryName[$InputFileName];
loaded = Check[Get[FileNameJoin[{base, "StradFixed3.wl"}]], $Failed];
If[loaded === $Failed, Print["Package loading failed."]; Exit[2]];
report = TestReport[FileNameJoin[{base, "StradFixed3Tests.wlt"}]];
Print[report];
passed = report["TestsSucceededCount"];
failed = report["TestsFailedCount"];
If[! IntegerQ[passed] || ! IntegerQ[failed],
 Print["No usable native TestReport was produced."]; Exit[2]];
If[passed + failed =!= 40,
 Print["Expected 40 tests, but the report contains ", passed + failed, "."]; Exit[2]];
summary = <|"Kernel" -> $Version, "TestsSucceeded" -> passed,
 "TestsFailed" -> failed, "NativeWolframExecuted" -> True|>;
exported = Check[Export[FileNameJoin[{base, "native_results.json"}],
  summary, "RawJSON"], $Failed];
If[exported === $Failed, Print["Could not write native_results.json."]; Exit[2]];
If[failed > 0, Exit[1], Exit[0]];
