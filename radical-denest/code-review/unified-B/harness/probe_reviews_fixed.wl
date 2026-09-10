(* The reviews' never-executed probes against the FIRST corrected version StradFixed.wl. *)
Get["C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/corrected/StradFixed.wl"];
Print["Kernel: ", $Version];
Clear[x];
Print["R4 F01 / R5 F1 / R6 F01  zero solver in symbolic host: ",
  TimeConstrained[RadicalDenest`Strad[x + Sqrt[5 + 2 Sqrt[6]], "Solver" -> (0 &), "Factor" -> False], 30, $Aborted]];
Print["R5 F1  zero solver, numeric host: ",
  TimeConstrained[RadicalDenest`DenestRadicals[Sqrt[5 + 2 Sqrt[6]], "Solver" -> Function[z, 0]], 30, $Aborted]];
Print["R4 F07 / R5 F2  ambient assumption: ",
  Block[{$Assumptions = x > 0}, RadicalDenest`DenestRadicals[Sqrt[x^2]]]];
Print["R4 F07  mixed host under assumption: ",
  Block[{$Assumptions = x > 0}, RadicalDenest`Strad[Sqrt[x^2] + Sqrt[5 + 2 Sqrt[6]]]]];
Print["R4 F06  PolynomialQ[$Failed, x] = ", PolynomialQ[$Failed, x]];
Print["R5 F7  cost arity: usage says ", StringCases[RadicalDenest`RadicalCost::usage, "{" ~~ __ ~~ "}"], "  actual length ", Length[RadicalDenest`RadicalCost[Sqrt[5 + 2 Sqrt[6]]]]];
Print["R4 F04  cap 1, q 3, discriminant 5: ",
  Block[{RadicalDenest`Private`$cap = 1, RadicalDenest`Private`$visited = <||>},
    RadicalDenest`Private`newMultipliers[{1, (#^2 - # - 1 &), 2}, Null, 3]]];
Print["R4 F04  cap 1, q 2, discriminant 65: ",
  Block[{RadicalDenest`Private`$cap = 1, RadicalDenest`Private`$visited = <||>},
    RadicalDenest`Private`newMultipliers[{1, (#^2 - # - 16 &), 2}, Null, 2]]];
Do[Print["R6 F04  cap ", cap, ", q 2, discriminant -9240: ",
   TimeConstrained[Block[{RadicalDenest`Private`$cap = cap, RadicalDenest`Private`$visited = <||>},
     RadicalDenest`Private`newMultipliers[{1, Function[z, z^2 + 2310], 2}, Null, 2]], 10, $Aborted]], {cap, {0, 1, 7}}];
Print["R6 F05  infinite cap (1 s watchdog): ",
  TimeConstrained[Block[{RadicalDenest`Private`$cap = Infinity, RadicalDenest`Private`$visited = <||>},
    RadicalDenest`Private`newMultipliers[{1, Function[z, z^2 + 2310], 2}, Null, 2]], 1, $Aborted]];
saved = Options[RadicalDenest`Strad];
SetOptions[RadicalDenest`Strad, "TimeBudget" -> 0];
Print["R4 F02  SetOptions[Strad, TimeBudget -> 0] then Strad[Sqrt[5+2Sqrt[6]]]: ", RadicalDenest`Strad[Sqrt[5 + 2 Sqrt[6]]]];
SetOptions[RadicalDenest`Strad, Sequence @@ saved];
callbackCalls = 0;
Print["R5 F4  TimeBudget 0 with counting callback: ",
  RadicalDenest`DenestRadicals[Sqrt[5 + 2 Sqrt[6]], "TimeBudget" -> 0, "Solver" -> Function[z, callbackCalls++; z]], "  callback calls: ", callbackCalls];
Print["R5 F3  combine helper with positive aggregate factor: ",
  RadicalDenest`Private`combine[{{{-1, 2}, {2, 1}}, {{-1, 2}, {3, 1}}}, 1/2]];
Print["R4 F09  Sqrt[I](-1+I) vs -Sqrt[2]: ", RootReduce[Sqrt[I] (-1 + I) + Sqrt[2]]];
Print["DONE"];
