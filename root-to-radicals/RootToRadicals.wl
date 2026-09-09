(* ::Package:: *)

(* RootToRadicals.wl

   Expressing algebraic numbers (Root objects) by radicals whenever this is
   possible, i.e. whenever the Galois group of the minimal polynomial is
   solvable.  Answers Mathematica StackExchange question 34011.

   Two layers:

   * Structural recognizers (cheap, short formulas): built-in ToRadicals;
     functional decomposition p = g1(g2(...(x))) (Decompose); generalized
     reciprocal symmetry p(x) = x^m P(x + a/x); Dickson polynomials
     D_n(x,a) - b; and the pair-sum resolvent (roots a_i + a_j of low degree
     generate a subfield over which p has a factor of degree <= 4), which is
     the systematic form of the search in the notebook of the question.
     Recursion on the pieces.

   * General Galois-Kummer descent (complete for solvable inputs): the Galois
     group and the splitting field come from RootDecomposition.wl (numerical
     resolvents, tower basis, trace-form coordinates).  The needed roots of
     unity are adjoined by running the same engine on p(x) * Prod Phi_q(x);
     a composition series with prime quotients of Gal(L(zeta)/Q(zeta)) is
     computed from the multiplication table; each prime step is inverted with
     Lagrange resolvents R_k = Sum_j zeta_p^(-kj) sigma^j(beta), whose p-th
     powers lie one level down.  Either all q-1 resolvents are extracted
     ("Fourier" form, beta = (1/q) Sum_k R_k) or a single one u = R_1 is
     extracted and the others are written as c_k u^k with c_k one level down
     ("Eigenvector" form).  Branches zeta_p^e Q^(1/p) are selected by
     high-precision numerics (the candidates are separated); the final
     identity is verified exactly with RootReduce.

   Nonsolvability is proved either by Frobenius cycle types (prime degree:
   a solvable transitive group of prime degree n lies in AGL(1,n), so every
   Frobenius element has cycle type 1^n, n or 1 d^((n-1)/d)) or by the exact
   Galois group.

   Requires RootDecomposition.wl (loaded automatically from the sibling
   directory root-decomposition/ if it is not already loaded).

   Prepared for Vladimir Reshetnikov, September 2026.  License: MIT-0.
*)

If[! MemberQ[$Packages, "RootDecomposition`"],
  Module[{dir = DirectoryName[$InputFileName /. "" -> Directory[]], f},
    f = FileNameJoin[{dir, "..", "root-decomposition", "RootDecomposition.wl"}];
    If[FileExistsQ[f], Get[f], Get["RootDecomposition`"]]]];

BeginPackage["RootToRadicals`", {"RootDecomposition`"}];

RootToRadicals::usage = "RootToRadicals[a] expresses the exact algebraic number a by radicals when the Galois group of its minimal polynomial is solvable; it returns a Failure otherwise. RootToRadicals[a, Method -> \"Galois\"] forces the general Galois-Kummer descent; Method -> \"Structural\" uses only the structural recognizers.";
RootRadicalReport::usage = "RootRadicalReport[a] returns an Association with the radical expression (if any), the method used, the Galois group order (when it was computed), the verification status and the timing.";
RootSolvableQ::usage = "RootSolvableQ[a] gives True if the Galois group of the minimal polynomial of a is solvable (so that a is expressible by radicals), False otherwise.";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] gives True if e is built from rational numbers, I, Plus, Times and Power with rational exponents only.";
RadicalDepth::usage = "RadicalDepth[e] gives the nesting depth of radicals in e.";

RootToRadicals::notsolv = "The Galois group of the minimal polynomial is not solvable (`1`); no radical expression exists.";
RootToRadicals::inexact = "The input `1` is not an exact algebraic number.";
RootToRadicals::verify = "The candidate radical expression could not be verified exactly within the time limit; returning it with \"Verified\" -> `1`.";
RootToRadicals::opts = "Invalid option value `1`.";

Begin["`Private`"];

x = RootDecomposition`Private`x;
exactZeroQ = RootDecomposition`Private`exactZeroQ;
minimalPolynomialOf = RootDecomposition`Private`minimalPolynomialOf;
rootObject = RootDecomposition`Private`rootObject;
inputData = RootDecomposition`Private`inputData;
failure = RootDecomposition`Private`failure;
locateTarget = RootDecomposition`Private`locateTarget;
conjugates = RootDecomposition`Private`conjugates;
multiplicationMatrixOfElement = RootDecomposition`Private`multiplicationMatrixOfElement;
rationalQ = RootDecomposition`Private`rationalQ;
precTag = RootDecomposition`Private`precTag;

(* ------------------------------------------------------------------ *)
(* Radical grammar                                                     *)
(* ------------------------------------------------------------------ *)

