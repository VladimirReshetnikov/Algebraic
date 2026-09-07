(* ::Package:: *)

(* RootDecomposition.wl

   Additive and multiplicative decomposition of algebraic numbers (Root objects)
   into components of the smallest possible maximum degree.

   Given an exact algebraic number a of degree n, the package computes

       D+(a) = min  max deg(b_i)   over all finite sums     a = b_1 + ... + b_r,
       Dx(a) = min  max deg(b_i)   over all finite products a = b_1 * ... * b_r,

   where the b_i range over all algebraic numbers (not only over Q(a)) and
   deg means the absolute degree over Q.

   Mathematical basis (see the accompanying article):

   * Sums.  Trace projection onto the splitting field L of a shows that every
     summand may be moved into L without increasing its degree.  Hence
     D+(a) <= d  iff  a lies in the Q-linear span of the fixed fields L^H with
     [G:H] <= d, where G = Gal(L/Q).  This is exact rational linear algebra
     once G and its subgroup lattice are known.  The algorithm is complete.

   * Products of two factors.  Relative norms show that a = b c with
     deg b, deg c <= d  iff  there are subfields E, F of L and an exponent t >= 1
     with t[E:Q] <= d, t[F:Q] <= d and E \[Intersection] a^t F != {0}.  The exponent t
     accounts for factors outside L, which genuinely occur.  Complete.

   * Products of arbitrarily many factors have no known complete finite
     algorithm.  The package combines the two-factor criterion, an exact
     rank-one tensor test, recursive splitting, a bounded dictionary search
     and rigorous lower bounds, and reports what has been certified.

   Engine.  The Galois group is computed as a permutation group of the roots
   by numerical resolvents: at each level the exact minimal polynomial of a
   weighted partial sum of roots is obtained from RootReduce and the orbit of
   the partial tuple is read off numerically; the final permutation set is
   checked to be a group.  The splitting field is represented in a tower
   monomial basis.  Rational coordinates of field elements are obtained by
   rounding numerically computed traces (integers for algebraic integers) and
   checked for accuracy.  Every returned decomposition is verified exactly with
   RootReduce and MinimalPolynomial.

   Prepared for Vladimir Reshetnikov, September 2026.  License: MIT-0.
*)

BeginPackage["RootDecomposition`"];

RootSumDecomposition::usage = "RootSumDecomposition[a] represents the exact algebraic number a as a sum of algebraic numbers whose largest degree over the rationals is as small as possible.
RootSumDecomposition[a, d] looks for a representation whose summands all have degree at most d.
The result is an Association with keys \"Terms\", \"Degrees\", \"MaximumDegree\", \"LowerBound\", \"Optimal\", \"ScopeOptimal\", \"Scope\", \"Expression\", \"Verified\" and \"Method\".";

RootProductDecomposition::usage = "RootProductDecomposition[a] represents the exact nonzero algebraic number a as a product of algebraic numbers whose largest degree over the rationals is as small as possible.
RootProductDecomposition[a, d] looks for a representation whose factors all have degree at most d.
The result is an Association with the same keys as RootSumDecomposition, plus \"TwoFactorOptimal\" and \"NormExponent\".";

RootGaloisData::usage = "RootGaloisData[a] computes the Galois group of the minimal polynomial of a as a group of permutations of its roots, the splitting field in a tower basis, all subgroups with their fixed fields, and related data.
RootGaloisData[poly, x] does the same for a squarefree rational polynomial.";

RootDecompositionLowerBound::usage = "RootDecompositionLowerBound[a] gives a rigorous lower bound for the maximum degree in any finite sum or product decomposition of a, from the largest prime divisor of deg(a) and from Frobenius cycle types of its minimal polynomial.";

RootDecompositionVerify::usage = "RootDecompositionVerify[a, terms, Plus|Times] checks exactly that the terms combine to a and returns their degrees.";

RootBoundedDecomposition::usage = "RootBoundedDecomposition[a, Plus|Times, d, h, r] searches for a decomposition of a into at most r components of degree at most d such that all components except the last are roots of primitive integer polynomials of coefficient height at most h; the last component is the exact residual.";

RootDecompositionCatalog::usage = "RootDecompositionCatalog[d, h] lists all roots of irreducible primitive integer polynomials of degree at most d and coefficient height at most h.";

RootDecomposition::inexact = "The input `1` is not an exact algebraic number.";
RootDecomposition::notalg = "Could not compute a rational minimal polynomial of `1`.";
RootDecomposition::order = "The Galois group has order `1`, larger than the limit `2` (option \"MaxGroupOrder\").";
RootDecomposition::group = "Failed to determine the Galois group numerically after `1` attempts; increase \"WorkingPrecision\" or \"MaxTries\".";
RootDecomposition::prec = "Numerical rounding failed at precision `1`; retrying with higher precision.";
RootDecomposition::verify = "Internal error: a candidate decomposition failed exact verification.";

Begin["`Private`"];

(* ------------------------------------------------------------------ *)
(* Utilities                                                          *)
(* ------------------------------------------------------------------ *)

rationalQ[q_] := IntegerQ[q] || Head[q] === Rational;

failure[tag_String, msg_String, extra_: <||>] :=
  Failure[tag, Join[<|"MessageTemplate" -> msg|>, extra]];

exactZeroQ[e_] := TrueQ[Quiet[RootReduce[e]] === 0];

rootObject[poly_, k_Integer] := Root[Function @@ {poly /. x -> Slot[1]}, k];

primitiveIntegerPolynomial[poly_] := Module[{c = CoefficientList[poly, x], den, g},
  den = LCM @@ Denominator[c]; c = c den; g = GCD @@ c;
  c = c/g; If[Last[c] < 0, c = -c];
  FromDigits[Reverse[c], x]];

polynomialHeight[poly_] := Max[Abs[CoefficientList[primitiveIntegerPolynomial[poly], x]]];

minimalPolynomialOf[a_] := Module[{p},
  p = Quiet[Check[MinimalPolynomial[a, x], $Failed]];
  If[p === $Failed || ! PolynomialQ[p, x] || ! And @@ (rationalQ /@ CoefficientList[p, x]), $Failed,
    primitiveIntegerPolynomial[p]]];

algebraicDegree[a_] := Module[{p = minimalPolynomialOf[a]}, If[p === $Failed, $Failed, Exponent[p, x]]];

