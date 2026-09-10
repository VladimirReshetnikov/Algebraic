#!/usr/bin/env python3
"""Reproduce the proposed package from the byte-verified pinned source.
Python execution verifies edits and source integrity, not Wolfram semantics.
"""
from pathlib import Path
import difflib
import hashlib
import json

ROOT = Path(__file__).resolve().parent
raw = (ROOT / 'StradFixed2.pinned.wl').read_bytes()
original = raw.decode('utf-8')
blob = hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()
assert blob == '0bdeded347385a55a044fdd35883006d053685dc', blob
s = original.replace('RadicalDenest2`', 'RadicalDenest3`').replace('[RadicalDenest2]', '[RadicalDenest3]')
edits = []
def replace(old, new, name, count=1):
    global s
    found = s.count(old)
    assert found == count, (name, found, count)
    s = s.replace(old, new)
    edits.append(name)
def between(start, end, new, name):
    global s
    assert s.count(start) == s.count(end) == 1, name
    a = s.index(start); b = s.index(end, a)
    s = s[:a] + new + s[b:]
    edits.append(name)

between('(* StradFixed2.wl', 'BeginPackage[', '''(* StradFixed3.wl -- proposed, NOT native-kernel-validated revision.
   Derived from RadicalDenest StradFixed2.wl at commit
   9000d6f533a68ee7659a6830ad25bba401f800a5, Git blob
   0bdeded347385a55a044fdd35883006d053685dc.  See the accompanying audit.

   Scope: evaluated, pure arithmetic expressions with principal complex powers.
   Exact input grammar accepts rational/Gaussian rational constants, rational
   powers and arithmetic combinations, canonical rational-polynomial Root
   objects, and AlgebraicNumber objects with admitted generators and rational
   coefficient lists. Other Root presentations are conservatively unsupported;
   apply RootReduce separately to known algebraic objects when necessary.

   Candidates must be smaller and certified by exact algebra. Numerical hints
   NEVER decide equality or inequality. Local congruence rewrites are committed
   only if the complete pass is cheaper. The search, input classification and
   cost construction share a time/memory region. Ordinary argument evaluation,
   option evaluation and final report assembly are outside that search budget.
   Kernel constraints are cooperative limits, not an OS sandbox or hard-real-time
   guarantees. MaxTrials bounds each multiplier-search visit, not the session.
   User functions/upvalues must be trusted, side-effect-free arithmetic code.

   No completeness, optimality, or performance improvement is asserted.
   Context RadicalDenest3` permits side-by-side testing with RadicalDenest2`.
   Distributed under the repository's MIT No Attribution License. *)

''', 'honest-contract')
replace('"Patience" -> 25, "NumericPrefilter" -> True', '"Patience" -> 25, "NumericPrefilter" -> False', 'numeric-default')
replace('$recursion = 0;\n$x', '$recursion = 0; $inProgress = {};\n$x', 'cycle-state')
replace('"CertificatesUnknown" -> 0, "NumericRejections" -> 0,', '"CertificatesUnknown" -> 0, "NumericRejections" -> 0, "NumericHints" -> 0,', 'numeric-telemetry')
replace('opaqueQ[e], TrueQ[Precision[e] === Infinity] && FreeQ[e, _Real],', '''Head[e] === Root, canonicalRootPolynomial[e] =!= $Failed,
   Head[e] === AlgebraicNumber,
    Length[e] === 2 && ListQ[e[[2]]] && AllTrue[e[[2]], rationalQ] &&
      algebraicFormQ[e[[1]]],''', 'opaque-admission')
