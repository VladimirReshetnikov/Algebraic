(* Third probe: hypothesis tests for the misses of probes 1-2 and more cases of the same shapes. *)
Get["C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/corrected/StradFixed3.wl"];
Print["Kernel: ", $Version];
depth[e_] := RadicalDenest3`RadicalDepth[e];
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

Print["=== H1. what does the core's Solve step return for C05 / R03 / P02? ==="];
inspect[id_, problem_, r_] := Module[{x, rho, mp, g, roots, cands},
  rho = problem^r;
  mp = MinimalPolynomial[problem, x];
  g = Quiet[PolynomialGCD[mp, x^r - rho, Extension -> Automatic]];
  Print["-- ", id, "  minpoly degree ", Exponent[mp, x], ",  gcd degree ", Exponent[g, x]];
  roots = Quiet[x /. Solve[g == 0, x]];
  Print["   Solve roots: ", ToString[Short[roots, 4], InputForm]];
  Print["   contain Root objects: ", ! FreeQ[roots, _Root], "   RadicalCost of roots: ", RadicalDenest3`RadicalCost /@ roots];
  cands = Quiet[ToRadicals /@ roots];
  Print["   ToRadicals: ", ToString[cands, InputForm]];
  Print["   certified equal to problem: ", Select[cands, eq[#, problem] &]]];
inspect["C05", (41 - 29 Sqrt[2])^(1/5), 5];
inspect["C14", (-99 - 70 Sqrt[2])^(1/6), 6];
inspect["R03", (7 20^(1/3) - 19)^(1/6), 6];
inspect["P02", Expand[(2^(1/3) + 3^(1/3))^6]^(1/6), 6];

Print["\n=== H2. R15 without the factorizer, and the factorizer's effect ==="];
r15 = Sqrt[3 + 3*2^(1/3) + 3*2^(2/3) + 2*2^(2/3)*3^(1/3) + 3^(2/3) + 2*6^(1/3)];
Print["Factorc[radicand] = ", ToString[RadicalDenest3`Factorc[First[r15]], InputForm]];
probe["R15b", Sqrt[3 + 3*2^(1/3) + 3*2^(2/3) + 2*2^(2/3)*3^(1/3) + 3^(2/3) + 2*6^(1/3)], 1 + 2^(1/3) + 3^(1/3), "Factor" -> False];
probe["R15c", Sqrt[3 + 3*2^(1/3) + 3*2^(2/3) + 2*2^(2/3)*3^(1/3) + 3^(2/3) + 2*6^(1/3)], 1 + 2^(1/3) + 3^(1/3), "Multipliers" -> {1}];
probe["R16", Expand[(1 + 2^(1/3) + 5^(1/3))^2]^(1/2), 1 + 2^(1/3) + 5^(1/3)];
probe["R17", Expand[(2 + 2^(1/3) + 3^(1/3))^2]^(1/2), 2 + 2^(1/3) + 3^(1/3)];
probe["R18", Expand[(1 + 3^(1/3) + 9^(1/3))^2]^(1/2), 1 + 3^(1/3) + 9^(1/3)];
probe["R19", Expand[(3 + 3^(1/3))^2]^(1/2), 3 + 3^(1/3)];

Print["\n=== H3. time budget on the five-prime sum ==="];
p13 = Sqrt[28 + 2*Sqrt[6] + 2*Sqrt[10] + 2*Sqrt[14] + 2*Sqrt[15] + 2*Sqrt[21] + 2*Sqrt[22] + 2*Sqrt[33] + 2*Sqrt[35] + 2*Sqrt[55] + 2*Sqrt[77]];
Print["MinimalPolynomial time of the answer: ", AbsoluteTiming[MinimalPolynomial[Sqrt[2] + Sqrt[3] + Sqrt[5] + Sqrt[7] + Sqrt[11], x];][[1]]];
Print["MinimalPolynomial time of the problem: ", AbsoluteTiming[TimeConstrained[MinimalPolynomial[p13, x], 120, $TimedOut]][[1]]];
Print["RootReduce time of the difference:      ", AbsoluteTiming[TimeConstrained[RootReduce[p13 - (Sqrt[2] + Sqrt[3] + Sqrt[5] + Sqrt[7] + Sqrt[11])], 120, $TimedOut]]];
{t, r} = AbsoluteTiming[TimeConstrained[Strad[p13, "TimeBudget" -> 20, "MaxTrials" -> 5, "CertifyTime" -> 10], 400, $TimedOut]];
Print["Strad with TimeBudget 20, MaxTrials 5, CertifyTime 10: ", Round[t, 0.1], " s -> ", ToString[Short[r], InputForm]];

Print["\n=== H4. more roots whose degree exceeds the radicand's degree, and roots of negatives ==="];
probe["S01", Expand[(1 + 2^(1/3))^6]^(1/6), 1 + 2^(1/3)];
probe["S02", Expand[(Sqrt[2] + 3^(1/3))^6]^(1/6), Sqrt[2] + 3^(1/3)];
probe["S03", Expand[(2^(1/3) + 3^(1/3))^4]^(1/4), 2^(1/3) + 3^(1/3)];
probe["S04", Expand[(2^(1/3) + 3^(1/3))^9]^(1/9), 2^(1/3) + 3^(1/3)];
probe["S05", Expand[(1 + Sqrt[2] + Sqrt[3])^6]^(1/6), 1 + Sqrt[2] + Sqrt[3]];
probe["S06", Expand[(1 + Sqrt[2])^10]^(1/10), 1 + Sqrt[2]];
probe["S07", Expand[(1 + Sqrt[2])^8]^(1/8), 1 + Sqrt[2]];
probe["S08", Expand[(1 + Sqrt[2])^12]^(1/12), 1 + Sqrt[2]];
probe["S09", Expand[(7 + 5 Sqrt[2])^2]^(1/6), 1 + Sqrt[2]];
probe["S10", Expand[(2^(1/3) + 5^(1/3))^6]^(1/6), 2^(1/3) + 5^(1/3)];
probe["S11", Expand[-(1 + 2^(1/3))^5]^(1/5), (-1)^(1/5) (1 + 2^(1/3))];
probe["S12", Expand[-(1 + Sqrt[2])^7]^(1/7), (-1)^(1/7) (1 + Sqrt[2])];
probe["S13", Expand[(1 - Sqrt[3])^5]^(1/5), (-1)^(1/5) (Sqrt[3] - 1)];
probe["S14", Expand[(2 - Sqrt[5])^5]^(1/5), (-1)^(1/5) (Sqrt[5] - 2)];
probe["S15", Expand[(1 - Sqrt[2])^9]^(1/9), (-1)^(1/9) (Sqrt[2] - 1)];
probe["S16", Expand[(1 - Sqrt[2])^4]^(1/4), Sqrt[2] - 1];
probe["S17", Expand[(1 - Sqrt[2])^6]^(1/6), Sqrt[2] - 1];
probe["S18", Expand[(1 - Sqrt[2])^3]^(1/3), (-1)^(1/3) (Sqrt[2] - 1)];
probe["S19", Expand[(1 - 2^(1/3))^3]^(1/3), (-1)^(1/3) (2^(1/3) - 1)];
probe["S20", Expand[(Sqrt[2] - Sqrt[3])^5]^(1/5), (-1)^(1/5) (Sqrt[3] - Sqrt[2])];

Print["\n=== SUMMARY ==="];
Print["non-ok: ", Select[$rows, #[[2]] =!= "ok" &][[All, {1, 2}]]];
Print["DONE"];