RadicalExpressionQ[e_] := Which[
  rationalQ[e], True,
  e === I || e === -I, True,
  Head[e] === Complex, rationalQ[Re[e]] && rationalQ[Im[e]],
  Head[e] === Plus || Head[e] === Times, AllTrue[List @@ e, RadicalExpressionQ],
  Head[e] === Power, rationalQ[e[[2]]] && RadicalExpressionQ[e[[1]]],
  True, False];

RadicalDepth[e_] := Which[
  rationalQ[e] || Head[e] === Complex, 0,
  Head[e] === Power, If[IntegerQ[e[[2]]], RadicalDepth[e[[1]]], 1 + RadicalDepth[e[[1]]]],
  Head[e] === Plus || Head[e] === Times, Max[RadicalDepth /@ List @@ e],
  True, 0];

(* ------------------------------------------------------------------ *)
(* Numerics and verification                                           *)
(* ------------------------------------------------------------------ *)

$prec = 60;
numeric[e_] := N[e, $prec];

(* the candidate closest to the target value, if it is clearly separated from the others *)
selectCandidate[cands_List, target_] := Module[{vals, d, ord},
  If[cands === {}, Return[$Failed]];
  vals = numeric /@ cands;
  d = Abs[vals - numeric[target]];
  ord = Ordering[d];
  If[d[[ord[[1]]]] < 10^-20 && (Length[d] == 1 || d[[ord[[2]]]] > 10^-15), cands[[ord[[1]]]], $Failed]];

(* exact verification with a time limit; True, False or Indeterminate (numerically equal, not proved) *)
verifyExact[expr_, a_, limit_] := Module[{r},
  r = TimeConstrained[exactZeroQ[expr - a], limit, Indeterminate];
  If[r === Indeterminate, If[Abs[N[expr - a, 200]] < 10^-150, Indeterminate, False], r]];

(* ------------------------------------------------------------------ *)
(* Frobenius negative test (prime degree)                              *)
(* ------------------------------------------------------------------ *)

