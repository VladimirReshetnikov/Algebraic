(* Native Wolfram regression suite. Supplied but NOT executed in this review.
   Load through run_tests.wls. Fully qualified names allow differential testing. *)

VerificationTest[RadicalDenest3`ExactAlgebraicQ[3/7 + I/5], True, TestID -> "domain-gaussian"]
VerificationTest[RadicalDenest3`ExactAlgebraicQ[Root[#^5 - # - 1 &, 1]], True, TestID -> "domain-rational-polynomial-root"]
VerificationTest[RadicalDenest3`ExactAlgebraicQ[Root[#^5 + Pi # + 1 &, 1]], False, TestID -> "domain-transcendental-coefficient-root"]
VerificationTest[RadicalDenest3`ExactAlgebraicQ[Root[#^5 + parameter # + 1 &, 1]], False, TestID -> "domain-parameter-root"]
VerificationTest[RadicalDenest3`ExactAlgebraicQ[Pi], False, TestID -> "domain-Pi"]
VerificationTest[RadicalDenest3`ExactAlgebraicQ[1.25], False, TestID -> "domain-inexact"]
VerificationTest[RadicalDenest3`ExactAlgebraicQ[Infinity], False, TestID -> "domain-infinite"]
VerificationTest[RadicalDenest3`ExactAlgebraicQ[AlgebraicNumber[Root[#^3 - # - 1 &, 1], {1, 2, 3}]], True, TestID -> "domain-algebraic-number"]
VerificationTest[RadicalDenest3`EqualityStatus[Sqrt[3 + 2 Sqrt[2]], 1 + Sqrt[2]], "Equal", TestID -> "equality-exact"]
VerificationTest[RadicalDenest3`EqualityStatus[Sqrt[3 + 2 Sqrt[2]], -1 - Sqrt[2]], "Different", TestID -> "equality-wrong-branch"]
VerificationTest[RadicalDenest3`EqualityStatus[Pi, Pi], "Unknown", TestID -> "equality-domain-before-SameQ"]
VerificationTest[RadicalDenest3`EqualityStatus[Sqrt[2], -Sqrt[2]], "Different", TestID -> "equality-noncanonical-residual"]
VerificationTest[RadicalDenest3`Private`bitSize[1 + I] > 0, True, TestID -> "cost-gaussian-bits"]
VerificationTest[RadicalDenest3`RadicalDepth[Root[#^5 - # - 1 &, 1]], 0, TestID -> "cost-opaque-depth"]
VerificationTest[RadicalDenest3`Private`radicalNodes[AlgebraicNumber[Root[#^5 - # - 1 &, 1], {1, 2}]], 0, TestID -> "cost-opaque-pruning"]
VerificationTest[FailureQ[RadicalDenest3`Strad[Sqrt[2], "Misspelled" -> 1]], True, TestID -> "unknown-option"]
VerificationTest[FailureQ[RadicalDenest3`Strad[Sqrt[2], 123]], True, TestID -> "nonrule-option"]
VerificationTest[FailureQ[RadicalDenest3`DenestCore[Sqrt[2], "MaxTrials" -> -1]], True, TestID -> "negative-limit"]
VerificationTest[FailureQ[RadicalDenest3`DenestReport[Sqrt[2], "MaxCharacterRank" -> 5]], True, TestID -> "character-rank-limit"]
VerificationTest[RadicalDenest3`DenestReport[Sqrt[2], "TimeBudget" -> 0]["Status"], "Disabled", TestID -> "zero-budget-status"]
VerificationTest[MissingQ[RadicalDenest3`DenestReport[Sqrt[2], "TimeBudget" -> 0]["InitialCost"]], True, TestID -> "zero-budget-no-post-cost"]
VerificationTest[RadicalDenest3`DenestCore[Sqrt[3 + 2 Sqrt[2]], "MaxTrials" -> 0], 1 + Sqrt[2], TestID -> "direct-quadratic"]
VerificationTest[RadicalDenest3`DenestCore[Sqrt[3 - 2 Sqrt[2]], "MaxTrials" -> 0], Sqrt[2] - 1, TestID -> "quadratic-negative-coefficient"]
VerificationTest[RadicalDenest3`CertifiedEqualQ[RadicalDenest3`DenestCore[Sqrt[4 + 3 Sqrt[2]], "MaxTrials" -> 0], 2^(1/4) (1 + Sqrt[2])], True, TestID -> "indirect-quartic"]
VerificationTest[RadicalDenest3`CertifiedEqualQ[RadicalDenest3`DenestCore[(7 + 5 Sqrt[2])^(1/3), "MaxTrials" -> 0], 1 + Sqrt[2]], True, TestID -> "cubic-trace-norm"]
VerificationTest[RadicalDenest3`CertifiedEqualQ[RadicalDenest3`DenestCore[(-7 - 5 Sqrt[2])^(1/3), "MaxTrials" -> 0], (-1)^(1/3) (1 + Sqrt[2])], True, TestID -> "principal-negative-cube"]
VerificationTest[RadicalDenest3`CertifiedEqualQ[RadicalDenest3`DenestCore[(41 + 29 Sqrt[2])^(1/5), "MaxTrials" -> 0], 1 + Sqrt[2]], True, TestID -> "fifth-root-Dickson"]
VerificationTest[RadicalDenest3`CertifiedEqualQ[RadicalDenest3`DenestCore[Sqrt[37 + 4 Sqrt[15] + 6 Sqrt[14] + 2 Sqrt[210]], "MaxTrials" -> 0], Sqrt[6] + Sqrt[10] + Sqrt[21]], True, TestID -> "character-missing-coset"]
VerificationTest[RadicalDenest3`RadicalDepth[RadicalDenest3`DenestCore[Sqrt[37 + 4 Sqrt[15] + 6 Sqrt[14] + 2 Sqrt[210]], "MaxTrials" -> 0]], 1, TestID -> "character-depth-reduction"]
VerificationTest[RadicalDenest3`CertifiedEqualQ[RadicalDenest3`RationalizeDenominator[1/(1 + Sqrt[2])], Sqrt[2] - 1], True, TestID -> "denominator-inverse"]
VerificationTest[RadicalDenest3`Strad[HoldComplete[Sqrt[3 + 2 Sqrt[2]]]], HoldComplete[Sqrt[3 + 2 Sqrt[2]]], TestID -> "held-host-untouched"]
VerificationTest[RadicalDenest3`Strad[unknownHead[Sqrt[3 + 2 Sqrt[2]]]], unknownHead[Sqrt[3 + 2 Sqrt[2]]], TestID -> "unknown-host-untouched"]
VerificationTest[RadicalDenest3`Strad[x + Sqrt[3 + 2 Sqrt[2]], "MaxTrials" -> 0], x + 1 + Sqrt[2], TestID -> "symbolic-host-congruence"]
VerificationTest[Module[{calls = 0, target = Sqrt[2 + Sqrt[2]], result},
 result = RadicalDenest3`DenestCore[target,
   "Solver" -> Function[e, calls++; 0], "MaxTrials" -> 0];
 calls > 0 && result =!= 0 && RadicalDenest3`CertifiedEqualQ[result, target]],
 True, TestID -> "incorrect-callback-cannot-override"]

(* White-box sessions isolate control-flow contracts from CAS discovery. *)
SetAttributes[withReviewSession, HoldAll];
withReviewSession[body_] := Block[{
 RadicalDenest3`Private`$active = True,
 RadicalDenest3`Private`$cfg = Association[Options[RadicalDenest3`Strad]],
 RadicalDenest3`Private`$deadline = AbsoluteTime[] + 120,
 RadicalDenest3`Private`$stats = RadicalDenest3`Private`newStats[],
 RadicalDenest3`Private`$limits = <||>, RadicalDenest3`Private`$trace = {},
 RadicalDenest3`Private`$records = {}, RadicalDenest3`Private`$memo = <||>,
 RadicalDenest3`Private`$inProgress = <||>, RadicalDenest3`Private`$recursion = 0,
 $Assumptions = True}, body];

VerificationTest[withReviewSession[
 Module[{rho = 3 + 2 Sqrt[2], target},
  target = rho^(1/4);
  Block[{RadicalDenest3`Private`recurse = Function[e, e]},
   RadicalDenest3`Private`kummerCandidates[target, rho, 1, 4] === Sqrt[1 + Sqrt[2]]]]],
 True, TestID -> "index-reduction-without-recursive-progress"]

VerificationTest[withReviewSession[
 Module[{rho, target, partial},
  rho = 16 - 2 Sqrt[29] + 2 Sqrt[55 - 10 Sqrt[29]];
  target = Sqrt[-rho]; partial = Sqrt[5] + Sqrt[11 - 2 Sqrt[29]];
  Block[{RadicalDenest3`Private`rootCandidates = Function[{r, q}, {}],
    RadicalDenest3`Private`recurse = Function[e, partial],
    RadicalDenest3`Private`linearRoots = Function[{r, q}, {}]},
   RadicalDenest3`Private`powerProposals[target, target] === Expand[I partial]]]],
 True, TestID -> "partial-negative-improvement-survives-later-noop"]

VerificationTest[withReviewSession[
 Module[{calls = 0, target = Sqrt[2 + Sqrt[2]]},
  Block[{RadicalDenest3`Private`powerProposals = Function[{t, b}, b],
    RadicalDenest3`Private`genericProposals = Function[{t, b}, b],
    RadicalDenest3`Private`multiplierSearch = Function[{t, b}, calls++; b]},
   RadicalDenest3`Private`improveNumber[target];
   RadicalDenest3`Private`improveNumber[target]; calls]]],
 2, TestID -> "no-negative-cache"]

VerificationTest[withReviewSession[
 Module[{target = Sqrt[2 + Sqrt[2]]},
  AssociateTo[RadicalDenest3`Private`$inProgress, target -> True];
  RadicalDenest3`Private`improveNumber[target] === target]],
 True, TestID -> "in-progress-cycle-cut"]

VerificationTest[withReviewSession[
 Block[{RadicalDenest3`Private`$cfg = Append[RadicalDenest3`Private`$cfg, "NumericPrefilter" -> True],
   RadicalDenest3`Private`numericallyDifferentQ = Function[e, True]},
  RadicalDenest3`Private`certify[Sqrt[3 + 2 Sqrt[2]], 1 + Sqrt[2]]]],
 "Equal", TestID -> "numeric-diagnostic-never-suppresses-exact-proof"]

VerificationTest[withReviewSession[
 Module[{rep},
  rep = RadicalDenest3`DenestReport[Sqrt[3 + 2 Sqrt[2]], "MaxTrials" -> 0];
  AllTrue[rep["Certificates"], RadicalDenest3`CertifiedEqualQ[#["Before"], #["After"]] &]]],
 True, TestID -> "every-reported-proposal-recertifies"]
