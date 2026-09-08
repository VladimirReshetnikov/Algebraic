(* ::Package:: *)

(* RootToRadicals.wl

   Expressing algebraic numbers (Root objects) by radicals whenever this is
   possible, i.e. whenever the Galois group of the minimal polynomial is
   solvable.  Answers Mathematica StackExchange question 34011.

   Two layers:

   * Structural recognizers (cheap, produce short formulas): built-in
     ToRadicals; functional decomposition p = g(h(x)) (Decompose), including
     translated power compositions; generalized reciprocal symmetry
     p(x) = x^m P(x + a/x); Dickson polynomials D_n(x,a) - b.  Recursion on
     the inner and outer pieces.

   * General Galois-Kummer descent (complete for solvable inputs): the Galois
     group and splitting field data come from RootDecomposition.wl (numerical
     resolvents, trace-form coordinates).  The needed roots of unity are
     adjoined by running the same engine on p(x) * Prod Phi_q(x); a
     composition series with prime quotients of Gal(L(zeta)/Q(zeta)) is
     computed from the multiplication table; each prime step is inverted with
     Lagrange resolvents R_k = Sum_j zeta_p^(-kj) sigma^j(beta), whose p-th
     powers lie one level down; branches zeta_p^e Q^(1/p) are selected by
     high-precision numerics (the candidates are separated) and the final
     identity is verified exactly with RootReduce.

   Requires RootDecomposition.wl (loaded automatically from the sibling
   directory root-decomposition/ if it is not already loaded).

   Prepared for Vladimir Reshetnikov, September 2026.  License: MIT-0.
*)

If[! MemberQ[$Packages, "RootDecomposition`"],
  Module[{dir = DirectoryName[$InputFileName /. "" -> Directory[]], f},
    f = FileNameJoin[{dir, "..", "root-decomposition", "RootDecomposition.wl"}];
    If[FileExistsQ[f], Get[f], Get["RootDecomposition`"]]]];

BeginPackage["RootToRadicals`", {"RootDecomposition`"}];

RootToRadicals::usage = "RootToRadicals[a] expresses the exact algebraic number a by radicals when the Galois group of its minimal polynomial is solvable; it returns a Failure otherwise. RootToRadicals[a, Method -> \"Galois\"] forces the general Galois-Kummer descent.";
RootRadicalReport::usage = "RootRadicalReport[a] returns an Association with the radical expression (if any), the method used, the Galois group order, solvability, verification status and timing.";
RootSolvableQ::usage = "RootSolvableQ[a] gives True if the Galois group of the minimal polynomial of a is solvable (so that a is expressible by radicals), False otherwise.";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] gives True if e is built from rational numbers, I, Plus, Times and Power with rational exponents only.";
RadicalDepth::usage = "RadicalDepth[e] gives the nesting depth of radicals in e.";

RootToRadicals::notsolv = "The Galois group of the minimal polynomial (order `1`) is not solvable; no radical expression exists.";
RootToRadicals::inexact = "The input `1` is not an exact algebraic number.";
RootToRadicals::verify = "The candidate radical expression could not be verified exactly; returning it with \"Verified\" -> `1`.";

Begin["`Private`"];

x = RootDecomposition`Private`x;
exactZeroQ = RootDecomposition`Private`exactZeroQ;
minimalPolynomialOf = RootDecomposition`Private`minimalPolynomialOf;
rootObject = RootDecomposition`Private`rootObject;
algebraicDegree = RootDecomposition`Private`algebraicDegree;
inputData = RootDecomposition`Private`inputData;
failure = RootDecomposition`Private`failure;
locateTarget = RootDecomposition`Private`locateTarget;
conjugates = RootDecomposition`Private`conjugates;
multiplicationMatrixOfElement = RootDecomposition`Private`multiplicationMatrixOfElement;
rationalQ = RootDecomposition`Private`rationalQ;

