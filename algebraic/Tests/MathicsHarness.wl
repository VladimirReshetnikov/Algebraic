(* The Mathics3 side of the regression runner.  Loaded by RunTests.wl when the
   kernel has no TestReport, and by run_mathics.py, which then feeds
   Algebraic.wlt to the kernel one statement at a time so that a Python-level
   abort inside a test ends that test and not the run.

   Mathics has neither TestReport nor VerificationTest, and neither name is a
   System symbol there, so the definitions below in Global` are the ones the
   suite's calls resolve to: the same file, the same expected values, the same
   test IDs.  What differs is reported separately, never folded into the pass
   count: a test that expects a particular message is judged on its value
   only, because Mathics' messages are not the Wolfram kernel's; and a test
   that reaches an operation the kernel report marks unavailable (the Galois
   engine, see AlgebraicKernelReport[]) counts as "unavailable" when it
   returns the documented KernelPrecision failure.

   The suite's own helpers call a few System functions Mathics lacks
   (RootReduce, FailureQ, ...); those names are not System symbols there, so
   definitions in Global` are what the helpers resolve to, each deferring to
   the package's portable stand-in.  In the Wolfram kernel this file is never
   read. *)

$IterationLimit = 1000000;
If[! MemberQ[$Packages, "Algebraic`"],
  Get[FileNameJoin[{DirectoryName[$InputFileName /. "" -> Directory[]], "..", "Algebraic.wl"}]]];

$testsPassed = 0; $testsFailed = 0; $testsUnavailable = 0; $testsValueOnly = 0;
$testsStarted = AbsoluteTime[];

RootReduce[e_] := Algebraic`Private`kRootReduce[e];
FailureQ[e_] := Algebraic`Private`kFailureQ[e];
MissingQ[e_] := Algebraic`Private`kMissingQ[e];
Cyclotomic[n_, v_] := Algebraic`Private`kCyclotomic[n, v];
ToRadicals[e_] := Algebraic`Private`kToRadicals[e];
SetAttributes[AssociateTo, HoldFirst];
AssociateTo[a_, r_] := Algebraic`Private`kAssociateTo[a, r];
KeyDrop[a_?AssociationQ, keys_] := Association @@ Select[Algebraic`Private`kNormalRules[a], ! MemberQ[Flatten[{keys}], First[#]] &];
(* Failure["tag", <|...|>]["key"] reads the association in the Wolfram kernel;
   Failure is a protected Global symbol in Mathics *)
Unprotect[Failure];
Failure[tag_, a_?AssociationQ][key_String] := a[key];
Protect[Failure];

SetAttributes[BeginTestSection, HoldAll];
BeginTestSection[___] := Null; EndTestSection[___] := Null;

unavailableQ[v_] := Head[v] === Failure && v[[1]] === "KernelPrecision" ||
  ! FreeQ[v, Failure["KernelPrecision", _]];

SetAttributes[VerificationTest, HoldAll];
(* the message list is typed: an untyped optional argument would take a
   TestID rule as the message list and leave every test without an ID *)
VerificationTest[actual_, expected_: True, messages_List : {}, opts___] := Module[
  {id, got, want, ok, t1 = AbsoluteTime[]},
  id = Replace[TestID /. Flatten[{opts}], TestID -> "(no id)"];
  (* announced before it runs: a Python-level abort names the culprit *)
  Print["> ", id];
  got = Quiet[actual];
  want = expected;
  If[messages =!= {}, $testsValueOnly++];
  ok = TrueQ[got === want];
  Which[
    ok, $testsPassed++,
    unavailableQ[got], $testsUnavailable++;
      Print["UNAVAILABLE ", id, " (Galois engine)"],
    True, $testsFailed++;
      Print["FAILED ", id, " | expected ", InputForm[want], " | actual ", InputForm[got]]];
  If[AbsoluteTime[] - t1 > 30, Print["   (", id, ": ", Round[AbsoluteTime[] - t1], " s)"]];
  ok];

mathicsSummary[aborted_: 0] := (
  Print["Tests succeeded: ", $testsPassed, ", failed: ", $testsFailed,
    ", aborted by the interpreter: ", aborted,
    ", unavailable in this kernel: ", $testsUnavailable,
    " (", $testsValueOnly, " judged on value only because they expect Wolfram messages); wall time: ",
    Round[AbsoluteTime[] - $testsStarted], " s"];
  $testsFailed + aborted);
