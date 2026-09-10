(* Second probe: further families, then verbose diagnostics of the misses found in probe 1. *)
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

Print["=== P. further families ==="];
probe["P01", Expand[(1 + 2^(1/3) + 4^(1/3))^3]^(1/3), 1 + 2^(1/3) + 4^(1/3)];
probe["P02", Expand[(2^(1/3) + 3^(1/3))^6]^(1/6), 2^(1/3) + 3^(1/3)];
probe["P03", Expand[(1 + 2^(1/3))^4]^(1/4), 1 + 2^(1/3)];
probe["P04", Expand[(1 + 2^(1/3))^5]^(1/5), 1 + 2^(1/3)];
probe["P05", Expand[(Sqrt[2] + Sqrt[3] + 2^(1/3))^2]^(1/2), Sqrt[2] + Sqrt[3] + 2^(1/3)];
probe["P06", Expand[(2^(1/3) + 3^(1/3) + 5^(1/3))^2]^(1/2), 2^(1/3) + 3^(1/3) + 5^(1/3)];
probe["P07", Sqrt[1 + 2 (7 + 5 Sqrt[2])^(1/3) + (7 + 5 Sqrt[2])^(2/3)], 2 + Sqrt[2], True];
probe["P08", Sqrt[1 + Sqrt[2]] Sqrt[Sqrt[2] - 1], 1];
probe["P09", Sqrt[(1 + Sqrt[2])^2], 1 + Sqrt[2]];
probe["P10", Sqrt[(1 - Sqrt[2])^2], Sqrt[2] - 1];
probe["P11", ((1 - Sqrt[2])^3)^(1/3), (-1)^(1/3) (Sqrt[2] - 1)];
probe["P12", Root[#^4 - 10 #^2 + 1 &, 4], Sqrt[2] + Sqrt[3]];
probe["P13", Expand[(Sqrt[2] + Sqrt[3] + Sqrt[5] + Sqrt[7] + Sqrt[11])^2]^(1/2), Sqrt[2] + Sqrt[3] + Sqrt[5] + Sqrt[7] + Sqrt[11]];
probe["P14", Expand[(5 + 7 Sqrt[2])^3]^(1/3), 5 + 7 Sqrt[2]];
probe["P15", (7 + 5 Sqrt[2])^(1/3) + (7 - 5 Sqrt[2])^(1/3), 1 + Sqrt[2] + (-1)^(1/3) (Sqrt[2] - 1)];
probe["P16", (17 + 12 Sqrt[2])^(3/4), 7 + 5 Sqrt[2]];
probe["P17", Expand[((1 + I) (1 + Sqrt[2]))^3]^(1/3), (1 + I) (1 + Sqrt[2])];
probe["P18", (-17 - 12 Sqrt[2])^(1/4), (-1)^(1/4) (1 + Sqrt[2])];
probe["P19", Expand[(41 - 29 Sqrt[2])^2]^(1/10), Sqrt[2] - 1];
probe["P20", Sqrt[1 + 2 2^(1/4) + Sqrt[2]], 1 + 2^(1/4)];
probe["P21", Expand[(1 + 2^(1/4))^4]^(1/4), 1 + 2^(1/4)];
probe["P22", Expand[(2^(1/4) + 3^(1/3))^2]^(1/2), 2^(1/4) + 3^(1/3)];
probe["P23", Expand[(2^(1/4) + 3^(1/3))^3]^(1/3), 2^(1/4) + 3^(1/3)];
probe["P24", Sqrt[a + 2 Sqrt[a - 1]], Sqrt[a + 2 Sqrt[a - 1]]];
probe["P25", Sqrt[2 + Sqrt[3]] + Sqrt[2 - Sqrt[3]] + Sqrt[1 + Sqrt[3]] - Sqrt[(1 + Sqrt[3])^3], Sqrt[6] - Sqrt[3] Sqrt[1 + Sqrt[3]]];
probe["P26", (2 (2 + Sqrt[3]))^(1/2), 1 + Sqrt[3]];
probe["P27", (5 + 2 Sqrt[6])^(1/4) (5 - 2 Sqrt[6])^(1/4), 1];
probe["P28", Sqrt[3 + Sqrt[3 + 2 Sqrt[2]] + Sqrt[5 + 2 Sqrt[6]]], Sqrt[4 + 2 Sqrt[2] + Sqrt[3]], True];
probe["P29", Sqrt[2] Sqrt[3 + 2 Sqrt[2]] Sqrt[Sqrt[2] - 1], Sqrt[2] Sqrt[1 + Sqrt[2]]];
probe["P30", (Sqrt[2] - 1)^(1/3) (Sqrt[2] + 1)^(1/3), 1];

Print["\n=== SUMMARY ==="];
Print["non-ok: ", Select[$rows, #[[2]] =!= "ok" &][[All, {1, 2}]]];

Print["\n=== VERBOSE DIAGNOSTICS ==="];
diag[id_, e_, opts___] := (Print["---- ", id, ": ", ToString[e, InputForm]];
  Print["   result: ", ToString[TimeConstrained[Strad[e, "Verbose" -> True, opts], 400, $TimedOut], InputForm]]);
diag["C05", (41 - 29 Sqrt[2])^(1/5)];
diag["C14", (-99 - 70 Sqrt[2])^(1/6)];
diag["R03", (7 20^(1/3) - 19)^(1/6)];
diag["P08", Sqrt[1 + Sqrt[2]] Sqrt[Sqrt[2] - 1]];
diag["Q21", Sqrt[1 + Sqrt[3]] + Sqrt[3 + 3 Sqrt[3]] - Sqrt[10 + 6 Sqrt[3]]];
diag["R15", Sqrt[3 + 3*2^(1/3) + 3*2^(2/3) + 2*2^(2/3)*3^(1/3) + 3^(2/3) + 2*6^(1/3)]];
Print["DONE"];
