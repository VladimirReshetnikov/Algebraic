(* Differential run of StradFixed2 and StradFixed3 on the corpus of review-8's
   tests/differential.wls (both packages loaded in one kernel; distinct contexts). *)
Get["C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/corrected/StradFixed2.wl"];
Get["C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/corrected/StradFixed3.wl"];
Print["Kernel: ", $Version];
corpus = {
 Sqrt[3 + 2 Sqrt[2]], Sqrt[5 + 2 Sqrt[6]], Sqrt[4 + 3 Sqrt[2]],
 Sqrt[3/2 + Sqrt[3]], (7 + 5 Sqrt[2])^(1/3), (41 - 29 Sqrt[2])^(1/5),
 (-99 - 70 Sqrt[2])^(1/6), (-239 - 169 Sqrt[2])^(1/7),
 (1393 - 985 Sqrt[2])^(1/9), (7 20^(1/3) - 19)^(1/6),
 (133 + 57 2^(2/3) 3^(1/3) + 48 2^(1/3) 3^(2/3))^(1/6),
 Sqrt[5^(1/3) - 4^(1/3)], Sqrt[28^(1/3) - 3],
 Sqrt[118 + 2 Sqrt[210] + 14 Sqrt[55] + 2 Sqrt[462]],
 Sqrt[1 + Sqrt[3]] + Sqrt[3 + 3 Sqrt[3]] - Sqrt[10 + 6 Sqrt[3]],
 (3 + 2 Sqrt[2])^(1/6), Sqrt[2 + Sqrt[2]],
 1/(Sqrt[2] + Sqrt[3 + 2 Sqrt[2]])};
eqQ[a_, b_] := TimeConstrained[Quiet[Check[RootReduce[a - b] === 0, False]], 60, "Unknown"];
rows = Table[
  old = RadicalDenest2`DenestReport[e, "TimeBudget" -> 60];
  new = RadicalDenest3`DenestReport[e, "TimeBudget" -> 60];
  r = <|"Input" -> e, "OldResult" -> old["Result"], "NewResult" -> new["Result"],
    "OldEqual" -> eqQ[e, old["Result"]], "NewEqual" -> eqQ[e, new["Result"]],
    "OldDepth" -> RadicalDenest2`RadicalDepth[old["Result"]], "NewDepth" -> RadicalDenest3`RadicalDepth[new["Result"]],
    "OldStatus" -> old["Status"], "NewStatus" -> new["Status"],
    "OldSeconds" -> Round[old["ElapsedSeconds"], 0.01], "NewSeconds" -> Round[new["ElapsedSeconds"], 0.01]|>;
  Print[InputForm[e], "\n   v2: ", InputForm[r["OldResult"]], "  equal=", r["OldEqual"], " depth=", r["OldDepth"], " ", r["OldStatus"], " ", r["OldSeconds"], " s",
    "\n   v3: ", InputForm[r["NewResult"]], "  equal=", r["NewEqual"], " depth=", r["NewDepth"], " ", r["NewStatus"], " ", r["NewSeconds"], " s"];
  r, {e, corpus}];
Put[rows, "C:/Users/vresh/AppData/Local/Temp/claude/C--RadicalDenest--claude-worktrees-strad-denesting-analysis-6158e6/8331ac58-d8d2-4638-b75d-79549acb84bf/scratchpad/differential3_rows.m"];
Print["DONE"];