replace('(* exactness is decided by the grammar (algebraic by construction) *)\nExactAlgebraicQ[e_] := algebraicFormQ[e] && FreeQ[e, Indeterminate | ComplexInfinity | _DirectedInfinity];', '''(* Root is NOT algebraic by its head alone. Only a rational polynomial
   together with a valid numerical root selector is admitted here. *)
canonicalRootPolynomial[e_] := Module[{p, degree, args},
   If[Head[e] =!= Root, Return[$Failed]];
   args = List @@ e;
   If[! MemberQ[{2, 3}, Length[args]] || Head[args[[1]]] =!= Function ||
     ! positiveIntegerQ[args[[2]]], Return[$Failed]];
   If[Length[args] === 3 && ! MemberQ[{0, 1}, args[[3]]], Return[$Failed]];
   p = bounded[Expand[args[[1]][$x]]];
   If[p === $Failed || ! TrueQ[PolynomialQ[p, $x]], Return[$Failed]];
   degree = Exponent[p, $x];
   If[! positiveIntegerQ[degree] || args[[2]] > degree ||
      ! AllTrue[CoefficientList[p, $x], rationalQ], Return[$Failed]];
   p];

ExactAlgebraicQ[e_] := standalone[
   algebraicFormQ[e] && FreeQ[e, Indeterminate | ComplexInfinity | _DirectedInfinity], False];''', 'canonical-root-validation')
between('radicalNodes[e_] :=', 'cheaperQ[new_', '''(* Stop at opaque objects once; do not subtract overlapping payload counts. *)
radicalNodes[e_] := Which[
   opaqueQ[e] || AtomQ[e], 0,
   True, Boole[MatchQ[e, Power[_, _Rational]]] + Total[radicalNodes /@ (List @@ e)]];
opaqueNodes[e_] := Which[opaqueQ[e], 1, AtomQ[e], 0,
   True, Total[opaqueNodes /@ (List @@ e)]];
bitSize[e_] := Which[
   IntegerQ[e], 1 + IntegerLength[Abs[e], 2],
   Head[e] === Rational, 2 + IntegerLength[Abs[Numerator[e]], 2] + IntegerLength[Denominator[e], 2],
   Head[e] === Complex, bitSize[Re[e]] + bitSize[Im[e]],
   AtomQ[e], 0,
   True, Total[bitSize /@ (List @@ e)]];
RadicalCost[e_] := {opaqueNodes[e], RadicalDepth[e], radicalNodes[e], LeafCount[e], bitSize[e]};
''', 'structural-cost')
between('canonicalNonzeroQ[e_] :=', '(* heuristic pre-rejection', '''canonicalNonzeroQ[e_] := Module[{p},
   If[gaussianQ[e], Return[e =!= 0]];
   If[Head[e] =!= Root, Return[False]];
   p = canonicalRootPolynomial[e];
   p =!= $Failed && Coefficient[p, $x, 0] =!= 0];

''', 'certified-nonzero')
replace('(* heuristic pre-rejection by significance arithmetic; never accepts *)', '(* Optional diagnostic only. Accuracy estimates are not interval certificates. *)', 'numeric-comment')
replace('If[numericallyDifferentQ[d], bump["NumericRejections"]; bump["CertificatesDifferent"]; Return["Different"]];', 'If[numericallyDifferentQ[d], bump["NumericHints"]; trace["NumericNonzeroHint"]];', 'no-heuristic-different')
between('standalone[body_, failure_] :=', 'EqualityStatus[a_, b_]', '''standalone[body_, failure_] := If[TrueQ[$active], body,
   Module[{cfg = resolveOptions[Strad, {}]},
    If[FailureQ[cfg], Return[failure]];
    Block[{$active = True, $cfg = cfg, $deadline = AbsoluteTime[] + 20,
      $stats = newStats[], $limits = <||>, $trace = {}, $records = {}, $memo = <||>,
      $recursion = 0, $inProgress = {}, $Assumptions = True},
     Quiet[Check[TimeConstrained[MemoryConstrained[body, 1073741824, failure], 20, failure], failure]]]]];

''', 'validate-standalone-defaults')
replace('"Before" -> target, "After" -> candidate, "Method" -> method', '"Before" -> target, "After" -> candidate, "Method" -> method, "EqualityStatus" -> "Equal", "Scope" -> "AcceptedProposal"', 'audit-not-proof')
replace('If[candidate === $Failed || ! exactQ[candidate], Return[best]];', 'If[expiredQ[] || candidate === $Failed || ! smallQ[candidate] || ! exactQ[candidate], Return[best]];', 'polish-size-guard')
replace('primes = Union @@ (First /@ FactorInteger[#] & /@ surds);', 'primes = bounded[Union @@ (First /@ FactorInteger[#] & /@ surds)];\n   If[primes === $Failed, Return[{}]];', 'bound-surd-factorization')
replace('vars = Array[cvar, Length[U]];', 'vars = Table[Unique["RadicalDenest3`Private`coef"], {Length[U]}];', 'fresh-solver-variables')
replace('sq = Expand[cand^2];', 'sq = bounded[Expand[cand^2]];\n    If[sq === $Failed, Continue[]];', 'bound-surd-expansion')
replace('Together[-Coefficient[f, $x, 0]/Coefficient[f, $x, 1]]];', 'bounded[Together[-Coefficient[f, $x, 0]/Coefficient[f, $x, 1]]]];', 'bound-linear-extraction')
replace('kummerCandidates[target_, rho_, p_Integer, q_Integer] := Module[{best = target,', 'kummerCandidates[target_, rho_, p_Integer, q_Integer, incumbent_] := Module[{best = incumbent,', 'kummer-incumbent')
replace('If[sub =!= den^(1/rest) && RadicalDepth[sub] < RadicalDepth[target],', 'If[exactQ[sub] && RadicalDepth[sub] <= RadicalDepth[target],', 'admit-unchanged-subproblem')
between('negativeRadicandCandidate[target_', '(* ------------------------------------------------------------------ *)\n(* the multiplier search', '''negativeRadicandCandidate[target_, rho_, p_Integer, q_Integer, incumbent_] := Module[{sub},
   If[! TrueQ[bounded[rho < 0, "Certificate"]], Return[incumbent]];
   sub = recurse[(-rho)^(p/q)];
   accept[bounded[Expand[(-1)^(p/q) sub]], target, incumbent, "NegativeRadicand"]];

''', 'negative-incumbent')
replace('primes = Take[Select[First /@ FactorInteger[Abs[disc]], PrimeQ], UpTo[8]];', 'primes = bounded[Take[Select[First /@ FactorInteger[Abs[disc]], PrimeQ], UpTo[8]]];\n      If[primes === $Failed, primes = {}];', 'bound-discriminant-factorization')
replace('Do[batch++; admit[m prime^e], {e, 1, q - 1}]', '''Do[If[batch >= 24 || admitted >= cap || proposed >= proposalCap || expiredQ[], Break[]];
        batch++; admit[m prime^e], {e, 1, q - 1}]''', 'batch-prefix-cap')
