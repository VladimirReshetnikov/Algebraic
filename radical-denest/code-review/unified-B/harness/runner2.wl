(* Experiment runner for the second corrected version StradFixed2.wl *)
$srcFile = "C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/corrected/StradFixed2.wl";
$printAttrsBefore = Attributes[Print];
Get[$srcFile];
$printAttrsAfter = Attributes[Print];
Needs["RadicalDenest2`"];

SetAttributes[capture, HoldAll];
capture[expr_] := Module[{msgs = {}, res},
  res = Internal`HandlerBlock[{"Message",
      Function[m, If[TrueQ[m[[2]]], AppendTo[msgs, ToString[Extract[m, {1, 1}, HoldForm]]]]]}, expr];
  {res, DeleteDuplicates[msgs]}];

radDepth[e_] := If[AtomQ[e], 0,
  If[MatchQ[e, Power[_, _Rational]], 1 + radDepth[e[[1]]],
   Max[Prepend[radDepth /@ (List @@ e), 0]]]];

SetAttributes[runCase, HoldAll];
runCase[id_, expr_, expected_, tlimit_: 120] := Module[
  {t, res, msgs, out, numQ, numOK, exactOK, inputVal, depthIn, depthOut},
  inputVal = ReleaseHold[Hold[expr] /. {HoldPattern[Strad[e_, ___]] :> e, HoldPattern[DenestRadicals[e_, ___]] :> e, HoldPattern[DenestCore[e_, ___]] :> e}];
  {t, {res, msgs}} = AbsoluteTiming[TimeConstrained[capture[expr], tlimit, {$TimedOut, {"TIMEOUT"}}]];
  numQ = NumericQ[inputVal] && NumericQ[res];
  numOK = If[numQ, Quiet[TrueQ[Abs[N[res - inputVal, 40]] < 10^-30]], "n/a"];
  exactOK = If[expected === None, "n/a",
     Quiet[TimeConstrained[TrueQ[RootReduce[res - expected] === 0], 30, "rr-timeout"]]];
  depthIn = radDepth[inputVal]; depthOut = radDepth[res];
  out = <|"id" -> id, "input" -> ToString[HoldForm[expr], InputForm],
    "result" -> ToString[res, InputForm], "time" -> Round[t, 0.001],
    "numeric" -> numOK, "exact" -> exactOK, "depth" -> {depthIn, depthOut},
    "messages" -> msgs|>;
  Print[id, " | ", ToString[HoldForm[expr], InputForm], "\n   -> ", ToString[res, InputForm],
    "\n   time ", Round[t, 0.001], "s  numeric=", numOK, "  exact=", exactOK,
    "  depth ", depthIn, "->", depthOut, If[msgs =!= {}, "  MSGS: " <> ToString[msgs], ""]];
  out];

Print["Kernel: ", $Version];
Print["Print attributes before load: ", $printAttrsBefore, "  after: ", $printAttrsAfter];
Print["Context symbols: ", Names["RadicalDenest2`*"]];