(* ------------------------------------------------------------------ *)
(* Radical grammar                                                     *)
(* ------------------------------------------------------------------ *)

RadicalExpressionQ[e_] := Module[{ok = True},
  Which[
    rationalQ[e], True,
    e === I || e === -I, True,
    Head[e] === Complex, rationalQ[Re[e]] && rationalQ[Im[e]],
    Head[e] === Plus || Head[e] === Times, AllTrue[List @@ e, RadicalExpressionQ],
    Head[e] === Power, rationalQ[e[[2]]] && RadicalExpressionQ[e[[1]]],
    True, False]];

RadicalDepth[e_] := Which[
  rationalQ[e] || Head[e] === Complex, 0,
  Head[e] === Power, If[IntegerQ[e[[2]]], RadicalDepth[e[[1]]], 1 + RadicalDepth[e[[1]]]],
  Head[e] === Plus || Head[e] === Times, Max[RadicalDepth /@ List @@ e],
  True, 0];

(* numeric comparison helpers *)
$prec = 60;
numeric[e_] := N[e, $prec];

(* pick the candidate closest to the target value; require clear separation *)
selectCandidate[cands_List, target_] := Module[{vals, d, ord},
  vals = numeric /@ cands;
  d = Abs[vals - numeric[target]];
  ord = Ordering[d];
  If[d[[ord[[1]]]] < 10^-20 && (Length[d] == 1 || d[[ord[[2]]]] > 10^-15), cands[[ord[[1]]]], $Failed]];

(* exact verification with a time limit; returns True, False or Indeterminate *)
verifyExact[expr_, a_, limit_] := Module[{r},
  r = TimeConstrained[exactZeroQ[expr - a], limit, Indeterminate];
  If[r === Indeterminate,
    If[Abs[N[expr - a, 200]] < 10^-150, Indeterminate, False], r]];

(* ------------------------------------------------------------------ *)
(* Structural layer                                                    *)
(* ------------------------------------------------------------------ *)

monic[p_] := Expand[p/Coefficient[p, x, Exponent[p, x]]];

(* roots of a polynomial with radical coefficients in the variable x, degree <= 4, as radicals *)
lowDegreeRoots[q_] := Module[{sols, t},
  sols = Quiet[x /. Solve[q == 0, x, Cubics -> True, Quartics -> True]];
  If[! ListQ[sols], Return[$Failed]];
  sols];

