(* Execute the three reviews' proposed (never executed) single-trial kernels on common cases *)
base = "C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/";
Print["Kernel: ", $Version];
eq[a_, b_] := Quiet[TrueQ[RootReduce[a - b] === 0]];
SetAttributes[try, HoldAll];
try[label_, expr_] := Module[{t, r},
  {t, r} = AbsoluteTiming[TimeConstrained[Quiet[Check[expr, $CheckFailed]], 120, $TimedOut]];
  Print["  ", label, " -> ", ToString[r, InputForm], "   (", Round[t, 0.01], " s)"]; r];

cases = {
  {"positive sqrt m=2", Sqrt[5 + 2 Sqrt[6]], 2, 2, Sqrt[2] + Sqrt[3]},
  {"positive sqrt m=1 (no proper GCD)", Sqrt[5 + 2 Sqrt[6]], 2, 1, None},
  {"negative target", -Sqrt[3 + 2 Sqrt[2]], 2, 1, -1 - Sqrt[2]},
  {"complex 3/2 power", (-1 + 2 I Sqrt[2])^(3/2), 2, 1, -5 + I Sqrt[2]},
  {"complex product", Sqrt[-1 + 2 I Sqrt[2]] Sqrt[-2 + 2 I Sqrt[3]], 2, 1, (1 + I Sqrt[2]) (1 + I Sqrt[3])},
  {"cube root m=9", (2^(1/3) - 1)^(1/3), 3, 9, (1 - 2^(1/3) + 4^(1/3))/9^(1/3)},
  {"equal-degree multiplier", Sqrt[5 + 2 Sqrt[6]], 2, 6 - 2 Sqrt[6] - 2 Sqrt[2] + 2 Sqrt[3], Sqrt[2] + Sqrt[3]},
  {"zero multiplier", Sqrt[3 + 2 Sqrt[2]], 2, 0, None},
  {"inexact multiplier", Sqrt[3 + 2 Sqrt[2]], 2, 2.0, None},
  {"root order 1", Sqrt[2], 1, 1, None},
  {"symbolic target", Sqrt[x^2 + 1], 2, 1, None}};

Print["\n########## review-1: VerifiedMultiplierTrial[beta, r, m] ##########"];
Get[base <> "review-1/verified_multiplier_trial.wl"];
Do[Module[{r = try[c[[1]], RadicalAudit`VerifiedMultiplierTrial[c[[2]], c[[3]], c[[4]]]]},
   If[AssociationQ[r] && KeyExistsQ[r, "Value"] && c[[5]] =!= None,
    Print["     value equals expected: ", eq[r["Value"], c[[5]]], "   equals target: ", eq[r["Value"], c[[2]]]]]], {c, cases}];
Quiet[Remove["RadicalAudit`*"]];

Print["\n########## review-2: CertifiedMultiplierStep[target, k, m] ##########"];
Get[base <> "review-2/safer_core.wl"];
Do[Module[{r = try[c[[1]], RadicalAudit`CertifiedMultiplierStep[c[[2]], c[[3]], c[[4]]]]},
   If[AssociationQ[r] && KeyExistsQ[r, "Candidates"] && r["Candidates"] =!= {} && c[[5]] =!= None,
    Print["     first candidate equals expected: ", eq[First[r["Candidates"]], c[[5]]], "   equals target: ", eq[First[r["Candidates"]], c[[2]]]]]], {c, cases}];

Print["\n########## review-3: TryDenestCandidate[original, q, m] ##########"];
Get[base <> "review-3/radical_denesting_review/safe_candidate_kernel.wl"];
Do[Module[{r = try[c[[1]], RadicalDenestingAudit`TryDenestCandidate[c[[2]], c[[3]], c[[4]]]]},
   If[AssociationQ[r] && KeyExistsQ[r, "Candidates"] && r["Candidates"] =!= {} && c[[5]] =!= None,
    Print["     first candidate equals expected: ", eq[First[r["Candidates"]], c[[5]]], "   equals target: ", eq[First[r["Candidates"]], c[[2]]]];
    Print["     BestImprovement: ", InputForm[RadicalDenestingAudit`BestImprovement[c[[2]], r["Candidates"]]]]]], {c, cases}];
Print["  RadicalDepth of ugly BFHT output: ", RadicalDenestingAudit`RadicalDepth[(Sqrt[319 - 58 Sqrt[29]] - 10 Sqrt[11 - 2 Sqrt[29]] + Sqrt[5] (-16 + 3 Sqrt[29]))/(-5 + Sqrt[29] - Sqrt[55 - 10 Sqrt[29]])]];
Print["  CandidateCost of it: ", RadicalDenestingAudit`CandidateCost[(Sqrt[319 - 58 Sqrt[29]] - 10 Sqrt[11 - 2 Sqrt[29]] + Sqrt[5] (-16 + 3 Sqrt[29]))/(-5 + Sqrt[29] - Sqrt[55 - 10 Sqrt[29]])], "  vs input ", RadicalDenestingAudit`CandidateCost[Sqrt[16 - 2 Sqrt[29] + 2 Sqrt[55 - 10 Sqrt[29]]]]];

Print["\n########## review-2 regression tests of the guarded component (re-run with safer_core loaded) ##########"];
Get[base <> "review-2/original.wl"];
auditEqual[a_, b_] := TrueQ[Quiet[Check[RootReduce[a - b] === 0, False]]];
Print["  zero multiplier -> Failure: ", MatchQ[RadicalAudit`CertifiedMultiplierStep[Sqrt[3 + 2 Sqrt[2]], 2, 0], _Failure]];
Print["  root order one -> Failure: ", MatchQ[RadicalAudit`CertifiedMultiplierStep[Sqrt[2], 1, 1], _Failure]];
Print["  negative target certified: ", Module[{r = RadicalAudit`CertifiedMultiplierStep[-Sqrt[3 + 2 Sqrt[2]], 2, 1]}, AssociationQ[r] && r["Candidates"] =!= {} && AllTrue[r["Candidates"], auditEqual[#, -1 - Sqrt[2]] &]]];
Print["  complex target certified: ", Module[{r = RadicalAudit`CertifiedMultiplierStep[(-1 + 2 I Sqrt[2])^(3/2), 2, 1]}, AssociationQ[r] && r["Candidates"] =!= {} && AllTrue[r["Candidates"], auditEqual[#, -5 + I Sqrt[2]] &]]];
Print["\nDONE"];
