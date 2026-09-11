(* Run the regression suite Algebraic.wlt in the Wolfram kernel or in Mathics3.

       wolfram -script RunTests.wl
       python -X utf8 -m mathics --no-readline -q -f RunTests.wl

   In the Wolfram kernel the suite runs through TestReport, unchanged.  In
   Mathics the runner reads MathicsHarness.wl, which defines the
   VerificationTest the same suite then resolves to; see that file for what
   is reported separately there.  For Mathics prefer

       python run_mathics.py

   which feeds the suite one statement at a time and survives the Python-level
   aborts that a single Get cannot.

   Exit code 0 when nothing failed. *)

$IterationLimit = 1000000;
(* TestReport's progress ticker, written from a script, produced two gigabytes
   of redrawn progress lines before the suite was half done.  The switch works
   only when it is set before TestReport is first used, which autoloads the
   testing framework; set just before the call it had no effect. *)
$ProgressReporting = False;
SetDirectory[DirectoryName[$InputFileName /. "" -> Directory[]]];
Get[FileNameJoin[{"..", "Algebraic.wl"}]];
Print["Kernel: ", $Version];
report = AlgebraicKernelReport[];
Print["Package ", $AlgebraicVersion, " on ", report["Kernel"], "; emulated: ",
  Length[report["EmulatedFunctions"]], " functions"];

If[Names["System`TestReport"] =!= {},

  (* ---------------- the Wolfram kernel ---------------- *)
  (* The report is also written to wolfram-report.txt.  TestReport redraws a
     progress line on standard output with carriage returns, continuously and
     unswitchably from a script; redirected to a file it reaches Git Bash's
     2 GB limit and the kernel then blocks, and a line filter never sees a
     line end.  Send standard output to the null device and read the file. *)
  Module[{wall, tr, results, failed, report, say},
    report = OpenWrite["wolfram-report.txt"];
    say[args___] := (Print[args]; WriteString[report, StringJoin[ToString /@ {args}], "
"]);
    say["Kernel: ", $Version];
    {wall, tr} = AbsoluteTiming[TestReport["Algebraic.wlt"]];
    If[! IntegerQ[tr["TestsSucceededCount"]] || ! IntegerQ[tr["TestsFailedCount"]] ||
        tr["TestsSucceededCount"] + tr["TestsFailedCount"] == 0,
      say["FAILED: no valid nonempty test report was produced."]; Close[report]; Exit[2]];
    results = Values[tr["TestResults"]];
    Do[If[t["Outcome"] =!= "Success",
        say["FAILED ", t["TestID"], " | expected ", ToString[t["ExpectedOutput"], InputForm],
          " | actual ", ToString[t["ActualOutput"], InputForm], " | messages ", t["ActualMessages"]]],
      {t, results}];
    say["Tests succeeded: ", tr["TestsSucceededCount"], ", failed: ",
      tr["TestsFailedCount"], ", wall time: ", Round[wall, 0.1], " s"];
    Close[report];
    Exit[If[tr["TestsFailedCount"] == 0, 0, 1]]],

  (* ---------------- Mathics3 ---------------- *)
  (* The suite is one Get here, so a Python-level abort inside a test ends the
     run with no report; run_mathics.py feeds the same suite one statement at
     a time and survives that.  Prefer it. *)
  Module[{bad},
    Get["MathicsHarness.wl"];
    Get["Algebraic.wlt"];
    bad = mathicsSummary[0];
    Exit[If[bad == 0, 0, 1]]]];