(* cycle type of a Frobenius element = degrees of the irreducible factors mod p (p not dividing disc) *)
frobeniusCycleType[poly_, p_] := Sort[Exponent[#[[1]], x] & /@ Select[FactorList[poly, Modulus -> p], Exponent[#[[1]], x] > 0 &]];

agl1TypeQ[degs_, n_] := degs === {n} || degs === ConstantArray[1, n] ||
  (First[degs] == 1 && Length[Union[Rest[degs]]] == 1 && Total[degs] == n);

(* a single prime cycle of length > n/2 (the rest fixed) makes a transitive group primitive, and a
   solvable primitive group has prime-power degree *)
longPrimeCycleQ[degs_, n_] := Module[{m = Last[degs]},
  PrimeQ[m] && 2 m > n && Union[Most[degs]] === {1}];

(* composite prime-power degree n = p^k: a solvable primitive group lies in AGL(k,p); an element fixing a
   point is conjugate into GL(k,p), its fixed points form a subspace of size p^j, so a single prime cycle
   of length l (the rest fixed) needs p^k - p^j = l, i.e. j = 0 and l = n - 1.  A prime cycle with
   n/2 < l < n - 1 therefore proves nonsolvability (primitivity as in longPrimeCycleQ). *)
primePowerCycleQ[degs_, n_] := Module[{m = Last[degs]},
  PrimeQ[m] && 2 m > n && m < n - 1 && Union[Most[degs]] === {1}];

(* True: proved nonsolvable.  False: no obstruction found (inconclusive). *)
frobeniusNonsolvableQ[poly_, maxPrimes_: 60] := Module[{n = Exponent[poly, x], disc, lc, p = 2, count = 0, degs, test},
  test = Which[PrimeQ[n], ! agl1TypeQ[#, n] &, PrimePowerQ[n], primePowerCycleQ[#, n] &, True, longPrimeCycleQ[#, n] &];
  disc = Discriminant[poly, x]; lc = Coefficient[poly, x, n];
  While[count < maxPrimes,
    p = NextPrime[p];
    If[Mod[disc lc, p] == 0, Continue[]];
    count++;
    degs = frobeniusCycleType[poly, p];
    If[test[degs], Return[True, Module]]];
  False];

(* the lcm of the orders of the Frobenius elements divides |G|; a multiple beyond the group order limit
   settles the resource status without building the splitting field *)
frobeniusOrderMultiple[poly_] := RootDecomposition`Private`frobeniusExponentMultiple[poly, 40];

(* ------------------------------------------------------------------ *)
(* Structural layer                                                    *)
(* ------------------------------------------------------------------ *)

monic[p_] := Expand[p/Coefficient[p, x, Exponent[p, x]]];

$method = Automatic; $opts = {}; $methodUsed = None; $galoisInfo = <||>;

(* radical solutions of g(x) = v where g has rational coefficients and v is a radical expression:
   degree <= 4 by Solve, or a binomial x^m + c by an m-th root with all branches *)
(* explicit formulas for degrees 2 and 3 (Solve can spend a long time simplifying large radical
   coefficients); the coefficient list is low to high *)
quadraticRoots[{c0_, c1_, c2_}] := Module[{d = Sqrt[c1^2 - 4 c2 c0]}, {(-c1 + d)/(2 c2), (-c1 - d)/(2 c2)}];

cubicRoots[{d0_, c0_, b0_, a0_}] := Module[{b = b0/a0, c = c0/a0, d = d0/a0, pp, qq, u, w = (-1)^(2/3)},
  pp = c - b^2/3; qq = 2 b^3/27 - b c/3 + d;
  If[pp === 0, Return[Table[w^k (-qq)^(1/3) - b/3, {k, 0, 2}]]];
  u = (-qq/2 + Sqrt[qq^2/4 + pp^3/27])^(1/3);
  Table[w^k u - pp/(3 w^k u) - b/3, {k, 0, 2}]];

solveWithRadicalRHS[g_, v_] := Module[{n = Exponent[g, x], sols, c, zeta, cl},
  cl = CoefficientList[Expand[g - v], x];
  Which[
    n == 1, {-cl[[1]]/cl[[2]]},
    n == 2, quadraticRoots[cl],
    n == 3 && cl[[1]] =!= 0, cubicRoots[cl],
    n <= 4,
      sols = Quiet[x /. Solve[g == v, x, Cubics -> True, Quartics -> True]];
      If[! ListQ[sols], $Failed, Select[sols, RadicalExpressionQ]],
    Exponent[g - Coefficient[g, x, n] x^n - Coefficient[g, x, 0], x] <= 0,
      c = (v - Coefficient[g, x, 0])/Coefficient[g, x, n];
      zeta = (-1)^(2/n);
      Table[zeta^e c^(1/n), {e, 0, n - 1}],
    True, $Failed]];

(* 1. functional decomposition p = g1(g2(...gk(x))), peeled from the outside *)
structuralDecompose[a_, p_, depth_] := Module[{comp, vals, rad, cands, sel, k},
  comp = Decompose[p, x];
  If[Length[comp] < 2, Return[$Failed]];
  k = Length[comp];
  (* vals[[i]] = (g_{i+1} o ... o g_k)(a) exactly; vals[[k]] = a *)
  vals = Table[RootReduce[Fold[#2 /. x -> #1 &, a, Reverse[comp[[i + 1 ;; k]]]]], {i, 1, k - 1}];
  AppendTo[vals, a];
  rad = radicalsOf[vals[[1]], depth - 1];
  If[FailureQ[rad] || rad === $Failed, Return[$Failed]];
  Do[
    cands = solveWithRadicalRHS[comp[[i]], rad];
    If[cands === $Failed, Return[$Failed, Module]];
    sel = selectCandidate[cands, vals[[i]]];
    If[sel === $Failed, Return[$Failed, Module]];
    rad = sel,
    {i, 2, k}];
  rad];

(* 2. generalized reciprocal symmetry: p(x) = x^m P(x + a/x), degree 2m *)
rationalRoots[q_, m_] := Module[{num = Numerator[q], den = Denominator[q], r, s},
  r = Abs[num]^(1/m); s = den^(1/m);
  If[! IntegerQ[r] || ! IntegerQ[s], Return[{}]];
  Select[{r/s, -r/s}, #^m == q &]];

reciprocalDecomposition[p_] := Module[{n = Exponent[p, x], m, q, c0, avals, res},
  If[OddQ[n] || n < 4, Return[$Failed]];
  m = n/2; q = monic[p]; c0 = Coefficient[q, x, 0];
  If[c0 == 0, Return[$Failed]];
  avals = rationalRoots[c0, m];
  res = $Failed;
  Do[
    Module[{rem = q, P = 0, cf},
      Do[
        cf = Coefficient[rem, x, m + k];
        P += cf x^k;
        rem = Expand[rem - cf x^m (x + av/x)^k],
        {k, m, 0, -1}];
      If[Expand[rem] === 0, res = {av, P}; Break[]]],
    {av, avals}];
  res];

structuralReciprocal[a_, p_, depth_] := Module[{rd, av, P, y, yrad, cands},
  rd = reciprocalDecomposition[p];
  If[rd === $Failed, Return[$Failed]];
  {av, P} = rd;
  y = RootReduce[a + av/a];                 (* a root of P *)
  yrad = radicalsOf[y, depth - 1];
  If[FailureQ[yrad] || yrad === $Failed, Return[$Failed]];
  cands = {(yrad + Sqrt[yrad^2 - 4 av])/2, (yrad - Sqrt[yrad^2 - 4 av])/2};
  selectCandidate[cands, a]];

(* 3. Dickson polynomials: the centered polynomial is D_n(x, a) - b *)
dickson[n_, av_] := Module[{d0 = 2, d1 = x, d2},
  If[n == 0, Return[2]]; If[n == 1, Return[x]];
  Do[d2 = Expand[x d1 - av d0]; d0 = d1; d1 = d2, {n - 1}]; d1];

structuralDickson[a_, p_, depth_] := Module[{n = Exponent[p, x], q, c, av, b, diff, t, cands, s, zeta},
  If[n < 3, Return[$Failed]];
  q = monic[p];
  c = -Coefficient[q, x, n - 1]/n;
  q = Expand[q /. x -> x + c];
  av = -Coefficient[q, x, n - 2]/n;
  If[av == 0, Return[$Failed]];
  diff = Expand[q - dickson[n, av]];
  If[Exponent[diff, x] > 0, Return[$Failed]];
  b = -diff;                                 (* q = D_n - b *)
  s = (b + Sqrt[b^2 - 4 av^n])/2;
  t = s^(1/n);
  zeta = (-1)^(2/n);
  cands = Table[c + zeta^j t + av/(zeta^j t), {j, 0, n - 1}];
  selectCandidate[cands, a]];

(* 4. pair-sum resolvent: Res_x(p(x), p(y-x)) = 2^n p(y/2) R2(y)^2 where the roots of R2 are a_i + a_j (i<j).
   A root y0 of a low-degree factor of R2 generates a field over which p may have a factor of
   degree <= 4 containing a. *)
pairSumPolynomial[p_] := Module[{n = Exponent[p, x], res, fl, r2 = 1},
  res = Resultant[p, p /. x -> y - x, x];
  res = Cancel[res/(2^n (p /. x -> y/2))];
  fl = FactorList[res];
  Do[
    If[Exponent[f[[1]], y] > 0,
      If[OddQ[f[[2]]], Return[$Failed, Module]];
      r2 = r2 f[[1]]^(f[[2]]/2)],
    {f, fl}];
  r2 /. y -> x];

structuralPairSum[a_, p_, depth_] := Module[{n = Exponent[p, x], r2, facs, cands, na, nroots, y0, ny, fac, yrad, sel, m},
  If[n < 4 || n > 12, Return[$Failed]];
  r2 = pairSumPolynomial[p];
  If[r2 === $Failed, Return[$Failed]];
  facs = Select[First /@ FactorList[r2], 2 <= Exponent[#, x] <= Min[6, n - 1] &];
  facs = SortBy[facs, Exponent[#, x] &];
  na = N[a, 40]; nroots = Table[N[rootObject[p, j], 40], {j, n}];
  Do[
    m = Exponent[g, x];
    Do[
      y0 = rootObject[g, j];
      ny = N[y0, 40];
      If[Min[Abs[ny - na - nroots]] > 10^-15, Continue[]];
      (* y0 = a + a' for a conjugate a': factor p over Q(y0) *)
      fac = SelectFirst[First /@ FactorList[p, Extension -> y0], vanishesAtQ[#, a] &, $Failed];
      If[fac === $Failed || Exponent[fac, x] > 4, Continue[]];
      yrad = radicalsOf[y0, depth - 1];
      If[FailureQ[yrad] || yrad === $Failed, Continue[]];
      cands = solveWithRadicalRHS[Expand[fac /. y0 -> yrad], 0];
      If[cands === $Failed, Continue[]];
      sel = selectCandidate[cands, a];
      If[sel =!= $Failed, Return[sel, Module]],
      {j, m}],
    {g, facs}];
  $Failed];

(* 0. user-supplied subfield generators ("Extension" option): factor p over Q(gens); if the factor
   containing a has degree <= 4 (or is a binomial), solve it after replacing each non-radical generator
   by its own radical expression.  This is the pair-sum reduction with the generators given instead of
   searched for, and it is what the notebook of the question does by hand. *)
$extension = None;

(* does the polynomial fac (exact algebraic coefficients, possibly of height 10^100) vanish at a?
   The evaluation is done at a precision that exceeds the cancellation between the terms, and the
   residual is compared with the scale of the terms. *)
vanishesAtQ[fac_, a_] := Module[{n = Exponent[fac, x], cl, mags, prec, na, terms, scale, val},
  If[n < 1, Return[False]];
  cl = CoefficientList[fac, x];
  mags = Abs[N[cl, 20]];
  prec = 60 + Max[0, Ceiling[Log10[Max[Append[mags, 1]]]]];
  na = N[a, prec];
  terms = Table[N[cl[[k + 1]], prec] na^k, {k, 0, n}];
  scale = Max[Abs[terms]];
  val = Abs[Total[terms]];
  TrueQ[val < 10^-25 scale]];

structuralExtension[a_, p_, depth_] := Module[{gens, facs, fac, rules, rads, facRad, cands},
  If[$extension === None, Return[$Failed]];
  gens = Flatten[{$extension}];
  (* factor cumulatively, one generator at a time: the factor containing a over a larger field divides
     the one over the smaller field, and factoring a small polynomial over a large field is much cheaper
     than factoring p over it *)
  fac = p;
  Do[
    facs = First /@ Quiet[FactorList[fac, Extension -> gens[[1 ;; i]]]];
    fac = SelectFirst[facs, vanishesAtQ[#, a] &, $Failed];
    If[fac === $Failed, Return[$Failed, Module]],
    {i, Length[gens]}];
  If[Exponent[fac, x] > 4 && Exponent[fac - Coefficient[fac, x, Exponent[fac, x]] x^Exponent[fac, x] - Coefficient[fac, x, 0], x] > 0,
    Return[$Failed]];
  rads = Table[If[RadicalExpressionQ[g], g, Block[{$extension = None}, radicalsOf[g, depth - 1]]], {g, gens}];
  If[AnyTrue[rads, FailureQ[#] || # === $Failed &], Return[$Failed]];
  rules = DeleteCases[Thread[gens -> rads], HoldPattern[g_ -> g_]];
  (* solve with the generators kept as atoms (their radical expressions substituted into
     high-degree polynomial coefficients and expanded would blow up), select the branch
     numerically, and substitute once at the end without expansion *)
  cands = solveWithRadicalRHS[fac, 0];
  If[cands === $Failed, Return[$Failed]];
  facRad = selectCandidate[cands, a];
  If[facRad === $Failed, Return[$Failed]];
  facRad = facRad /. rules;
  If[RadicalExpressionQ[facRad], facRad, $Failed]];

structuralMethods = {
  {"Extension", structuralExtension},
  {"ToRadicals", Function[{a, p, depth}, Module[{r}, r = Quiet[TimeConstrained[ToRadicals[a], 5, $Failed]];
      If[r =!= $Failed && RadicalExpressionQ[r], r, $Failed]]]},
  {"Decompose", structuralDecompose},
  {"Reciprocal", structuralReciprocal},
  {"Dickson", structuralDickson},
  {"PairSum", structuralPairSum}};

(* the structural driver: a radical expression equal to a, or $Failed *)
structural[a_, p_, depth_] := Module[{r},
  If[depth <= 0, Return[$Failed]];
  Do[
    r = m[[2]][a, p, depth];
    If[r =!= $Failed && ! FailureQ[r] && RadicalExpressionQ[r], $methodUsed = m[[1]]; Return[r, Module]],
    {m, structuralMethods}];
  $Failed];

(* ------------------------------------------------------------------ *)
(* Group theory on the multiplication table                            *)
(* ------------------------------------------------------------------ *)

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
    If[nxt === cur, Return[False, Module]];
    cur = nxt];
  True];

(* composition series with prime quotients, from H down to 1: a normal subgroup of prime index
   containing the commutator subgroup at each step *)
primeSeries[mt_, idElem_, H0_] := Module[{H = Sort[H0], steps = {}, D, N, p, sigma},
  While[Length[H] > 1,
    D = commutatorSubgroup[mt, idElem, H];
    If[D === H, Return[$Failed, Module]];
    N = D;
    Do[If[! MemberQ[N, g],
        With[{J = groupClosure[mt, idElem, Append[N, g]]}, If[Length[J] < Length[H], N = J]]],
      {g, H}];
    p = Length[H]/Length[N];
    If[! PrimeQ[p], Return[$Failed, Module]];
    sigma = First[Complement[H, N]];
    AppendTo[steps, <|"Group" -> H, "Normal" -> N, "Generator" -> sigma, "Prime" -> p|>];
    H = N];
  steps];

fixedByQ[gd_, v_, elems_] := AllTrue[elems, gd["Automorphisms"][[#]] . v == v &];

(* ------------------------------------------------------------------ *)
(* General Galois-Kummer descent                                       *)
(* ------------------------------------------------------------------ *)

mapEngineFailure[f_Failure] := If[f[[1]] === "GroupOrder",
  failure["ResourceLimit", "The Galois group is larger than \"MaxGroupOrder\"", f[[2]]], f];

(* the descent proper, for Galois data gd of p(x) Prod Phi_q(x); may throw "precision" *)
descend[gd_, a_, primes_, resolventForm_] := Module[
  {ord = gd["Order"], c, target, va, mt, idElem, zetaIdx, zetaCoord, zetaMult, H, steps, baseSymbols, baseBasis, memo, rad, radCompute, branch},
  c = gd["Scale"];
  target = locateTarget[gd, a];
  If[target === $Failed, Return[failure["RootIndex", "Could not locate the input among the roots"]]];
  va = gd["RootCoordinates"][[target]]/c;
  mt = gd["MultiplicationTable"]; idElem = gd["Identity"];
  (* roots of unity zeta_q = Exp[2 Pi I/q] among the roots; the engine scales all roots by c *)
  zetaIdx = Association @@ Table[
    q -> First[FirstPosition[gd["Roots"], _?(exactZeroQ[# - c Exp[2 Pi I/q]] &)]], {q, primes}];
  zetaCoord = Association @@ Table[q -> gd["RootCoordinates"][[zetaIdx[q]]]/c, {q, primes}];
  zetaMult = Association @@ Table[q -> multiplicationMatrixOfElement[gd, zetaCoord[q]], {q, primes}];
  H = Select[Range[ord], Function[s, AllTrue[Values[zetaIdx], gd["Permutations"][[s, #]] == # &]]];
  steps = primeSeries[mt, idElem, H];
  If[steps === $Failed, Return[failure["NotSolvable", "Could not build a prime composition series"]]];
  baseSymbols = Table[(-1)^(2/q), {q, primes}];
  baseBasis = Module[{exps = Tuples[Range[0, # - 2] & /@ primes]},
    Table[{Times @@ MapThread[#1^#2 &, {baseSymbols, e}],
           Fold[#2 . #1 &, UnitVector[ord, 1], MapThread[MatrixPower[zetaMult[#1], #2] &, {primes, e}]]}, {e, exps}]];
  memo = <||>;
  rad[v_, level_] := Module[{key = {v, level}, res},
    If[KeyExistsQ[memo, key], Return[memo[key]]];
    res = radCompute[v, level];
    memo[key] = res; res];
  (* level 0: the element lies in Q(zeta_m); write it in the monomial basis *)
  radCompute[v_, 0] := Module[{B, sol},
    B = Transpose[baseBasis[[All, 2]]];
    sol = Quiet[Check[LinearSolve[B, v], $Failed]];
    If[sol === $Failed, Throw[failure["Descent", "Element not in the base cyclotomic field"], radTag]];
    Expand[sol . baseBasis[[All, 1]]]];
  (* branch[Rk, q, z, level]: the q-th root of Rk^q (one level down) with the branch equal to Rk *)
  branch[Rk_, q_, z_, level_] := Module[{Qk, qrad, numR, cands, sel},
    Qk = MatrixPower[multiplicationMatrixOfElement[gd, Rk], q - 1] . Rk;
    qrad = rad[Qk, level - 1];
    numR = conjugates[gd, Rk][[idElem]];
    cands = Table[z^e qrad^(1/q), {e, 0, q - 1}];
    sel = selectCandidate[cands, numR];
    If[sel === $Failed, Throw[failure["Branch", "Could not identify the radical branch"], radTag]];
    sel];
  (* one prime step: v is fixed by steps[[level]]["Normal"]; extract q-th roots of Lagrange resolvents *)
  radCompute[v_, level_] := Module[{st = steps[[level]], M, sigma, q, autS, z, zm, sv, zpows, R, R0rad, fourier, eigen, k1, u, m, ck, choices},
    If[v == 0 v, Return[0, Module]];
    M = st["Group"]; sigma = st["Generator"]; q = st["Prime"];
    If[fixedByQ[gd, v, M], Return[rad[v, level - 1], Module]];
    autS = gd["Automorphisms"][[sigma]];
    zm = If[q == 2, -IdentityMatrix[ord], zetaMult[q]];
    z = If[q == 2, -1, (-1)^(2/q)];
    sv = NestList[autS . # &, v, q - 1];                       (* sigma^j(v) *)
    zpows = NestList[zm . # &, IdentityMatrix[ord], q - 1];    (* zeta^j *)
    R = Table[Sum[zpows[[Mod[-k j, q] + 1]] . sv[[j + 1]], {j, 0, q - 1}], {k, 0, q - 1}];   (* R[[k+1]] = R_k *)
    R0rad = rad[R[[1]], level - 1];
    choices = {};
    If[resolventForm =!= "Eigenvector" || q == 2,
      fourier = (R0rad + Sum[If[R[[k + 1]] == 0 R[[k + 1]], 0, branch[R[[k + 1]], q, z, level]], {k, 1, q - 1}])/q;
      AppendTo[choices, fourier]];
    If[resolventForm =!= "Fourier" && q > 2,
      k1 = SelectFirst[Range[1, q - 1], R[[# + 1]] != 0 R[[# + 1]] &];
      u = branch[R[[k1 + 1]], q, z, level];
      eigen = R0rad + u;
      Do[
        If[k == k1 || R[[k + 1]] == 0 R[[k + 1]], Continue[]];
        m = Mod[k PowerMod[k1, -1, q], q];
        (* c_k = R_k / R_k1^m is fixed by M *)
        ck = LinearSolve[MatrixPower[multiplicationMatrixOfElement[gd, R[[k1 + 1]]], m], R[[k + 1]]];
        If[! fixedByQ[gd, ck, M], Throw[failure["Descent", "Eigenvector ratio is not in the lower field"], radTag]];
        eigen += rad[ck, level - 1] u^m,
        {k, 1, q - 1}];
      AppendTo[choices, eigen/q]];
    First[SortBy[choices, LeafCount]]];
  <|"Expression" -> Catch[rad[va, Length[steps]], radTag], "ExtendedGroupOrder" -> ord,
    "SeriesPrimes" -> steps[[All, "Prime"]]|>];

galoisRadicals[a_, p_, opts_] := Module[{n = Exponent[p, x], gd0, order, primes, poly, gd, prec, maxOrder, res, attempt, form},
  maxOrder = OptionValue[RootToRadicals, opts, "MaxGroupOrder"];
  prec = OptionValue[RootToRadicals, opts, "WorkingPrecision"];
  form = OptionValue[RootToRadicals, opts, "Resolvents"];
  With[{mult = frobeniusOrderMultiple[p]},
    If[mult > maxOrder,
      Return[failure["ResourceLimit", "A divisor of the Galois group order exceeds \"MaxGroupOrder\"",
        <|"GroupOrderMultiple" -> mult, "Limit" -> maxOrder|>]]]];
  gd0 = RootGaloisData[p, x, "MaxGroupOrder" -> maxOrder, "WorkingPrecision" -> prec];
  If[FailureQ[gd0], Return[mapEngineFailure[gd0]]];
  order = gd0["Order"];
  $galoisInfo = <|"GaloisGroupOrder" -> order|>;
  If[! solvableQ[gd0["MultiplicationTable"], gd0["Identity"], Range[order]],
    Message[RootToRadicals::notsolv, "order " <> ToString[order]];
    Return[failure["NotSolvable", "The Galois group is not solvable", <|"GaloisGroupOrder" -> order|>]]];
  primes = Select[First /@ FactorInteger[order], OddQ];
  (* adjoin the roots of unity; a cyclotomic factor equal to p itself is already present *)
  poly = Expand[p Times @@ Select[Cyclotomic[#, x] & /@ primes, PolynomialGCD[#, p] === 1 &]];
  attempt = 0;
  While[True,
    attempt++;
    gd = If[primes === {}, gd0,
      RootGaloisData[poly, x, "MaxGroupOrder" -> maxOrder Times @@ (# - 1 & /@ primes), "WorkingPrecision" -> prec]];
    If[FailureQ[gd], Return[mapEngineFailure[gd]]];
    res = Catch[descend[gd, a, primes, form], precTag];
    If[res === "precision",
      If[attempt >= 3, Return[failure["Precision", "Precision escalation failed in the descent"]]];
      prec = 2 prec; Continue[]];
    Break[]];
  If[FailureQ[res], Return[res]];
  If[FailureQ[res["Expression"]], Return[res["Expression"]]];
  $galoisInfo = Join[$galoisInfo, <|"ExtendedGroupOrder" -> res["ExtendedGroupOrder"], "SeriesPrimes" -> res["SeriesPrimes"], "Primes" -> primes|>];
  res["Expression"]];

(* ------------------------------------------------------------------ *)
(* Driver                                                              *)
(* ------------------------------------------------------------------ *)

Options[RootToRadicals] = {
  Method -> Automatic,            (* Automatic, "Structural", "Galois" *)
  "Resolvents" -> Automatic,      (* Automatic (shorter of the two), "Fourier", "Eigenvector" *)
  "MaxGroupOrder" -> 400,
  "WorkingPrecision" -> 80,
  "VerificationTimeLimit" -> 60,
  "MaxDepth" -> 6,
  "Extension" -> None          (* exact algebraic numbers generating a subfield over which p is factored first *)
};
Options[RootRadicalReport] = Options[RootToRadicals];

(* recursive core: a radical expression, or a Failure *)
radicalsOf[a_, depth_] := Module[{in, p, n, r},
  If[rationalQ[a], Return[a]];
  If[RadicalExpressionQ[a], Return[a]];
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  p = in["Polynomial"]; n = in["Degree"];
  If[n == 1, Return[in["Value"]]];
  If[$method =!= "Galois",
    r = structural[a, p, depth];
    If[r =!= $Failed && ! FailureQ[r], Return[r]]];
  If[$method === "Structural", Return[failure["NotFound", "No structural radical form was found"]]];
  If[frobeniusNonsolvableQ[p],
    Message[RootToRadicals::notsolv, Which[PrimeQ[n], "Frobenius cycle type outside AGL(1," <> ToString[n] <> ")",
      PrimePowerQ[n], "Frobenius element with a long prime cycle that no affine group of degree " <> ToString[n] <> " contains",
      True, "Frobenius element with a long prime cycle in a non-prime-power degree"]];
    $galoisInfo = <|"Method" -> "Frobenius"|>;
    Return[failure["NotSolvable", "The Galois group is not solvable (Frobenius cycle types)"]]];
  r = galoisRadicals[a, p, $opts];
  If[! FailureQ[r], $methodUsed = "Galois"];
  r];

validOptionsQ[opts_] := MemberQ[{Automatic, "Structural", "Galois"}, OptionValue[RootToRadicals, opts, Method]] &&
  MemberQ[{Automatic, "Fourier", "Eigenvector"}, OptionValue[RootToRadicals, opts, "Resolvents"]] &&
  IntegerQ[OptionValue[RootToRadicals, opts, "MaxGroupOrder"]] && OptionValue[RootToRadicals, opts, "MaxGroupOrder"] > 0 &&
  IntegerQ[OptionValue[RootToRadicals, opts, "WorkingPrecision"]] && OptionValue[RootToRadicals, opts, "WorkingPrecision"] >= 30 &&
  IntegerQ[OptionValue[RootToRadicals, opts, "MaxDepth"]] && OptionValue[RootToRadicals, opts, "MaxDepth"] > 0 &&
  (OptionValue[RootToRadicals, opts, "Extension"] === None ||
    AllTrue[Flatten[{OptionValue[RootToRadicals, opts, "Extension"]}], FreeQ[#, _Real] && minimalPolynomialOf[#] =!= $Failed &]);

RootRadicalReport[a_, opts : OptionsPattern[]] := Module[{t0 = AbsoluteTime[], in, r, expr, ver},
  If[! validOptionsQ[Flatten[{opts}]], Message[RootToRadicals::opts, Flatten[{opts}]]; Return[failure["InvalidOptions", "Invalid options"]]];
  If[! FreeQ[a, _Real], Message[RootToRadicals::inexact, a]; Return[failure["Inexact", "Inexact input"]]];
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  Block[{$method = OptionValue[Method], $opts = Flatten[{opts}], $methodUsed = None, $galoisInfo = <||>,
         $prec = Max[60, OptionValue["WorkingPrecision"]], $extension = OptionValue["Extension"]},
    r = radicalsOf[a, OptionValue["MaxDepth"]];
    If[FailureQ[r], Return[Failure[r[[1]], Join[r[[2]], $galoisInfo, <|"Degree" -> in["Degree"], "Time" -> AbsoluteTime[] - t0|>]], Module]];
    expr = r;
    ver = verifyExact[expr, a, OptionValue["VerificationTimeLimit"]];
    If[ver =!= True, Message[RootToRadicals::verify, ver]];
    Join[<|"Expression" -> expr, "Verified" -> ver, "Method" -> $methodUsed, "Degree" -> in["Degree"],
      "RadicalDepth" -> RadicalDepth[expr], "LeafCount" -> LeafCount[expr]|>, $galoisInfo,
      <|"Time" -> AbsoluteTime[] - t0|>]]];

RootToRadicals[a_, opts : OptionsPattern[]] := Module[{r = RootRadicalReport[a, opts]},
  If[FailureQ[r], r,
    If[r["Verified"] === False, failure["VerificationFailed", "The candidate expression is not equal to the input"], r["Expression"]]]];

RootSolvableQ[a_, opts : OptionsPattern[RootToRadicals]] := Module[{in, gd},
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  If[in["Degree"] <= 4, Return[True]];
  If[frobeniusNonsolvableQ[in["Polynomial"]], Return[False]];
  With[{mult = frobeniusOrderMultiple[in["Polynomial"]]},
    If[mult > OptionValue["MaxGroupOrder"],
      Return[failure["ResourceLimit", "A divisor of the Galois group order exceeds \"MaxGroupOrder\"",
        <|"GroupOrderMultiple" -> mult, "Limit" -> OptionValue["MaxGroupOrder"]|>]]]];
  gd = RootGaloisData[in["Polynomial"], x, "MaxGroupOrder" -> OptionValue["MaxGroupOrder"], "WorkingPrecision" -> OptionValue["WorkingPrecision"]];
  If[FailureQ[gd], Return[mapEngineFailure[gd]]];
  solvableQ[gd["MultiplicationTable"], gd["Identity"], Range[gd["Order"]]]];

End[];
EndPackage[];
