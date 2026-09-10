(* These native tests were supplied but NOT executed in this review environment.
   Run through run_tests.wls in a fresh licensed Wolfram kernel. *)
ClearAll[eq, lower, memberEqualQ, testSession];
eq[a_, b_] := TrueQ[Quiet[Check[RootReduce[a - b] === 0, False]]];
lower[e_] := Module[{r = RadicalDenest3`Strad[e]},
 {eq[r, e], RadicalDenest3`RadicalDepth[r] < RadicalDenest3`RadicalDepth[e]}];
memberEqualQ[list_, v_] := ListQ[list] && AnyTrue[list, eq[#, v] &];
SetAttributes[testSession, HoldAll];
testSession[body_] := RadicalDenest3`Private`standalone[
 Block[{RadicalDenest3`Private`$cfg = Join[RadicalDenest3`Private`$cfg,
   <|"MaxRecursion" -> 0, "MaxTrials" -> 0, "NumericPrefilter" -> False|>]}, body], $Failed];

VerificationTest[
 RadicalDenest3`ExactAlgebraicQ[3/7 + I/5],
 True,
 TestID -> "gaussian-type"
]

VerificationTest[
 RadicalDenest3`ExactAlgebraicQ[Root[#^5 - # - 1 &, 1]],
 True,
 TestID -> "rational-root-type"
]

VerificationTest[
 RadicalDenest3`ExactAlgebraicQ[Root[#^3 + Pi # + 1 &, 1]],
 False,
 TestID -> "transcendental-root-rejected"
]

VerificationTest[
 RadicalDenest3`ExactAlgebraicQ[Root[#^3 - # + parameter &, 1]],
 False,
 TestID -> "parameterized-root-rejected"
]

VerificationTest[
 RadicalDenest3`ExactAlgebraicQ[Root[#^3 + Sqrt[2] # + 1 &, 1]],
 True,
 TestID -> "algebraic-coefficient-root"
]

VerificationTest[
 RadicalDenest3`ExactAlgebraicQ[AlgebraicNumber[Sqrt[2], {1, 2}]],
 True,
 TestID -> "algebraic-number-type"
]

VerificationTest[
 RadicalDenest3`ExactAlgebraicQ[Pi],
 False,
 TestID -> "pi-rejected"
]

VerificationTest[
 RadicalDenest3`ExactAlgebraicQ[1.0],
 False,
 TestID -> "inexact-rejected"
]

VerificationTest[
 RadicalDenest3`ExactAlgebraicQ[Infinity],
 False,
 TestID -> "infinity-rejected"
]

VerificationTest[
 RadicalDenest3`RadicalExpressionQ[Root[#^5 - # - 1 &, 1]],
 False,
 TestID -> "opaque-not-output"
]

VerificationTest[
 RadicalDenest3`EqualityStatus[Sqrt[5 + 2 Sqrt[6]], Sqrt[2] + Sqrt[3]],
 "Equal",
 TestID -> "exact-positive-equality"
]

VerificationTest[
 RadicalDenest3`EqualityStatus[Sqrt[2], -Sqrt[2]],
 "Different",
 TestID -> "conjugates-distinguished"
]

VerificationTest[
 RadicalDenest3`EqualityStatus[1, 1 + 10^-1000],
 "Different",
 TestID -> "tiny-exact-nonzero"
]

VerificationTest[
 RadicalDenest3`EqualityStatus[Pi, Pi],
 "Unknown",
 TestID -> "unsupported-reflexive-pair"
]

VerificationTest[
 Block[{RadicalDenest3`Private`numericallyDifferentQ = (True &)}, RadicalDenest3`EqualityStatus[Sqrt[5 + 2 Sqrt[6]], Sqrt[2] + Sqrt[3]]],
 "Equal",
 TestID -> "exact-status-independent-of-prefilter"
]

VerificationTest[
 lower[Sqrt[3 + 2 Sqrt[2]]],
 {True, True},
 TestID -> "direct"
]

VerificationTest[
 lower[Sqrt[5 + 2 Sqrt[6]]],
 {True, True},
 TestID -> "two-surd"
]

VerificationTest[
 lower[Sqrt[4 + 3 Sqrt[2]]],
 {True, True},
 TestID -> "indirect"
]

VerificationTest[
 lower[Sqrt[3/2 + Sqrt[3]]],
 {True, True},
 TestID -> "indirect-rational"
]

VerificationTest[
 lower[(7 + 5 Sqrt[2])^(1/3)],
 {True, True},
 TestID -> "cubic"
]

VerificationTest[
 lower[(41 - 29 Sqrt[2])^(1/5)],
 {True, True},
 TestID -> "negative-fifth"
]

VerificationTest[
 lower[(-239 - 169 Sqrt[2])^(1/7)],
 {True, True},
 TestID -> "negative-seventh"
]

VerificationTest[
 lower[(1393 - 985 Sqrt[2])^(1/9)],
 {True, True},
 TestID -> "negative-ninth"
]

VerificationTest[
 testSession[RadicalDenest3`Private`negativeRadicandCandidate[(3 + 2 Sqrt[2])^(1/6), 3 + 2 Sqrt[2], 1, 6, (1 + Sqrt[2])^(1/3)]] === (1 + Sqrt[2])^(1/3),
 True,
 TestID -> "negative-stage-preserves-incumbent"
]

VerificationTest[
 Module[{t = (3 + 2 Sqrt[2])^(1/6), r}, r = testSession[RadicalDenest3`Private`kummerCandidates[t, 3 + 2 Sqrt[2], 1, 6, t]]; {eq[r, t], RadicalDenest3`Private`cheaperQ[r, t]}],
 {True, True},
 TestID -> "raw-index-reduction-without-recursion"
]

VerificationTest[
 memberEqualQ[testSession[RadicalDenest3`Private`honsbeekSquareRoots[28^(1/3) - 3]], Sqrt[28^(1/3) - 3]],
 True,
 TestID -> "honsbeek-rational-summand"
]

VerificationTest[
 memberEqualQ[testSession[RadicalDenest3`Private`honsbeekSquareRoots[5^(1/3) - 4^(1/3)]], Sqrt[5^(1/3) - 4^(1/3)]],
 True,
 TestID -> "honsbeek-classical"
]

VerificationTest[
 testSession[RadicalDenest3`Private`cosetBases[{55, 210, 462}, {2, 3, 5, 7, 11}]] // (MemberQ[#, {6, 35, 77, 330}] &),
 True,
 TestID -> "coset-enumeration"
]

VerificationTest[
 memberEqualQ[testSession[RadicalDenest3`Private`surdSystem[{6, 35, 77, 330}, <|1 -> 118, 55 -> 14, 210 -> 2, 462 -> 2|>]], Sqrt[6] + Sqrt[35] + Sqrt[77]],
 True,
 TestID -> "coset-coefficient-solver"
]

VerificationTest[
 RadicalDenest3`RadicalDepth[Root[#^5 + Sqrt[2] # + 1 &, 1]],
 0,
 TestID -> "opaque-depth"
]

VerificationTest[
 RadicalDenest3`Private`radicalNodes[AlgebraicNumber[Root[#^5 + Sqrt[2] # + 1 &, 1], {1, 1}]],
 0,
 TestID -> "opaque-node-count"
]

VerificationTest[
 eq[RadicalDenest3`RationalizeDenominator[1/(1 + Sqrt[2])], 1/(1 + Sqrt[2])],
 True,
 TestID -> "inverse-certificate"
]

VerificationTest[
 eq[RadicalDenest3`RationalizeDenominator[1/(2 + I)], 1/(2 + I)],
 True,
 TestID -> "gaussian-denominator"
]

VerificationTest[
 RadicalDenest3`Strad[1.0 + symbolic] === 1.0 + symbolic,
 True,
 TestID -> "inexact-conservative-default"
]

VerificationTest[
 RadicalDenest3`Strad[{1.0, Sqrt[5 + 2 Sqrt[6]]}] === {1.0, Sqrt[5 + 2 Sqrt[6]]},
 True,
 TestID -> "mixed-list-default"
]

VerificationTest[
 Module[{r = RadicalDenest3`Strad[{1.0, Sqrt[5 + 2 Sqrt[6]]}, "ProcessExactIslands" -> True, "ListProgress" -> "Independent"]}, r[[1]] === 1.0 && eq[r[[2]], Sqrt[5 + 2 Sqrt[6]]] && RadicalDenest3`RadicalDepth[r[[2]]] == 1],
 True,
 TestID -> "mixed-list-opt-in"
]

VerificationTest[
 RadicalDenest3`Strad[HoldComplete[Sqrt[5 + 2 Sqrt[6]]]] === HoldComplete[Sqrt[5 + 2 Sqrt[6]]],
 True,
 TestID -> "hold-not-traversed"
]

VerificationTest[
 RadicalDenest3`Strad[f[Sqrt[5 + 2 Sqrt[6]]]] === f[Sqrt[5 + 2 Sqrt[6]]],
 True,
 TestID -> "unknown-head-not-traversed"
]

VerificationTest[
 eq[RadicalDenest3`Strad[symbolic + Sqrt[5 + 2 Sqrt[6]], "Solver" -> (0 &)] - symbolic, Sqrt[5 + 2 Sqrt[6]]],
 True,
 TestID -> "bad-solver-cannot-cross-host-boundary"
]

VerificationTest[
 Block[{$Assumptions = symbolic > 0}, RadicalDenest3`Strad[Sqrt[symbolic^2]]] === Sqrt[symbolic^2],
 True,
 TestID -> "ambient-assumptions-ignored"
]

VerificationTest[
 FailureQ[RadicalDenest3`Strad[Sqrt[3 + 2 Sqrt[2]], "NoSuchOption" -> 1]],
 True,
 TestID -> "unknown-option"
]

VerificationTest[
 FailureQ[RadicalDenest3`Strad[Sqrt[3 + 2 Sqrt[2]], 17]],
 True,
 TestID -> "malformed-option"
]

VerificationTest[
 FailureQ[RadicalDenest3`Strad[Sqrt[3 + 2 Sqrt[2]], "MultiplierCap" -> Infinity]],
 True,
 TestID -> "infinite-cap"
]

VerificationTest[
 FailureQ[RadicalDenest3`Strad[Sqrt[3 + 2 Sqrt[2]], "MaxTrials" -> -1]],
 True,
 TestID -> "negative-trials"
]

VerificationTest[
 FailureQ[RadicalDenest3`Strad[Sqrt[3 + 2 Sqrt[2]], "MaxSolveDegree" -> 5]],
 True,
 TestID -> "solve-degree-limit"
]

VerificationTest[
 FailureQ[RadicalDenest3`Strad[Sqrt[3 + 2 Sqrt[2]], "ListProgress" -> "Anything"]],
 True,
 TestID -> "invalid-list-policy"
]

VerificationTest[
 RadicalDenest3`DenestReport[Sqrt[3 + 2 Sqrt[2]], "TimeBudget" -> 0]["Status"],
 "Disabled",
 TestID -> "zero-budget"
]

VerificationTest[
 Module[{old = Options[RadicalDenest3`Strad], r}, SetOptions[RadicalDenest3`Strad, "TimeBudget" -> 0]; r = RadicalDenest3`Strad[Sqrt[3 + 2 Sqrt[2]]]; Options[RadicalDenest3`Strad] = old; r === Sqrt[3 + 2 Sqrt[2]]],
 True,
 TestID -> "entry-point-defaults"
]

VerificationTest[
 Module[{r = RadicalDenest3`DenestReport[Sqrt[3 + 2 Sqrt[2]], "MaxTraceEntries" -> 0]}, {r["CertificateRecordScope"], r["Certificates"], r["CompletenessClaim"]}],
 {"AcceptedSearchCandidatesNotFinalProof", {}, False},
 TestID -> "report-scopes"
]

VerificationTest[
 Module[{t = Sqrt[3/2 + Sqrt[3]], u = Sqrt[2 + Sqrt[3 + Sqrt[5]]], v = 3^(1/4) (1 + Sqrt[3])/2}, testSession[Block[{RadicalDenest3`Private`$cfg = Append[RadicalDenest3`Private`$cfg, "ListProgress" -> "Independent"]}, RadicalDenest3`Private`progressQ[{v, u}, {t, u}]]]],
 True,
 TestID -> "independent-list-progress"
]

VerificationTest[
 testSession[Block[{
  RadicalDenest3`Private`powerProposals = Function[{target, best}, best],
  RadicalDenest3`Private`genericProposals = Function[{target, best}, best],
  RadicalDenest3`Private`multiplierSearch = Function[{target, best}, best]},
 RadicalDenest3`Private`improveNumber[Sqrt[2 + Sqrt[2]]];
 KeyExistsQ[RadicalDenest3`Private`$memo, HoldComplete[Sqrt[2 + Sqrt[2]]]]]],
 False,
 TestID -> "failed-search-not-cached"
]

VerificationTest[
 FailureQ[RadicalDenest3`Strad[]],
 True,
 TestID -> "missing-input"
]
