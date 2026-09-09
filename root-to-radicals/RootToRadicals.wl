(* ::Package:: *)

(* RootToRadicals.wl

   Expressing algebraic numbers (Root objects) by radicals whenever this is
   possible, i.e. whenever the Galois group of the minimal polynomial is
   solvable.  Answers Mathematica StackExchange question 34011.

   Two layers:

   * Structural recognizers (cheap, short formulas): user-supplied subfield
     generators ("Extension" option); built-in ToRadicals; functional
     decomposition p = g1(g2(...(x))) (Decompose); generalized reciprocal
     symmetry p(x) = x^m P(x + a/x); Dickson polynomials D_n(x,a) - b; and the
     pair-sum resolvent (roots a_i + a_j of low degree generate a subfield over
     which p has a factor of degree <= 4), which is the systematic form of the
     search in the notebook of the question.  Recursion on the pieces.

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

   Nonsolvability is proved by Frobenius cycle types (prime degree: cycle
   types outside AGL(1,n); other degrees: a single prime cycle longer than
   n/2, which forces primitivity, excluded for solvable groups unless the
   degree is a prime power and the cycle has length n-1) or by the exact
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
multiplicationMatrixOfElement = RootDecomposition`Private`multiplicationMatrixOfElement;
powerCoordinates = RootDecomposition`Private`powerCoordinates;
powerDivider = RootDecomposition`Private`powerDivider;
rationalQ = RootDecomposition`Private`rationalQ;
precTag = RootDecomposition`Private`precTag;
frobeniusExponentMultiple = RootDecomposition`Private`frobeniusExponentMultiple;
frobeniusCycleType = RootDecomposition`Private`frobeniusCycleType;
groupClosure = RootDecomposition`Private`groupClosure;

okQ[r_] := r =!= $Failed && ! FailureQ[r];      (* a usable result of a recursive step *)

(* ------------------------------------------------------------------ *)
(* Radical grammar                                                     *)
(* ------------------------------------------------------------------ *)

RadicalExpressionQ[e_] := Which[
  rationalQ[e] || e === I, True,
  Head[e] === Complex, rationalQ[Re[e]] && rationalQ[Im[e]],
  Head[e] === Plus || Head[e] === Times, AllTrue[List @@ e, RadicalExpressionQ],
  Head[e] === Power, rationalQ[e[[2]]] && RadicalExpressionQ[e[[1]]],
  True, False];

RadicalDepth[e_] := Which[
  Head[e] === Power, RadicalDepth[e[[1]]] + If[IntegerQ[e[[2]]], 0, 1],
  Head[e] === Plus || Head[e] === Times, Max[RadicalDepth /@ List @@ e],
  True, 0];

(* ------------------------------------------------------------------ *)
(* Numerics and verification                                           *)
(* ------------------------------------------------------------------ *)

$prec = 60;

(* the candidate closest to the target value, if it is clearly separated from the others *)
selectCandidate[cands_List, target_] := Module[{d, ord},
  If[cands === {}, Return[$Failed]];
  d = Abs[N[cands, $prec] - N[target, $prec]];
  ord = Ordering[d];
  If[d[[ord[[1]]]] < 10^-20 && (Length[d] == 1 || d[[ord[[2]]]] > 10^-15), cands[[ord[[1]]]], $Failed]];

(* exact verification with a time limit; True, False or Indeterminate (numerically equal, not proved) *)
verifyExact[expr_, a_, limit_] := Module[{r = TimeConstrained[exactZeroQ[expr - a], limit, Indeterminate]},
  If[r === Indeterminate && ! (Abs[N[expr - a, 200]] < 10^-150), False, r]];

(* does the polynomial fac (exact algebraic coefficients, possibly of height 10^100) vanish at a?  The
   evaluation precision exceeds the cancellation between the terms, and the residual is compared with
   the largest term. *)
vanishesAtQ[fac_, a_] := Module[{n = Exponent[fac, x], cl, prec, na, terms},
  If[n < 1, Return[False]];
  cl = CoefficientList[fac, x];
  prec = 60 + Max[0, Ceiling[Log10[Max[Append[Abs[N[cl, 20]], 1]]]]];
  na = N[a, prec];
  terms = N[cl, prec] na^Range[0, n];
  TrueQ[Abs[Total[terms]] < 10^-25 Max[Abs[terms]]]];

(* ------------------------------------------------------------------ *)
(* Frobenius negative tests                                            *)
(* ------------------------------------------------------------------ *)

(* prime degree n: a solvable transitive group lies in AGL(1,n), whose cycle types are 1^n, n, 1 d^((n-1)/d) *)
agl1TypeQ[degs_, n_] := degs === {n} || degs === ConstantArray[1, n] ||
  (First[degs] == 1 && Length[Union[Rest[degs]]] == 1);

(* a single prime cycle of length l > n/2 (the rest fixed) makes a transitive group primitive; a
   solvable primitive group has prime-power degree n = p^k and lies in AGL(k,p), where an element
   fixing a point is conjugate into GL(k,p) and its fixed points form a subspace of size p^j, so
   p^k - p^j = l forces l = n - 1.  Hence such a cycle proves nonsolvability unless n is a prime
   power and l = n - 1. *)
singlePrimeCycleQ[degs_, n_] := Module[{l = Last[degs]},
  PrimeQ[l] && 2 l > n && Union[Most[degs]] === {1} && ! (PrimePowerQ[n] && l == n - 1)];

(* True: proved nonsolvable.  False: no obstruction found (inconclusive). *)
frobeniusNonsolvableQ[poly_, maxPrimes_: 60] := Module[{n = Exponent[poly, x], bad, p = 2, count = 0},
  bad = If[PrimeQ[n], ! agl1TypeQ[#, n] &, singlePrimeCycleQ[#, n] &];
  With[{d = Discriminant[poly, x] Coefficient[poly, x, n]},
    While[count < maxPrimes,
      p = NextPrime[p];
      If[Mod[d, p] == 0, Continue[]];
      count++;
      If[bad[frobeniusCycleType[poly, p]], Return[True, Module]]]];
  False];

frobeniusReason[n_] := Which[
  PrimeQ[n], "Frobenius cycle type outside AGL(1," <> ToString[n] <> ")",
  PrimePowerQ[n], "Frobenius element with a long prime cycle that no affine group of degree " <> ToString[n] <> " contains",
  True, "Frobenius element with a long prime cycle in a non-prime-power degree"];

(* the lcm of the orders of the Frobenius elements divides |G|; beyond the limit the resource status
   is settled without building the splitting field.  Returns None or a Failure. *)
orderLimitFailure[poly_, maxOrder_] := With[{mult = frobeniusExponentMultiple[poly, 40]},
  If[mult > maxOrder,
    failure["ResourceLimit", "A divisor of the Galois group order exceeds \"MaxGroupOrder\"",
      <|"GroupOrderMultiple" -> mult, "Limit" -> maxOrder|>],
    None]];

(* the engine's Galois data, with its resource failure renamed *)
galoisData[poly_, maxOrder_, prec_] := With[{gd = RootGaloisData[poly, x, "MaxGroupOrder" -> maxOrder, "WorkingPrecision" -> prec]},
  If[FailureQ[gd] && gd[[1]] === "GroupOrder",
    failure["ResourceLimit", "The Galois group is larger than \"MaxGroupOrder\"", gd[[2]]], gd]];

(* ------------------------------------------------------------------ *)
(* Structural layer                                                    *)
(* ------------------------------------------------------------------ *)

$method = Automatic; $opts = {}; $methodUsed = None; $galoisInfo = <||>; $extension = None;

monic[p_] := Expand[p/Coefficient[p, x, Exponent[p, x]]];
binomialQ[g_] := Exponent[g - Coefficient[g, x, Exponent[g, x]] x^Exponent[g, x] - Coefficient[g, x, 0], x] <= 0;
formulaSolvableQ[g_] := Exponent[g, x] <= 4 || binomialQ[g];

(* the radical expression of an exact algebraic number, or $Failed *)
sub[a_, depth_] := With[{r = radicalsOf[a, depth]}, If[okQ[r], r, $Failed]];

(* explicit formulas for degrees 2 and 3 (Solve can spend a long time simplifying large radical
   coefficients); the coefficient list is low to high *)
rootOrbit[root_, n_] := root (-1)^(2 Range[0, n - 1]/n);
quadraticRoots[{c0_, c1_, c2_}] := (-c1 + {1, -1} Sqrt[c1^2 - 4 c2 c0])/(2 c2);

cubicRoots[{d0_, c0_, b0_, a0_}] := Module[{b = b0/a0, c = c0/a0, d = d0/a0, pp, qq, branches},
  pp = c - b^2/3; qq = 2 b^3/27 - b c/3 + d;
  If[pp === 0, Return[rootOrbit[(-qq)^(1/3), 3] - b/3]];
  branches = rootOrbit[(-qq/2 + Sqrt[qq^2/4 + pp^3/27])^(1/3), 3];
  branches - pp/(3 branches) - b/3];

(* all radical solutions of g(x) = v for a polynomial g whose coefficients may be radicals or
   algebraic atoms: degree <= 4 by formulas or Solve, binomials x^n + c by n-th roots; else $Failed *)
solveWithRadicalRHS[g_, v_] := Module[{n = Exponent[g, x], cl = CoefficientList[Expand[g - v], x], sols},
  Which[
    n == 1, {-cl[[1]]/cl[[2]]},
    n == 2, quadraticRoots[cl],
    n == 3 && cl[[1]] =!= 0, cubicRoots[cl],
    n <= 4, sols = Quiet[x /. Solve[g == v, x, Cubics -> True, Quartics -> True]];
      If[ListQ[sols], Select[sols, RadicalExpressionQ], $Failed],
    binomialQ[g], rootOrbit[(-cl[[1]]/cl[[-1]])^(1/n), n],
    True, $Failed]];

(* solve g(x) = v and pick the solution equal to the exact number target *)
solveAndSelect[g_, v_, target_] := With[{cands = solveWithRadicalRHS[g, v]},
  If[cands === $Failed, $Failed, selectCandidate[cands, target]]];

factorAt[p_, a_, extension_] :=
  SelectFirst[First /@ Quiet[FactorList[p, Extension -> extension]], vanishesAtQ[#, a] &, $Failed];

(* 0. user-supplied subfield generators ("Extension" option): factor p over Q(gens) cumulatively (the
   factor containing a over a larger field divides the one over a smaller field, and factoring a small
   polynomial over a large field is much cheaper than factoring p over it); solve the factor containing
   a with the generators kept as atoms (substituting their radical expressions into high-degree
   coefficients and expanding would blow up), select the branch numerically, and substitute once at the
   end.  This is the pair-sum reduction with the generators given instead of searched for, and it is
   what the notebook of the question does by hand. *)
structuralExtension[a_, p_, depth_] := Module[{gens, fac = p, rads, sel},
  If[$extension === None, Return[$Failed]];
  gens = Flatten[{$extension}];
  Do[
    fac = factorAt[fac, a, gens[[;; i]]];
    If[fac === $Failed, Return[$Failed, Module]],
    {i, Length[gens]}];
  If[! formulaSolvableQ[fac], Return[$Failed]];
  rads = Table[If[RadicalExpressionQ[g], g, Block[{$extension = None}, sub[g, depth - 1]]], {g, gens}];
  If[MemberQ[rads, $Failed], Return[$Failed]];
  sel = solveAndSelect[fac, 0, a];
  If[sel === $Failed, Return[$Failed]];
  sel = sel /. Thread[gens -> rads];
  If[RadicalExpressionQ[sel], sel, $Failed]];

(* 1. functional decomposition p = g1(g2(...gk(x))), peeled from the outside: v_i = (g_{i+1} o ... o g_k)(a)
   is a root of g_i(x) - v_{i-1} *)
structuralDecompose[a_, p_, depth_] := Module[{comp = Decompose[p, x], k, vals, rad},
  k = Length[comp];
  If[k < 2, Return[$Failed]];
  vals = Reverse[FoldList[RootReduce[#2 /. x -> #1] &, a, Reverse[Rest[comp]]]];
  rad = sub[vals[[1]], depth - 1];
  Do[
    If[rad === $Failed, Return[$Failed, Module]];
    rad = solveAndSelect[comp[[i]], rad, vals[[i]]],
    {i, 2, k}];
  rad];

(* 2. generalized reciprocal symmetry: p(x) = x^m P(x + c/x), degree 2m; c^m is the constant term *)
rationalRoots[q_, m_] := With[{r = Abs[Numerator[q]]^(1/m), s = Denominator[q]^(1/m)},
  If[IntegerQ[r] && IntegerQ[s], Select[{r/s, -r/s}, #^m == q &], {}]];

reciprocalDecomposition[p_] := Module[{n = Exponent[p, x], m, q, rem, P},
  If[OddQ[n] || n < 4, Return[$Failed]];
  m = n/2; q = monic[p];
  Do[
    rem = q; P = 0;
    Do[With[{cf = Coefficient[rem, x, m + k]}, P += cf x^k; rem = Expand[rem - cf x^m (x + c/x)^k]], {k, m, 0, -1}];
    If[rem === 0, Return[{c, P}, Module]],
    {c, rationalRoots[Coefficient[q, x, 0], m]}];
  $Failed];

structuralReciprocal[a_, p_, depth_] := Module[{rd = reciprocalDecomposition[p], c, yrad},
  If[rd === $Failed, Return[$Failed]];
  c = rd[[1]];
  yrad = sub[RootReduce[a + c/a], depth - 1];        (* a + c/a is a root of P *)
  If[yrad === $Failed, $Failed, selectCandidate[quadraticRoots[{c, -yrad, 1}], a]]];

(* 3. Dickson polynomials: the centered polynomial is D_n(x, c) - b, and the roots are zeta^j u + c/(zeta^j u)
   with u^n a root of s^2 - b s + c^n *)
dickson[0, _] = 2; dickson[1, _] = x;
dickson[n_, c_] := dickson[n, c] = Expand[x dickson[n - 1, c] - c dickson[n - 2, c]];

structuralDickson[a_, p_, depth_] := Module[{n = Exponent[p, x], q = monic[p], t, c, b, diff, u},
  If[n < 3, Return[$Failed]];
  t = -Coefficient[q, x, n - 1]/n;
  q = Expand[q /. x -> x + t];
  c = -Coefficient[q, x, n - 2]/n;
  diff = Expand[q - dickson[n, c]];
  If[c == 0 || Exponent[diff, x] > 0, Return[$Failed]];
  b = -diff;
  u = ((b + Sqrt[b^2 - 4 c^n])/2)^(1/n);
  selectCandidate[t + # + c/# & /@ rootOrbit[u, n], a]];

(* 4. pair-sum resolvent: Res_x(p(x), p(y-x)) = 2^n p(y/2) R2(y)^2 where the roots of R2 are a_i + a_j (i<j).
   A root y0 of a low-degree factor of R2 generates a field over which p may have a factor of
   degree <= 4 containing a. *)
pairSumPolynomial[p_] := Module[{fl, r2 = 1},
  fl = FactorList[Cancel[Resultant[p, p /. x -> y - x, x]/(2^Exponent[p, x] (p /. x -> y/2))]];
  Do[If[Exponent[f[[1]], y] > 0, If[OddQ[f[[2]]], Return[$Failed, Module]]; r2 *= f[[1]]^(f[[2]]/2)], {f, fl}];
  r2 /. y -> x];

structuralPairSum[a_, p_, depth_] := Module[{n = Exponent[p, x], r2, facs, na, nroots, y0, fac, yrad, sel},
  If[n < 4 || n > 12, Return[$Failed]];
  r2 = pairSumPolynomial[p];
  If[r2 === $Failed, Return[$Failed]];
  facs = SortBy[Select[First /@ FactorList[r2], 2 <= Exponent[#, x] <= Min[6, n - 1] &], Exponent[#, x] &];
  na = N[a, 40]; nroots = Table[N[rootObject[p, j], 40], {j, n}];
  Do[
    y0 = rootObject[g, j];
    If[Min[Abs[N[y0, 40] - na - nroots]] > 10^-15, Continue[]];   (* y0 = a + a' for a conjugate a' *)
    fac = factorAt[p, a, y0];
    If[fac === $Failed || Exponent[fac, x] > 4, Continue[]];
    yrad = sub[y0, depth - 1];
    If[yrad === $Failed, Continue[]];
    sel = solveAndSelect[Expand[fac /. y0 -> yrad], 0, a];
    If[sel =!= $Failed, Return[sel, Module]],
    {g, facs}, {j, Exponent[g, x]}];
  $Failed];

structuralMethods = {
  {"Extension", structuralExtension},
  {"ToRadicals", Function[{a, p, depth}, With[{r = Quiet[TimeConstrained[ToRadicals[a], 5, $Failed]]},
      If[RadicalExpressionQ[r], r, $Failed]]]},
  {"Decompose", structuralDecompose},
  {"Reciprocal", structuralReciprocal},
  {"Dickson", structuralDickson},
  {"PairSum", structuralPairSum}};

(* the structural driver: a radical expression equal to a, or $Failed *)
structural[a_, p_, depth_] := Module[{r},
  If[depth <= 0, Return[$Failed]];
  Do[
    r = m[[2]][a, p, depth];
    If[okQ[r] && RadicalExpressionQ[r], $methodUsed = m[[1]]; Return[r, Module]],
    {m, structuralMethods}];
  $Failed];

(* ------------------------------------------------------------------ *)
(* Group theory on the multiplication table                            *)
(* ------------------------------------------------------------------ *)

commutatorSubgroup[mt_, idElem_, H_] := Module[{inv = Association @@ Table[g -> First[FirstPosition[mt[[g]], idElem]], {g, H}]},
  groupClosure[mt, idElem, DeleteDuplicates[Flatten[Table[mt[[mt[[inv[g], inv[h]]], mt[[g, h]]]], {g, H}, {h, H}]]]]];

solvableQ[mt_, idElem_, H_] := Module[{cur = Sort[H], nxt},
  While[Length[cur] > 1,
    nxt = commutatorSubgroup[mt, idElem, cur];
    If[nxt === cur, Return[False, Module]];
    cur = nxt];
  True];

(* composition series with prime quotients, from H down to 1: at each step a normal subgroup of prime
   index containing the commutator subgroup (obtained by enlarging the latter while staying proper) *)
primeSeries[mt_, idElem_, H0_] := Module[{H = Sort[H0], steps = {}, N, p},
  While[Length[H] > 1,
    N = commutatorSubgroup[mt, idElem, H];
    If[N === H, Return[$Failed, Module]];
    Do[If[! MemberQ[N, g], With[{J = groupClosure[mt, idElem, Append[N, g]]}, If[Length[J] < Length[H], N = J]]], {g, H}];
    p = Length[H]/Length[N];
    If[! PrimeQ[p], Return[$Failed, Module]];
    AppendTo[steps, <|"Group" -> H, "Normal" -> N, "Generator" -> First[Complement[H, N]], "Prime" -> p|>];
    H = N];
  steps];

fixedByQ[gd_, v_, elems_] := AllTrue[elems, gd["Automorphisms"][[#]] . v == v &];

(* ------------------------------------------------------------------ *)
(* General Galois-Kummer descent                                       *)
(* ------------------------------------------------------------------ *)

(* the descent proper, for Galois data gd of p(x) Prod Phi_q(x); may throw "precision" *)
descend[gd_, a_, primes_, resolventForm_] := Module[
  {ord = gd["Order"], c = gd["Scale"], target, va, zetaIdx, zetaMult, zeta, H, steps, baseBasis, rad, radCompute, branch},
  target = locateTarget[gd, a];
  If[target === $Failed, Return[failure["RootIndex", "Could not locate the input among the roots"]]];
  va = gd["RootCoordinates"][[target]]/c;
  (* roots of unity zeta_q = Exp[2 Pi I/q] among the (scaled) roots, as multiplication matrices and as
     radical symbols; zeta_2 = -1 is handled by the same tables *)
  zetaIdx = Association @@ Table[q -> First[FirstPosition[gd["Roots"], _?(exactZeroQ[# - c Exp[2 Pi I/q]] &)]], {q, primes}];
  zetaMult = Association @@ Table[q -> multiplicationMatrixOfElement[gd, gd["RootCoordinates"][[zetaIdx[q]]]/c], {q, primes}];
  zetaMult[2] = -IdentityMatrix[ord];
  zeta = Association @@ Table[q -> (-1)^(2/q), {q, primes}]; zeta[2] = -1;
  H = Select[Range[ord], Function[s, AllTrue[Values[zetaIdx], gd["Permutations"][[s, #]] == # &]]];
  steps = primeSeries[gd["MultiplicationTable"], gd["Identity"], H];
  If[steps === $Failed, Return[failure["NotSolvable", "Could not build a prime composition series"]]];
  (* basis of Q(zeta_m): monomials prod zeta_q^e_q, 0 <= e_q <= q-2, as symbols and as coordinate vectors *)
  baseBasis = Table[{Times @@ MapThread[zeta[#1]^#2 &, {primes, e}],
      Fold[Function[{vec, qe}, Nest[zetaMult[qe[[1]]] . # &, vec, qe[[2]]]], UnitVector[ord, 1], MapThread[List, {primes, e}]]},
    {e, Tuples[Range[0, # - 2] & /@ primes]}];
  rad[v_, level_] := rad[v, level] = radCompute[v, level];
  (* level 0: the element lies in Q(zeta_m) *)
  radCompute[v_, 0] := With[{sol = Quiet[Check[LinearSolve[Transpose[baseBasis[[All, 2]]], v], $Failed]]},
    If[sol === $Failed, Throw[failure["Descent", "Element not in the base cyclotomic field"], radTag]];
    Expand[sol . baseBasis[[All, 1]]]];
  (* branch[Rk, q, level]: the q-th root of Rk^q (one level down) with the branch equal to Rk *)
  branch[Rk_, q_, level_] := branch[Rk, q, level] = Module[{qrad, sel},
    qrad = rad[powerCoordinates[gd, Rk, q], level - 1];
    sel = selectCandidate[rootOrbit[qrad^(1/q), q], gd["Values"][[gd["Identity"]]] . Rk];
    If[sel === $Failed, Throw[failure["Branch", "Could not identify the radical branch"], radTag]];
    sel];
  (* one prime step: v is fixed by steps[[level]]["Normal"]; extract q-th roots of the Lagrange resolvents
     R_k = Sum_j zeta^(-kj) sigma^j(v) (Fourier form), or of R_k1 alone with R_k = c_k R_k1^m, c_k one
     level down (eigenvector form) *)
  radCompute[v_, level_] := Module[{st = steps[[level]], generators, q, zw, R, nonzero, R0rad, k1, u, divide, ck, choices = {}},
    If[v == 0 v, Return[0, Module]];
    generators = steps[[level ;;, "Generator"]]; q = st["Prime"];
    If[fixedByQ[gd, v, generators], Return[rad[v, level - 1], Module]];
    (* zw[[j+1, e+1]] = zeta^e sigma^j(v), as vectors: q^2 matrix-vector products instead of matrix powers *)
    zw = NestList[zetaMult[q] . # &, #, q - 1] & /@ NestList[gd["Automorphisms"][[st["Generator"]]] . # &, v, q - 1];
    R = Table[Sum[zw[[j + 1, Mod[-k j, q] + 1]], {j, 0, q - 1}], {k, 0, q - 1}];
    nonzero = Select[Range[1, q - 1], R[[# + 1]] != 0 R[[# + 1]] &];
    R0rad = rad[R[[1]], level - 1];
    If[resolventForm =!= "Eigenvector" || q == 2,
      AppendTo[choices, (R0rad + Sum[branch[R[[k + 1]], q, level], {k, nonzero}])/q]];
    If[resolventForm =!= "Fourier" && q > 2,
      k1 = First[nonzero];
      u = branch[R[[k1 + 1]], q, level];
      divide = powerDivider[gd, R[[k1 + 1]]];
      AppendTo[choices, (R0rad + u + Sum[
        With[{m = Mod[k PowerMod[k1, -1, q], q]},
          ck = divide[R[[k + 1]], m];
          If[! fixedByQ[gd, ck, generators], Throw[failure["Descent", "Eigenvector ratio is not in the lower field"], radTag]];
          rad[ck, level - 1] u^m],
        {k, DeleteCases[nonzero, k1]}])/q]];
    First[SortBy[choices, LeafCount]]];
  <|"Expression" -> Catch[rad[va, Length[steps]], radTag], "ExtendedGroupOrder" -> ord, "SeriesPrimes" -> steps[[All, "Prime"]]|>];

galoisRadicals[a_, p_] := Module[{maxOrder, prec, form, gd0, order, primes, poly, gd, res, limit},
  {maxOrder, prec, form} = OptionValue[RootToRadicals, $opts, {"MaxGroupOrder", "WorkingPrecision", "Resolvents"}];
  limit = orderLimitFailure[p, maxOrder];
  If[limit =!= None, Return[limit]];
  gd0 = galoisData[p, maxOrder, prec];
  If[FailureQ[gd0], Return[gd0]];
  order = gd0["Order"];
  $galoisInfo = <|"GaloisGroupOrder" -> order|>;
  If[! solvableQ[gd0["MultiplicationTable"], gd0["Identity"], Range[order]],
    Message[RootToRadicals::notsolv, "order " <> ToString[order]];
    Return[failure["NotSolvable", "The Galois group is not solvable", <|"GaloisGroupOrder" -> order|>]]];
  primes = Select[First /@ FactorInteger[order], OddQ];
  (* adjoin the roots of unity; a cyclotomic factor equal to p itself is already present *)
  poly = Expand[p Times @@ Select[Cyclotomic[#, x] & /@ primes, PolynomialGCD[#, p] === 1 &]];
  Do[
    gd = galoisData[poly, maxOrder Times @@ (primes - 1), prec];
    If[FailureQ[gd], Return[gd, Module]];
    res = Catch[descend[gd, a, primes, form], precTag];
    If[res =!= "precision", Break[]];
    prec *= 2,
    {3}];
  If[res === "precision", Return[failure["Precision", "Precision escalation failed in the descent"]]];
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
  "Extension" -> None             (* exact algebraic numbers generating a subfield over which p is factored first *)
};
Options[RootRadicalReport] = Options[RootToRadicals];

(* recursive core: a radical expression, or a Failure *)
radicalsOf[a_, depth_] := Module[{in, p, n, r},
  If[RadicalExpressionQ[a], Return[a]];
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  p = in["Polynomial"]; n = in["Degree"];
  If[n == 1, Return[in["Value"]]];
  If[$method =!= "Galois", r = structural[a, p, depth]; If[okQ[r], Return[r]]];
  If[$method === "Structural", Return[failure["NotFound", "No structural radical form was found"]]];
  If[frobeniusNonsolvableQ[p],
    Message[RootToRadicals::notsolv, frobeniusReason[n]];
    $galoisInfo = <|"Method" -> "Frobenius"|>;
    Return[failure["NotSolvable", "The Galois group is not solvable (Frobenius cycle types)"]]];
  r = galoisRadicals[a, p];
  If[okQ[r], $methodUsed = "Galois"];
  r];

positiveIntegerQ[v_] := IntegerQ[v] && v > 0;
validOptionsQ[opts_] := With[{o = OptionValue[RootToRadicals, opts, #] &},
  MemberQ[{Automatic, "Structural", "Galois"}, o[Method]] &&
  MemberQ[{Automatic, "Fourier", "Eigenvector"}, o["Resolvents"]] &&
  positiveIntegerQ[o["MaxGroupOrder"]] && positiveIntegerQ[o["MaxDepth"]] &&
  IntegerQ[o["WorkingPrecision"]] && o["WorkingPrecision"] >= 30 &&
  (o["Extension"] === None || AllTrue[Flatten[{o["Extension"]}], FreeQ[#, _Real] && minimalPolynomialOf[#] =!= $Failed &])];

RootRadicalReport[a_, opts : OptionsPattern[]] := Module[{t0 = AbsoluteTime[], in, r, ver},
  If[! validOptionsQ[Flatten[{opts}]], Message[RootToRadicals::opts, Flatten[{opts}]]; Return[failure["InvalidOptions", "Invalid options"]]];
  If[! FreeQ[a, _Real], Message[RootToRadicals::inexact, a]; Return[failure["Inexact", "Inexact input"]]];
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  Block[{$method = OptionValue[Method], $opts = Flatten[{opts}], $methodUsed = None, $galoisInfo = <||>,
         $prec = Max[60, OptionValue["WorkingPrecision"]], $extension = OptionValue["Extension"]},
    r = radicalsOf[a, OptionValue["MaxDepth"]];
    If[FailureQ[r], Return[Failure[r[[1]], Join[r[[2]], $galoisInfo, <|"Degree" -> in["Degree"], "Time" -> AbsoluteTime[] - t0|>]], Module]];
    ver = verifyExact[r, a, OptionValue["VerificationTimeLimit"]];
    If[ver =!= True, Message[RootToRadicals::verify, ver]];
    Join[<|"Expression" -> r, "Verified" -> ver, "Method" -> $methodUsed, "Degree" -> in["Degree"],
      "RadicalDepth" -> RadicalDepth[r], "LeafCount" -> LeafCount[r]|>, $galoisInfo, <|"Time" -> AbsoluteTime[] - t0|>]]];

RootToRadicals[a_, opts : OptionsPattern[]] := With[{r = RootRadicalReport[a, opts]},
  Which[FailureQ[r], r,
    r["Verified"] === False, failure["VerificationFailed", "The candidate expression is not equal to the input"],
    True, r["Expression"]]];

RootSolvableQ[a_, opts : OptionsPattern[RootToRadicals]] := Module[{in = inputData[a], p, limit, gd},
  If[FailureQ[in], Return[in]];
  If[in["Degree"] <= 4, Return[True]];
  p = in["Polynomial"];
  If[frobeniusNonsolvableQ[p], Return[False]];
  limit = orderLimitFailure[p, OptionValue["MaxGroupOrder"]];
  If[limit =!= None, Return[limit]];
  gd = galoisData[p, OptionValue["MaxGroupOrder"], OptionValue["WorkingPrecision"]];
  If[FailureQ[gd], gd, solvableQ[gd["MultiplicationTable"], gd["Identity"], Range[gd["Order"]]]]];

End[];
EndPackage[];
