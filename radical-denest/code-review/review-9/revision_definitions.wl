(* === Replacement definitions and new bounded proposal kernels === *)

ExactAlgebraicQ::usage = "ExactAlgebraicQ[e] accepts the explicit radical grammar, indexed univariate Root objects with rational polynomial coefficients, and AlgebraicNumber objects with an admitted generator and Gaussian-rational coefficient list. Other exact representations are conservatively rejected.";
RadicalCost::usage = "RadicalCost[e] is {opaque nodes, radical depth, rational-power nodes, LeafCount, coefficient bit size}. Opaque node counts and radical counts prune Root/AlgebraicNumber bodies; bit size includes their payloads and Gaussian-rational components.";
$inProgress = <||>;
$lastCertificateMethod = "None";

(* Only indexed roots of a univariate rational polynomial are admitted.
   This is a sufficient grammar, not a decision procedure for algebraicity. *)
rationalPolynomialRootQ[e_] := Module[{f, p, x = Unique["rootVariable"], n},
   If[Head[e] =!= Root || ! MemberQ[{2, 3}, Length[e]], Return[False]];
   If[! IntegerQ[e[[2]]] || e[[2]] < 1, Return[False]];
   If[Length[e] === 3 && ! MemberQ[{0, 1}, e[[3]]], Return[False]];
   f = e[[1]];
   If[Head[f] =!= Function, Return[False]];
   p = Quiet[Check[f[x], $Failed]];
   If[p === $Failed || ! TrueQ[PolynomialQ[p, x]], Return[False]];
   n = Exponent[p, x];
   IntegerQ[n] && 1 <= e[[2]] <= n &&
    AllTrue[CoefficientList[p, x], rationalQ]];

algebraicFormQ[e_] := Which[
   gaussianQ[e], True,
   Head[e] === Root, rationalPolynomialRootQ[e],
   Head[e] === AlgebraicNumber,
    Length[e] === 2 && ListQ[e[[2]]] &&
     AllTrue[e[[2]], gaussianQ] && algebraicFormQ[e[[1]]],
   AtomQ[e], False,
   MemberQ[{Plus, Times}, Head[e]], AllTrue[List @@ e, algebraicFormQ],
   Head[e] === Power && Length[e] === 2,
    rationalQ[e[[2]]] && algebraicFormQ[e[[1]]],
   True, False];

radicalNodes[e_] := Which[
   AtomQ[e] || opaqueQ[e], 0,
   True, Boole[MatchQ[e, Power[_, _Rational]]] +
    Total[radicalNodes /@ (List @@ e)]];
opaqueCount[e_] := Which[opaqueQ[e], 1, AtomQ[e], 0,
   True, Total[opaqueCount /@ (List @@ e)]];
bitSize[e_] := Which[
   IntegerQ[e], 1 + IntegerLength[Abs[e], 2],
   Head[e] === Rational, 2 + IntegerLength[Abs[Numerator[e]], 2] +
    IntegerLength[Denominator[e], 2],
   Head[e] === Complex, bitSize[Re[e]] + bitSize[Im[e]],
   AtomQ[e], 0,
   True, Total[bitSize /@ (List @@ e)]];
RadicalCost[e_] := {opaqueCount[e], RadicalDepth[e], radicalNodes[e],
   LeafCount[e], bitSize[e]};

(* A nonzero constant coefficient excludes zero from every root of p. *)
canonicalNonzeroQ[e_] := If[gaussianQ[e], e =!= 0,
   rationalPolynomialRootQ[e] && TrueQ[e[[1]][0] =!= 0]];

(* Optional numerical information is diagnostic only. Never promote it to
   Different, and never suppress a subsequent exact equality check. *)
numericallyDifferentQ[d_] := Module[{num},
   If[! TrueQ[$cfg["NumericPrefilter"]], Return[False]];
   num = bounded[N[d, 40]];
   TrueQ[NumberQ[num] && Accuracy[num] >= 25 && Abs[num] > 10^-20]];
certify[a_, b_] := Module[{d, r},
   bump["Certificates"]; $lastCertificateMethod = "None";
   If[! exactQ[a] || ! exactQ[b], bump["CertificatesUnknown"]; Return["Unknown"]];
   If[a === b, $lastCertificateMethod = "SameQ";
    bump["CertificatesEqual"]; Return["Equal"]];
   d = a - b;
   If[numericallyDifferentQ[d], bump["NumericDiagnostics"]];
   r = bounded[RootReduce[d], "Certificate"];
   Which[
    r === 0, $lastCertificateMethod = "RootReduceZero";
     bump["CertificatesEqual"]; Return["Equal"],
    canonicalNonzeroQ[r], $lastCertificateMethod = "ExactNonzeroNormalForm";
     bump["CertificatesDifferent"]; Return["Different"]];
   r = bounded[PossibleZeroQ[d, Method -> "ExactAlgebraics"], "Certificate"];
   Which[
    r === True, $lastCertificateMethod = "PossibleZeroQ/ExactAlgebraics";
     bump["CertificatesEqual"]; "Equal",
    r === False, $lastCertificateMethod = "PossibleZeroQ/ExactAlgebraics";
     bump["CertificatesDifferent"]; "Different",
    True, bump["CertificatesUnknown"]; "Unknown"]];