(* 1. functional decomposition p = g(h(x)) with deg h <= 4 or recursion *)
structuralDecompose[a_, p_, depth_] := Module[{comp, g, h, v, vrad, cands, sel},
  comp = Decompose[p, x];
  If[Length[comp] < 2, Return[$Failed]];
  g = First[comp]; h = Fold[#2 /. x -> #1 &, x, Reverse[Rest[comp]]];   (* h = inner composition *)
  h = Expand[h];
  v = RootReduce[h /. x -> a];               (* a root of g *)
  vrad = radicalsOf[v, depth - 1];
  If[FailureQ[vrad], Return[$Failed]];
  If[Exponent[h, x] <= 4,
    cands = lowDegreeRoots[h - vrad];
    If[cands === $Failed, Return[$Failed]];
    sel = selectCandidate[cands, a];
    If[sel === $Failed, $Failed, sel],
    (* inner piece of degree > 4: solve h(x) = v recursively as an algebraic number problem *)
    Module[{inner = radicalsOf[a, depth - 1, "Polynomial" -> Expand[h - v]]}, inner]]];

(* 2. generalized reciprocal symmetry: p(x) = x^m P(x + a/x), even degree 2m *)
rationalRoots[q_, m_] := Module[{num = Numerator[q], den = Denominator[q], cands = {}, r},
  r = Abs[num]^(1/m); If[IntegerQ[r] && (EvenQ[m] || True), cands = {r/den^(1/m), -r/den^(1/m)}];
  Select[DeleteDuplicates[cands], rationalQ[#] && #^m == q &]];

reciprocalDecomposition[p_] := Module[{n = Exponent[p, x], m, q, c0, avals, res},
  If[OddQ[n], Return[$Failed]];
  m = n/2; q = monic[p]; c0 = Coefficient[q, x, 0];
  If[c0 == 0, Return[$Failed]];
  avals = rationalRoots[c0, m];
  res = $Failed;
  Do[
    Module[{rem = q, P = 0, k, cf, ok = True},
      Do[
        cf = Coefficient[rem, x, m + k];
        P += cf x^k;
        rem = Expand[rem - cf x^m (x + av/x)^k],
        {k, m, 0, -1}];
      If[Expand[rem] === 0, res = {av, P}; Break[]]],
    {av, avals}];
  res];

structuralReciprocal[a_, p_, depth_] := Module[{rd, av, P, y, yrad, cands, sel},
  rd = reciprocalDecomposition[p];
  If[rd === $Failed, Return[$Failed]];
  {av, P} = rd;
  y = RootReduce[a + av/a];                 (* a root of P *)
  yrad = radicalsOf[y, depth - 1];
  If[FailureQ[yrad], Return[$Failed]];
  cands = {(yrad + Sqrt[yrad^2 - 4 av])/2, (yrad - Sqrt[yrad^2 - 4 av])/2};
  sel = selectCandidate[cands, a];
  sel];

(* 3. Dickson polynomials: centered q(y) = D_n(y, av) - b *)
dickson[n_, av_] := Module[{d0 = 2, d1 = x, d2},
  If[n == 0, Return[2]]; If[n == 1, Return[x]];
  Do[d2 = Expand[x d1 - av d0]; d0 = d1; d1 = d2, {n - 1}]; d1];

structuralDickson[a_, p_, depth_] := Module[{n = Exponent[p, x], q, c, av, b, diff, t, cands, sel, s, zeta},
  q = monic[p];
  c = -Coefficient[q, x, n - 1]/n;
  q = Expand[q /. x -> x + c];
  If[n < 3, Return[$Failed]];
  av = -Coefficient[q, x, n - 2]/n;
  If[av == 0, Return[$Failed]];
  diff = Expand[q - dickson[n, av]];
  If[Exponent[diff, x] > 0, Return[$Failed]];
  b = -diff;                                 (* q = D_n - b *)
  s = (b + Sqrt[b^2 - 4 av^n])/2;
  t = s^(1/n);
  zeta = (-1)^(2/n);
  cands = Table[c + zeta^j t + av/(zeta^j t), {j, 0, n - 1}];
  sel = selectCandidate[cands, a];
  sel];

(* the structural driver: returns a radical expression equal to a, or $Failed *)
structural[a_, p_, depth_] := Module[{n = Exponent[p, x], r},
  If[depth <= 0, Return[$Failed]];
  If[n <= 4, r = ToRadicals[a]; If[RadicalExpressionQ[r], Return[r]]];
  r = Quiet[TimeConstrained[ToRadicals[a], 5, $Failed]];
  If[r =!= $Failed && RadicalExpressionQ[r], Return[r]];
  r = structuralDecompose[a, p, depth]; If[r =!= $Failed && ! FailureQ[r], Return[r]];
  r = structuralReciprocal[a, p, depth]; If[r =!= $Failed && ! FailureQ[r], Return[r]];
  r = structuralDickson[a, p, depth]; If[r =!= $Failed && ! FailureQ[r], Return[r]];
  $Failed];

(* ------------------------------------------------------------------ *)
(* General Galois-Kummer descent                                       *)
(* ------------------------------------------------------------------ *)

(* subgroup generated by gens (as element indices) from the multiplication table *)
groupClosure[mt_, idElem_, gens_] := Module[{elems = {idElem}, frontier = {idElem}, next, h},
  While[frontier =!= {},
    next = {};
    Do[h = mt[[e, g]]; If[! MemberQ[elems, h], AppendTo[elems, h]; AppendTo[next, h]], {e, frontier}, {g, gens}];
    frontier = next];
  Sort[elems]];

inverseOf[mt_, idElem_, g_] := First[FirstPosition[mt[[g]], idElem]];

commutatorSubgroup[mt_, idElem_, H_] := Module[{comms},
  comms = DeleteDuplicates[Flatten[Table[mt[[mt[[inverseOf[mt, idElem, g], inverseOf[mt, idElem, h]]], mt[[g, h]]]], {g, H}, {h, H}]]];
  groupClosure[mt, idElem, comms]];

solvableQ[mt_, idElem_, H_] := Module[{cur = Sort[H], nxt},
  While[Length[cur] > 1,
    nxt = commutatorSubgroup[mt, idElem, cur];
    If[nxt === cur, Return[False]];
    cur = nxt];
  True];

(* composition series with prime quotients: list of <|"Group", "Normal", "Generator", "Prime"|> from H down to 1 *)
primeSeries[mt_, idElem_, H0_] := Module[{H = Sort[H0], steps = {}, D, N, g, p, sigma},
  While[Length[H] > 1,
    D = commutatorSubgroup[mt, idElem, H];
    If[D === H, Return[$Failed]];
    N = D;
    Do[If[! MemberQ[N, g],
        With[{J = groupClosure[mt, idElem, Append[N, g]]}, If[Length[J] < Length[H], N = J]]],
      {g, H}];
    p = Length[H]/Length[N];
    If[! PrimeQ[p], Return[$Failed]];
    sigma = First[Complement[H, N]];
    AppendTo[steps, <|"Group" -> H, "Normal" -> N, "Generator" -> sigma, "Prime" -> p|>];
    H = N];
  steps];

fixedByQ[gd_, v_, elems_] := AllTrue[elems, gd["Automorphisms"][[#]] . v == v &];

(* coordinates of the exact algebraic number e (given in radicals or as an exact number) are not needed;
   we go the other way: from coordinates to radicals. *)

galoisRadicals[a_, p_, opts_] := Module[
  {n = Exponent[p, x], gd0, order, primes, poly, gd, c, target, va, zetaIdx, zetaCoord, zetaMult, zetaVal,
   H, steps, mt, idElem, rad, memo, expr, zetaNums, baseBasis, baseSymbols, val},
  gd0 = RootGaloisData[p, x, "MaxGroupOrder" -> OptionValue[RootToRadicals, opts, "MaxGroupOrder"],
    "WorkingPrecision" -> OptionValue[RootToRadicals, opts, "WorkingPrecision"]];
  If[FailureQ[gd0], Return[gd0]];
  order = gd0["Order"];
  If[! solvableQ[gd0["MultiplicationTable"], gd0["Identity"], Range[order]],
    Message[RootToRadicals::notsolv, order];
    Return[failure["NotSolvable", "The Galois group is not solvable", <|"GaloisGroupOrder" -> order|>]]];
  primes = Select[First /@ FactorInteger[order], OddQ];
  poly = Expand[p Times @@ (Cyclotomic[#, x] & /@ primes)];
  (* if p itself is a cyclotomic polynomial the product is not squarefree; ToRadicals handles roots of unity *)
  If[! SquareFreeQ[poly], Return[$Failed]];
  gd = If[primes === {}, gd0,
    RootGaloisData[poly, x, "MaxGroupOrder" -> OptionValue[RootToRadicals, opts, "MaxGroupOrder"] Times @@ (# - 1 & /@ primes),
      "WorkingPrecision" -> OptionValue[RootToRadicals, opts, "WorkingPrecision"]]];
  If[FailureQ[gd], Return[gd]];
  c = gd["Scale"];
  target = locateTarget[gd, a];
  If[target === $Failed, Return[failure["RootIndex", "Could not locate the input among the roots"]]];
  va = gd["RootCoordinates"][[target]]/c;
  mt = gd["MultiplicationTable"]; idElem = gd["Identity"];
  (* roots of unity: choose zeta_q = Exp[2 Pi I/q] among the roots *)
  zetaIdx = Association @@ Table[
    q -> First[FirstPosition[gd["Roots"], _?(exactZeroQ[# - Exp[2 Pi I/q]] &)]], {q, primes}];
  zetaCoord = Association @@ Table[q -> gd["RootCoordinates"][[zetaIdx[q]]], {q, primes}];   (* scale c is 1 for these since they are integral: roots scaled by c! *)
  (* the engine scales all roots by c; zeta appears as c*zeta.  Undo: *)
  zetaCoord = Association @@ Table[q -> gd["RootCoordinates"][[zetaIdx[q]]]/c, {q, primes}];
  zetaMult = Association @@ Table[q -> multiplicationMatrixOfElement[gd, zetaCoord[q]], {q, primes}];
  (* H = stabilizer of all roots of unity *)
  H = Select[Range[gd["Order"]], Function[s, AllTrue[Values[zetaIdx], gd["Permutations"][[s, #]] == # &]]];
  steps = primeSeries[mt, idElem, H];
  If[steps === $Failed, Return[failure["NotSolvable", "Could not build a prime composition series"]]];
  (* base field Q(zeta): basis monomials prod zeta_q^j *)
  baseSymbols = Table[(-1)^(2/q), {q, primes}];
  baseBasis = Module[{exps = Tuples[Range[0, # - 2] & /@ primes]},
    Table[{Times @@ MapThread[#1^#2 &, {baseSymbols, e}],
           Fold[#2 . #1 &, UnitVector[gd["Order"], 1], MapThread[MatrixPower[zetaMult[#1], #2] &, {primes, e}]]}, {e, exps}]];
  memo = <||>;
  (* rad[v, level]: level = number of steps applied; level 0 = base field Q(zeta) *)
  rad[v_, level_] := Module[{key = {v, level}, res},
    If[KeyExistsQ[memo, key], Return[memo[key]]];
    res = radCompute[v, level];
    memo[key] = res; res];
  radCompute[v_, 0] := Module[{B, sol},
    If[baseBasis === {}, Return[v[[1]]]];
    B = Transpose[baseBasis[[All, 2]]];
    sol = Quiet[Check[LinearSolve[B, v], $Failed]];
    If[sol === $Failed, Throw[failure["Descent", "Element not in the base cyclotomic field"], radTag]];
    Simplify[sol . baseBasis[[All, 1]]]];
  radCompute[v_, level_] := Module[{st = steps[[level]], M, N, sigma, q, autS, z, zm, Rk, terms, k, Qk, qrad, cand, val, numR, sel, pieces},
    If[v == 0 v, Return[0]];
    M = st["Group"]; N = st["Normal"]; sigma = st["Generator"]; q = st["Prime"];
    If[fixedByQ[gd, v, M], Return[rad[v, level - 1]]];
    autS = gd["Automorphisms"][[sigma]];
    zm = If[q == 2, -IdentityMatrix[gd["Order"]], zetaMult[q]];
    z = If[q == 2, -1, (-1)^(2/q)];
    pieces = {};
    Do[
      (* R_k = sum_j zeta^(-k j) sigma^j(v) *)
      Rk = Module[{acc = 0 v, w = v, zk = MatrixPower[zm, Mod[-k, q]], zpow = IdentityMatrix[gd["Order"]]},
        Do[acc += zpow . w; w = autS . w; zpow = zk . zpow, {j, 0, q - 1}]; acc];
      If[Rk == 0 Rk, Continue[]];
      If[k == 0,
        AppendTo[pieces, rad[Rk, level - 1]],
        Qk = MatrixPower[multiplicationMatrixOfElement[gd, Rk], q - 1] . Rk;    (* R_k^q, fixed by M *)
        qrad = rad[Qk, level - 1];
        numR = conjugates[gd, Rk][[gd["Identity"]]];
        cand = Table[z^e qrad^(1/q), {e, 0, q - 1}];
        sel = selectCandidate[cand, numR];
        If[sel === $Failed, Throw[failure["Branch", "Could not identify the radical branch"], radTag]];
        AppendTo[pieces, sel]],
      {k, 0, q - 1}];
    Total[pieces]/q];
  expr = Catch[rad[va, Length[steps]], radTag];
  If[FailureQ[expr], Return[expr]];
  <|"Expression" -> expr, "GaloisGroupOrder" -> order, "ExtendedGroupOrder" -> gd["Order"],
    "Primes" -> primes, "SeriesPrimes" -> steps[[All, "Prime"]]|>];

(* ------------------------------------------------------------------ *)
(* Driver                                                              *)
(* ------------------------------------------------------------------ *)

Options[RootToRadicals] = {
  Method -> Automatic,            (* Automatic, "Structural", "Galois" *)
  "MaxGroupOrder" -> 400,
  "WorkingPrecision" -> 80,
  "VerificationTimeLimit" -> 60,
  "MaxDepth" -> 6
};
Options[RootRadicalReport] = Options[RootToRadicals];

(* recursive core: returns a radical expression or a Failure; the optional polynomial overrides the minimal polynomial *)
radicalsOf[a_, depth_, OptionsPattern[{"Polynomial" -> Automatic}]] := Module[{in, p, n, r},
  If[rationalQ[a], Return[a]];
  If[RadicalExpressionQ[a], Return[a]];
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  p = in["Polynomial"]; n = in["Degree"];
  If[n == 1, Return[in["Value"]]];
  r = If[$method =!= "Galois", structural[a, p, depth], $Failed];
  If[r =!= $Failed && ! FailureQ[r], Return[r]];
  If[$method === "Structural", Return[failure["NotFound", "No structural radical form found"]]];
  r = galoisRadicals[a, p, $opts];
  If[FailureQ[r], r, r["Expression"]]];

$method = Automatic; $opts = {};

RootRadicalReport[a_, opts : OptionsPattern[]] := Module[{t0 = AbsoluteTime[], in, r, expr, ver, method},
  If[! FreeQ[a, _Real], Message[RootToRadicals::inexact, a]; Return[failure["Inexact", "Inexact input"]]];
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  $prec = Max[60, OptionValue["WorkingPrecision"]];
  Block[{$method = OptionValue[Method], $opts = Flatten[{opts}]},
    r = radicalsOf[a, OptionValue["MaxDepth"]]];
  If[FailureQ[r], Return[Join[r, <|"Time" -> AbsoluteTime[] - t0|>]]];
  expr = r;
  ver = verifyExact[expr, a, OptionValue["VerificationTimeLimit"]];
  If[ver =!= True, Message[RootToRadicals::verify, ver]];
  <|"Expression" -> expr, "Verified" -> ver, "Degree" -> in["Degree"], "RadicalDepth" -> RadicalDepth[expr],
    "Time" -> AbsoluteTime[] - t0|>];

RootToRadicals[a_, opts : OptionsPattern[]] := Module[{r = RootRadicalReport[a, opts]},
  If[FailureQ[r], r, If[r["Verified"] === False, failure["VerificationFailed", "The candidate expression is not equal to the input"], r["Expression"]]]];

RootSolvableQ[a_, opts : OptionsPattern[RootToRadicals]] := Module[{in, gd},
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  If[in["Degree"] <= 4, Return[True]];
  gd = RootGaloisData[in["Polynomial"], x, "MaxGroupOrder" -> OptionValue["MaxGroupOrder"]];
  If[FailureQ[gd], Return[gd]];
  solvableQ[gd["MultiplicationTable"], gd["Identity"], Range[gd["Order"]]]];

End[];
EndPackage[];
