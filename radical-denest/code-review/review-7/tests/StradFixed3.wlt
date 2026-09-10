(* Native Wolfram regression suite. SUPPLIED, NOT EXECUTED in this review.
   Load ../code/StradFixed3.wl first; tests use fully qualified public names. *)
VerificationTest[RadicalDenest3`ExactAlgebraicQ[3/7], True, TestID -> "rational-admission"]
VerificationTest[RadicalDenest3`ExactAlgebraicQ[2 + 3 I], True, TestID -> "gaussian-admission"]
VerificationTest[RadicalDenest3`ExactAlgebraicQ[Pi], False, TestID -> "reject-pi"]
VerificationTest[RadicalDenest3`ExactAlgebraicQ[1.2], False, TestID -> "reject-inexact"]
VerificationTest[RadicalDenest3`ExactAlgebraicQ[Root[#^5 + # - 1 &, 1]], True, TestID -> "rational-root-admission"]
VerificationTest[RadicalDenest3`ExactAlgebraicQ[Root[#^5 + # - Pi &, 1]], False, TestID -> "transcendental-root-rejected"]
VerificationTest[Module[{a}, RadicalDenest3`ExactAlgebraicQ[Root[#^5 + # + a &, 1]]], False, TestID -> "parametric-root-rejected"]
VerificationTest[RadicalDenest3`EqualityStatus[Root[#^5 + # - Pi &, 1], 0], "Unknown", TestID -> "unsupported-root-equality-unknown"]
VerificationTest[RadicalDenest3`EqualityStatus[Sqrt[5 + 2 Sqrt[6]], Sqrt[2] + Sqrt[3]], "Equal", TestID -> "classical-exact-equality"]
VerificationTest[RadicalDenest3`EqualityStatus[0, 10^-100], "Different", TestID -> "small-nonzero-exact"]
VerificationTest[RadicalDenest3`EqualityStatus[(-8)^(1/3), -2], "Different", TestID -> "principal-not-real-cube-root"]
VerificationTest[RadicalDenest3`CertifiedEqualQ[Pi, Pi], False, TestID -> "outside-grammar-not-certified"]
VerificationTest[
 Block[{RadicalDenest3`Private`numericallyDifferentQ = (True &)},
  RadicalDenest3`EqualityStatus[Sqrt[5 + 2 Sqrt[6]], Sqrt[2] + Sqrt[3]]],
 "Equal", TestID -> "injected-false-numeric-hint-cannot-decide"]
VerificationTest[FailureQ[RadicalDenest3`Strad[1, 17]], True, TestID -> "nonrule-option-fails"]
VerificationTest[FailureQ[RadicalDenest3`Strad[]], True, TestID -> "missing-input-fails"]
VerificationTest[FailureQ[RadicalDenest3`Strad[1, "Typo" -> 1]], True, TestID -> "unknown-option-fails"]
VerificationTest[FailureQ[RadicalDenest3`Strad[1, "TimeBudget" -> Infinity]], True, TestID -> "infinite-budget-fails"]
VerificationTest[FailureQ[RadicalDenest3`Strad[1, "MaxTrials" -> -1]], True, TestID -> "negative-trials-fail"]
VerificationTest[FailureQ[RadicalDenest3`Strad[1, "AllLevels" -> 1]], True, TestID -> "invalid-boolean-fails"]
VerificationTest[FailureQ[RadicalDenest3`Strad[1, "MaxSolveDegree" -> 5]], True, TestID -> "solve-degree-ceiling"]
VerificationTest[RadicalDenest3`DenestReport[Sqrt[5 + 2 Sqrt[6]], "TimeBudget" -> 0]["Status"], "Disabled", TestID -> "zero-budget-disabled"]
VerificationTest[RadicalDenest3`DenestReport[1, "TimeBudget" -> 0]["FinalCost"], Missing["NotComputed"], TestID -> "disabled-no-unbudgeted-cost"]
VerificationTest[RadicalDenest3`DenestReport[1, {"MaxTrials" -> 0}, "TimeBudget" -> 0]["Options"]["MaxTrials"], 0, TestID -> "nested-option-list"]
VerificationTest[RadicalDenest3`DenestReport[1, "MaxTrials" -> 0, "MaxTrials" -> 3]["Options"]["MaxTrials"], 0, TestID -> "first-option-wins"]
VerificationTest[Module[{old=Options[RadicalDenest3`Strad], r},
 SetOptions[RadicalDenest3`Strad, "TimeBudget" -> 0];
 r=RadicalDenest3`Strad[Sqrt[5 + 2 Sqrt[6]]];
 Options[RadicalDenest3`Strad]=old; r], Sqrt[5 + 2 Sqrt[6]], TestID -> "setoptions-entrypoint"]
VerificationTest[RadicalDenest3`RadicalDepth[Sqrt[1 + Sqrt[2]]], 2, TestID -> "nested-depth"]
VerificationTest[RadicalDenest3`RadicalDepth[Root[#^5 + Sqrt[2] # + 1 &, 1]], 0, TestID -> "opaque-depth"]
VerificationTest[RadicalDenest3`RadicalCost[Root[#^5 + Sqrt[2] # + 1 &, 1]][[3]], 0, TestID -> "opaque-radical-count"]
VerificationTest[RadicalDenest3`RadicalCost[1 + 2^100 I][[5]] > RadicalDenest3`RadicalCost[1 + I][[5]], True, TestID -> "complex-bit-size"]
VerificationTest[Module[{e=Sqrt[5+2 Sqrt[6]], r}, r=RadicalDenest3`Strad[e];
 RootReduce[r-e]===0 && RadicalDenest3`RadicalDepth[r]===1], True, TestID -> "direct-denesting"]
VerificationTest[Module[{e=Sqrt[4+3 Sqrt[2]], r}, r=RadicalDenest3`Strad[e];
 RootReduce[r-e]===0 && RadicalDenest3`RadicalDepth[r]===1], True, TestID -> "indirect-denesting"]
VerificationTest[Module[{e=(7+5 Sqrt[2])^(1/3), r}, r=RadicalDenest3`Strad[e];
 RootReduce[r-e]===0 && RadicalDenest3`RadicalDepth[r]===1], True, TestID -> "quadratic-cube-root"]
VerificationTest[Module[{e=(7-5 Sqrt[2])^(1/3), r}, r=RadicalDenest3`Strad[e];
 RootReduce[r-e]===0], True, TestID -> "negative-cube-branch"]
VerificationTest[Module[{e=(41-29 Sqrt[2])^(1/5), r}, r=RadicalDenest3`Strad[e];
 RootReduce[r-e]===0 && RadicalDenest3`RadicalDepth[r]===1], True, TestID -> "negative-fifth-root"]
VerificationTest[Module[{e=Sqrt[5^(1/3)-4^(1/3)],r},r=RadicalDenest3`Strad[e];
 RootReduce[r-e]===0 && RadicalDenest3`RadicalDepth[r]===1], True, TestID -> "honsbeek"]
VerificationTest[Module[{e=Sqrt[15+2 Sqrt[6]+2 Sqrt[10]+2 Sqrt[15]],r},r=RadicalDenest3`Strad[e];
 RootReduce[r-e]===0], True, TestID -> "multisurd-safety"]
VerificationTest[Module[{x,e,r},e=x+Sqrt[5+2 Sqrt[6]];
 r=RadicalDenest3`Strad[e,"Solver" -> (0 &)];RootReduce[(r-x)-(e-x)]===0], True, TestID -> "host-wrong-solver-not-accepted"]
VerificationTest[Module[{x,e,r},e=x+Sqrt[1+Sqrt[2]];
 r=Block[{$Assumptions=x==0},RadicalDenest3`Strad[e,"Solver" -> (0 &),"MaxTrials"->0]];
 !FreeQ[r,x] && RootReduce[(r-x)-(e-x)]===0], True, TestID -> "assumptions-isolation"]
VerificationTest[Module[{e=1.0+Sqrt[1+Sqrt[2]]},SameQ[RadicalDenest3`Strad[e],e]], True, TestID -> "inexact-tree-intentional-noop"]
VerificationTest[RadicalDenest3`Strad[HoldComplete[Sqrt[5+2 Sqrt[6]]]], HoldComplete[Sqrt[5+2 Sqrt[6]]], TestID -> "held-host-opaque"]
VerificationTest[Module[{e=Sqrt[1+Sqrt[2]],r},r=RadicalDenest3`DenestReport[e,"MaxTrials"->0,"Multipliers"->{},"Solver"->(0 &)];
 RootReduce[r["Result"]-e]===0 && r["Statistics"]["Trials"]===0], True, TestID -> "zero-trials-safe"]
VerificationTest[Module[{e=Sqrt[1+Sqrt[2]],r},r=RadicalDenest3`DenestReport[e,"MaxTrials"->1,"MultiplierCap"->1,"MaxRecursion"->0];
 RootReduce[r["Result"]-e]===0 && r["Statistics"]["Trials"]<=1], True, TestID -> "single-visit-trial-cap"]
VerificationTest[Module[{e=Sqrt[1+Sqrt[2]],r},r=RadicalDenest3`DenestReport[e,"Solver"->(Throw[0]&),"MaxTrials"->0];
 RootReduce[r["Result"]-e]===0], True, TestID -> "throwing-solver-quarantined"]
VerificationTest[Module[{e=Sqrt[5+2 Sqrt[6]],r},r=RadicalDenest3`DenestReport[e];
 r["FinalCost"]===RadicalDenest3`RadicalCost[r["Result"]] && StringQ[r["CertificateKind"]]], True, TestID -> "report-cost-and-evidence-kind"]
VerificationTest[Module[{e=1/(1+Sqrt[2]),r},r=RadicalDenest3`RationalizeDenominator[e];
 RootReduce[r-e]===0], True, TestID -> "denominator-inverse"]
VerificationTest[
 RadicalDenest3`Private`standalone[
  Module[{t=(3+2 Sqrt[2])^(1/4),i=Sqrt[1+Sqrt[2]]},
   SameQ[RadicalDenest3`Private`negativeRadicandCandidate[t,3+2 Sqrt[2],1,4,i],i]],False],
 True, TestID -> "positive-radicand-preserves-incumbent"]
VerificationTest[
 RadicalDenest3`Private`standalone[
  Block[{RadicalDenest3`Private`linearRoots=Function[{r,k},{}],RadicalDenest3`Private`recurse=Identity},
   Module[{t=(3+2 Sqrt[2])^(1/4),i=Sqrt[1+Sqrt[2]],r},
    r=RadicalDenest3`Private`powerProposals[t,i];
    RootReduce[r-t]===0 && Order[RadicalDenest3`RadicalCost[r],RadicalDenest3`RadicalCost[t]]===1]],False],
 True, TestID -> "power-stage-monotonicity-mocked-search"]
VerificationTest[
 RadicalDenest3`Private`standalone[
  Block[{RadicalDenest3`Private`linearRoots=Function[{r,k},If[k===2,{1+Sqrt[2]},{}]],RadicalDenest3`Private`recurse=Identity},
   Module[{t=(3+2 Sqrt[2])^(1/4),r},
    r=RadicalDenest3`Private`kummerCandidates[t,3+2 Sqrt[2],1,4,t];
    RootReduce[r-t]===0 && Order[RadicalDenest3`RadicalCost[r],RadicalDenest3`RadicalCost[t]]===1]],False],
 True, TestID -> "unchanged-subproblem-admitted-mocked-factors"]
VerificationTest[Module[{e=(239+169 Sqrt[2])^(1/7),r},r=RadicalDenest3`Strad[e];
 RootReduce[r-e]===0 && RadicalDenest3`RadicalDepth[r]===1], True, TestID -> "higher-odd-seventh"]
VerificationTest[RadicalDenest3`Private`standalone[
 Module[{q=9,z=1+Sqrt[2],rho,parts,roots},rho=Expand[z^q];
  parts=RadicalDenest3`Private`quadraticParts[rho];
  roots=RadicalDenest3`Private`quadraticOddRoots[parts,q];
  AnyTrue[roots,RootReduce[#-z]===0&]],False], True, TestID -> "higher-odd-ninth-private-recipe"]
