(* ::Package:: *)
(* RadicalRoot 0.1.0. Reference implementation; see validation/STATUS.md.
   Uses only documented number-field operations. No PowerExpand or numerical
   equality tests. All Root indices are native Wolfram Language indices. *)
BeginPackage["RadicalRoot`"];
RootToRadicals::usage = "RootToRadicals[a, opts] returns a radical expression exactly equal to the algebraic number a, or a Failure.";
RadicalSolve::usage = "RadicalSolve[a, opts] returns an Association containing a verified radical expression and construction information, or a Failure.";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] tests the grammar of rational constants, rational complex constants, arithmetic and rational powers. It rejects Root and trigonometric placeholders.";
VerifyRadical::usage = "VerifyRadical[a,e] checks the radical grammar and exact equality RootReduce[a-e]===0.";
PairSumResolvent::usage = "PairSumResolvent[f,x,y] is the polynomial whose roots are sums of unordered pairs of distinct roots of square-free f in Q[x].";
Options[RadicalSolve] = {Method -> "Automatic", TimeConstraint -> 120,
  "MaxFieldDegree" -> 48, "MaxGroupOrder" -> 96,
  "PairResolventLimit" -> 8, "Extensions" -> {}};
Options[RootToRadicals] = Options[RadicalSolve];
Begin["`Private`"];

rationalQ[e_] := IntegerQ[e] || Head[e] === Rational;
RadicalExpressionQ[e_] := Which[
  rationalQ[e], True,
  Head[e] === Complex, rationalQ[Re[e]] && rationalQ[Im[e]],
  Head[e] === Plus || Head[e] === Times, AllTrue[List @@ e, RadicalExpressionQ],
  Head[e] === Power, rationalQ[e[[2]]] && RadicalExpressionQ[e[[1]]],
  True, False];
zeroQ[e_] := TrueQ[Quiet[Check[RootReduce[e], $Failed]] === 0];
VerifyRadical[a_, e_] := RadicalExpressionQ[e] && zeroQ[a - e];
zeta[n_Integer] /; n > 0 := If[n === 1, 1, (-1)^(2/n)];
fail[tag_, msg_, details_: <||>] := Failure[tag, Join[<|"MessageTemplate" -> msg|>, details]];
bail[tag_, msg_, details_: <||>] := Throw[fail[tag, msg, details], $failureTag];
success[a_, e_, method_, cert_: <||>] := <|"Status" -> "Success", "Target" -> a,
  "Expression" -> e, "Method" -> method, "Certificate" -> cert|>;
monic[p_, x_] := Expand[p/Coefficient[p, x, Exponent[p, x]]];
rootList[p_, x_] := With[{ff = Function[Evaluate[p /. x -> Slot[1]]]},
  Table[Root[ff, k], {k, Exponent[p, x]}]];
lowRoots[p_, x_] := Quiet[Check[ToRadicals[x /. Solve[p == 0, x,
  Cubics -> True, Quartics -> True]], {}]];
dickson[0, x_, a_] := 2;
dickson[1, x_, a_] := x;
dickson[n_Integer, x_, a_] := Module[{u = 2, v = x, w},
  Do[w = Expand[x v - a u]; u = v; v = w, {n - 1}]; v];