(* Real odd roots in a quadratic field: Dickson/Lucas recurrences. *)
oddInQuadratic[{a_, b_, c_}, q_Integer] := Module[
   {norm, n, d0 = 2, d1 = $x, s0 = 0, s1 = 1,
    dn, sn, roots, den, beta, out = {}},
   If[! OddQ[q] || q < 3 || q > $cfg["MaxOddIndex"], Return[{}]];
   norm = a^2 - b^2 c; n = Sign[norm] Abs[norm]^(1/q);
   If[! rationalQ[n], Return[{}]];
   Do[
    dn = bounded[Expand[$x d1 - n d0]];
    sn = bounded[Expand[$x s1 - n s0]];
    If[dn === $Failed || sn === $Failed, Return[{}]];
    {d0, d1} = {d1, dn}; {s0, s1} = {s1, sn}, {q - 1}];
   roots = rationalRoots[d1 - 2 a];
   Do[den = s1 /. $x -> t;
    If[den =!= 0,
     beta = t/2 + b Sqrt[c]/den;
     If[certify[beta^q, a + b Sqrt[c]] === "Equal", AppendTo[out, beta]]],
    {t, roots}]; out];

(* Hadamard reconstruction. No integer factorization is needed to build the
   square-class basis. The finite sign search is explicitly capped. *)
