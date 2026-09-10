(* Probe the corrected denester with denestable inputs from the literature guide. *)
Get["C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/corrected/StradFixed2.wl"];
Print["Kernel: ", $Version];
depth[e_] := RadicalDenest2`RadicalDepth[e];
eq[a_, b_] := Quiet[TrueQ[RootReduce[a - b] === 0] || TrueQ[PossibleZeroQ[a - b, Method -> "ExactAlgebraics"]]];
SetAttributes[probe, HoldAll];
$rows = {};
probe[id_, input_, expected_, opts___] := Module[{in, t, r, status, exp},
  in = input; exp = expected;
  {t, r} = AbsoluteTiming[TimeConstrained[Quiet[Strad[in, opts]], 400, $TimedOut]];
  status = Which[
    r === $TimedOut, "TIMEOUT",
    ! eq[r, in], "WRONG(not equal to input)",
    r === in || depth[r] >= depth[in], If[eq[in, exp], "MISS", "MISS?"],
    depth[r] > depth[exp], "PARTIAL",
    True, "ok"];
  Print[id, "  ", status, "  depth ", depth[in], "->", depth[r], "  ", Round[t, 0.01], " s"];
  Print["      in : ", ToString[in, InputForm]];
  Print["      out: ", ToString[r, InputForm]];
  If[status =!= "ok", Print["      exp: ", ToString[exp, InputForm], "  (exp==in: ", eq[in, exp], ")"]];
  AppendTo[$rows, {id, status, depth[in], depth[r], t}]];

Print["=== Q. quadratic surds and multiquadratic sums ==="];
probe["Q01", Sqrt[(3 + Sqrt[5])/2], (1 + Sqrt[5])/2];
probe["Q02", Sqrt[2 - Sqrt[3]], (Sqrt[6] - Sqrt[2])/2];
probe["Q03", Sqrt[4 + 3 Sqrt[2]], 2^(1/4) (1 + Sqrt[2])];
probe["Q04", Sqrt[1/2 + Sqrt[3]/4], (Sqrt[6] + Sqrt[2])/4];
probe["Q05", Sqrt[9 + 4 Sqrt[5]], 2 + Sqrt[5]];
probe["Q06", Sqrt[3 - 2 Sqrt[2]], Sqrt[2] - 1];
probe["Q07", Sqrt[7 - 4 Sqrt[3]], 2 - Sqrt[3]];
probe["Q08", Sqrt[112 + 70 Sqrt[2] + (46 + 34 Sqrt[2]) Sqrt[5]], 5 + 4 Sqrt[2] + 3 Sqrt[5] + Sqrt[10]];
probe["Q09", Sqrt[12 + 8 Sqrt[2] + 6 Sqrt[3] + 4 Sqrt[6]], 1 + Sqrt[2] + Sqrt[3] + Sqrt[6]];
probe["Q10", Sqrt[10 + 2 Sqrt[6] + 2 Sqrt[10] + 2 Sqrt[15]], Sqrt[2] + Sqrt[3] + Sqrt[5]];
probe["Q11", Sqrt[17 + 2 Sqrt[6] + 2 Sqrt[10] + 2 Sqrt[14] + 2 Sqrt[15] + 2 Sqrt[21] + 2 Sqrt[35]], Sqrt[2] + Sqrt[3] + Sqrt[5] + Sqrt[7]];
probe["Q12", Sqrt[2 Sqrt[2] + Sqrt[6]], (1 + Sqrt[3])/2^(1/4)];
probe["Q13", Sqrt[(5 + 2 Sqrt[6])/(5 - 2 Sqrt[6])], 5 + 2 Sqrt[6]];
probe["Q14", Sqrt[(5 + 2 Sqrt[6])/3], 1 + Sqrt[6]/3];
probe["Q15", Sqrt[2] Sqrt[2 + Sqrt[3]], 1 + Sqrt[3]];
probe["Q16", Sqrt[6 + 2 Sqrt[6] + 2 Sqrt[5 + 2 Sqrt[6]]], 1 + Sqrt[2] + Sqrt[3], True];
probe["Q17", Sqrt[6 + 2 Sqrt[3] + 4 Sqrt[2 + Sqrt[3]]], 1 + Sqrt[2] + Sqrt[3], True];
probe["Q18", Sqrt[3 + 2 Sqrt[2]] Sqrt[2 + Sqrt[3]] Sqrt[2 - Sqrt[3]], 1 + Sqrt[2]];
probe["Q19", Sqrt[2 + Sqrt[3]] Sqrt[2 - Sqrt[3]], 1];
probe["Q20", Sqrt[5 + 2 Sqrt[6]] + Sqrt[5 - 2 Sqrt[6]], 2 Sqrt[3]];
probe["Q21", Sqrt[1 + Sqrt[3]] + Sqrt[3 + 3 Sqrt[3]] - Sqrt[10 + 6 Sqrt[3]], 0];
probe["Q22", Sqrt[8 + 2 Sqrt[15]], Sqrt[3] + Sqrt[5]];

Print["=== R. Ramanujan-type and Honsbeek-type higher-index identities ==="];
probe["R01", Sqrt[28^(1/3) - 3], (98^(1/3) - 28^(1/3) - 1)/3];
probe["R02", Sqrt[5^(1/3) - 4^(1/3)], (2^(1/3) + 20^(1/3) - 25^(1/3))/3];
probe["R03", (7 20^(1/3) - 19)^(1/6), (5/3)^(1/3) - (2/3)^(1/3)];
probe["R04", ((3 + 2 5^(1/4))/(3 - 2 5^(1/4)))^(1/4), (5^(1/4) + 1)/(5^(1/4) - 1)];
probe["R05", Sqrt[4^(1/3) - 1], (1 + 4^(1/3) - 2^(1/3))/Sqrt[3]];
probe["R06", Sqrt[1 - (1/4)^(1/3)], (2/Sqrt[3]) (-1/2 + 2^(-2/3) + 2^(-4/3))];
probe["R07", Sqrt[(189/20)^(1/3) - 1], Sqrt[(189/20)^(1/3) - 1]];
probe["R08", Sqrt[(128/7)^(1/3) - 1], Sqrt[(128/7)^(1/3) - 1]];
probe["R09", (5 + 3 12^(1/3) + 3 18^(1/3))^(1/3), 2^(1/3) + 3^(1/3)];
probe["R10", Sqrt[4^(1/3) + 2 6^(1/3) + 9^(1/3)], 2^(1/3) + 3^(1/3)];
probe["R11", Sqrt[2 + 2 Sqrt[2] 3^(1/3) + 9^(1/3)], Sqrt[2] + 3^(1/3)];
probe["R12", (3 + 3 2^(1/3) + 3 4^(1/3))^(1/3), 1 + 2^(1/3)];
probe["R13", Sqrt[4 + 2 2^(1/3) + 4^(1/3)], 2^(1/3) + 4^(1/3)];
probe["R14", Sqrt[5 + 4 2^(1/3) + 3 4^(1/3)], 1 + 2^(1/3) + 4^(1/3)];
probe["R15", Sqrt[3 2^(1/3) + 3 4^(1/3) + 3 + 2 6^(1/3) + 2 12^(1/3) + 9^(1/3)], Sqrt[3 2^(1/3) + 3 4^(1/3) + 3 + 2 6^(1/3) + 2 12^(1/3) + 9^(1/3)]];

Print["=== C. cubic, quintic and higher roots in quadratic fields ==="];
probe["C01", (7 + 5 Sqrt[2])^(1/3), 1 + Sqrt[2]];
probe["C02", (85 + 62 Sqrt[7])^(1/3), 1 + 2 Sqrt[7]];
probe["C03", (90 + 34 Sqrt[7])^(1/3), 3 + Sqrt[7]];
probe["C04", (41 + 29 Sqrt[2])^(1/5), 1 + Sqrt[2]];
probe["C05", (41 - 29 Sqrt[2])^(1/5), (-1)^(1/5) (Sqrt[2] - 1)];
probe["C06", (239 + 169 Sqrt[2])^(1/7), 1 + Sqrt[2]];
probe["C07", (11 Sqrt[2] + 9 Sqrt[3])^(1/3), Sqrt[2] + Sqrt[3]];
probe["C08", (56 - 24 Sqrt[5])^(1/4), Sqrt[5] - 1];
probe["C09", (28 + 16 Sqrt[3])^(1/4), 1 + Sqrt[3]];
probe["C10", (7 + 5 Sqrt[2])^(2/3), 3 + 2 Sqrt[2]];
probe["C11", (7 + 5 Sqrt[2])^(-1/3), Sqrt[2] - 1];
probe["C12", (3 + 2 Sqrt[2])^(5/2), 41 + 29 Sqrt[2]];
probe["C13", (-7 - 5 Sqrt[2])^(1/3), (-1)^(1/3) (1 + Sqrt[2])];
probe["C14", (-99 - 70 Sqrt[2])^(1/6), (-1)^(1/6) (1 + Sqrt[2])];
probe["C15", (2 + Sqrt[5])^(1/3) - (Sqrt[5] - 2)^(1/3), 1];
probe["C16", Expand[(Sqrt[2] + Sqrt[3])^5]^(1/5), Sqrt[2] + Sqrt[3]];
probe["C17", Expand[(1 + Sqrt[2] + Sqrt[3])^3]^(1/3), 1 + Sqrt[2] + Sqrt[3]];
probe["C18", Expand[(2^(1/3) + 3^(1/3) + 5^(1/3))^3]^(1/3), 2^(1/3) + 3^(1/3) + 5^(1/3)];
probe["C19", Expand[(1 + Sqrt[2] + Sqrt[3])^4]^(1/4), 1 + Sqrt[2] + Sqrt[3]];
probe["C20", Expand[(1 + Sqrt[2] + Sqrt[3] + Sqrt[5])^2]^(1/2), 1 + Sqrt[2] + Sqrt[3] + Sqrt[5]];

Print["=== X. complex radicands ==="];
probe["X01", Sqrt[3 + 4 I], 2 + I];
probe["X02", Sqrt[-5 + 12 I], 2 + 3 I];
probe["X03", Sqrt[2 I], 1 + I];
probe["X04", Sqrt[-2 I], 1 - I];
probe["X05", Sqrt[-7 - 24 I], 3 - 4 I];
probe["X06", (-2 + 2 I)^(1/3), 1 + I];
probe["X07", (2 + 11 I)^(1/3), 2 + I];
probe["X08", (-5 + I Sqrt[2])^(1/3), 1 + I Sqrt[2]];
probe["X09", Sqrt[1 + I Sqrt[3]], (Sqrt[6] + I Sqrt[2])/2];
probe["X10", Sqrt[-1 + I Sqrt[3]], (Sqrt[2] + I Sqrt[6])/2];
probe["X11", (2 + 2 I Sqrt[3])^(1/2), Sqrt[3] + I];

Print["=== N. expected non-denestable controls ==="];
probe["N01", Sqrt[2 + Sqrt[2]], Sqrt[2 + Sqrt[2]]];
probe["N02", (3 + Sqrt[10])^(1/3), (3 + Sqrt[10])^(1/3)];
probe["N03", (1 + Sqrt[2])^(1/3), (1 + Sqrt[2])^(1/3)];
probe["N04", Sqrt[3 + Sqrt[2] + Sqrt[3]], Sqrt[3 + Sqrt[2] + Sqrt[3]]];

Print["\n=== SUMMARY ==="];
Print[Grid[Prepend[$rows, {"id", "status", "din", "dout", "t"}]]];
Print["non-ok: ", Select[$rows, #[[2]] =!= "ok" &][[All, {1, 2}]]];