rootIndexOf[a_, poly_] := Module[{n = Exponent[poly, x], vals, av, k},
  av = N[a, 40];
  vals = Table[N[rootObject[poly, j], 40], {j, n}];
  k = First[Ordering[Abs[vals - av], 1]];
  If[exactZeroQ[a - rootObject[poly, k]], k, $Failed]];

(* ------------------------------------------------------------------ *)
(* Input normalization                                                *)
(* ------------------------------------------------------------------ *)

inputData[a_] := Module[{p, n, k},
  If[! FreeQ[a, _Real], Message[RootDecomposition::inexact, a]; Return[failure["Inexact", "Inexact input"]]];
  p = minimalPolynomialOf[a];
  If[p === $Failed, Message[RootDecomposition::notalg, a]; Return[failure["NotAlgebraic", "Not algebraic"]]];
  n = Exponent[p, x];
  If[n == 1, Return[<|"Value" -> RootReduce[a], "Polynomial" -> p, "Degree" -> 1, "Index" -> 1|>]];
  k = rootIndexOf[a, p];
  If[k === $Failed, Return[failure["RootIndex", "Could not identify the root branch"]]];
  <|"Value" -> a, "Polynomial" -> p, "Degree" -> n, "Index" -> k|>];

(* ------------------------------------------------------------------ *)
(* Lower bounds                                                       *)
(* ------------------------------------------------------------------ *)

largestPrimeFactor[1] = 1;
largestPrimeFactor[n_Integer] := Max[First /@ FactorInteger[n]];

(* least d with e | lcm(1..d): the largest prime power dividing e *)
exponentBound[1] = 1;
exponentBound[e_Integer] := Max[Power @@@ FactorInteger[e]];