replace('dedups by exact canonical value', 'dedups by expanded syntax, not algebraic value', 'dedup-description')
replace('Module[{best = incumbent, rho, p, q, root, cands},', 'Module[{best = incumbent, rho, p, q, root, cands, before},', 'fast-stage-baseline')
replace('cands = rootCandidates[rho, q];', 'before = best;\n   cands = rootCandidates[rho, q];', 'fast-baseline-assignment')
replace('If[RadicalDepth[best] <= 1, bump["FastPathAccepted"]; Return[best]];', 'If[best =!= before, bump["FastPathAccepted"]];\n   If[RadicalDepth[best] <= 1 && FreeQ[best, _Root | _AlgebraicNumber], Return[best]];', 'fast-accept-count')
replace('best = negativeRadicandCandidate[target, rho, p, q];', 'best = negativeRadicandCandidate[target, rho, p, q, best];', 'pass-negative-incumbent')
replace('best = kummerCandidates[target, rho, p, q];', 'best = kummerCandidates[target, rho, p, q, best];', 'pass-kummer-incumbent')
replace('If[root =!= rho^(1/2) && RadicalDepth[root] < RadicalDepth[target],', 'If[exactQ[root] && RadicalDepth[root] <= RadicalDepth[target],', 'even-index-candidate-guard')
between('improveNumber[target_] :=', '(* an exact algebraic island:', '''improveNumber[target_] := Module[{best = target, key},
   If[expiredQ[] || ! smallQ[target] || ! exactQ[target], Return[target]];
   If[RadicalDepth[target] < 2 && FreeQ[target, _Root | _AlgebraicNumber], Return[target]];
   If[MemberQ[$inProgress, target], Return[target]];
   (* A reduced-budget failure must not poison a later full-budget search. *)
   key = memoKey[target, $cfg["MaxTrials"], $cfg["MaxRecursion"] - $recursion];
   If[KeyExistsQ[$memo, key], Return[$memo[key]]];
   bump["Islands"];
   Block[{$inProgress = Append[$inProgress, target]},
    best = powerProposals[target, best];
    If[RadicalDepth[best] >= 2 || ! FreeQ[best, _Root | _AlgebraicNumber],
     best = genericProposals[target, best]];
    If[RadicalDepth[best] >= 2 && $cfg["Solver"] === Automatic && searchableQ[target] && ! expiredQ[],
     best = multiplierSearch[target, best]]];
   If[best =!= target && ! expiredQ[], AssociateTo[$memo, key -> best]];
   best];

''', 'positive-context-cache')
between('run[e_, cfg_Association, coreOnly_: False] :=', 'invoke[e_, head_Symbol', '''run[e_, cfg_Association, coreOnly_: False] :=
 Block[{$active = True, $cfg = cfg, $deadline = AbsoluteTime[] + cfg["TimeBudget"],
   $stats = newStats[], $limits = <||>, $trace = {}, $records = {}, $memo = <||>,
   $recursion = 0, $inProgress = {}, $Assumptions = True},
  Module[{committed = {e, Missing["NotComputed"]}, initialCost = Missing["NotComputed"],
    candidate, candidateCost, outcome = Null, started = AbsoluteTime[], passes, status, isNumber},
   passes = If[TrueQ[cfg["AllLevels"]] && ! coreOnly, cfg["MaxPasses"], 1];
   If[TrueQ[cfg["TimeBudget"] == 0], limitHit["TimeBudget"],
    outcome = TimeConstrained[MemoryConstrained[
      initialCost = RadicalCost[e]; committed = {e, initialCost};
      Which[
       ! FreeQ[e, _Real | _Complex?InexactNumberQ], limitHit["InexactInput"],
       coreOnly && ! exactQ[e], limitHit["NotExactAlgebraic"],
       True,
       isNumber = exactQ[e];
       Do[
        If[expiredQ[], Break[]];
        candidate = If[coreOnly, improveNumber[First[committed]], walk[First[committed]]];
        bump["PassesCompleted"];
        If[candidate === First[committed], Break[]];
        candidateCost = RadicalCost[candidate];
        If[Order[candidateCost, Last[committed]] =!= 1, Break[]];
        If[isNumber && certify[candidate, e] =!= "Equal", Break[]];
        committed = {candidate, candidateCost};
        If[pass === passes && passes > 1, limitHit["MaxPasses"]],
        {pass, passes}]],
      cfg["MemoryBudget"], memoryStopped], cfg["TimeBudget"], timeStopped]];
   If[outcome === memoryStopped, limitHit["MemoryBudget"]];
   If[outcome === timeStopped, limitHit["TimeBudget"]];
   status = Which[outcome === timeStopped, "Timeout", outcome === memoryStopped, "MemoryLimit",
     TrueQ[cfg["TimeBudget"] == 0], "Disabled", First[committed] === e, "Unchanged", True, "Improved"];
   <|"Result" -> First[committed], "Status" -> status, "Limits" -> Keys[$limits],
    "InitialCost" -> initialCost, "FinalCost" -> Last[committed], "Statistics" -> $stats,
    "Certificates" -> $records, "CertificateKind" -> "Kernel-checked accepted proposals, not proof objects",
    "CertificateRecordsTruncated" -> ($stats["CandidatesAccepted"] > Length[$records]),
    "ElapsedSeconds" -> AbsoluteTime[] - started, "Options" -> cfg, "Trace" -> $trace,
    "BudgetScope" -> "Search, preflight and cost construction; excludes ordinary argument/option evaluation",
    "LimitsMeaning" -> "Triggered guards or reached caps, not impossibility certificates",
    "CompletenessClaim" -> False|>]];

''', 'timed-preflight-and-costs')
between('Strad[e_, all :', 'End[];\nEndPackage[];', '''(* Deliberately accept raw arguments so malformed option syntax reaches
   resolveOptions instead of leaving the public call unevaluated. *)
invokeArgs[e_, head_Symbol, raw_List, report_, core_] := Module[{rules = raw},
   If[! TrueQ[core] && rules =!= {} && booleanQ[First[rules]],
    rules = Join[{"AllLevels" -> First[rules]}, Rest[rules]]];
   invoke[e, head, rules, report, core]];
Strad[e_, args___] := invokeArgs[e, Strad, {args}, False, False];
DenestRadicals[e_, args___] := invokeArgs[e, DenestRadicals, {args}, False, False];
DenestCore[e_, args___] := invokeArgs[e, DenestCore, {args}, False, True];
DenestReport[e_, args___] := invokeArgs[e, DenestReport, {args}, True, False];
Strad[] := Failure["InvalidArguments", <|"MessageTemplate" -> "An expression is required."|>];
DenestRadicals[] := Failure["InvalidArguments", <|"MessageTemplate" -> "An expression is required."|>];
DenestCore[] := Failure["InvalidArguments", <|"MessageTemplate" -> "An expression is required."|>];
DenestReport[] := Failure["InvalidArguments", <|"MessageTemplate" -> "An expression is required."|>];

''', 'invalid-argument-dispatch')
# Extend the proved trace-norm recipe to higher odd indices. The final
# acceptance gate still selects the principal branch and enforces the cost.
replace('rationalRoots[p_] :=', r'''(* Dickson trace-norm reconstruction for odd m >= 5 in a real quadratic
   field. This tests membership in Q(Sqrt[c]), not general denestability. *)
quadraticOddRoots[{a_, b_, c_}, m_Integer] := Module[
   {norm = a^2 - b^2 c, n, poly, roots, den, beta, out = {}},
   If[m < 5 || ! OddQ[m] || m > $cfg["MaxRootIndex"], Return[{}]];
   n = bounded[Sign[norm] Abs[norm]^(1/m)];
   If[n === $Failed || ! rationalQ[n], Return[{}]];
   poly = bounded[Sum[m/(m-j) Binomial[m-j,j] (-n)^j $x^(m-2j),
      {j,0,Quotient[m,2]}] - 2 a];
   If[poly === $Failed, Return[{}]];
   roots = rationalRoots[poly];
   Do[
    If[expiredQ[], Break[]];
    den = bounded[Sum[Binomial[m-1-j,j] (-n)^j t^(m-1-2j),
       {j,0,Quotient[m-1,2]}]];
    If[den === $Failed || den === 0, Continue[]];
    beta = bounded[t/2 + b Sqrt[c]/den];
    If[beta =!= $Failed && TrueQ[bounded[
       RootReduce[beta^m - (a+b Sqrt[c])] === 0, "Certificate"]],
     AppendTo[out,beta]], {t,roots}];
   out];

rationalRoots[p_] :=''', 'higher-odd-quadratic-recipe')
replace('If[neg, out = (-1)^(1/3) out]];', r'''If[neg, out = (-1)^(1/3) out],
    OddQ[q] && q >= 5,
     parts = quadraticParts[r];
     If[parts =!= $Failed, out = quadraticOddRoots[parts,q]];
     If[neg, out = (-1)^(1/q) out]];''', 'dispatch-higher-odd-recipe')

