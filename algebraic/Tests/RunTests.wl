(* Run the regression suite Algebraic.wlt in the Wolfram kernel or in Mathics3.

       wolfram -script RunTests.wl
       python -X utf8 -m mathics --no-readline -q -f RunTests.wl

   In the Wolfram kernel the suite runs through TestReport, unchanged.  Mathics
   has neither TestReport nor VerificationTest, so the runner defines its own
   VerificationTest in Global` before reading the suite: the same file, the
   same expected values, the same test IDs.  Two things differ there and are
   reported separately rather than hidden: a test that expects a particular
   message is judged on its value only, because Mathics' messages are not the
   Wolfram kernel's; and a test that reaches an operation the kernel report
   marks unavailable (the Galois engine, see AlgebraicKernelReport[]) counts
   as "unavailable", not as a failure, when it returns the documented
   KernelPrecision failure.

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
  Module[{wall, tr, results, failed},
    {wall, tr} = AbsoluteTiming[TestReport["Algebraic.wlt"]];
    If[! IntegerQ[tr["TestsSucceededCount"]] || ! IntegerQ[tr["TestsFailedCount"]] ||
        tr["TestsSucceededCount"] + tr["TestsFailedCount"] == 0,
      Print["FAILED: no valid nonempty test report was produced."]; Exit[2]];
    results = Values[tr["TestResults"]];
    Do[If[t["Outcome"] =!= "Success",
        Print["FAILED ", t["TestID"], " | expected ", t["ExpectedOutput"],
          " | actual ", t["ActualOutput"], " | messages ", t["ActualMessages"]]],
      {t, results}];
    Print["Tests succeeded: ", tr["TestsSucceededCount"], ", failed: ",
      tr["TestsFailedCount"], ", wall time: ", Round[wall, 0.1], " s"];
    Exit[If[tr["TestsFailedCount"] == 0, 0, 1]]],

  (* ---------------- Mathics3 ---------------- *)
  Module[{passed = 0, failed = 0, unavailable = 0, valueOnly = 0, t0 = AbsoluteTime[]},
    SetAttributes[VerificationTest, HoldAll];
    SetAttributes[BeginTestSection, HoldAll];
    BeginTestSection[___] := Null; EndTestSection[___] := Null;
    unavailableQ[v_] := Head[v] === Failure && v[[1]] === "KernelPrecision" ||
      ! FreeQ[v, Failure["KernelPrecision", _]];
    VerificationTest[actual_, expected_: True, messages_: {}, opts___] := Module[
      {id, got, want, ok, t1 = AbsoluteTime[]},
      id = Replace[TestID /. Flatten[{opts}], TestID -> "(no id)"];
      got = Quiet[actual];
      want = expected;
      If[ListQ[messages] && messages =!= {}, valueOnly++];
      ok = TrueQ[got === want];
      Which[
        ok, passed++,
        unavailableQ[got], unavailable++;
          Print["UNAVAILABLE ", id, " (Galois engine)"],
        True, failed++;
          Print["FAILED ", id, " | expected ", InputForm[want], " | actual ", InputForm[got]]];
      If[AbsoluteTime[] - t1 > 30, Print["   (", id, ": ", Round[AbsoluteTime[] - t1], " s)"]];
      ok];
    Get["Algebraic.wlt"];
    Print["Tests succeeded: ", passed, ", failed: ", failed,
      ", unavailable in this kernel: ", unavailable,
      " (", valueOnly, " judged on value only because they expect Wolfram messages); wall time: ",
      Round[AbsoluteTime[] - t0], " s"];
    Exit[If[failed == 0, 0, 1]]]];
