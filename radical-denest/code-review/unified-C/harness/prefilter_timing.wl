(* Times the slowest battery rows with the numeric prefilter off (default) and on. *)
Get["C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/corrected/StradFixed3.wl"];
Print["Kernel: ", $Version];
cases = {
  "L09" -> Hold[(5 + 2 Sqrt[6])^(1/6)],
  "A27" -> Hold[(3 + 2 Sqrt[2])^(1/4)],
  "A30" -> Hold[Sqrt[(112 + 70 Sqrt[2]) + (46 + 34 Sqrt[2]) Sqrt[5]]],
  "K04" -> Hold[Sqrt[1 + Sqrt[2]] + Sqrt[3 + Sqrt[5]]],
  "N19" -> Hold[(3 + 2 Sqrt[2])^(1/6)],
  "N20" -> Hold[(3 + 2 Sqrt[2])^(1/6)],
  "N29" -> Hold[Sqrt[1 + Sqrt[2]]],
  "N30" -> Hold[Sqrt[2 + Sqrt[3] + Sqrt[5]]]};
extra = <|"N20" -> {"MaxRecursion" -> 0}|>;
Do[Module[{e = ReleaseHold[Last[c]], id = First[c], opts, t0, t1, r0, r1, s0, s1},
  opts = Lookup[extra, id, {}];
  {t0, r0} = AbsoluteTiming[DenestReport[e, Sequence @@ opts]];
  {t1, r1} = AbsoluteTiming[DenestReport[e, "NumericPrefilter" -> True, Sequence @@ opts]];
  s0 = r0["Statistics"]; s1 = r1["Statistics"];
  Print[id, "  ", InputForm[e], "\n   prefilter off: ", Round[t0, 0.01], " s  certificates ", s0["Certificates"], " trials ", s0["Trials"], " -> ", InputForm[r0["Result"]],
   "\n   prefilter on:  ", Round[t1, 0.01], " s  certificates ", s1["Certificates"], " numeric rejections ", s1["NumericRejections"], " trials ", s1["Trials"], " -> ", InputForm[r1["Result"]],
   If[r0["Result"] =!= r1["Result"], "   RESULTS DIFFER", ""]]], {c, cases}];
Print["DONE"];
