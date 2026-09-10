(* ::Package:: *)
(* StradFixed3.wl -- proposed derivative of StradFixed2.wl, 2026-09-05.
   Based on the RadicalDenest repository's second corrected implementation.
   This file retains its principal algorithms, but is NOT a byte-for-byte patch.
   Native Wolfram execution was unavailable during preparation. Run the supplied
   tests and the repository's unified-B battery before adopting this proposal.

   Trust boundary: a replacement must be an explicit exact radical expression,
   strictly cheaper, and exactly equal to the selected input value. Numerical
   rejection is optional and NEVER constitutes an exact "Different" certificate.
   Root and AlgebraicNumber payloads are validated, not trusted by their heads.
   Budgets cover the core session, not prior argument/option evaluation, callback
   side effects, or serialization. Kernel resource controls are cooperative.
   No completeness, optimal-depth, or universal performance claim is made.
*)
BeginPackage["RadicalDenest3`"];
Strad::usage = "Strad[expr, opts] tries certified, cost-decreasing radical rewrites. Strad[expr, True, opts] enables inner levels and bounded repeated passes.";
DenestRadicals::usage = "DenestRadicals[expr, opts] is the option-driven entry point, with its own defaults.";
DenestCore::usage = "DenestCore[expr, opts] processes one exact algebraic number.";
DenestReport::usage = "DenestReport[expr, opts] returns the result, termination information, accepted search candidates, and committed passes. Candidate records are not standalone proof objects.";
EqualityStatus::usage = "EqualityStatus[a,b] is Equal, Different, or Unknown (as strings). Equal and Different require exact algebraic evidence; resource exhaustion or an unsupported representation gives Unknown.";
CertifiedEqualQ::usage = "CertifiedEqualQ[a,b] is True only for an exact Equal certificate.";
ExactAlgebraicQ::usage = "ExactAlgebraicQ[e] recognizes the supported exact algebraic grammar. Opaque payloads require a rational defining polynomial or certified canonicalization. False may mean unsupported or out of budget.";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] recognizes finite expressions made from Gaussian rationals using Plus, Times, and rational Power; no opaque algebraic objects.";
RadicalDepth::usage = "RadicalDepth[e] counts nested nonintegral rational powers, treating opaque algebraic objects as atoms.";
RadicalCost::usage = "RadicalCost[e] is {opaque-object count, maximum radical depth, radical-node count, LeafCount, rational bit size}.";
RationalizeDenominator::usage = "RationalizeDenominator[e] uses a certified polynomial inverse of the exact algebraic denominator. It need not lower RadicalCost.";
Factorc::usage = "Factorc[e] offers Factor[e] through the exact acceptance gate; symbolic input is unchanged.";
Options[Strad] = {
 "AllLevels" -> False, "Verbose" -> False, "Trace" -> False,
 "Multipliers" -> Automatic, "Solver" -> Automatic, "Factor" -> True,
 "MaxTrials" -> 120, "TimeBudget" -> 120, "OperationTime" -> 30,
 "CertifyTime" -> 20, "MemoryBudget" -> 1073741824,
 "MultiplierCap" -> 1000, "MaxRootIndex" -> 32, "MaxDegree" -> 64,
 "MaxSolveDegree" -> 4, "MaxLeafCount" -> 20000, "MaxPasses" -> 4,
 "MaxRecursion" -> 3, "Patience" -> 25, "NumericPrefilter" -> True,
 "MaxTraceEntries" -> 200,
 "HigherOddQuadratic" -> True, "SquareClassSearch" -> False, "MaxPrimeRank" -> 6,
 "MaxBasisSize" -> 16, "MaxCosets" -> 16,
 "CanonicalMultipliers" -> False, "ProcessExactIslands" -> False,
 "ListProgress" -> "Global"
};
Options[DenestRadicals] = Options[Strad];
Options[DenestCore] = Options[Strad];
Options[DenestReport] = Options[Strad];
Begin["`Private`"];

(* Session state is dynamically scoped. No persistent problem/result cache. *)
$active = False; $cfg = Association[Options[Strad]]; $deadline = Infinity;
$stats = <||>; $limits = <||>; $trace = {}; $records = {}; $commits = {};
$recordsTruncated = False; $traceTruncated = False; $commitsTruncated = False;
$memo = <||>; $inProgress = <||>; $typeMemo = <||>; $eqMemo = <||>;
$trialUse = <||>; $recursion = 0; $x = Unique["RadicalDenest3`Private`x"];
newStats[] := Association[Thread[{
 "Islands", "Trials", "Operations", "OperationTimeouts", "OperationFailures",
 "Certificates", "CertificatesEqual", "CertificatesDifferent", "CertificatesUnknown",
 "CertificateCacheHits", "NumericRejections", "CandidatesAccepted", "MultipliersProposed",
 "MultipliersAdmitted", "DuplicateMultipliers", "FastPathAccepted", "PassesCompleted",
 "SquareClassSystems", "PositiveMemoHits"} -> ConstantArray[0, 19]]];
bump[k_String] := AssociateTo[$stats, k -> (Lookup[$stats, k, 0] + 1)];
limitHit[k_String] := AssociateTo[$limits, k -> True];
remaining[] := $deadline - AbsoluteTime[];
expiredQ[] := If[remaining[] <= 0, limitHit["TimeBudget"]; True, False];
log[a___] := If[TrueQ[$cfg["Verbose"]], Print["[RadicalDenest3] ", a]];
trace[tag_String, data_: <||>] := If[TrueQ[$cfg["Trace"]],
 If[Length[$trace] < $cfg["MaxTraceEntries"],
  AppendTo[$trace, <|"Event" -> tag, "Data" -> data|>], $traceTruncated = True]];
SetAttributes[bounded, HoldAll];
bounded[body_, kind_: "Operation"] := Module[{seconds, value},
 seconds = Min[remaining[], If[kind === "Certificate", $cfg["CertifyTime"], $cfg["OperationTime"]]];
 If[! TrueQ[seconds > 0], limitHit[If[remaining[] <= 0, "TimeBudget", kind <> "Time"]]; Return[$Failed]];
 bump["Operations"];
 value = Quiet[Check[TimeConstrained[body, seconds, operationTimedOut], operationFailed]];
 Which[value === operationTimedOut,
  bump["OperationTimeouts"]; limitHit[If[kind === "Certificate", "CertifyTime", "OperationTime"]];
  If[remaining[] <= 0, limitHit["TimeBudget"]]; $Failed,
  MemberQ[{operationFailed, $Failed, $Aborted}, value], bump["OperationFailures"]; $Failed,
  True, value]];