PairSumResolvent[f_, x_Symbol, y_Symbol] := Catch[Module[
  {p = monic[f, x], n, rr, diag, q, fs, out},
  If[x === y || !PolynomialQ[p, x] ||
     !AllTrue[CoefficientList[p, x], rationalQ],
     bail["UnsupportedInput", "Expected distinct variables and a rational polynomial."]];
  n = Exponent[p, x];
  If[n < 2 || Exponent[PolynomialGCD[p, D[p, x]], x] > 0,
     bail["UnsupportedInput", "Expected a square-free polynomial of degree at least two."]];
  rr = Resultant[p, p /. x -> y - x, x];
  diag = Expand[2^n (p /. x -> y/2)];
  If[Expand[PolynomialRemainder[rr, diag, y]] =!= 0,
    bail["BackendFailure", "Pair-sum diagonal division failed."]];
  q = PolynomialQuotient[rr, diag, y]; fs = Rest[FactorList[q]];
  If[!AllTrue[fs, EvenQ[Last[#]] &],
    bail["BackendFailure", "Pair-sum square extraction failed."]];
  out = Expand[Times @@ ((First[#]^(Last[#]/2)) & /@ fs)];
  If[Exponent[out, y] =!= n (n - 1)/2,
    bail["BackendFailure", "Wrong pair-sum degree."]]; monic[out, y]
], $failureTag];

(* Candidate generation is intentionally bounded and is not a decision procedure. *)
fastCandidates[f_, x_, depth_: 0] := Module[
  {p = monic[f, x], n, shift, g, support, d, q, bs, a, c, u0,
   m, j, aa, out = {}, b, k, sign},
  n = Exponent[p, x]; If[n < 1 || depth > 10, Return[{}]];
  If[n <= 4, Return[Select[lowRoots[p, x], RadicalExpressionQ]]];
  If[!AllTrue[CoefficientList[p, x], rationalQ], Return[{}]];
  shift = -Coefficient[p, x, n - 1]/n;
  g = Expand[p /. x -> x + shift];
  support = Select[Range[n], Coefficient[g, x, #] =!= 0 &];
  d = GCD @@ support;
  If[d > 1,
    q = Sum[Coefficient[g, x, j d] x^j, {j, 0, n/d}];
    bs = fastCandidates[q, x, depth + 1];
    Return[Flatten[Table[shift + zeta[d]^k b^(1/d), {b, bs}, {k, 0, d - 1}]]]];
  a = -Coefficient[g, x, n - 2]/n; c = Coefficient[g, x, 0];
  If[a =!= 0 && Expand[g - dickson[n, x, a] - c] === 0,
    u0 = (-c + Sqrt[c^2 - 4 a^n])/2;
    If[zeroQ[u0], u0 = (-c - Sqrt[c^2 - 4 a^n])/2];
    Return[Table[With[{u = zeta[n]^k u0^(1/n)}, shift + u + a/u], {k, 0, n - 1}]]];
  If[EvenQ[n] && Coefficient[p, x, 0] =!= 0,
    m = n/2;
    j = First[Select[Range[m], Coefficient[p, x, m + #] =!= 0 &, 1]];
    aa = Select[lowRoots[x^j - Coefficient[p, x, m - j]/Coefficient[p, x, m + j], x], rationalQ];
    Do[If[a =!= 0 && And @@ Table[Coefficient[p, x, m - k] ===
          a^k Coefficient[p, x, m + k], {k, m}],
      q = Coefficient[p, x, m] + Sum[Coefficient[p, x, m + k] dickson[k, x, a], {k, m}];
      bs = fastCandidates[q, x, depth + 1];
      out = Join[out, Flatten[Table[(b + sign Sqrt[b^2 - 4 a])/2,
          {b, bs}, {sign, {1, -1}}]]]], {a, aa}]];
  out];

tryCandidates[target_, candidates_, method_] := Module[{good},
  good = Select[candidates, VerifyRadical[target, #] &, 1];
  If[good === {}, Missing["NotFound"],
    success[target, First[good], method, <|"Verification" -> "ExactRootReduce"|>]]];

fastSolve[a_, p_, x_, pairLimit_, extensions_] := Module[
  {ans, y = Unique["y$"], res, fs, bs, ff, q, beta, ext},
  ans = tryCandidates[a, {Quiet[ToRadicals[a]]}, "BuiltIn"];
  If[AssociationQ[ans], Return[ans]];
  ans = tryCandidates[a, fastCandidates[p, x], "Structural"];
  If[AssociationQ[ans], Return[ans]];
  If[Exponent[p, x] <= pairLimit,
    res = PairSumResolvent[p, x, y];
    If[!FailureQ[res],
      fs = SortBy[Rest[FactorList[res]], Exponent[First[#], y] &];
      Do[If[1 < Exponent[q[[1]], y] < Min[5, Exponent[p, x]],
        bs = fastCandidates[q[[1]], y];
        Do[ff = Quiet[Check[Rest[FactorList[p, Extension -> beta]], {}]];
          ff = SortBy[ff, Exponent[First[#], x] &];
          Do[If[0 < Exponent[ext[[1]], x] < Min[4, Exponent[p, x]],
            ans = tryCandidates[a, lowRoots[ext[[1]], x], "PairResolvent"];
            If[AssociationQ[ans], Return[ans]]], {ext, ff}], {beta, bs}]], {q, fs}]]];
  Do[If[RadicalExpressionQ[ext] || (ListQ[ext] && AllTrue[ext, RadicalExpressionQ]),
    ff = Quiet[Check[Rest[FactorList[p, Extension -> ext]], {}]];
    ff = SortBy[ff, Exponent[First[#], x] &];
    Do[If[Exponent[q[[1]], x] <= 4,
      ans = tryCandidates[a, lowRoots[q[[1]], x], "SuppliedExtension"];
      If[AssociationQ[ans], Return[ans]]], {q, ff}]], {ext, extensions}];
  Missing["NotFound"]];

(* Explicit finite group operations. Indices here are one-based. *)
gClosure[tab_, id_, generators_] := Module[{seen = {id}, next, gen = Union[generators]},
  While[True,
    next = Union[seen, Flatten[Table[tab[[a, b]], {a, seen}, {b, gen}]]];
    If[next === seen, Return[seen]]; seen = next]];
gInverse[tab_, id_] := Table[First[FirstPosition[tab[[i]], id]], {i, Length[tab]}];
gDerived[tab_, id_, inv_, group_] := gClosure[tab, id,
  Flatten[Table[tab[[tab[[tab[[a, b]], inv[[a]]]], inv[[b]]]], {a, group}, {b, group}]]];
gChain[tab_, id_] := Module[{inv = gInverse[tab, id], s = Range[Length[tab]], d,
  derived, series, normal, candidate, sigma, prime, chain = {}},
  derived = s; series = {s};
  While[Length[derived] > 1,
    d = gDerived[tab, id, inv, derived]; AppendTo[series, d];
    If[d === derived, bail["NotSolvable", "The exact derived series stabilizes nontrivially.",
      <|"MultiplicationTable" -> tab, "DerivedSeries" -> series|>]];
    derived = d];
  While[Length[s] > 1,
    normal = gDerived[tab, id, inv, s];
    Do[If[!MemberQ[normal, a],
      candidate = gClosure[tab, id, Append[normal, a]];
      If[Length[candidate] < Length[s], normal = candidate]], {a, s}];
    prime = Length[s]/Length[normal];
    If[!PrimeQ[prime], bail["BackendFailure", "Nonprime group-chain index."]];
    sigma = First[Complement[s, normal]];
    If[!And @@ Flatten[Table[MemberQ[normal, tab[[tab[[a, b]], inv[[a]]]]],
          {a, s}, {b, normal}]], bail["BackendFailure", "Nonnormal group-chain step."]];
    AppendTo[chain, {s, normal, sigma, prime}]; s = normal]; chain];

primitive[aa_List] := Module[{nf, gens, th, u = Unique["u$"], mp},
  (* All is essential: Automatic need not give the smallest compositum. *)
  nf = Quiet[Check[ToNumberField[aa, All], $Failed]];
  gens = Cases[nf, AlgebraicNumber[t_, _] :> t, {1}];
  If[gens === {}, bail["BackendFailure", "Primitive-element construction failed."]];
  th = First[gens];
  (* An integral generator prevents ToNumberField from silently rescaling it. *)
  mp = MinimalPolynomial[th, u];
  RootReduce[Coefficient[mp, u, Exponent[mp, u]] th]];

kummerSolve[target_, f_, variable_, maxDegree_, maxGroup_] := Module[
  {roots, th, P, x = Unique["X$"], dL, m, zz, d, d0, red, mul, pow, enc, vec, act,
   coords, z, fs, autos, allAutos, tab, id, index, chain, basis, bexpr, zs, defs,
   records = {}, upper, lower, sig, prime, zp, a, r, b, power, cc, radicand,
   actual, principal, matches, branch, sym, oldBasis, oldExpr, value, expanded,
   result, nf, pos, k, j, step, rule},
  roots = rootList[f, variable]; th = primitive[roots];
  dL = Exponent[MinimalPolynomial[th, x], x];
  If[dL > maxDegree, bail["ResourceLimit", "Splitting-field degree exceeds the configured bound.",
    <|"Degree" -> dL, "Bound" -> maxDegree|>]];
  m = Times @@ (First /@ FactorInteger[dL]); zz = zeta[m];
  th = primitive[{th, zz}]; P = monic[MinimalPolynomial[th, x], x]; d = Exponent[P, x];
  If[d > maxDegree, bail["ResourceLimit", "Cyclotomic compositum exceeds the degree bound.",
    <|"Degree" -> d, "Bound" -> maxDegree|>]];
  red[e_] := Expand[PolynomialRemainder[Expand[e], P, x]];
  mul[u_, v_] := red[u v];
  pow[u_, n_Integer] /; n >= 0 := Module[{v = 1, b0 = u, k0 = n},
    While[k0 > 0, If[OddQ[k0], v = mul[v, b0]]; k0 = Quotient[k0, 2];
      If[k0 > 0, b0 = mul[b0, b0]]]; v];
  act[u_, v_] := red[u /. x -> v];
  enc[e_] := Module[{an, out},
    If[rationalQ[e], Return[e]];
    an = Quiet[Check[ToNumberField[RootReduce[e], th], $Failed]];
    If[Head[an] === AlgebraicNumber && !zeroQ[an[[1]] - th],
      bail["BackendFailure", "The field backend changed the chosen primitive generator."]];
    out = If[Head[an] === AlgebraicNumber, AlgebraicNumberPolynomial[an, x], an];
    If[!PolynomialQ[out, x] || !AllTrue[CoefficientList[out, x], rationalQ],
      bail["BackendFailure", "An exact field-membership computation failed."]]; red[out]];
  vec[e_] := PadRight[CoefficientList[red[e], x], d];
  coords[e_, bb_] := Module[{mat = Transpose[vec /@ bb], c0},
    c0 = Quiet[Check[LinearSolve[mat, vec[e]], $Failed]];
    If[!VectorQ[c0, rationalQ] || Length[c0] =!= Length[bb] || mat.c0 =!= vec[e],
      bail["BackendFailure", "Inconsistent or nonrational lower-field coordinates."]]; c0];
  z = enc[zz];
  fs = Rest[FactorList[P, Extension -> th]];
  If[Length[fs] =!= d || !AllTrue[fs, Exponent[First[#], x] === 1 && Last[#] === 1 &],
    bail["BackendFailure", "The constructed field failed the exact normality test."]];
  allAutos = enc[-Coefficient[First[#], x, 0]/Coefficient[First[#], x, 1]] & /@ fs;
  autos = Select[allAutos, act[z, #] === z &];
  If[!MemberQ[autos, x], bail["BackendFailure", "Missing identity automorphism."]];
  autos = Prepend[DeleteCases[autos, x], x]; id = 1;
  d0 = EulerPhi[m];
  If[Length[autos] d0 =!= d, bail["BackendFailure", "Wrong cyclotomic stabilizer order."]];
  If[Length[autos] > maxGroup, bail["ResourceLimit", "Relative group exceeds its order bound."]];
  index[e_] := Module[{at = FirstPosition[autos, e]},
    If[MissingQ[at], bail["BackendFailure", "Automorphisms are not closed."]]; First[at]];
  tab = Table[index[act[b, a]], {a, autos}, {b, autos}];
  chain = gChain[tab, id];
  zs = Unique["z0$"]; defs = {zs -> zz};
  basis = Table[pow[z, j], {j, 0, d0 - 1}]; bexpr = Table[zs^j, {j, 0, d0 - 1}];
  Do[{upper, lower, sig, prime} = step;
    If[Mod[m, prime] =!= 0, bail["BackendFailure", "Missing prime root of unity."]];
    zp = pow[z, m/prime]; r = 0;
    Do[a = red[Total[pow[autos[[#]], k] & /@ lower]]; r = 0; b = a;
      Do[r = red[r + mul[pow[zp, Mod[-j, prime]], b]]; b = act[b, autos[[sig]]],
        {j, 0, prime - 1}]; If[r =!= 0, Break[]], {k, 0, d - 1}];
    If[r === 0, bail["BackendFailure", "Every trace-basis resolvent vanished."]];
    If[act[r, autos[[sig]]] =!= mul[zp, r] ||
       !AllTrue[lower, act[r, autos[[#]]] === r &],
      bail["BackendFailure", "The Kummer eigenvector identity failed."]];
    power = pow[r, prime];
    If[!AllTrue[upper, act[power, autos[[#]]] === power &],
      bail["BackendFailure", "The Kummer radicand is not fixed by the upper subgroup."]];
    cc = coords[power, basis]; radicand = cc.bexpr;
    actual = RootReduce[r /. x -> th];
    principal = RootReduce[(RootReduce[power /. x -> th])^(1/prime)];
    matches = Select[Range[0, prime - 1], zeroQ[actual - zz^(# m/prime) principal] &, 1];
    If[matches === {}, bail["BackendFailure", "Exact principal-branch selection failed."]];
    branch = First[matches]; sym = Unique["r$"];
    AppendTo[defs, sym -> zs^(branch m/prime) radicand^(1/prime)];
    AppendTo[records, <|"Prime" -> prime, "Branch" -> branch, "Symbol" -> sym,
      "Radicand" -> radicand, "EigenvectorCoordinates" -> vec[r],
      "UpperOrder" -> Length[upper], "LowerOrder" -> Length[lower]|>];
    oldBasis = basis; oldExpr = bexpr;
    basis = Flatten[Table[mul[b, pow[r, j]], {j, 0, prime - 1}, {b, oldBasis}]];
    bexpr = Flatten[Table[b sym^j, {j, 0, prime - 1}, {b, oldExpr}]];
    If[Length[basis] =!= d/Length[lower], bail["BackendFailure", "Tower dimension mismatch."]],
    {step, chain}];
  value = coords[enc[target], basis].bexpr; expanded = {};
  Do[AppendTo[expanded, First[rule] -> (Last[rule] /. expanded)], {rule, defs}];
  result = value /. expanded;
  If[!VerifyRadical[target, result], bail["VerificationFailure", "Final exact radical equality failed."]];
  success[target, result, "GaloisKummer", <|"SplittingFieldDegree" -> dL,
    "FieldDegree" -> d, "CyclotomicConductor" -> m, "RelativeGroupOrder" -> Length[autos],
    "ChainIndices" -> (Last /@ chain), "Definitions" -> defs, "Value" -> value,
    "Steps" -> records, "MultiplicationTable" -> tab, "Verification" -> "ExactRootReduce"|>]
];

RadicalSolve[input_, OptionsPattern[]] := Module[
  {tc = OptionValue[TimeConstraint], method = OptionValue[Method],
   maxDegree = OptionValue["MaxFieldDegree"], maxGroup = OptionValue["MaxGroupOrder"],
   pairLimit = OptionValue["PairResolventLimit"], ext = OptionValue["Extensions"],
   work, x = Unique["x$"], a, p, ans},
  work[] := Catch[Module[{},
    If[!MemberQ[{"Automatic", "Fast", "Galois"}, method],
      bail["UnsupportedInput", "Method must be Automatic, Fast or Galois (as a string)."]];
    If[!And @@ (TrueQ[# === Infinity || (IntegerQ[#] && # > 0)] & /@ {maxDegree, maxGroup}),
      bail["UnsupportedInput", "Field and group bounds must be positive integers or Infinity."]];
    If[!IntegerQ[pairLimit] || pairLimit < 0 || !ListQ[ext],
      bail["UnsupportedInput", "Expected a nonnegative pair bound and a list of extensions."]];
    If[!FreeQ[input, _Real], bail["UnsupportedInput", "Inexact input is not accepted."]];
    a = Quiet[Check[RootReduce[input], $Failed]];
    p = Quiet[Check[MinimalPolynomial[a, x], $Failed]];
    If[!PolynomialQ[p, x] || Exponent[p, x] < 1 ||
       !AllTrue[CoefficientList[p, x], rationalQ] || !zeroQ[p /. x -> a],
      bail["UnsupportedInput", "Expected a parameter-free exact algebraic number."]];
    p = monic[p, x];
    If[rationalQ[a], Return[success[a, a, "Rational"]]];
    If[method =!= "Galois",
      ans = fastSolve[a, p, x, pairLimit, ext]; If[AssociationQ[ans], Return[ans]];
      If[method === "Fast", bail["NotFound", "Fast paths exhausted; nonsolvability has not been proved."]]];
    kummerSolve[a, p, x, maxDegree, maxGroup]], $failureTag];
  If[tc === Infinity, work[], TimeConstrained[work[], tc,
    fail["ResourceLimit", "The time limit was reached; no nonsolvability conclusion follows."]]]
];
RootToRadicals[a_, opts : OptionsPattern[]] := Module[{r = RadicalSolve[a, opts]},
  If[AssociationQ[r], r["Expression"], r]];
End[];
EndPackage[];