characterSquareRoots[rho_] := Module[
   {e, terms, surds, coeffs, a, products = {1}, rank = 0,
    positions, pos, m, chars, conjugates, lambdas, signs, fourier,
    squares, pieces, z, v, candidate, maxPatterns, out = {}},
   If[$cfg["MaxCharacterRank"] === 0 || $cfg["MaxCharacterPatterns"] === 0,
    Return[{}]];
   e = bounded[Expand[rho]]; If[e === $Failed, Return[{}]];
   terms = If[Head[e] === Plus, List @@ e, {e}];
   If[! AllTrue[terms,
      MatchQ[#, _?rationalQ | Power[_Integer, Rational[1, 2]] |
        Times[_?rationalQ, Power[_Integer, Rational[1, 2]]]] &], Return[{}]];
   surds = DeleteDuplicates[Cases[e,
      Power[n_Integer, Rational[1, 2]] /; n > 1 :> n, {0, Infinity}]];
   If[Length[surds] < 2, Return[{}]];
   coeffs = Coefficient[e, Sqrt[#]] & /@ surds;
   a = e /. Power[_Integer, Rational[1, 2]] -> 0;
   If[! rationalQ[a] || ! AllTrue[coeffs, rationalQ], Return[{}]];
   Do[
    If[! AnyTrue[products, rationalQ[Sqrt[d/#]] &],
     If[rank >= $cfg["MaxCharacterRank"],
      limitHit["MaxCharacterRank"]; Return[{}]];
     products = Join[products, d products]; rank++], {d, surds}];
   m = Length[products];
   positions = Table[SelectFirst[Range[m],
      rationalQ[Sqrt[d/products[[#]]]] &, $Failed], {d, surds}];
   If[MemberQ[positions, $Failed], Return[{}]];
   chars = Table[(-1)^DigitCount[BitAnd[i, j], 2, 1],
     {i, 0, m - 1}, {j, 0, m - 1}];
   conjugates = Table[a + Total[coeffs Sqrt[surds] chars[[i, positions]]],
     {i, m}];
   lambdas = Sqrt /@ conjugates;
   maxPatterns = Min[2^(m - 1), $cfg["MaxCharacterPatterns"]];
   Do[
    If[expiredQ[], Break[]];
    bump["CharacterPatterns"];
    signs = Prepend[1 - 2 IntegerDigits[pattern, 2, m - 1], 1];
    fourier = bounded[(chars . (signs lambdas))/m];
    If[fourier === $Failed, Continue[]];
    squares = Table[bounded[RootReduce[v^2], "Certificate"], {v, fourier}];
    If[! AllTrue[squares, rationalQ], Continue[]];
    pieces = {}; candidate = $Failed;
    Do[
     z = Sqrt[squares[[i]]]; v = fourier[[i]];
     Which[
      certify[v, z] === "Equal", AppendTo[pieces, z],
      certify[v, -z] === "Equal", AppendTo[pieces, -z],
      True, Break[]], {i, m}];
    If[Length[pieces] === m,
     candidate = Total[pieces];
     If[certify[candidate, Sqrt[rho]] === "Equal",
      out = {candidate}; Break[]]],
    {pattern, 0, maxPatterns - 1}];
   If[out === {} && maxPatterns < 2^(m - 1), limitHit["MaxCharacterPatterns"]];
   out];

rootCandidates[rho_, q_Integer] := Module[{parts, out = {}, r = rho, neg},
   If[q === 2 && Head[rho] === Complex, Return[gaussianSquareRoots[rho]]];
   neg = TrueQ[bounded[rho < 0, "Certificate"]]; If[neg, r = -rho];
   Which[
    q === 2,
     parts = quadraticParts[r];
     If[parts =!= $Failed, out = quadraticSquareRoots[parts]];
     If[out === {}, out = honsbeekSquareRoots[r]];
     If[out === {}, out = characterSquareRoots[r]];
     If[out === {}, out = multiSurdSquareRoots[r]];
     If[neg, out = I out],
    q === 3 || (OddQ[q] && q <= $cfg["MaxOddIndex"]),
     parts = quadraticParts[r];
     If[parts =!= $Failed,
      out = If[q === 3, cubicInQuadratic[parts], oddInQuadratic[parts, q]]];
     If[neg, out = (-1)^(1/q) out]];
   out];

kummerCandidates[target_, rho_, p_Integer, q_Integer, incumbent_: Automatic] :=
 Module[{best = If[incumbent === Automatic, target, incumbent],
   gammas, rest, sub, den, reduced},
  Do[
   If[expiredQ[], Break[]]; gammas = linearRoots[rho, k]; rest = q/k;
   Do[
    If[expiredQ[], Break[]];
    If[rest === 1,
     Do[best = acceptWithPolish[bounded[Expand[(gamma unity[l, q])^p]],
       target, best, "LinearFactor"], {l, 0, q - 1}],
     Do[
      den = bounded[Expand[gamma unity[j, k]]];
      If[den === $Failed, Continue[]];
      reduced = den^(1/rest);
      (* Already-useful index reduction must not depend on recursive progress. *)
      Do[best = acceptWithPolish[bounded[Expand[(reduced unity[l, rest])^p]],
        target, best, "IndexReduction/Direct"], {l, 0, rest - 1}];
      sub = recurse[reduced];
      If[sub =!= reduced,
       Do[best = acceptWithPolish[bounded[Expand[(sub unity[l, rest])^p]],
         target, best, "IndexReduction/Recursive"], {l, 0, rest - 1}]],
      {j, 0, k - 1}]], {gamma, gammas}];
   If[RadicalDepth[best] <= 1, Break[]],
   {k, Reverse[Rest[Divisors[q]]]}]; best];

negativeRadicandCandidate[target_, rho_, p_Integer, q_Integer,
   incumbent_: Automatic] := Module[{best, sub},
   best = If[incumbent === Automatic, target, incumbent];
   If[! TrueQ[bounded[rho < 0, "Certificate"]], Return[best]];
   sub = recurse[(-rho)^(p/q)];
   accept[bounded[Expand[(-1)^(p/q) sub]], target, best, "NegativeRadicand"]];

powerProposals[target_, incumbent_] := Module[
   {best = incumbent, rho, p, q, root, cands},
   If[! MatchQ[target, Power[_, _Rational]], Return[best]];
   rho = First[target]; p = Numerator[Last[target]]; q = Denominator[Last[target]];
   If[q > $cfg["MaxRootIndex"], limitHit["MaxRootIndex"]; Return[best]];
   cands = bounded[rootCandidates[rho, q]];
   If[! ListQ[cands], cands = {}];
   Do[best = acceptWithPolish[bounded[Expand[c^p]], target, best, "FastPath"],
    {c, cands}];
   If[RadicalDepth[best] <= 1, bump["FastPathAccepted"]; Return[best]];
   best = negativeRadicandCandidate[target, rho, p, q, best];
   If[RadicalDepth[best] <= 1, Return[best]];
   best = kummerCandidates[target, rho, p, q, best];
   If[RadicalDepth[best] >= 2 && EvenQ[q] && q > 2,
    root = recurse[rho^(1/2)];
    If[root =!= rho^(1/2),
     root = recurse[root^(2/q)];
     best = acceptWithPolish[bounded[Expand[root^p]], target, best, "EvenIndexSplit"]]];
   best];

(* Memoized successes are incumbents, not certificates of search exhaustion.
   A path-local in-progress set breaks recursive cycles without negative caching. *)
improveNumber[target_] := Module[{best = target, key = target},
   If[expiredQ[] || ! exactQ[target] || ! smallQ[target], Return[target]];
   If[RadicalDepth[target] < 2 && FreeQ[target, _Root | _AlgebraicNumber], Return[target]];
   If[KeyExistsQ[$memo, key], best = $memo[key]];
   If[KeyExistsQ[$inProgress, key], Return[best]];
   bump["Islands"];
   Block[{$inProgress = Append[$inProgress, key -> True]},
    best = powerProposals[target, best];
    If[RadicalDepth[best] >= 2 || ! FreeQ[best, _Root | _AlgebraicNumber],
     best = genericProposals[target, best]];
    If[RadicalDepth[best] >= 2 && $cfg["Solver"] === Automatic &&
      searchableQ[target] && ! expiredQ[], best = multiplierSearch[target, best]]];
   If[best =!= target, AssociateTo[$memo, key -> best]];
   best];

(* Input scans and costs are inside the common outer budget. Cached report costs
   are never recomputed after exhaustion. Ordinary WL argument evaluation and
   option resolution are necessarily outside this routine. *)
run[e_, cfg_Association, coreOnly_: False] :=
 Block[{$active = True, $cfg = cfg, $deadline = AbsoluteTime[] + cfg["TimeBudget"],
   $stats = newStats[], $limits = <||>, $trace = {}, $records = {},
   $memo = <||>, $inProgress = <||>, $recursion = 0,
   $lastCertificateMethod = "None", $Assumptions = True},
  Module[{snapshot = e, candidate, outcome = Null, started = AbsoluteTime[],
    passes, status, numericInput = False,
    initialCost = Missing["NotComputed"], finalCost = Missing["NotComputed"],
    candidateCost},
   passes = If[TrueQ[cfg["AllLevels"]] && ! coreOnly, cfg["MaxPasses"], 1];
   If[TrueQ[cfg["TimeBudget"] == 0], limitHit["TimeBudget"],
    outcome = Quiet[Check[TimeConstrained[MemoryConstrained[
       Which[
        ! FreeQ[e, _Real | _Complex?InexactNumberQ], limitHit["InexactInput"],
        coreOnly && ! exactQ[e], limitHit["NotExactAlgebraic"],
        True,
        numericInput = exactQ[e];
        initialCost = bounded[RadicalCost[e]];
        If[initialCost === $Failed, initialCost = Missing["NotComputed"]];
        finalCost = initialCost;
        Do[
         If[expiredQ[], Break[]];
         candidate = If[coreOnly, improveNumber[snapshot], walk[snapshot]];
         bump["PassesCompleted"];
         If[candidate === snapshot, Break[]];
         candidateCost = bounded[RadicalCost[candidate]];
         If[candidateCost === $Failed || ! ListQ[finalCost] ||
           Order[candidateCost, finalCost] =!= 1, Break[]];
         If[numericInput && certify[candidate, e] =!= "Equal", Break[]];
         (* Publish a complete pass and its already-computed cost together. *)
         {snapshot, finalCost} = {candidate, candidateCost};
         If[pass === passes && passes > 1, limitHit["MaxPasses"]],
         {pass, passes}]], cfg["MemoryBudget"], memoryStopped],
       cfg["TimeBudget"], timeStopped], operationFailed]];
    If[outcome === memoryStopped, limitHit["MemoryBudget"]];
    If[outcome === timeStopped, limitHit["TimeBudget"]];
    If[outcome === operationFailed, limitHit["SessionFailure"]]];
   status = Which[
     outcome === timeStopped, "Timeout", outcome === memoryStopped, "MemoryLimit",
     outcome === operationFailed, "Failure", TrueQ[cfg["TimeBudget"] == 0], "Disabled",
     snapshot === e, "Unchanged", True, "Improved"];
   <|"Result" -> snapshot, "Status" -> status, "Limits" -> Keys[$limits],
    "InitialCost" -> initialCost, "FinalCost" -> finalCost,
    "Statistics" -> $stats, "Certificates" -> $records,
    "CertificateScope" -> "Bounded sample of accepted proposals, not a committed proof DAG",
    "ElapsedSeconds" -> AbsoluteTime[] - started, "Options" -> cfg,
    "Trace" -> $trace, "CompletenessClaim" -> False,
    "BudgetModel" -> "Cooperative kernel limits; no hard process wall-clock/RSS guarantee"|>]];