(* variants valid when Gaussian rational coefficients are allowed: the prime 2 is free *)
gaussianPrimeBound[n_Integer] := Max[1, Max[Select[First /@ FactorInteger[n], # > 2 &] /. {} -> {1}]];
gaussianExponentBound[e_Integer] := Max[1, Max[(If[#[[1]] == 2, 2^(#[[2]] - 1), #[[1]]^#[[2]]] & /@ FactorInteger[e]) /. {} -> {1}]];

frobeniusExponentMultiple[poly_, maxPrimes_: 40] := Module[{disc, lc, ps, orders = {}, q, fl},
  lc = Coefficient[poly, x, Exponent[poly, x]];
  disc = Discriminant[poly, x];
  ps = Select[Prime[Range[maxPrimes + 10]], Mod[disc lc, #] != 0 &];
  ps = Take[ps, UpTo[maxPrimes]];
  Do[
    fl = Select[FactorList[poly, Modulus -> q], Exponent[#[[1]], x] > 0 &];
    AppendTo[orders, LCM @@ (Exponent[#[[1]], x] & /@ fl)],
    {q, ps}];
  LCM @@ orders];

lowerBoundFromPolynomial[poly_] := Module[{n = Exponent[poly, x]},
  If[n == 1, 1, Max[largestPrimeFactor[n], exponentBound[frobeniusExponentMultiple[poly]]]]];

RootDecompositionLowerBound[a_] := Module[{in = inputData[a]},
  If[FailureQ[in], Return[in]];
  lowerBoundFromPolynomial[in["Polynomial"]]];

(* ------------------------------------------------------------------ *)
(* Galois group by numerical resolvents                               *)
(* ------------------------------------------------------------------ *)

Options[RootGaloisData] = {
  "WorkingPrecision" -> 80,
  "MaxGroupOrder" -> 400,
  "MaxTries" -> 12,
  "Cache" -> True
};

$galoisCache = <||>;

allRoots[poly_] := Module[{fl},
  fl = Select[FactorList[poly], Exponent[#[[1]], x] > 0 &];
  Join @@ Table[rootObject[f[[1]], j], {f, fl}, {j, Exponent[f[[1]], x]}]];

roundInteger[z_] := Module[{r},
  If[Abs[Im[z]] > 10^-12, Throw["precision", precTag]];
  r = Round[Re[z]];
  If[Abs[Re[z] - r] > 10^-12 || Accuracy[z] < 12, Throw["precision", precTag]];
  r];

roundIntegerMatrix[m_] := Map[roundInteger, m, {2}];

galoisGroupNumerically[roots_List, nums_List, prec_, maxOrder_, maxTries_] :=
  Module[{n = Length[roots], orbit, vals, thetaExact = 0, tower = {}, k, w, newTheta, m, md, mroots,
          cand, matched, idx, used, ok, perms, set, lastDeg, tol, dists, pos, rprec},
    orbit = {{}}; vals = {0};
    rprec = Max[30, Floor[prec/2]];
    tol = 10^(-Floor[rprec/2]);
    Do[
      ok = False; used = {};
      Do[
        w = RandomChoice[Complement[Range[1, 60], used]];
        AppendTo[used, w];
        newTheta = RootReduce[thetaExact + w roots[[k]]];
        m = minimalPolynomialOf[newTheta];
        If[m === $Failed, Continue[]];
        md = Exponent[m, x];
        lastDeg = Length[orbit];
        If[md < lastDeg || Mod[md, lastDeg] != 0, Continue[]];
        If[md > maxOrder, Message[RootDecomposition::order, md, maxOrder];
          Throw[failure["GroupOrder", "Galois group too large", <|"Order" -> md, "Limit" -> maxOrder|>], failTag]];
        mroots = If[md == 1, {N[newTheta, rprec]}, Table[N[rootObject[m, j], rprec], {j, md}]];
        cand = Join @@ Table[{Append[orbit[[i]], j], vals[[i]] + w nums[[j]]},
                  {i, Length[orbit]}, {j, Complement[Range[n], orbit[[i]]]}];
        matched = {}; idx = {};
        Do[
          dists = Abs[c[[2]] - mroots];
          pos = First[Ordering[dists, 1]];
          If[dists[[pos]] < tol, AppendTo[matched, c]; AppendTo[idx, pos]],
          {c, cand}];
        If[Length[matched] == md && Length[Union[idx]] == md,
          orbit = matched[[All, 1]]; vals = matched[[All, 2]];
          thetaExact = newTheta;
          If[md > lastDeg, AppendTo[tower, {k, md/lastDeg}]];
          ok = True; Break[]],
        {maxTries}];
      If[! ok, Message[RootDecomposition::group, maxTries];
        Throw[failure["GaloisGroup", "Could not determine the Galois group"], failTag]],
      {k, n}];
    perms = orbit;
    set = Association[Thread[perms -> Range[Length[perms]]]];
    If[! KeyExistsQ[set, Range[n]], Throw[failure["GaloisGroup", "Identity missing"], failTag]];
    Do[If[! KeyExistsQ[set, perms[[i]][[perms[[j]]]]],
        Throw[failure["GaloisGroup", "Closure check failed"], failTag]],
      {i, Length[perms]}, {j, Length[perms]}];
    <|"Permutations" -> perms, "Order" -> Length[perms], "Tower" -> tower, "PrimitiveElement" -> thetaExact|>];

(* Subgroup lattice from the multiplication table. *)
subgroupLattice[mt_, idElem_] := Module[{ord = Length[mt], closure, seen, queue, H, J, g},
  closure[gs_] := Module[{elems = {idElem}, frontier = {idElem}, next, h},
    While[frontier =!= {},
      next = {};
      Do[h = mt[[e, gg]]; If[! MemberQ[elems, h], AppendTo[elems, h]; AppendTo[next, h]], {e, frontier}, {gg, gs}];
      frontier = next];
    Sort[elems]];
  seen = <|{idElem} -> {}|>;
  Do[J = closure[{g}]; If[! KeyExistsQ[seen, J], seen[J] = {g}], {g, ord}];
  queue = Keys[seen];
  While[queue =!= {},
    H = First[queue]; queue = Rest[queue];
    Do[
      If[! MemberQ[H, g],
        J = closure[Join[seen[H], {g}]];
        If[! KeyExistsQ[seen, J], seen[J] = Join[seen[H], {g}]; AppendTo[queue, J]]],
      {g, ord}]];
  Table[<|"Elements" -> k, "Generators" -> seen[k], "Order" -> Length[k], "Index" -> ord/Length[k]|>, {k, Keys[seen]}]];

elementOrder[mt_, g_, idElem_] := Module[{h = g, k = 1}, While[h != idElem, h = mt[[h, g]]; k++]; k];

buildGaloisData[poly_, prec0_, maxOrder_, maxTries_] := Module[{prec = prec0, result, attempt = 0},
  While[True,
    attempt++;
    result = Catch[Catch[buildGaloisDataAtPrecision[poly, prec, maxOrder, maxTries], precTag], failTag];
    If[result === "precision",
      If[attempt >= 4, Return[failure["Precision", "Precision escalation failed"]]];
      Message[RootDecomposition::prec, prec]; prec = 2 prec; Continue[]];
    Return[result]]];

buildGaloisDataAtPrecision[poly_, prec_, maxOrder_, maxTries_] := Module[
  {roots, nums, n, gg, perms, ord, tower, gens, expo, basisExp, pw, val, gram, gramInv, set, mt, idElem,
   rootCoords, auts, subs, fixed, orders, numsPerm},
  roots = allRoots[poly];
  n = Length[roots];
  nums = N[roots, prec];
  gg = galoisGroupNumerically[roots, nums, prec, maxOrder, maxTries];
  perms = gg["Permutations"]; ord = gg["Order"]; tower = gg["Tower"];
  gens = tower[[All, 1]]; expo = tower[[All, 2]];
  basisExp = If[gens === {}, {{}}, Tuples[Range[0, # - 1] & /@ expo]];
  pw = Table[nums[[i]]^e, {i, n}, {e, 0, Max[Append[expo, 1]]}];
  val = Table[Times @@ Table[pw[[perm[[gens[[j]]]], basisExp[[b, j]] + 1]], {j, Length[gens]}], {perm, perms}, {b, ord}];
  gram = roundIntegerMatrix[Transpose[val] . val];
  If[Det[gram] == 0, Throw["precision", precTag]];
  gramInv = Inverse[gram];
  set = Association[Thread[perms -> Range[ord]]];
  mt = Table[set[perms[[i]][[perms[[j]]]]], {i, ord}, {j, ord}];
  idElem = set[Range[n]];
  numsPerm = Map[nums[[#]] &, perms];
  rootCoords = Transpose[gramInv . roundIntegerMatrix[Transpose[val] . numsPerm]];
  auts = Table[gramInv . roundIntegerMatrix[Transpose[val] . val[[mt[[All, s]]]]], {s, ord}];
  (* consistency check: automorphisms permute the root coordinates *)
  Do[If[auts[[s]] . rootCoords[[i]] != rootCoords[[perms[[s, i]]]], Throw["precision", precTag]], {s, ord}, {i, n}];
  subs = subgroupLattice[mt, idElem];
  fixed = Table[
    If[sub["Order"] == 1, IdentityMatrix[ord],
      NullSpace[Join @@ Table[auts[[g]] - IdentityMatrix[ord], {g, sub["Generators"]}]]],
    {sub, subs}];
  subs = MapThread[Append[#1, "FixedField" -> #2] &, {subs, fixed}];
  orders = Table[elementOrder[mt, g, idElem], {g, ord}];
  <|"Polynomial" -> poly, "Roots" -> roots, "NumericRoots" -> nums, "Precision" -> prec,
    "Degree" -> n, "Permutations" -> perms, "Order" -> ord, "Exponent" -> LCM @@ orders,
    "Tower" -> tower, "BasisExponents" -> basisExp, "Values" -> val, "Gram" -> gram,
    "GramInverse" -> gramInv, "MultiplicationTable" -> mt, "Identity" -> idElem,
    "RootCoordinates" -> rootCoords, "Automorphisms" -> auts, "Subgroups" -> subs,
    "PrimitiveElement" -> gg["PrimitiveElement"]|>];

RootGaloisData[a_, opts : OptionsPattern[]] := Module[{in},
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  RootGaloisData[in["Polynomial"], x, opts]];

RootGaloisData[poly0_, var_Symbol, OptionsPattern[]] := Module[{poly, c, n, res, mon, key},
  poly = primitiveIntegerPolynomial[poly0 /. var -> x];
  n = Exponent[poly, x];
  c = Coefficient[poly, x, n];
  mon = Expand[c^(n - 1) (poly /. x -> x/c)];
  If[! SquareFreeQ[mon], Return[failure["NotSquareFree", "The polynomial is not squarefree"]]];
  key = {mon, OptionValue["WorkingPrecision"]};
  If[OptionValue["Cache"] && KeyExistsQ[$galoisCache, key], Return[$galoisCache[key]]];
  res = buildGaloisData[mon, OptionValue["WorkingPrecision"], OptionValue["MaxGroupOrder"], OptionValue["MaxTries"]];
  If[FailureQ[res], Return[res]];
  res = Join[res, <|"Scale" -> c, "OriginalPolynomial" -> poly,
    "SplittingFieldDegree" -> res["Order"],
    "SubfieldDegrees" -> Sort[res["Subgroups"][[All, "Index"]]]|>];
  If[OptionValue["Cache"], $galoisCache[key] = res];
  res];

(* ------------------------------------------------------------------ *)
(* Field element utilities                                            *)
(* ------------------------------------------------------------------ *)

valuesAtPrecision[gd_, prec_] := Module[{nums, gens, expo, basisExp, pw, perms, ord = gd["Order"]},
  If[prec <= gd["Precision"], Return[gd["Values"]]];
  nums = N[gd["Roots"], prec];
  gens = gd["Tower"][[All, 1]]; expo = gd["Tower"][[All, 2]]; basisExp = gd["BasisExponents"]; perms = gd["Permutations"];
  pw = Table[nums[[i]]^e, {i, Length[nums]}, {e, 0, Max[Append[expo, 1]]}];
  Table[Times @@ Table[pw[[perm[[gens[[j]]]], basisExp[[b, j]] + 1]], {j, Length[gens]}], {perm, perms}, {b, ord}]];

conjugates[gd_, v_] := gd["Values"] . v;

multiplicationMatrix[gd_, yv_] := gd["GramInverse"] . roundIntegerMatrix[Transpose[gd["Values"]] . (yv gd["Values"])];

multiplicationMatrixOfElement[gd_, v_] := Module[{den = LCM @@ Denominator[v]},
  multiplicationMatrix[gd, conjugates[gd, den v]]/den];

elementDegree[gd_, v_] := Module[{cnt = 0}, Do[If[aut . v == v, cnt++], {aut, gd["Automorphisms"]}]; gd["Order"]/cnt];

coordinateOfOne[gd_] := UnitVector[gd["Order"], 1];

(* exact mean of the conjugates: Tr(y)/[L:Q] with Tr(b_j) = Gram[j,1] *)
meanTrace[gd_, v_] := (v . gd["Gram"][[1]])/gd["Order"];

elementToAlgebraic[gd_, v_] := Module[{d, den, prec, vals, distinct, poly, cl, k, cands, tol, mag, need, id = gd["Identity"]},
  If[v == 0 v, Return[0]];
  d = elementDegree[gd, v];
  If[d == 1, Return[v[[1]]]];
  den = LCM @@ Denominator[v];
  mag = Max[Abs[conjugates[gd, den v]]];
  need = Ceiling[d Log10[2 Max[mag, 2]]] + 30;
  prec = Max[gd["Precision"], need];
  vals = valuesAtPrecision[gd, prec] . (den v);
  tol = 10^(-Floor[prec/3]);
  distinct = {};
  Do[If[! AnyTrue[distinct, Abs[# - z] < tol &], AppendTo[distinct, z]], {z, vals}];
  If[Length[distinct] != d, Throw["precision", precTag]];
  poly = Expand[Times @@ (x - distinct)];
  cl = roundInteger /@ CoefficientList[poly, x];
  poly = primitiveIntegerPolynomial[FromDigits[Reverse[cl], x] /. x -> den x];
  cands = Table[N[rootObject[poly, j], 40], {j, d}];
  k = First[Ordering[Abs[cands - N[vals[[id]]/den, 40]], 1]];
  RootReduce[rootObject[poly, k]]];

(* ------------------------------------------------------------------ *)
(* Result assembly                                                    *)
(* ------------------------------------------------------------------ *)

termDegrees[terms_] := algebraicDegree /@ terms;

RootDecompositionVerify[a_, terms_List, op : (Plus | Times)] := Module[{degs, ok},
  ok = exactZeroQ[a - (op @@ terms)];
  degs = termDegrees[terms];
  <|"Verified" -> ok, "Degrees" -> degs, "MaximumDegree" -> Max[degs]|>];

makeResult[a_, op_, terms_, lb_, scope_, method_, optimal_, scopeOptimal_, extra_: <||>] := Module[{v, degs},
  v = RootDecompositionVerify[a, terms, op];
  degs = v["Degrees"];
  If[! v["Verified"], Message[RootDecomposition::verify]];
  Join[<|"Terms" -> terms, "Degrees" -> degs, "MaximumDegree" -> Max[degs], "LowerBound" -> lb,
    "Optimal" -> optimal, "ScopeOptimal" -> scopeOptimal, "Scope" -> scope, "Verified" -> v["Verified"],
    "Expression" -> Inactive[op] @@ terms, "Method" -> method|>, extra]];

(* locate c*a among the roots of the Galois data; returns the index *)
locateTarget[gd_, a_] := Module[{c = gd["Scale"], pos},
  pos = Position[gd["Roots"], _?(exactZeroQ[# - c a] &), {1}, 1];
  If[pos === {}, $Failed, pos[[1, 1]]]];

stabilizerOf[gd_, target_] := Select[Range[gd["Order"]], gd["Permutations"][[#, target]] == target &];

(* ------------------------------------------------------------------ *)
(* Additive decomposition                                             *)
(* ------------------------------------------------------------------ *)

Options[RootSumDecomposition] = {
  "Scope" -> "Global",               (* "Global" or "InputField" *)
  "Coefficients" -> "Rationals",     (* "Rationals" or "GaussianRationals" *)
  "MaxTerms" -> Infinity,
  "WorkingPrecision" -> 80,
  "MaxGroupOrder" -> 400,
  "MaxTries" -> 12
};

(* inclusion-minimal subgroups of index <= d (containing stab if given): their fixed fields are the maximal fields of degree <= d *)
candidateFields[gd_, d_, stab_: None] := Module[{subs},
  subs = Select[gd["Subgroups"], #["Index"] <= d &];
  If[stab =!= None, subs = Select[subs, SubsetQ[#["Elements"], stab] &]];
  Select[subs, Function[H, ! AnyTrue[subs, #["Order"] < H["Order"] && SubsetQ[H["Elements"], #["Elements"]] &]]]];

rowSpaceBasis[rows_] := DeleteCases[RowReduce[rows], {0 ..}];

(* Solve v in the sum of the given spaces (each an association with a "Basis" of rows);
   returns the list of {space, contribution vector} or $Failed. *)
solveInSpaces[spaces_, v_] := Module[{B, sol, lens, p = 1, chunks},
  If[spaces === {}, Return[$Failed]];
  B = Transpose[Join @@ (#["Basis"] & /@ spaces)];
  sol = Quiet[Check[LinearSolve[B, v], $Failed]];
  If[sol === $Failed, Return[$Failed]];
  lens = Length[#["Basis"]] & /@ spaces;
  chunks = Table[With[{ch = Take[sol, {p, p + lens[[i]] - 1}]}, p += lens[[i]]; ch], {i, Length[spaces]}];
  Select[MapThread[{#1, #2 . #1["Basis"]} &, {spaces, chunks}], #[[2]] != 0 #[[2]] &]];

findSumRepresentation[spaces_, v_, maxTerms_] := Module[{limit, res},
  limit = If[maxTerms === Infinity, Min[3, Length[spaces]], Min[maxTerms, Length[spaces]]];
  res = Catch[
    Do[Do[With[{r = solveInSpaces[s, v]}, If[r =!= $Failed, Throw[r, foundTag]]], {s, Subsets[spaces, {k}]}], {k, 1, limit}];
    $Failed, foundTag];
  If[res === $Failed && maxTerms === Infinity, solveInSpaces[spaces, v], res]];

RootSumDecomposition[a_, opts : OptionsPattern[]] := RootSumDecomposition[a, Automatic, opts];

RootSumDecomposition[a_, dmax_, OptionsPattern[]] := Module[
  {in, n, lb, scope = OptionValue["Scope"], coeffs = OptionValue["Coefficients"], trivial, prec, res, attempt = 0, gaussian},
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  n = in["Degree"];
  gaussian = coeffs === "GaussianRationals";
  lb = If[n == 1, 1, If[gaussian, gaussianPrimeBound[n], lowerBoundFromPolynomial[in["Polynomial"]]]];
  trivial := makeResult[a, Plus, {RootReduce[a]}, lb, scope, "Trivial", lb == n, lb == n];
  If[n == 1, Return[trivial]];
  If[dmax =!= Automatic && dmax >= n, Return[trivial]];
  If[lb == n, Return[trivial]];
  prec = OptionValue["WorkingPrecision"];
  While[True,
    attempt++;
    res = Catch[sumDecompositionCore[a, in, dmax, lb, scope, gaussian, OptionValue["MaxTerms"], prec,
        OptionValue["MaxGroupOrder"], OptionValue["MaxTries"]], precTag];
    If[res === "precision",
      If[attempt >= 4, Return[failure["Precision", "Precision escalation failed"]]];
      Message[RootDecomposition::prec, prec]; prec = 2 prec; Continue[]];
    Return[res]]];

sumDecompositionCore[a_, in_, dmax_, lb0_, scope_, gaussian_, maxTerms_, prec_, maxOrder_, maxTries_] := Module[
  {n = in["Degree"], lb = lb0, poly, gd, c, target, va, stab, iCoord, iMult, dlist, d, cf, spaces, rep, terms, rational, mean, term, method, res},
  poly = in["Polynomial"];
  If[gaussian && PolynomialRemainder[poly, x^2 + 1, x] =!= 0, poly = Expand[poly (x^2 + 1)]];
  gd = RootGaloisData[poly, x, "WorkingPrecision" -> prec, "MaxGroupOrder" -> maxOrder, "MaxTries" -> maxTries];
  If[FailureQ[gd], Return[gd]];
  c = gd["Scale"];
  target = locateTarget[gd, a];
  If[target === $Failed, Return[failure["RootIndex", "Could not locate the input among the roots"]]];
  va = gd["RootCoordinates"][[target]]/c;
  stab = If[scope === "InputField", stabilizerOf[gd, target], None];
  If[gaussian,
    iCoord = gd["RootCoordinates"][[First[FirstPosition[gd["Roots"], _?(exactZeroQ[# - I] &)]]]];
    iMult = multiplicationMatrix[gd, conjugates[gd, iCoord]]];
  lb = Max[lb, If[gaussian, gaussianExponentBound[gd["Exponent"]], exponentBound[gd["Exponent"]]]];
  method = If[scope === "Global", "SplittingFieldFixedSpaces", "InputFieldSubfields"];
  If[lb >= n && ! gaussian,
    Return[makeResult[a, Plus, {RootReduce[a]}, lb, scope, "CompleteSearch", True, True, <|"GroupOrder" -> gd["Order"]|>]]];
  dlist = If[dmax === Automatic, Range[lb, n - 1], {dmax}];
  res = Catch[
    Do[
      cf = candidateFields[gd, d, stab];
      spaces = Table[<|"Index" -> H["Index"], "Field" -> H["FixedField"],
        "Basis" -> If[gaussian, rowSpaceBasis[Join[H["FixedField"], Map[iMult . # &, H["FixedField"]]]], H["FixedField"]]|>, {H, cf}];
      rep = findSumRepresentation[spaces, va, maxTerms];
      If[rep =!= $Failed,
        If[gaussian,
          Throw[gaussianResult[gd, a, rep, iMult, lb, scope, dmax === Automatic], foundTag]];
        rational = 0; terms = {};
        Do[mean = meanTrace[gd, e[[2]]]; rational += mean;
          term = e[[2]] - mean coordinateOfOne[gd];
          If[term != 0 term, AppendTo[terms, term]], {e, rep}];
        terms = elementToAlgebraic[gd, #] & /@ terms;
        If[rational != 0, AppendTo[terms, rational]];
        If[terms === {}, terms = {0}];
        Throw[makeResult[a, Plus, terms, lb, scope, method,
          (dmax === Automatic) && (scope === "Global" || Max[termDegrees[terms]] == lb),
          dmax === Automatic, <|"GroupOrder" -> gd["Order"]|>], foundTag]],
      {d, dlist}];
    $Failed, foundTag];
  If[res =!= $Failed, Return[res]];
  If[dmax === Automatic,
    makeResult[a, Plus, {RootReduce[a]}, lb, scope, "CompleteSearch", scope === "Global" && ! gaussian, ! gaussian,
      <|"GroupOrder" -> gd["Order"]|>],
    failure["NotFound", "No representation with the requested maximum degree",
      <|"MaximumDegree" -> dmax, "Scope" -> scope, "GroupOrder" -> gd["Order"]|>]]];

(* Gaussian mode: each contribution e in E + iE is split as u + i w with u, w in E. *)
gaussianResult[gd_, a_, rep_, iMult_, lb_, scope_, automatic_] := Module[{terms = {}, Bf, sol, u, w, degs},
  Do[
    Bf = e[[1]]["Field"];
    sol = Quiet[Check[LinearSolve[Transpose[Join[Bf, Map[iMult . # &, Bf]]], e[[2]]], $Failed]];
    If[sol === $Failed, Throw["precision", precTag]];
    u = Take[sol, Length[Bf]] . Bf; w = Drop[sol, Length[Bf]] . Bf;
    Which[
      w == 0 w, AppendTo[terms, {1, u}],
      u == 0 u, AppendTo[terms, {I, w}],
      MatrixRank[{u, w}] == 1, AppendTo[terms, {1 + I First[Select[w/u, NumericQ]], u}],
      True, AppendTo[terms, {1, u}]; AppendTo[terms, {I, w}]],
    {e, rep}];
  terms = Map[{#[[1]], elementToAlgebraic[gd, #[[2]]]} &, terms];
  degs = algebraicDegree[#[[2]]] & /@ terms;
  <|"Terms" -> terms, "Degrees" -> degs, "MaximumDegree" -> Max[degs], "LowerBound" -> lb,
    "Optimal" -> automatic, "ScopeOptimal" -> automatic, "Scope" -> scope,
    "Verified" -> exactZeroQ[a - Total[Times @@@ terms]],
    "Expression" -> Inactive[Plus] @@ (Times @@@ terms), "Method" -> "GaussianFixedSpaces",
    "Coefficients" -> "GaussianRationals", "GroupOrder" -> gd["Order"]|>];

(* ------------------------------------------------------------------ *)
(* Multiplicative decomposition                                       *)
(* ------------------------------------------------------------------ *)

Options[RootProductDecomposition] = {
  "Scope" -> "Global",
  "MaxFactors" -> Infinity,
  "RecursionDepth" -> 3,
  "TensorTest" -> True,
  "BoundedSearch" -> {3, 3},          (* {height, factors} for the final dictionary search, or None *)
  "WorkingPrecision" -> 80,
  "MaxGroupOrder" -> 400,
  "MaxTries" -> 12
};

(* p-adically minimal integral scaling: the smallest rational q > 0 (prime by prime) such that q*u is an
   algebraic integer; this removes accidental huge scalings produced by linear algebra. *)
integralScale[f_] := Module[{d = Exponent[f, x], c, primes, q = 1, e, v},
  c = CoefficientList[f/Coefficient[f, x, d], x];  (* monic, rational *)
  primes = Union @@ (First /@ FactorInteger[#] & /@ DeleteCases[Abs[Join[Numerator[c], Denominator[c]]], 0 | 1]);
  Do[
    v[r_] := If[r == 0, Infinity, IntegerExponent[r, p]];
    e = Max[Table[If[c[[i + 1]] == 0, -Infinity, Ceiling[-v[c[[i + 1]]]/(d - i)]], {i, 0, d - 1}]];
    If[e =!= -Infinity, q = q p^e],
    {p, primes}];
  q];

niceScale[u_] := Module[{f, d, best = 1, h, hb = {Infinity, 0, 0}, g, q0},
  f = minimalPolynomialOf[u];
  If[f === $Failed, Return[1]];
  d = Exponent[f, x];
  q0 = integralScale[f];
  Do[
    g = primitiveIntegerPolynomial[Expand[(q q0)^d (f /. x -> x/(q q0))]];
    h = {Max[Abs[CoefficientList[g, x]]], -Sign[g /. x -> 0], Abs[Log[Abs[q]]]};
    If[Order[h, hb] == 1, hb = h; best = q q0],
    {q, DeleteDuplicates[Flatten[Table[{s k/l, s l/k}, {k, 1, 12}, {l, 1, 12}, {s, {1, -1}}]]]}];
  best];

principalRoot[u_, t_Integer] := If[t == 1, u, RootReduce[Power[u, 1/t]]];

twoFactorSearch[gd_, target_, a_, n_, d_, stab_] := Module[{c = gd["Scale"], tmax, subs, pairs, yv, mt},
  tmax = If[stab === None, Min[d, Floor[d^2/n]], 1];
  Catch[
    Do[
      subs = Select[gd["Subgroups"], t #["Index"] <= d &];
      If[stab =!= None, subs = Select[subs, SubsetQ[#["Elements"], stab] &]];
      If[subs === {}, Continue[]];
      yv = (gd["NumericRoots"][[#[[target]]]] & /@ gd["Permutations"])^t;
      mt = multiplicationMatrix[gd, yv]/c^t;
      pairs = Select[Join @@ Table[{subs[[i]], subs[[j]]}, {i, Length[subs]}, {j, i, Length[subs]}],
        n <= t #[[1]]["Index"] #[[2]]["Index"] &];
      pairs = SortBy[pairs, {Max[#[[1]]["Index"], #[[2]]["Index"]], #[[1]]["Index"] + #[[2]]["Index"]} &];
      Do[
        With[{res = tryPair[gd, pr, mt, t, a, d]}, If[res =!= $Failed, Throw[res, foundTag]]],
        {pr, pairs}],
      {t, 1, tmax}];
    $Failed, foundTag]];

(* choose a small nullspace vector: LLL-reduce the integer basis, take the shortest E-part *)
shortestVector[ns_, len_] := Module[{ints, red},
  ints = Map[# LCM @@ Denominator[#] &, ns];
  red = If[Length[ints] > 1, LatticeReduce[ints], ints];
  First[SortBy[red, Norm[Take[#, len]] &]]];

tryPair[gd_, pr_, mt_, t_, a_, d_] := Module[{EE = pr[[1]]["FixedField"], FF = pr[[2]]["FixedField"], ns, u, uExact, q, b, cc, degs},
  ns = NullSpace[Join[Transpose[EE], -mt . Transpose[FF], 2]];
  If[ns === {}, Return[$Failed]];
  u = shortestVector[ns, Length[EE]] . EE;
  uExact = elementToAlgebraic[gd, u];
  q = niceScale[uExact];
  b = principalRoot[RootReduce[q uExact], t];
  cc = RootReduce[a/b];
  degs = algebraicDegree /@ {b, cc};
  If[Max[degs] <= d && exactZeroQ[a - b cc],
    <|"Terms" -> {b, cc}, "Exponent" -> t, "FieldDegrees" -> {pr[[1]]["Index"], pr[[2]]["Index"]}|>,
    $Failed]];

(* Exact rank-one tensor test for families of at least three subfields whose product basis spans L. *)
familiesWithProduct[subs_, target_, minSize_] := Module[{rec},
  rec[start_, remaining_, acc_] := Module[{out = {}, i},
    If[remaining == 1, Return[If[Length[acc] >= minSize, {acc}, {}]]];
    Do[If[Divisible[remaining, subs[[i]]["Index"]],
        out = Join[out, rec[i + 1, remaining/subs[[i]]["Index"], Append[acc, subs[[i]]]]]],
      {i, start, Length[subs]}];
    out];
  rec[1, target, {}]];

$multCache = <||>;

tensorSearch[gd_, va_, d_, stab_] := Module[{subs, ord = gd["Order"], fams, count = 0},
  subs = Select[gd["Subgroups"], 1 < #["Index"] <= d &];
  If[stab =!= None, subs = Select[subs, SubsetQ[#["Elements"], stab] &]];
  subs = SortBy[subs, #["Index"] &];
  fams = familiesWithProduct[subs, ord, 3];
  $multCache = <||>;
  Catch[
    Do[count++; If[count > 5000, Throw[$Failed, foundTag]];
      With[{res = tensorTest[gd, fam, va]}, If[res =!= $Failed, Throw[res, foundTag]]], {fam, fams}];
    $Failed, foundTag]];

tensorTest[gd_, fam_, va_] := Module[{bases, prodBasis, mats, coords, dims, tensor, piv, pos, vecs, ok, elems, ord = gd["Order"], idx},
  bases = #["FixedField"] & /@ fam; dims = Length /@ bases;
  mats = Map[Function[B, Map[(If[! KeyExistsQ[$multCache, #], $multCache[#] = multiplicationMatrixOfElement[gd, #]]; $multCache[#]) &, B]], bases];
  idx = Tuples[Range /@ dims];
  prodBasis = Table[Fold[#2 . #1 &, coordinateOfOne[gd], Table[mats[[j, i[[j]]]], {j, Length[fam]}]], {i, idx}];
  If[MatrixRank[prodBasis] < ord, Return[$Failed]];
  coords = LinearSolve[Transpose[prodBasis], va];
  tensor = ArrayReshape[coords, dims];
  pos = FirstPosition[tensor, _?(# != 0 &), Missing["NotFound"], {Length[dims]}];
  If[MissingQ[pos], Return[$Failed]];
  piv = Extract[tensor, pos];
  vecs = Table[Table[Extract[tensor, ReplacePart[pos, j -> i]]/piv, {i, dims[[j]]}], {j, Length[fam]}];
  ok = tensor == piv Fold[Outer[Times, #1, #2] &, First[vecs], Rest[vecs]];
  If[! ok, Return[$Failed]];
  elems = MapThread[#1 . #2 &, {vecs, bases}];
  elems[[1]] = piv elems[[1]];
  elems];

(* merge rational factors and rescale each factor to a small representative *)
cleanProductTerms[terms_] := Module[{rat, rest, q},
  rat = Times @@ Select[terms, rationalQ];
  rest = Select[terms, ! rationalQ[#] &];
  If[rest === {}, Return[{rat}]];
  Do[q = niceScale[rest[[j]]]; rest[[j]] = RootReduce[q rest[[j]]]; rat /= q, {j, 2, Length[rest]}];
  rest[[1]] = RootReduce[rat rest[[1]]];
  q = niceScale[rest[[1]]];
  rest[[1]] = RootReduce[q rest[[1]]];
  If[q != 1, AppendTo[rest, 1/q]];
  rest];

RootProductDecomposition[a_, opts : OptionsPattern[]] := RootProductDecomposition[a, Automatic, opts];

RootProductDecomposition[a_, dmax_, OptionsPattern[]] := Module[
  {in, n, lb, scope = OptionValue["Scope"], trivial, prec, res, attempt = 0},
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  n = in["Degree"];
  If[n == 1 && in["Value"] === 0,
    Return[makeResult[0, Times, {0}, 1, scope, "Trivial", True, True, <|"TwoFactorOptimal" -> True, "NormExponent" -> 1|>]]];
  lb = If[n == 1, 1, lowerBoundFromPolynomial[in["Polynomial"]]];
  trivial := makeResult[a, Times, {RootReduce[a]}, lb, scope, "Trivial", lb == n, lb == n, <|"TwoFactorOptimal" -> (lb == n), "NormExponent" -> 1|>];
  If[n == 1, Return[trivial]];
  If[dmax =!= Automatic && dmax >= n, Return[trivial]];
  If[lb == n, Return[trivial]];
  prec = OptionValue["WorkingPrecision"];
  While[True,
    attempt++;
    res = Catch[productDecompositionCore[a, in, dmax, lb, scope, OptionValue["MaxFactors"], OptionValue["RecursionDepth"],
        OptionValue["TensorTest"], prec, OptionValue["MaxGroupOrder"], OptionValue["MaxTries"]], precTag];
    If[res === "precision",
      If[attempt >= 4, Return[failure["Precision", "Precision escalation failed"]]];
      Message[RootDecomposition::prec, prec]; prec = 2 prec; Continue[]];
    Return[res]]];

productDecompositionCore[a_, in_, dmax_, lb0_, scope_, maxFactors_, depth_, tensorQ_, prec_, maxOrder_, maxTries_] := Module[
  {n = in["Degree"], lb = lb0, gd, c, target, va, stab, dlist, d, two, best, terms, degs, res, tens, sub, extra},
  gd = RootGaloisData[in["Polynomial"], x, "WorkingPrecision" -> prec, "MaxGroupOrder" -> maxOrder, "MaxTries" -> maxTries];
  If[FailureQ[gd], Return[gd]];
  c = gd["Scale"];
  target = locateTarget[gd, a];
  If[target === $Failed, Return[failure["RootIndex", "Could not locate the input among the roots"]]];
  va = gd["RootCoordinates"][[target]]/c;
  stab = If[scope === "InputField", stabilizerOf[gd, target], None];
  lb = Max[lb, exponentBound[gd["Exponent"]]];
  extra = <|"GroupOrder" -> gd["Order"]|>;
  If[lb >= n,
    Return[makeResult[a, Times, {RootReduce[a]}, lb, scope, "Trivial", True, True, Join[<|"TwoFactorOptimal" -> True, "NormExponent" -> 1|>, extra]]]];
  dlist = If[dmax === Automatic, Range[Max[lb, Ceiling[Sqrt[n]]], n - 1], {dmax}];
  (* 1. complete two-factor algorithm (norm-intersection criterion) *)
  two = $Failed;
  Do[two = twoFactorSearch[gd, target, a, n, d, stab]; If[two =!= $Failed, Break[]], {d, dlist}];
  If[two === $Failed && dmax === Automatic, two = <|"Terms" -> {RootReduce[a]}, "Exponent" -> 1, "FieldDegrees" -> {n}|>];
  best = If[two === $Failed, $Failed,
    makeResult[a, Times, two["Terms"], lb, scope,
      If[Length[two["Terms"]] == 1, "CompleteTwoFactorSearch", "NormIntersection"],
      Max[termDegrees[two["Terms"]]] == lb, dmax === Automatic,
      Join[<|"TwoFactorOptimal" -> (dmax === Automatic), "NormExponent" -> two["Exponent"]|>, extra]]];
  If[maxFactors === 2,
    Return[If[best === $Failed, failure["NotFound", "No two-factor representation with the requested maximum degree", <|"MaximumDegree" -> dmax|>], best]]];
  If[best =!= $Failed && best["MaximumDegree"] == lb, Return[best]];
  (* 2. rank-one tensor test for independent families of subfields *)
  If[tensorQ,
    Do[
      If[best =!= $Failed && d >= best["MaximumDegree"], Break[]];
      tens = tensorSearch[gd, va, d, stab];
      If[tens =!= $Failed,
        terms = cleanProductTerms[elementToAlgebraic[gd, #] & /@ tens];
        res = makeResult[a, Times, terms, lb, scope, "TensorRankOne", Max[termDegrees[terms]] == lb, False,
          Join[<|"TwoFactorOptimal" -> False, "NormExponent" -> 1|>, extra]];
        If[res["Verified"] && (best === $Failed || res["MaximumDegree"] < best["MaximumDegree"]), best = res; Break[]]],
      {d, dlist}]];
  If[best =!= $Failed && best["MaximumDegree"] == lb, Return[best]];
  (* 3. recursive splitting of the factors *)
  If[best =!= $Failed && depth > 0 && Length[best["Terms"]] >= 2,
    terms = Join @@ Table[
      If[algebraicDegree[f] > lb,
        sub = RootProductDecomposition[f, "RecursionDepth" -> depth - 1, "WorkingPrecision" -> prec,
                "MaxGroupOrder" -> maxOrder, "TensorTest" -> tensorQ];
        If[! FailureQ[sub] && sub["Verified"], sub["Terms"], {f}],
        {f}],
      {f, best["Terms"]}];
    degs = termDegrees[terms];
    If[Max[degs] < best["MaximumDegree"],
      best = makeResult[a, Times, terms, lb, scope, "RecursiveSplitting", Max[degs] == lb, False,
        Join[<|"TwoFactorOptimal" -> False, "NormExponent" -> 1|>, extra]]]];
  (* 4. small bounded dictionary search *)
  If[best =!= $Failed && best["MaximumDegree"] > lb && OptionValue[RootProductDecomposition, "BoundedSearch"] =!= None,
    Module[{bd = OptionValue[RootProductDecomposition, "BoundedSearch"], dd},
      Do[
        res = RootBoundedDecomposition[a, Times, dd, bd[[1]], bd[[2]]];
        If[! FailureQ[res] && res["Verified"] && res["MaximumDegree"] < best["MaximumDegree"],
          best = Join[res, <|"Scope" -> scope, "TwoFactorOptimal" -> False, "NormExponent" -> 1|>, extra]; Break[]],
        {dd, lb, best["MaximumDegree"] - 1}]]];
  If[best === $Failed, failure["NotFound", "No representation with the requested maximum degree", <|"MaximumDegree" -> dmax|>], best]];

(* ------------------------------------------------------------------ *)
(* Bounded dictionary search                                          *)
(* ------------------------------------------------------------------ *)

RootDecompositionCatalog[d_Integer?Positive, h_Integer?Positive] := Module[{polys},
  polys = Join @@ Table[
    Select[Tuples[Range[-h, h], m + 1],
      Last[#] > 0 && GCD @@ # == 1 && IrreduciblePolynomialQ[FromDigits[Reverse[#], x]] &],
    {m, 1, d}];
  polys = FromDigits[Reverse[#], x] & /@ polys;
  DeleteDuplicates[Join @@ Table[RootReduce[rootObject[p, j]], {p, polys}, {j, Exponent[p, x]}]]];

RootBoundedDecomposition[a_, op : (Plus | Times), d_Integer, h_Integer, r_Integer] := Module[
  {cat, n, lb, search, residual, in, res},
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  n = in["Degree"]; lb = lowerBoundFromPolynomial[in["Polynomial"]];
  If[n <= d, Return[makeResult[a, op, {RootReduce[a]}, lb, "Bounded", "Trivial", lb == n, True]]];
  cat = RootDecompositionCatalog[d, h];
  If[op === Times, cat = Select[cat, # =!= 0 &]];
  cat = Select[cat, algebraicDegree[#] > 1 &];
  residual[prefix_] := RootReduce[If[op === Plus, a - Total[prefix], a/Times @@ prefix]];
  search[prefix_, start_, slots_] := Module[{rr, deg, i},
    rr = residual[prefix];
    deg = algebraicDegree[rr];
    If[deg <= d, Throw[Append[prefix, rr], foundTag]];
    If[slots <= 1 || deg > d^slots || largestPrimeFactor[deg] > d, Return[]];
    Do[search[Append[prefix, cat[[i]]], i, slots - 1], {i, start, Length[cat]}]];
  res = Catch[search[{}, 1, r]; $Failed, foundTag];
  If[res === $Failed,
    failure["NotFoundWithinBounds", "No decomposition found within the bounds", <|"Degree" -> d, "Height" -> h, "Components" -> r|>],
    makeResult[a, op, res, lb, "Bounded", "DictionarySearch", Max[termDegrees[res]] == lb, False]]];

End[];
EndPackage[];