# Public descriptions explicitly state the changed admission policy.
replace('ExactAlgebraicQ[e] is True when e is an explicit exact algebraic number: rationals, Gaussian rationals, Root and AlgebraicNumber objects, and Plus, Times and rational Power combinations of them.', 'ExactAlgebraicQ[e] recognizes the conservative exact algebraic input grammar: rationals, Gaussian rationals, canonical rational-polynomial Root objects, AlgebraicNumber objects with admitted generators and rational coefficients, and arithmetic/rational powers. False also means unsupported or a validation timeout.', 'predicate-usage')
replace('total bit size of integer and rational atoms}', 'total bit size of integer and rational atoms, including Gaussian components}', 'bit-cost-usage')
(ROOT / 'StradFixed3.wl').write_text(s, encoding='utf-8', newline='\n')
(ROOT / 'StradFixed2-to-3.patch').write_text(''.join(difflib.unified_diff(original.splitlines(True),s.splitlines(True),fromfile='StradFixed2.pinned.wl',tofile='StradFixed3.wl')))
(ROOT.parent / 'evidence' / 'patch_manifest.json').write_text(json.dumps({'original_git_blob':blob,'edits':edits,'count':len(edits),'native_wolfram_execution':False},indent=2)+'\n')
print(f'Pinned blob verified: {blob}; {len(edits)} checked edit groups; {len(s.splitlines())} output lines.')
