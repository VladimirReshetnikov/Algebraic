(* Fourth probe: the factorizer's effect (S05, P13), profiling of P13, and a few more shapes. *)
Get["C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/corrected/StradFixed.wl"];
Print["Kernel: ", $Version];
depth[e_] := RadicalDenest`RadicalDepth[e];
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

Print["=== F. the factorizer's effect on S05 ==="];
s05 = (1296 + 880*Sqrt[2] + 720*Sqrt[3] + 528*Sqrt[6])^(1/6);
Print["Factorc[radicand] = ", ToString[RadicalDenest`Factorc[First[s05]], InputForm]];
Print["Factorc[problem]  = ", ToString[RadicalDenest`Factorc[s05], InputForm]];
probe["S05b", (1296 + 880*Sqrt[2] + 720*Sqrt[3] + 528*Sqrt[6])^(1/6), 1 + Sqrt[2] + Sqrt[3], "Factor" -> False];
probe["S05c", (1296 + 880*Sqrt[2] + 720*Sqrt[3] + 528*Sqrt[6])^(1/6), 1 + Sqrt[2] + Sqrt[3], "Verbose" -> True];
probe["S21", Expand[(2 + 2 Sqrt[2])^6]^(1/6), 2 + 2 Sqrt[2]];
probe["S22", Expand[(2 + 2 Sqrt[2])^4]^(1/4), 2 + 2 Sqrt[2]];
probe["S23", Expand[(2 + 2 Sqrt[2])^3]^(1/3), 2 + 2 Sqrt[2]];
probe["S24", Expand[(3 + 3 Sqrt[2])^5]^(1/5), 3 + 3 Sqrt[2]];
probe["S25", Expand[(2 Sqrt[2] + 2 Sqrt[3])^2]^(1/2), 2 Sqrt[2] + 2 Sqrt[3]];
probe["S26", Expand[(3 + 3 2^(1/3))^3]^(1/3), 3 + 3 2^(1/3)];

Print["\n=== T. where does the time go on the five-prime sum? ==="];
p13 = Sqrt[28 + 2*Sqrt[6] + 2*Sqrt[10] + 2*Sqrt[14] + 2*Sqrt[15] + 2*Sqrt[21] + 2*Sqrt[22] + 2*Sqrt[33] + 2*Sqrt[35] + 2*Sqrt[55] + 2*Sqrt[77]];
tc[e_] := TimeConstrained[e, 150, $TimedOut];
SetAttributes[tc, HoldAll];
Print["Factorc[radicand]:        ", AbsoluteTiming[tc[RadicalDenest`Factorc[First[p13]]]] /. e_ /; LeafCount[e] > 40 :> Short[e]];
Print["Factorc[problem]:         ", AbsoluteTiming[tc[RadicalDenest`Factorc[p13]]] /. e_ /; LeafCount[e] > 40 :> Short[e]];
Print["DenestCore, m=1 only:     ", AbsoluteTiming[tc[RadicalDenest`DenestCore[p13, "Multipliers" -> {1}]]]];
Print["DenestCore, default:      ", AbsoluteTiming[tc[RadicalDenest`DenestCore[p13, "MaxTrials" -> 3, "TimeBudget" -> 10]]]];
Print["Strad, Factor->False:     ", AbsoluteTiming[tc[Strad[p13, "Factor" -> False, "MaxTrials" -> 3, "TimeBudget" -> 10]]]];
Print["Strad, Multipliers->{1}:  ", AbsoluteTiming[tc[Strad[p13, "Multipliers" -> {1}]]]];
p4 = Sqrt[17 + 2 Sqrt[6] + 2 Sqrt[10] + 2 Sqrt[14] + 2 Sqrt[15] + 2 Sqrt[21] + 2 Sqrt[35]];
Print["four primes, Factorc[radicand]: ", AbsoluteTiming[tc[RadicalDenest`Factorc[First[p4]]]][[1]]];
Print["four primes, DenestCore m=1:    ", AbsoluteTiming[tc[RadicalDenest`DenestCore[p4, "Multipliers" -> {1}]]]];
Print["four primes, Strad default:     ", AbsoluteTiming[tc[Strad[p4]]]];

Print["\n=== M. more shapes ==="];
probe["M01", Sqrt[(-1 + I Sqrt[3])/2], (1 + I Sqrt[3])/2];
probe["M02", 1/(Sqrt[2] + Sqrt[3 + 2 Sqrt[2]]), (2 Sqrt[2] - 1)/7];
probe["M03", (Sqrt[2] + Sqrt[3])/Sqrt[5 + 2 Sqrt[6]], 1];
probe["M04", Sqrt[(10 + 2 Sqrt[6] + 2 Sqrt[10] + 2 Sqrt[15])/4], (Sqrt[2] + Sqrt[3] + Sqrt[5])/2];
probe["M05", Sqrt[3 (5 + 2 Sqrt[6])], 3 + Sqrt[6]];
probe["M06", Sqrt[2 (5 + 2 Sqrt[6])], 2 + Sqrt[6]];
probe["M07", Sqrt[Sqrt[2] (3 + 2 Sqrt[2])], 2^(1/4) (1 + Sqrt[2])];
probe["M08", (10 + 7 Sqrt[2])^(1/3), 2^(1/6) (1 + Sqrt[2])];
probe["M09", Sqrt[3 + Sqrt[2] + Sqrt[3] + Sqrt[6]] , Sqrt[3 + Sqrt[2] + Sqrt[3] + Sqrt[6]]];
probe["M10", Sqrt[4 + Sqrt[2] + Sqrt[6]], Sqrt[4 + Sqrt[2] + Sqrt[6]]];
probe["M11", Sqrt[5 + 2 Sqrt[3] + 2 Sqrt[2 + Sqrt[3]] ], Sqrt[5 + 2 Sqrt[3] + 2 Sqrt[2 + Sqrt[3]] ], True];
probe["M12", Sqrt[2 + Sqrt[2]] Sqrt[2 - Sqrt[2]], Sqrt[2]];
probe["M13", Sqrt[2 + Sqrt[2]] + Sqrt[2 - Sqrt[2]], Sqrt[4 + 2 Sqrt[2]]];
probe["M14", Sqrt[2 + Sqrt[3]] - Sqrt[2 - Sqrt[3]], Sqrt[2]];
probe["M15", (Sqrt[2 + Sqrt[3]] + Sqrt[2 - Sqrt[3]])^2, 6];

Print["\n=== SUMMARY ==="];
Print["non-ok: ", Select[$rows, #[[2]] =!= "ok" &][[All, {1, 2}]]];
Print["DONE"];