(* Options are resolved once using the defaults of the actual public head. *)
rationalQ[e_] := MatchQ[e, _Integer | _Rational];
finiteNonnegativeQ[v_] := MatchQ[v, _Integer | _Rational | _Real] && TrueQ[0 <= v < Infinity];
booleanQ[v_] := v === True || v === False;
flattenRules[items_List] := Flatten[Replace[items, l_List :> flattenRules[l], {1}], 1];
resolveOptions[head_Symbol, raw_List] := Module[{rules, names, unknown, cfg, bad},
 rules = flattenRules[raw];
 If[! AllTrue[rules, MatchQ[#, _Rule | _RuleDelayed] &],
  Return[Failure["InvalidOption", <|"MessageTemplate" -> "Options must be rules."|>]]];
 names = First /@ Options[head]; unknown = Complement[First /@ rules, names];
 If[unknown =!= {}, Return[Failure["UnknownOption", <|"Keys" -> unknown|>]]];
 cfg = Association[Table[With[{name = key}, name -> OptionValue[head, rules, name]], {key, names}]];
 bad = Join[
  Select[{"AllLevels", "Verbose", "Trace", "Factor", "NumericPrefilter", "SquareClassSearch",
    "CanonicalMultipliers", "ProcessExactIslands", "HigherOddQuadratic"}, ! booleanQ[cfg[#]] &],
  Select[{"MaxTrials", "MultiplierCap", "MaxTraceEntries", "MaxRecursion", "Patience"},
    ! (IntegerQ[cfg[#]] && cfg[#] >= 0) &],
  Select[{"MemoryBudget", "MaxRootIndex", "MaxDegree", "MaxSolveDegree", "MaxLeafCount",
    "MaxPasses", "MaxPrimeRank", "MaxBasisSize", "MaxCosets"},
    ! (IntegerQ[cfg[#]] && cfg[#] >= 1) &],
  Select[{"TimeBudget", "OperationTime", "CertifyTime"}, ! finiteNonnegativeQ[cfg[#]] &]];
 If[! (cfg["Multipliers"] === Automatic || ListQ[cfg["Multipliers"]]), AppendTo[bad, "Multipliers"]];
 If[! (cfg["Solver"] === Automatic || MatchQ[cfg["Solver"], _Function | _Symbol]), AppendTo[bad, "Solver"]];
 If[cfg["MaxSolveDegree"] > 4, AppendTo[bad, "MaxSolveDegree"]];
 If[! MemberQ[{"Global", "Independent"}, cfg["ListProgress"]], AppendTo[bad, "ListProgress"]];
 If[bad =!= {}, Failure["InvalidOption", <|"Keys" -> DeleteDuplicates[bad]|>], cfg]];

(* A Root head and infinite precision are NOT an algebraicity certificate. *)
gaussianQ[e_] := rationalQ[e] || (Head[e] === Complex && rationalQ[Re[e]] && rationalQ[Im[e]]);
opaqueQ[e_] := MatchQ[e, _Root | _AlgebraicNumber];
RadicalExpressionQ[e_] := Which[
 gaussianQ[e], True, AtomQ[e], False,
 MemberQ[{Plus, Times}, Head[e]], AllTrue[List @@ e, RadicalExpressionQ],
 Head[e] === Power && Length[e] === 2, rationalQ[e[[2]]] && RadicalExpressionQ[e[[1]]],
 True, False];
rationalPolynomialQ[p_, x_] := FreeQ[p, $Failed | $Aborted | operationTimedOut | operationFailed] &&
 TrueQ[PolynomialQ[p, x]] && IntegerQ[Exponent[p, x]] && Exponent[p, x] >= 1 &&
 AllTrue[CoefficientList[p, x], rationalQ];
ordinaryRootQ[r_] := Module[{p, f, k},
 If[Head[r] =!= Root || ! MemberQ[{2, 3}, Length[r]], Return[False]];
 If[Length[r] === 3 && ! MemberQ[{0, 1}, r[[3]]], Return[False]];
 f = r[[1]]; k = r[[2]];
 If[Head[f] =!= Function || ! IntegerQ[k] || k < 1 || ! TrueQ[NumericQ[r]], Return[False]];
 p = bounded[f[$x], "Certificate"];
 p =!= $Failed && rationalPolynomialQ[p, $x] && k <= Exponent[p, $x]];
closedCanonicalQ[e_] := Which[
 gaussianQ[e], True,
 Head[e] === Root, ordinaryRootQ[e],
 Head[e] === AlgebraicNumber && Length[e] === 2,
  ListQ[e[[2]]] && AllTrue[e[[2]], rationalQ] && closedCanonicalQ[e[[1]]],
 AtomQ[e], False,
 MemberQ[{Plus, Times}, Head[e]], AllTrue[List @@ e, closedCanonicalQ],
 Head[e] === Power && Length[e] === 2, rationalQ[e[[2]]] && closedCanonicalQ[e[[1]]],
 True, False];
opaqueExactQ[e_] := Module[{r},
 If[! FreeQ[e, _Real | Indeterminate | _DirectedInfinity], Return[False]];
 If[closedCanonicalQ[e], Return[True]];
 (* Also allows triangular/algebraic-coefficient Root representations when
    RootReduce actually converts them to the checked rational grammar. *)
 r = bounded[RootReduce[e], "Certificate"];
 r =!= $Failed && r =!= e && closedCanonicalQ[r]];
algebraicFormQ[e_] := Which[
 gaussianQ[e], True, opaqueQ[e], opaqueExactQ[e], AtomQ[e], False,
 MemberQ[{Plus, Times}, Head[e]], AllTrue[List @@ e, algebraicFormQ],
 Head[e] === Power && Length[e] === 2, rationalQ[e[[2]]] && algebraicFormQ[e[[1]]],
 True, False];
exactQ[e_] := Module[{key = HoldComplete[e], result},
 If[KeyExistsQ[$typeMemo, key], Return[True]];
 result = FreeQ[e, _Real | Indeterminate | _DirectedInfinity] && TrueQ[algebraicFormQ[e]];
 (* Do not cache an unsupported/timeout result as a mathematical negative. *)
 If[result, AssociateTo[$typeMemo, key -> True]]; result];
ExactAlgebraicQ[e_] := standalone[exactQ[e], False];
RadicalDepth[e_] := Which[AtomQ[e] || opaqueQ[e], 0,
 MatchQ[e, Power[_, _Rational]], 1 + RadicalDepth[First[e]],
 True, Max[Prepend[RadicalDepth /@ (List @@ e), 0]]];
radicalNodes[e_] := Which[AtomQ[e] || opaqueQ[e], 0,
 MatchQ[e, Power[_, _Rational]], 1 + radicalNodes[First[e]],
 True, Total[radicalNodes /@ (List @@ e)]];
bitSize[e_] := Total[Cases[e, n_Integer :> 1 + IntegerLength[Abs[n], 2], {0, Infinity}, Heads -> False]] +
 Total[Cases[e, r_Rational :> 2 + IntegerLength[Abs[Numerator[r]], 2] + IntegerLength[Denominator[r], 2],
   {0, Infinity}, Heads -> False]];
RadicalCost[e_] := {Count[e, _Root | _AlgebraicNumber, {0, Infinity}], RadicalDepth[e],
 radicalNodes[e], LeafCount[e], bitSize[e]};
cheaperQ[a_, b_] := Order[RadicalCost[a], RadicalCost[b]] === 1;
smallQ[e_] := If[LeafCount[e] > $cfg["MaxLeafCount"], limitHit["MaxLeafCount"]; False, True];
progressQ[a_, b_] := a =!= b && (cheaperQ[a, b] ||
 ($cfg["ListProgress"] === "Independent" && ListQ[a] && ListQ[b] && Length[a] === Length[b] &&
  And @@ MapThread[(#1 === #2 || progressQ[#1, #2]) &, {a, b}]));

(* Exact equality and heuristic rejection have different interfaces. *)
recordStatus[s_] := (bump["Certificates" <> s]; s);
certify[a_, b_] := Module[{key = HoldComplete[a, b], d, r, z, result = "Unknown"},
 bump["Certificates"];
 If[KeyExistsQ[$eqMemo, key], bump["CertificateCacheHits"]; Return[recordStatus[$eqMemo[key]]]];
 If[! exactQ[a] || ! exactQ[b], Return[recordStatus["Unknown"]]];
 If[a === b, AssociateTo[$eqMemo, key -> "Equal"]; Return[recordStatus["Equal"]]];
 d = bounded[a - b, "Certificate"];
 If[d === $Failed, Return[recordStatus["Unknown"]]];
 r = bounded[RootReduce[d], "Certificate"];
 If[r === 0, result = "Equal",
  If[r =!= $Failed && gaussianQ[r] && r =!= 0, result = "Different",
   (* Handles nonzero forms such as 2 Sqrt[2], not just atomic Root objects. *)
   z = bounded[PossibleZeroQ[d, Method -> "ExactAlgebraics"], "Certificate"];
   result = Which[z === True, "Equal", z === False, "Different", True, "Unknown"]]];
 If[result =!= "Unknown", AssociateTo[$eqMemo, key -> result]];
 recordStatus[result]];
numericallyDifferentQ[d_] := Module[{v},
 If[! TrueQ[$cfg["NumericPrefilter"]], Return[False]];
 v = bounded[N[d, 40]];
 TrueQ[NumberQ[v] && Accuracy[v] >= 25 && Abs[v] > 10^-20]];
EqualityStatus[a_, b_] := standalone[certify[a, b], "Unknown"];
CertifiedEqualQ[a_, b_] := EqualityStatus[a, b] === "Equal";
accept[c_, target_, incumbent_, method_String] := Module[{},
 If[c === $Failed || c === target || ! smallQ[c] || ! RadicalExpressionQ[c] || ! cheaperQ[c, incumbent],
  Return[incumbent]];
 If[numericallyDifferentQ[c - target], bump["NumericRejections"]; Return[incumbent]];
 If[certify[c, target] =!= "Equal", Return[incumbent]];
 bump["CandidatesAccepted"];
 If[Length[$records] < $cfg["MaxTraceEntries"],
  AppendTo[$records, <|"Before" -> target, "After" -> c, "Method" -> method,
   "Scope" -> "AcceptedSearchCandidate", "EqualityEvidence" -> "ExactKernel"|>], $recordsTruncated = True];
 trace["AcceptedCandidate", <|"Method" -> method, "Cost" -> RadicalCost[c]|>];
 log[method, ": ", target, " -> ", c]; c];
acceptWithPolish[c_, target_, incumbent_, method_String] := Module[{best = incumbent, v},
 If[c === $Failed || ! smallQ[c] || ! exactQ[c], Return[best]];
 If[numericallyDifferentQ[c - target], bump["NumericRejections"]; Return[best]];
 best = accept[c, target, best, method];
 v = bounded[Simplify[c, Assumptions -> True, TimeConstraint -> 5]];
 best = accept[v, target, best, method <> "/Simplify"];
 best = accept[bounded[Expand[c]], target, best, method <> "/Expand"];
 best = accept[bounded[Together[c]], target, best, method <> "/Together"];
 best = accept[rationalizeRaw[c], target, best, method <> "/Rationalize"]; best];

(* Polynomial inverse of a nonzero denominator; no sentinel polynomial. *)
validPolynomialQ[p_, x_, minimum_Integer: 1] := Module[{degree},
 If[! FreeQ[p, $Failed | $Aborted | operationFailed | operationTimedOut] || ! TrueQ[PolynomialQ[p, x]], Return[False]];
 degree = Exponent[p, x]; IntegerQ[degree] && minimum <= degree <= $cfg["MaxDegree"]];
rationalizeRaw[e_] := Module[{t, num, den, p, c, inv, result},
 t = bounded[Together[e]]; If[t === $Failed, Return[$Failed]];
 num = Numerator[t]; den = Denominator[t]; If[rationalQ[den], Return[t]];
 If[! smallQ[den] || ! exactQ[den], Return[$Failed]];
 p = bounded[MinimalPolynomial[den, $x]];
 If[! validPolynomialQ[p, $x], Return[$Failed]];
 c = CoefficientList[p, $x]; If[! AllTrue[c, rationalQ] || First[c] === 0, Return[$Failed]];
 inv = bounded[-Fold[#1 den + #2 &, Last[c], Reverse[Rest[Most[c]]]]/First[c]];
 If[inv === $Failed || certify[den inv, 1] =!= "Equal", Return[$Failed]];
 result = bounded[Expand[num inv]];
 If[result === $Failed || ! smallQ[result], $Failed, result]];
RationalizeDenominator[e_] := standalone[Replace[rationalizeRaw[e], $Failed -> e], e];
Factorc[e_] := standalone[If[exactQ[e], accept[bounded[Factor[e]], e, e, "Factor"], e], e];

(* Direct, indirect, Gaussian, and trace-norm fast paths. *)
quadraticParts[rho_] := Module[{e, terms, rat, irr, a, t, c, b},
 e = bounded[Expand[rho]]; If[e === $Failed, Return[$Failed]];
 terms = If[Head[e] === Plus, List @@ e, {e}]; rat = Select[terms, rationalQ];
 irr = Select[terms, ! rationalQ[#] &]; If[Length[irr] =!= 1, Return[$Failed]];
 a = Total[rat]; t = First[irr];
 c = Replace[t, {Sqrt[cc_?rationalQ] :> cc, Times[k_?rationalQ, Sqrt[cc_?rationalQ]] :> k^2 cc, _ -> $Failed}];
 If[c === $Failed || ! TrueQ[c > 0] || rationalQ[Sqrt[c]], Return[$Failed]];
 b = Replace[t, {Sqrt[_] :> 1, Times[k_?rationalQ, Sqrt[_]] :> Sign[k], _ -> 1}]; {a, b, c}];
quadraticSquareRoots[{a_, b_, c_}] := Module[{d = a^2 - b^2 c, s, u, v, e, out = {}},
 If[d >= 0, s = Sqrt[d]; If[rationalQ[s] && a > 0,
  u = (a + s)/2; v = (a - s)/2; If[u >= 0 && v >= 0, AppendTo[out, Sqrt[u] + Sign[b] Sqrt[v]]]]];
 If[d < 0 && b > 0, e = Sqrt[b^2 - a^2/c]; If[rationalQ[e] && 0 <= e <= b,
  AppendTo[out, c^(1/4) (Sqrt[(b + e)/2] + Sign[a] Sqrt[(b - e)/2])]]]; out];
rationalRoots[p_] := Module[{fl}, fl = bounded[FactorList[p]];
 If[fl === $Failed || ! ListQ[fl], Return[{}]];
 DeleteDuplicates[Select[Cases[fl, {f_, _Integer} /; PolynomialQ[f, $x] && Exponent[f, $x] === 1 :>
  -Coefficient[f, $x, 0]/Coefficient[f, $x, 1]], rationalQ]]];
cubicInQuadratic[{a_, b_, c_}] := Module[{norm, n, roots, out = {}, den, beta},
 norm = a^2 - b^2 c; n = Sign[norm] Abs[norm]^(1/3); If[! rationalQ[n], Return[{}]];
 roots = rationalRoots[$x^3 - 3 n $x - 2 a];
 Do[den = t^2 - n; If[den =!= 0, beta = t/2 + b Sqrt[c]/den;
  If[certify[beta^3, a + b Sqrt[c]] === "Equal", AppendTo[out, beta]]], {t, roots}]; out];
(* Odd-index trace/norm reconstruction by Dickson polynomials.  The two
   polynomials are D_q(T,n)=u^q+v^q and S_q(T,n)=(u^q-v^q)/(u-v),
   for u+v=T and uv=n.  No divisors of an integer norm are enumerated. *)
quadraticOddRoots[{a_, b_, c_}, q_Integer] := Module[{norm, n, polys, roots, den, beta, out = {}},
 If[q < 3 || ! OddQ[q] || q > $cfg["MaxDegree"], Return[{}]];
 norm = a^2 - b^2 c; n = Sign[norm] Abs[norm]^(1/q);
 If[! rationalQ[n], Return[{}]];
 polys = bounded[Module[{d0 = 2, d1 = $x, s0 = 0, s1 = 1, d2, s2},
  Do[d2 = Expand[$x d1 - n d0]; s2 = Expand[$x s1 - n s0];
   {d0, d1} = {d1, d2}; {s0, s1} = {s1, s2}, {j, 2, q}]; {d1, s1}]];
 If[! ListQ[polys], Return[{}]];
 roots = rationalRoots[polys[[1]] - 2 a];
 Do[den = polys[[2]] /. $x -> t;
  If[den =!= 0, beta = t/2 + b Sqrt[c]/den;
   If[certify[beta^q, a + b Sqrt[c]] === "Equal", AppendTo[out, beta]]], {t, roots}]; out];
gaussianSquareRoots[z_] := Module[{a = Re[z], b = Im[z], n},
 n = Sqrt[a^2 + b^2]; If[rationalQ[n], {Sqrt[(n + a)/2] + I Sign[b] Sqrt[(n - a)/2]}, {}]];
honsbeekSquareRoots[rho_] := Module[{terms, a, b, roots, den, num, out = {}},
 If[Head[rho] =!= Plus || Length[rho] =!= 2, Return[{}]];
 terms = List @@ rho;
 If[! AllTrue[terms, exactQ], Return[{}]];
 {a, b} = (bounded[RootReduce[#^3], "Certificate"] &) /@ terms;
 If[! AllTrue[{a, b}, rationalQ] || a === 0 || b === 0, Return[{}]];
 roots = rationalRoots[$x^4 + 4 $x^3 + 8 (b/a) $x - 4 b/a];
 Do[den = b - s^3 a;
  If[den =!= 0, num = bounded[-s^2 terms[[1]]^2/2 + s terms[[1]] terms[[2]] + terms[[2]]^2];
   If[num =!= $Failed, out = Join[out, {num/Sqrt[den], -num/Sqrt[den]}]]], {s, roots}];
 (* Rational summands and negative den are allowed; the final gate chooses the branch. *)
 out];

(* Square-class coefficient arithmetic. Every represented radicand is positive
   and squarefree. sqrt(d_i) sqrt(d_j) = gcd(d_i,d_j) sqrt(d_i d_j/gcd^2).
   The optional coset search is complete only in the explicitly enumerated
   multiquadratic ambient field, and only when every rational system is solved. *)
integerSurdTerm[t_] := Replace[t, {
 r_?rationalQ :> {r, 1}, Power[n_Integer, Rational[1, 2]] /; n > 0 :> {1, n},
 Times[c_?rationalQ, Power[n_Integer, Rational[1, 2]]] /; n > 0 :> {c, n}, _ -> $Failed}];
squarefreeData[n_Integer] := Module[{f = bounded[FactorInteger[n]]},
 If[! ListQ[f], Return[$Failed]];
 {Times @@ (#[[1]]^Quotient[#[[2]], 2] & /@ f),
  Times @@ (#[[1]]^Mod[#[[2]], 2] & /@ f), First /@ f}];
surdSystem[U_List, coeff_Association] := Module[{vars, polys = <||>, d, g, h, basis, eqs, sol, cand},
 If[Length[U] > $cfg["MaxBasisSize"] || expiredQ[], Return[{}]];
 vars = Table[Unique["c$"], {Length[U]}];
 Do[Do[g = GCD[U[[i]], U[[j]]]; d = U[[i]] U[[j]]/g^2;
  AssociateTo[polys, d -> (Lookup[polys, d, 0] + If[i === j, 1, 2] g vars[[i]] vars[[j]])],
  {j, i, Length[U]}], {i, Length[U]}];
 basis = Union[Keys[polys], Keys[coeff]];
 eqs = (Lookup[polys, #, 0] == Lookup[coeff, #, 0] &) /@ basis;
 bump["SquareClassSystems"]; sol = bounded[Solve[eqs, vars, Rationals]];
 If[! ListQ[sol] || sol === {}, Return[{}]];
 cand = vars . Sqrt[U]; DeleteDuplicates[Select[cand /. sol, RadicalExpressionQ]]];
maskOf[n_Integer, primes_List] := Sum[If[Mod[n, primes[[i]]] === 0, 2^(i - 1), 0], {i, Length[primes]}];
fromMask[m_Integer, primes_List] := Times @@ Table[If[BitAnd[m, 2^(i - 1)] =!= 0, primes[[i]], 1], {i, Length[primes]}];
cosetBases[radicands_List, primes_List] := Module[{h = {0}, masks, used = <||>, c, out = {}, rank = Length[primes]},
 If[rank > $cfg["MaxPrimeRank"], limitHit["MaxPrimeRank"]; Return[{}]];
 masks = maskOf[#, primes] & /@ radicands;
 Do[h = Union[h, (BitXor[#, m] &) /@ h];
  If[Length[h] > $cfg["MaxBasisSize"], limitHit["MaxBasisSize"]; Return[{}]], {m, masks}];
 (* No full 2^rank array is materialized. Enumeration is clipped before admission. *)
 Do[If[expiredQ[], Break[]]; If[KeyExistsQ[used, j], Continue[]];
  If[Length[out] >= $cfg["MaxCosets"], limitHit["MaxCosets"]; Break[]];
  c = Sort[(BitXor[j, #] &) /@ h];
  Do[AssociateTo[used, k -> True], {k, c}];
  AppendTo[out, Sort[fromMask[#, primes] & /@ c]], {j, 0, 2^rank - 1}]; out];
multiSurdSquareRoots[rho_] := Module[{e, terms, parsed, coeff = <||>, primes = {}, data, surds, sets, out},
 e = bounded[Expand[rho]]; If[e === $Failed, Return[{}]];
 terms = If[Head[e] === Plus, List @@ e, {e}]; parsed = integerSurdTerm /@ terms;
 If[MemberQ[parsed, $Failed], Return[{}]];
 Do[data = squarefreeData[t[[2]]]; If[data === $Failed, Return[{}]];
  AssociateTo[coeff, data[[2]] -> (Lookup[coeff, data[[2]], 0] + t[[1]] data[[1]])];
  primes = Union[primes, data[[3]]], {t, parsed}];
 surds = DeleteCases[Keys[coeff], 1]; If[Length[surds] < 2 || Length[surds] > 15, Return[{}]];
 sets = DeleteDuplicates[{Union[{1}, primes], Union[{1}, primes, surds]}];
 Do[out = surdSystem[u, coeff]; If[out =!= {}, Return[out]], {u, sets}];
 If[! TrueQ[$cfg["SquareClassSearch"]], Return[{}]];
 sets = cosetBases[surds, primes];
 Do[out = surdSystem[u, coeff]; If[out =!= {}, Return[out]], {u, sets}]; {}];

unity[k_Integer, q_Integer] := (-1)^(Mod[2 k, 2 q]/q);
rootCandidates[rho_, q_Integer] := Module[{parts, out = {}, r = rho, neg},
 If[q === 2 && Head[rho] === Complex, Return[gaussianSquareRoots[rho]]];
 neg = TrueQ[bounded[rho < 0, "Certificate"]]; If[neg, r = -rho];
 Which[q === 2, parts = quadraticParts[r]; If[parts =!= $Failed, out = quadraticSquareRoots[parts]];
  out = Join[out, honsbeekSquareRoots[r], multiSurdSquareRoots[r]]; If[neg, out = I out],
  q === 3, parts = quadraticParts[r]; If[parts =!= $Failed, out = cubicInQuadratic[parts]];
  If[neg, out = (-1)^(1/3) out],
  OddQ[q] && q >= 5 && TrueQ[$cfg["HigherOddQuadratic"]],
  parts = quadraticParts[r]; If[parts =!= $Failed, out = quadraticOddRoots[parts, q]];
  If[neg, out = (-1)^(1/q) out]]; out];
radicalExtension[e_] := Module[{ext = DeleteDuplicates[Cases[e, Power[_, _Rational], {0, Infinity}]]},
 If[! FreeQ[e, Complex], ext = Prepend[ext, I]]; If[ext === {}, Automatic, ext]];
radicalForms[z_] := Module[{out = {z}, r},
 If[FreeQ[z, _Root | _AlgebraicNumber], Return[out]];
 r = bounded[ToRadicals[z]]; If[r =!= $Failed, AppendTo[out, r]];
 r = bounded[RootReduce[z], "Certificate"];
 If[r =!= $Failed, r = bounded[ToRadicals[r]]; If[r =!= $Failed, AppendTo[out, r]]];
 DeleteDuplicates[Select[out, exactQ]]];
linearRoots[rho_, k_Integer] := Module[{fl, roots},
 If[k > $cfg["MaxRootIndex"] || k > $cfg["MaxDegree"], limitHit["KnownPolynomialDegree"]; Return[{}]];
 fl = bounded[FactorList[$x^k - rho, Extension -> radicalExtension[rho]]];
 If[! ListQ[fl], fl = bounded[FactorList[$x^k - rho, Extension -> Automatic]]];
 If[! ListQ[fl], Return[{}]];
 roots = Cases[fl, {f_, _Integer} /; PolynomialQ[f, $x] && Exponent[f, $x] === 1 :>
  bounded[Together[-Coefficient[f, $x, 0]/Coefficient[f, $x, 1]]]];
 DeleteDuplicates[Select[Flatten[radicalForms /@ DeleteCases[roots, $Failed]], exactQ]]];
recurse[sub_] := If[$recursion >= $cfg["MaxRecursion"] || expiredQ[], sub,
 Block[{$recursion = $recursion + 1, $cfg = Append[$cfg, "MaxTrials" -> Quotient[$cfg["MaxTrials"], 4]]},
  improveNumber[sub]]];
negativeRadicandCandidate[target_, rho_, p_Integer, q_Integer, incumbent_] := Module[{raw, sub, best = incumbent},
 If[! TrueQ[bounded[rho < 0, "Certificate"]], Return[best]];
 raw = (-rho)^(p/q);
 best = acceptWithPolish[bounded[Expand[(-1)^(p/q) raw]], target, best, "NegativePhase"];
 sub = recurse[raw];
 acceptWithPolish[bounded[Expand[(-1)^(p/q) sub]], target, best, "NegativeRadicand"]];
kummerCandidates[target_, rho_, p_Integer, q_Integer, incumbent_] := Module[
 {best = incumbent, gammas, rest, den, raw, sub},
 Do[If[expiredQ[], Break[]]; gammas = linearRoots[rho, k]; rest = q/k;
  Do[If[expiredQ[], Break[]];
   If[rest === 1,
    Do[best = acceptWithPolish[bounded[Expand[(gamma unity[l, q])^p]], target, best, "LinearFactor"], {l, 0, q - 1}],
    Do[den = bounded[Expand[gamma unity[j, k]]]; If[den === $Failed, Continue[]];
     raw = den^(1/rest);
     (* Offer the raw index reduction even when recursion does nothing. *)
     Do[best = acceptWithPolish[bounded[Expand[(raw unity[l, rest])^p]], target, best, "IndexReduction"], {l, 0, rest - 1}];
     sub = recurse[raw];
     If[sub =!= raw, Do[best = acceptWithPolish[bounded[Expand[(sub unity[l, rest])^p]], target, best,
       "IndexReduction/Recursive"], {l, 0, rest - 1}]], {j, 0, k - 1}]], {gamma, gammas}];
  If[RadicalDepth[best] <= 1, Break[]], {k, Reverse[Rest[Divisors[q]]]}]; best];

(* Bounded FIFO multiplier search, including cubic/quartic GCD factors. *)
reductionIndex[e_] := Module[{d = RadicalDepth[e], nodes, q = 1},
 nodes = Select[Cases[e, Power[_, _Rational], {0, Infinity}], RadicalDepth[#] === d &];
 Do[q = LCM[q, Denominator[Last[node]]];
  If[q > $cfg["MaxRootIndex"], limitHit["MaxRootIndex"]; Return[$Failed]], {node, nodes}];
 If[q < 2, $Failed, q]];
complementaryFactor[Power[b_, r_Rational]] := b^(Mod[-Numerator[r], Denominator[r]]/Denominator[r]);
complementaryFactor[Complex[0, _]] := -I;
complementaryFactor[e_] := Module[{deep = Cases[e, Power[_, _Rational], {0, Infinity}], maxd},
 If[deep === {}, 1, maxd = Max[RadicalDepth /@ deep];
  Times @@ (complementaryFactor /@ Select[deep, RadicalDepth[#] === maxd &])]];
complementaryMultiplier[t_] := Times @@ (complementaryFactor /@ If[Head[t] === Times, List @@ t, {t}]);
multiplierSearch[target_, initialBest_] := Module[
 {best = initialBest, q, rho, queue = {}, seen = <||>, admitted = 0, proposed = 0, cursor = 1,
  cap = $cfg["MultiplierCap"], proposalCap, admit, seeds, terms, m, theta, poly, degree, gcd, gd,
  roots, mroot, candidate, disc, primes, factorization, j, digits, batch, sol, before,
  keyTarget = HoldComplete[target], sinceImprovement = 0, bestDegree = Infinity},
 If[cap === 0 || $cfg["MaxTrials"] === 0 || expiredQ[], Return[best]];
 q = reductionIndex[target]; If[q === $Failed, Return[best]];
 rho = bounded[Expand[target^q]]; If[rho === $Failed || ! exactQ[rho], Return[best]];
 proposalCap = 4 cap;
 admit[value_] := Module[{canonical, key},
  If[admitted >= cap, limitHit["MultiplierCap"]; Return[False]];
  If[proposed >= proposalCap, limitHit["MultiplierProposals"]; Return[False]];
  proposed++; bump["MultipliersProposed"];
  If[! smallQ[value] || ! exactQ[value], Return[False]];
  canonical = bounded[Expand[value]];
  If[canonical === $Failed || canonical === 0, Return[False]];
  If[TrueQ[$cfg["CanonicalMultipliers"]],
   canonical = bounded[RootReduce[canonical], "Certificate"];
   If[canonical === $Failed || canonical === 0, Return[False]]];
  (* Full expressions as keys avoid formatting as a hidden normalization step.
     Default equivalence is expanded syntax, not equality of algebraic values. *)
  key = With[{v = canonical}, HoldComplete[v]];
  If[KeyExistsQ[seen, key], bump["DuplicateMultipliers"]; Return[False]];
  AssociateTo[seen, key -> True]; AppendTo[queue, value]; admitted++; bump["MultipliersAdmitted"]; True];
 If[ListQ[$cfg["Multipliers"]], seeds = $cfg["Multipliers"],
  terms = DeleteCases[Replace[#, {
    Times[a___, _?rationalQ, b___] :> a*b, _?rationalQ -> 0, Complex[a_, b_] :> Sign[b] I}] & /@
    If[Head[rho] === Plus, List @@ rho, {rho}], 0];
  seeds = bounded[Join[{1}, DeleteCases[complementaryMultiplier /@ terms, 1], {2, 3, 5}]];
  If[! ListQ[seeds], seeds = {1}]];
 Do[If[admitted >= cap || proposed >= proposalCap || expiredQ[], Break[]]; admit[seed], {seed, seeds}];
 While[cursor <= Length[queue] && ! expiredQ[],
  (* Usage is shared by repeated visits to this same target. A low-quota
     recursive visit cannot consume the larger quota of a later outer visit. *)
  If[Lookup[$trialUse, keyTarget, 0] >= $cfg["MaxTrials"], limitHit["MaxTrials"]; Break[]];
  If[best =!= initialBest && sinceImprovement >= $cfg["Patience"], limitHit["Patience"]; Break[]];
  m = queue[[cursor]]; cursor++; sinceImprovement++; bump["Trials"];
  AssociateTo[$trialUse, keyTarget -> (Lookup[$trialUse, keyTarget, 0] + 1)];
  If[certify[m, 0] =!= "Different", Continue[]];
  theta = bounded[Expand[m rho]]; If[theta === $Failed, Continue[]];
  poly = bounded[MinimalPolynomial[theta^(1/q), $x]];
  If[! validPolynomialQ[poly, $x], If[poly =!= $Failed, limitHit["MaxDegree"]]; Continue[]];
  degree = Exponent[poly, $x]; bestDegree = Min[bestDegree, degree];
  trace["Trial", <|"Multiplier" -> m, "Degree" -> degree, "Index" -> q|>];
  roots = If[m === 1, {}, linearRoots[theta, q]];
  gcd = bounded[PolynomialGCD[poly, $x^q - theta, Extension -> Automatic]];
  If[validPolynomialQ[gcd, $x], gd = Exponent[gcd, $x];
   If[gd < q, roots = Join[roots, Which[
    gd === 1, {-Coefficient[gcd, $x, 0]/Coefficient[gcd, $x, 1]},
    gd <= $cfg["MaxSolveDegree"], sol = bounded[Solve[gcd == 0, $x]];
     If[ListQ[sol], Select[$x /. sol, exactQ], {}], True, {}]]]];
  roots = DeleteDuplicates[Select[Flatten[radicalForms /@ roots], exactQ]];
  If[roots =!= {}, mroot = bounded[m^(1/q)];
   If[mroot =!= $Failed, Do[If[expiredQ[], Break[]];
    Do[If[expiredQ[], Break[]]; candidate = bounded[Expand[z/mroot unity[k, q]]]; before = best;
     best = acceptWithPolish[candidate, target, best, "MultiplierOrbit"];
     If[best =!= before, sinceImprovement = 0];
     If[candidate =!= $Failed && candidate =!= target && RadicalDepth[candidate] <= RadicalDepth[target] &&
       certify[candidate, target] === "Equal", before = best;
      best = acceptWithPolish[recurse[candidate], target, best, "MultiplierOrbit/Recursive"];
      If[best =!= before, sinceImprovement = 0]], {k, 0, q - 1}], {z, roots}]]];
  If[RadicalDepth[best] <= 1, Break[]];
  If[! ListQ[$cfg["Multipliers"]] && degree <= bestDegree && admitted < cap && proposed < proposalCap && ! expiredQ[],
   disc = bounded[Discriminant[poly, $x]];
   If[IntegerQ[disc] && disc =!= 0,
    factorization = bounded[FactorInteger[Abs[disc]]];
    primes = If[ListQ[factorization], Take[First /@ factorization, UpTo[8]], {}]; batch = 0;
    Do[If[admitted >= cap || proposed >= proposalCap || batch >= 24 || expiredQ[], Break[]];
     Do[If[admitted >= cap || proposed >= proposalCap || batch >= 24 || expiredQ[], Break[]];
      batch++; admit[m prime^exponent], {exponent, 1, q - 1}], {prime, primes}];
    j = 1;
    While[primes =!= {} && j < q^Length[primes] && batch < 24 && admitted < cap && proposed < proposalCap && ! expiredQ[],
     digits = IntegerDigits[j, q, Length[primes]]; j++; batch++;
     admit[m Times @@ MapThread[Power, {primes, digits}]]]]]];
 best];

(* Every stage preserves its incoming incumbent, including partial reductions. *)
powerProposals[target_, incumbent_] := Module[{best = incumbent, rho, p, q, root, raw, cands},
 If[! MatchQ[target, Power[_, _Rational]], Return[best]];
 rho = First[target]; p = Numerator[Last[target]]; q = Denominator[Last[target]];
 If[q > $cfg["MaxRootIndex"], limitHit["MaxRootIndex"]; Return[best]];
 cands = rootCandidates[rho, q];
 Do[best = acceptWithPolish[bounded[Expand[c^p]], target, best, "FastPath"], {c, cands}];
 If[RadicalDepth[best] <= 1, bump["FastPathAccepted"]; Return[best]];
 best = negativeRadicandCandidate[target, rho, p, q, best];
 If[RadicalDepth[best] <= 1, Return[best]];
 best = kummerCandidates[target, rho, p, q, best];
 If[RadicalDepth[best] >= 2 && EvenQ[q] && q > 2,
  root = recurse[rho^(1/2)]; raw = root^(2/q);
  best = acceptWithPolish[bounded[Expand[raw^p]], target, best, "EvenIndexSplit"];
  root = recurse[raw];
  best = acceptWithPolish[bounded[Expand[root^p]], target, best, "EvenIndexSplit/Recursive"]]; best];
genericProposals[target_, incumbent_] := Module[{best = incumbent, r, solver, polynomial},
 solver = $cfg["Solver"];
 If[solver =!= Automatic, r = bounded[Catch[solver[target], _, $Failed &]];
  best = acceptWithPolish[r, target, best, "Solver"]];
 If[! FreeQ[target, _Root | _AlgebraicNumber], r = bounded[ToRadicals[target]];
  If[r =!= $Failed && r =!= target,
   best = acceptWithPolish[r, target, best, "ToRadicals"];
   best = acceptWithPolish[recurse[r], target, best, "ToRadicals/Recursive"]]];
 r = bounded[RootReduce[target], "Certificate"];
 If[r =!= $Failed, best = accept[r, target, best, "RootReduce"];
  If[Head[r] === Root && ordinaryRootQ[r], polynomial = bounded[First[r][$x]];
   If[polynomial =!= $Failed && Exponent[polynomial, $x] <= 4,
    best = acceptWithPolish[bounded[ToRadicals[r]], target, best, "RootReduce/ToRadicals"]]]];
 best = accept[bounded[Simplify[target, Assumptions -> True, TimeConstraint -> 5]], target, best, "Simplify"];
 If[TrueQ[$cfg["Factor"]], best = accept[bounded[Factor[target]], target, best, "Factor"]];
 best = accept[rationalizeRaw[target], target, best, "Rationalize"]; best];
searchableQ[e_] := MatchQ[e, Power[_, _Rational]] ||
 (Head[e] === Times && AllTrue[List @@ e, MatchQ[#, _?gaussianQ | Power[_, _Rational]] &]);
improveNumber[target_] := Module[{best = target, key = HoldComplete[target]},
 If[expiredQ[] || ! smallQ[target] || ! exactQ[target], Return[target]];
 If[RadicalDepth[target] < 2 && FreeQ[target, _Root | _AlgebraicNumber], Return[target]];
 If[KeyExistsQ[$memo, key], best = $memo[key]; bump["PositiveMemoHits"]];
 If[KeyExistsQ[$inProgress, key] || (best =!= target && RadicalDepth[best] <= 1), Return[best]];
 AssociateTo[$inProgress, key -> True]; bump["Islands"];
 best = powerProposals[target, best];
 If[RadicalDepth[best] >= 2 || ! FreeQ[best, _Root | _AlgebraicNumber], best = genericProposals[target, best]];
 If[RadicalDepth[best] >= 2 && $cfg["Solver"] === Automatic && searchableQ[target] && ! expiredQ[],
  best = multiplierSearch[target, best]];
 (* Cache certified positive progress as an incumbent, never a failed search. *)
 If[best =!= target, AssociateTo[$memo, key -> best]];
 KeyDropFrom[$inProgress, key]; best];
combineProposals[target_, incumbent_] := Module[{best = incumbent, r},
 r = bounded[RootReduce[incumbent], "Certificate"]; best = accept[r, target, best, "Combine/RootReduce"];
 best = accept[bounded[Simplify[incumbent, Assumptions -> True, TimeConstraint -> 5]], target, best, "Combine/Simplify"];
 best = accept[bounded[Together[incumbent]], target, best, "Combine/Together"];
 accept[bounded[Expand[incumbent]], target, best, "Combine/Expand"]];
island[e_] := Module[{current = e, rebuilt},
 If[expiredQ[] || (RadicalDepth[e] < 2 && FreeQ[e, _Root | _AlgebraicNumber]), Return[e]];
 If[MatchQ[e, Power[_, _Rational]],
  If[TrueQ[$cfg["AllLevels"]], rebuilt = Power[island[First[e]], Last[e]];
   If[rebuilt =!= e && cheaperQ[rebuilt, e], current = rebuilt]];
  Return[improveNumber[current]]];
 If[MemberQ[{Plus, Times}, Head[e]] || MatchQ[e, Power[_, _Integer]],
  rebuilt = If[Head[e] === Power, Power[island[First[e]], Last[e]], Map[island, e]];
  If[rebuilt =!= e && cheaperQ[rebuilt, e], current = rebuilt];
  If[RadicalDepth[current] >= 2 || ! FreeQ[current, _Root | _AlgebraicNumber], current = improveNumber[current]];
  If[current =!= e, current = combineProposals[e, current]]; Return[current]];
 If[opaqueQ[e], Return[improveNumber[e]]]; e];
walk[e_] := Module[{h},
 If[expiredQ[] || ! smallQ[e], Return[e]];
 If[exactQ[e], Return[island[e]]]; If[AtomQ[e], Return[e]]; h = Head[e];
 Which[MemberQ[{List, Plus, Times}, h], Map[walk, e],
  h === Power && Length[e] === 2 && rationalQ[Last[e]], Power[walk[First[e]], Last[e]], True, e]];

(* Session controls cover preflight and costs as well as the search. Reports
   after a timeout may legitimately contain Missing costs rather than spend
   unbounded work computing them after the deadline. *)
run[e_, cfg_Association, coreOnly_: False] :=
 Block[{$active = True, $cfg = cfg, $deadline = AbsoluteTime[] + cfg["TimeBudget"],
  $stats = newStats[], $limits = <||>, $trace = {}, $records = {}, $commits = {},
  $recordsTruncated = False, $traceTruncated = False, $commitsTruncated = False,
  $memo = <||>, $inProgress = <||>, $typeMemo = <||>, $eqMemo = <||>, $trialUse = <||>,
  $recursion = 0, $Assumptions = True},
  Module[{snapshot = e, beforeSnapshot, candidate, outcome = Null, started = AbsoluteTime[], passes, status,
   initialCost = Missing["NotComputed"], finalCost = Missing["NotComputed"], numericInput = False},
   passes = If[TrueQ[cfg["AllLevels"]] && ! coreOnly, cfg["MaxPasses"], 1];
   If[TrueQ[cfg["TimeBudget"] == 0], limitHit["TimeBudget"],
    outcome = Quiet[Check[TimeConstrained[MemoryConstrained[
     initialCost = RadicalCost[e];
     Which[! smallQ[e], Null,
      ! TrueQ[cfg["ProcessExactIslands"]] && ! FreeQ[e, _Real | _Complex?InexactNumberQ], limitHit["InexactInput"],
      coreOnly && ! exactQ[e], limitHit["NotExactAlgebraic"],
      True, numericInput = exactQ[e];
       Do[If[expiredQ[], Break[]]; candidate = If[coreOnly, improveNumber[snapshot], walk[snapshot]];
        bump["PassesCompleted"];
        If[candidate === snapshot || ! progressQ[candidate, snapshot], Break[]];
        If[numericInput && certify[candidate, e] =!= "Equal", Break[]];
        beforeSnapshot = snapshot; snapshot = candidate;
        If[Length[$commits] < cfg["MaxTraceEntries"],
         AppendTo[$commits, <|"Before" -> beforeSnapshot, "After" -> snapshot,
          "Evidence" -> If[numericInput, "ExactKernel", "ArithmeticCongruence"], "Pass" -> pass|>],
         $commitsTruncated = True];
        If[pass === passes && passes > 1, limitHit["MaxPasses"]], {pass, passes}]];
     finalCost = RadicalCost[snapshot]; Null,
     cfg["MemoryBudget"], memoryStopped], cfg["TimeBudget"], timeStopped], sessionFailed]]];
   If[outcome === memoryStopped, limitHit["MemoryBudget"]];
   If[outcome === timeStopped, limitHit["TimeBudget"]];
   If[outcome === sessionFailed, limitHit["SessionFailure"]];
   If[MemberQ[{memoryStopped, timeStopped, sessionFailed}, outcome],
    $commitsTruncated = True]; (* An interrupt can precede journal append. *)
   status = Which[TrueQ[cfg["TimeBudget"] == 0], "Disabled", outcome === memoryStopped, "MemoryLimit",
    outcome === timeStopped || KeyExistsQ[$limits, "TimeBudget"], "Timeout",
    outcome === sessionFailed, "Failure", snapshot === e, "Unchanged", True, "Improved"];
   <|"Result" -> snapshot, "Status" -> status, "ResultChanged" -> (snapshot =!= e),
    "Limits" -> Keys[$limits], "Statistics" -> $stats, "InitialCost" -> initialCost, "FinalCost" -> finalCost,
    "Certificates" -> $records, "CertificateRecordScope" -> "AcceptedSearchCandidatesNotFinalProof",
    "CandidateRecordsTruncated" -> $recordsTruncated, "CommittedPasses" -> $commits,
    "CommittedPassesTruncated" -> $commitsTruncated, "Trace" -> $trace, "TraceTruncated" -> $traceTruncated,
    "ElapsedSeconds" -> AbsoluteTime[] - started, "Options" -> cfg,
    "BudgetScope" -> "Core session; excludes argument/option evaluation and serialization",
    "CompletenessClaim" -> False|>]];
SetAttributes[standalone, HoldAll];
standalone[body_, fallback_] := If[TrueQ[$active], body,
 Module[{cfg = resolveOptions[Strad, {}], seconds},
  If[FailureQ[cfg], Return[fallback]]; seconds = Min[20, cfg["TimeBudget"]];
  If[! TrueQ[seconds > 0], Return[fallback]];
  Block[{$active = True, $cfg = cfg, $deadline = AbsoluteTime[] + seconds,
   $stats = newStats[], $limits = <||>, $trace = {}, $records = {}, $commits = {},
   $recordsTruncated = False, $traceTruncated = False, $commitsTruncated = False,
   $memo = <||>, $inProgress = <||>, $typeMemo = <||>, $eqMemo = <||>, $trialUse = <||>,
   $recursion = 0, $Assumptions = True},
   Quiet[Check[TimeConstrained[MemoryConstrained[body, cfg["MemoryBudget"], fallback], seconds, fallback], fallback]]]]];
invoke[e_, head_Symbol, raw_List, report_, core_, allowFlag_: True] := Module[{rules = raw, cfg, result},
 If[allowFlag && rules =!= {} && booleanQ[First[rules]], rules = Prepend[Rest[rules], "AllLevels" -> First[rules]]];
 cfg = resolveOptions[head, rules]; If[FailureQ[cfg], Return[cfg]];
 result = run[e, cfg, core]; If[TrueQ[report], result, result["Result"]]];
Strad[e_, args___] := invoke[e, Strad, {args}, False, False];
DenestRadicals[e_, args___] := invoke[e, DenestRadicals, {args}, False, False];
DenestCore[e_, args___] := invoke[e, DenestCore, {args}, False, True, False];
DenestReport[e_, args___] := invoke[e, DenestReport, {args}, True, False];
Strad[] := Failure["MissingInput", <||>];
DenestRadicals[] := Failure["MissingInput", <||>];
DenestCore[] := Failure["MissingInput", <||>];
DenestReport[] := Failure["MissingInput", <||>];
End[];
EndPackage[];
