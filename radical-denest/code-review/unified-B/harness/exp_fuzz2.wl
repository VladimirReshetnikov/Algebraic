(* Randomized fuzz of the second corrected version StradFixed2 over the same families and seed *)
Get["C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/corrected/StradFixed2.wl"];
Needs["RadicalDenest2`"];
SeedRandom[20260905];
SetAttributes[capture, HoldAll];
capture[expr_] := Module[{msgs = {}, res},
  res = Internal`HandlerBlock[{"Message",
      Function[m, If[TrueQ[m[[2]]], AppendTo[msgs, ToString[Extract[m, {1, 1}, HoldForm]]]]]}, expr];
  {res, DeleteDuplicates[msgs]}];
radDepth[e_] := If[AtomQ[e], 0,
  If[MatchQ[e, Power[_, _Rational]], 1 + radDepth[e[[1]]], Max[Prepend[radDepth /@ (List @@ e), 0]]]];
exactEq[a_, b_] := Quiet[TimeConstrained[TrueQ[RootReduce[a - b] === 0], 20,
    TrueQ[Abs[N[a - b, 60]] < 10^-50]]];
classify[input_, res_, msgs_] := Which[
  res === $TimedOut, "timeout",
  ! NumericQ[res], "nonnumeric",
  ! exactEq[input, res], "WRONGVALUE",
  radDepth[res] < radDepth[input], "denested",
  res === input, "unchanged",
  True, "equal-rewritten"];
runFamily[name_, gen_, n_] := Module[{stats = <||>, tmax = 0, ttot = 0, bad = {}, input, t, res, msgs, c, k},
  Do[
   input = gen[];
   {t, {res, msgs}} = AbsoluteTiming[TimeConstrained[capture[Strad[input]], 60, {$TimedOut, {}}]];
   c = classify[input, res, msgs];
   stats[c] = Lookup[stats, c, 0] + 1;
   If[msgs =!= {}, k = "msg:" <> StringRiffle[msgs, ","]; stats[k] = Lookup[stats, k, 0] + 1];
   tmax = Max[tmax, t]; ttot += t;
   If[c === "WRONGVALUE" || c === "timeout" || c === "nonnumeric" || c === "unchanged" || c === "equal-rewritten", AppendTo[bad, {input, res, c, msgs}]],
   {n}];
  Print["FAMILY ", name, "  n=", n, "  total ", Round[ttot, 0.01], "s  max ", Round[tmax, 0.01], "s"];
  Print["   ", stats];
  Do[Print["   NOTE: ", ToString[b[[1]], InputForm], "  ->  ", ToString[b[[2]], InputForm], "  ", b[[3]], " ", b[[4]]], {b, Take[bad, Min[6, Length[bad]]]}];
  {name, n, stats, ttot, tmax, bad}];
sqf = {2, 3, 5, 6, 7, 10, 11, 13, 15, 17};
rnz[] := RandomChoice[Join[Range[-7, -1], Range[1, 7]]];
results = {};
AppendTo[results, runFamily["F1 Sqrt[(p+q Sqrt[c])^2]", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Sqrt[Expand[(p + q Sqrt[c])^2]]]], 40]];
AppendTo[results, runFamily["F2 ((p+q Sqrt[c])^3)^(1/3)", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Expand[(p + q Sqrt[c])^3]^(1/3)]], 30]];
AppendTo[results, runFamily["F3 Sqrt[a+b Sqrt[c]] generic", Function[{}, Module[{a = RandomInteger[{-30, 30}], b = rnz[], c = RandomChoice[sqf]}, Sqrt[a + b Sqrt[c]]]], 40]];
AppendTo[results, runFamily["F4 Sqrt[(p+q I Sqrt[c])^2]", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Sqrt[Expand[(p + q I Sqrt[c])^2]]]], 40]];
AppendTo[results, runFamily["F5 ((p+q I Sqrt[c])^2)^(3/2)", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Expand[(p + q I Sqrt[c])^2]^(3/2)]], 40]];
AppendTo[results, runFamily["F6 Sqrt[u^2] Sqrt[v^2] complex products", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf], r = rnz[], s = rnz[], d = RandomChoice[sqf]}, Sqrt[Expand[(p + q I Sqrt[c])^2]] Sqrt[Expand[(r + s I Sqrt[d])^2]]]], 40]];
AppendTo[results, runFamily["F7 ((p+q Sqrt[c])^4)^(1/4)", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Expand[(p + q Sqrt[c])^4]^(1/4)]], 25]];
AppendTo[results, runFamily["F8 Sqrt[(p+q Sqrt[c]+r Sqrt[d])^2]", Function[{}, Module[{p = rnz[], q = rnz[], r = rnz[], cd = RandomSample[sqf, 2]}, Sqrt[Expand[(p + q Sqrt[cd[[1]]] + r Sqrt[cd[[2]]])^2]]]], 25]];
AppendTo[results, runFamily["F9 ((p+q Sqrt[c])^2)^(3/2) real", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Expand[(p + q Sqrt[c])^2]^(3/2)]], 30]];
AppendTo[results, runFamily["F10 -Sqrt[..] Sqrt[..] real products with negative radicands", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf], r = rnz[], s = rnz[], d = RandomChoice[sqf]}, Sqrt[-Expand[(p + q Sqrt[c])^2]] Sqrt[-Expand[(r + s Sqrt[d])^2]]]], 30]];
Put[results, "C:/Users/vresh/AppData/Local/Temp/claude/C--RadicalDenest--claude-worktrees-strad-denesting-analysis-6158e6/8331ac58-d8d2-4638-b75d-79549acb84bf/scratchpad/exp_fuzz2_results.m"];
Print["DONE"];
