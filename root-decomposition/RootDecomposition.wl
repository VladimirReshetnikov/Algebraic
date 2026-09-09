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

positiveIntegerQ[v_] := IntegerQ[v] && v > 0;
componentLimitQ[v_] := v === Infinity || positiveIntegerQ[v];
degreeLimitQ[v_] := v === Automatic || positiveIntegerQ[v];
engineOptionsQ[scope_, engine_, prec_, order_, tries_] :=
  MemberQ[{"Global", "InputField"}, scope] && MemberQ[{Automatic, "InputField", "SplittingField"}, engine] &&
  IntegerQ[prec] && prec >= 30 && positiveIntegerQ[order] && positiveIntegerQ[tries];
degreeFailure[d_, lb_] := failure["DegreeBound", "The requested maximum degree is below a proved lower bound",
  <|"MaximumDegree" -> d, "LowerBound" -> lb|>];

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
  If[exactZeroQ[a - rootObject[poly, k]], Return[k]];
  (* Fixed-precision nearest-root matching may tie for very close roots.
     Exact equality remains decisive, so numerical ambiguity is not an input error. *)
  SelectFirst[DeleteCases[Range[n], k], exactZeroQ[a - rootObject[poly, #]] &, $Failed]];

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

(* Gaussian coefficients contribute a C2 factor.  For d >= 2 this does not
   enlarge lcm(1,...,d); only the d = 1 exponent bound changes. *)
gaussianPrimeBound[n_Integer] := Max[1, Max[Select[First /@ FactorInteger[n], # > 2 &] /. {} -> {1}]];
gaussianExponentBound[e_Integer] := If[MemberQ[{1, 2}, e], 1, exponentBound[e]];

(* cycle type at a prime not dividing the discriminant or leading coefficient *)
frobeniusCycleType[poly_, p_] := Sort[Exponent[#[[1]], x] & /@ Select[FactorList[poly, Modulus -> p], Exponent[#[[1]], x] > 0 &]];

frobeniusExponentMultiple[poly_, maxPrimes_: 40] := Module[
  {bad = Discriminant[poly, x] Coefficient[poly, x, Exponent[poly, x]], ps},
  ps = Take[Select[Prime[Range[maxPrimes + 10]], Mod[bad, #] != 0 &], UpTo[maxPrimes]];
  LCM @@ Prepend[Flatten[frobeniusCycleType[poly, #] & /@ ps], 1]];

lowerBoundFromPolynomial[poly_] := Module[{n = Exponent[poly, x], bound},
  bound = largestPrimeFactor[n];
  If[bound == n, bound, Max[bound, exponentBound[frobeniusExponentMultiple[poly]]]]];

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
        w = RandomChoice[Complement[Range[1, Max[60, maxTries]], used]];
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

(* Shared with RootToRadicals: queue-based closure with constant-time membership. *)
groupClosure[mt_, idElem_, gs_, visit_: None] := Module[{seen = ConstantArray[False, Length[mt]], queue = {idElem}, pos = 1, h},
  seen[[idElem]] = True;
  While[pos <= Length[queue],
    Do[h = mt[[queue[[pos]], g]];
      If[! seen[[h]], seen[[h]] = True; AppendTo[queue, h];
        If[visit =!= None, visit[queue[[pos]], g, h]]], {g, gs}];
    pos++];
  Sort[queue]];

(* Subgroup lattice from the multiplication table. *)
subgroupLattice[mt_, idElem_] := Module[{ord = Length[mt], seen, queue, H, J, g, pos = 1},
  seen = <|{idElem} -> {}|>;
  Do[J = groupClosure[mt, idElem, {g}]; If[! KeyExistsQ[seen, J], seen[J] = {g}], {g, ord}];
  queue = Keys[seen];
  While[pos <= Length[queue],
    H = queue[[pos++]];
    Do[
      If[! MemberQ[H, g],
        J = groupClosure[mt, idElem, Append[seen[H], g]];
        If[! KeyExistsQ[seen, J], seen[J] = Join[seen[H], {g}]; AppendTo[queue, J]]],
      {g, ord}]];
  Table[<|"Elements" -> k, "Generators" -> seen[k], "Order" -> Length[k], "Index" -> ord/Length[k]|>, {k, Keys[seen]}]];

elementOrder[mt_, g_, idElem_] := Module[{h = g, k = 1}, While[h != idElem, h = mt[[h, g]]; k++]; k];

retryPrecision[compute_, prec0_] := Module[{prec = prec0, result, attempt = 0},
  While[attempt++ < 4,
    result = Catch[compute[prec], precTag];
    If[result =!= "precision", Return[result]];
    If[attempt < 4, Message[RootDecomposition::prec, prec]; prec *= 2]];
  failure["Precision", "Precision escalation failed"]];

buildGaloisData[poly_, prec0_, maxOrder_, maxTries_] :=
  retryPrecision[Function[prec, Catch[buildGaloisDataAtPrecision[poly, prec, maxOrder, maxTries], failTag]], prec0];

basisValues[nums_, perms_, tower_, basisExp_] := Module[{gens = tower[[All, 1]], pw},
  pw = Table[Prepend[Table[nums[[i]]^e, {e, Max[Flatten[{0, basisExp}]]}], 1], {i, Length[nums]}];
  Table[Times @@ Table[pw[[perm[[gens[[j]]]], ex[[j]] + 1]], {j, Length[gens]}], {perm, perms}, {ex, basisExp}]];

buildGaloisDataAtPrecision[poly_, prec_, maxOrder_, maxTries_] := Module[
  {roots, nums, n, gg, perms, ord, tower, basisExp, val, gram, gramInv, set, mt, idElem,
   rootCoords, auts, subs, fixed, orders, numsPerm, groupGens},
  roots = allRoots[poly];
  n = Length[roots];
  nums = N[roots, prec];
  gg = galoisGroupNumerically[roots, nums, prec, maxOrder, maxTries];
  perms = gg["Permutations"]; ord = gg["Order"]; tower = gg["Tower"];
  basisExp = Tuples[Range[0, # - 1] & /@ tower[[All, 2]]];
  val = basisValues[nums, perms, tower, basisExp];
  gram = roundIntegerMatrix[Transpose[val] . val];
  If[Det[gram] == 0, Throw["precision", precTag]];
  gramInv = Inverse[gram];
  set = Association[Thread[perms -> Range[ord]]];
  mt = Table[set[perms[[i]][[perms[[j]]]]], {i, ord}, {j, ord}];
  idElem = set[Range[n]];
  numsPerm = Map[nums[[#]] &, perms];
  rootCoords = Transpose[gramInv . roundIntegerMatrix[Transpose[val] . numsPerm]];
  subs = subgroupLattice[mt, idElem];
  groupGens = SelectFirst[subs, #["Order"] == ord &]["Generators"];
  auts = ConstantArray[None, ord]; auts[[idElem]] = IdentityMatrix[ord];
  Do[auts[[s]] = gramInv . roundIntegerMatrix[Transpose[val] . val[[mt[[All, s]]]]], {s, groupGens}];
  (* The multiplication table determines every remaining automorphism exactly. *)
  groupClosure[mt, idElem, groupGens, Function[{parent, generator, element},
    If[auts[[element]] === None, auts[[element]] = auts[[parent]] . auts[[generator]]]]];
  (* consistency check: automorphisms permute the root coordinates *)
  Do[If[Transpose[auts[[s]] . Transpose[rootCoords]] != rootCoords[[perms[[s]]]],
    Throw["precision", precTag]], {s, ord}];
  fixed = Table[
    If[sub["Order"] == 1, IdentityMatrix[ord],
      NullSpace[Join @@ Table[auts[[g]] - IdentityMatrix[ord], {g, sub["Generators"]}]]],
    {sub, subs}];
  subs = MapThread[Append[#1, "FixedField" -> #2] &, {subs, fixed}];
  orders = Table[elementOrder[mt, g, idElem], {g, ord}];
  <|"Type" -> "Galois", "Polynomial" -> poly, "Roots" -> roots, "NumericRoots" -> nums, "Precision" -> prec,
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
  If[! PolynomialQ[poly0, var] || ! FreeQ[poly0, _Real] ||
      ! And @@ (rationalQ /@ CoefficientList[poly0, var]) || Exponent[poly0, var] < 1,
    Return[failure["InvalidPolynomial", "Expected a nonconstant polynomial with exact rational coefficients"]]];
  If[! engineOptionsQ["Global", Automatic, OptionValue["WorkingPrecision"], OptionValue["MaxGroupOrder"], OptionValue["MaxTries"]] ||
      ! MemberQ[{True, False}, OptionValue["Cache"]], Return[failure["InvalidOptions", "Invalid Galois computation options"]]];
  poly = primitiveIntegerPolynomial[poly0 /. var -> x];
  n = Exponent[poly, x];
  c = Coefficient[poly, x, n];
  mon = Expand[c^(n - 1) (poly /. x -> x/c)];
  If[! SquareFreeQ[mon], Return[failure["NotSquareFree", "The polynomial is not squarefree"]]];
  (* Scale and OriginalPolynomial belong to the input, not just its integral model.
     Include resource limits so a cached large group cannot bypass a smaller cap. *)
  key = {poly, OptionValue["WorkingPrecision"], OptionValue["MaxGroupOrder"], OptionValue["MaxTries"]};
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

valuesAtPrecision[gd_, prec_] := If[prec <= gd["Precision"], gd["Values"],
  basisValues[N[gd["Roots"], prec], gd["Permutations"], gd["Tower"], gd["BasisExponents"]]];

conjugates[gd_, v_] := gd["Values"] . v;

multiplicationMatrix[gd_, yv_] := gd["GramInverse"] . roundIntegerMatrix[Transpose[gd["Values"]] . (yv gd["Values"])];

multiplicationMatrixOfElement[gd_, v_] := Module[{den = LCM @@ Denominator[v]},
  multiplicationMatrix[gd, conjugates[gd, den v]]/den];

(* Reconstruct one coordinate vector from integral traces; retain the matrix route if a large power
   exhausts trace precision at which the multiplication matrix itself can still be recovered. *)
powerCoordinates[gd_, v_, 0] := coordinateOfOne[gd];
powerCoordinates[gd_, v_, 1] := v;
powerCoordinates[gd_, v_, k_Integer?positiveIntegerQ] := Module[{den = LCM @@ Denominator[v], result},
  result = Catch[gd["GramInverse"] .
    (roundInteger /@ (Transpose[gd["Values"]] . conjugates[gd, den v]^k))/den^k, precTag];
  If[result === "precision",
    With[{matrix = multiplicationMatrixOfElement[gd, v]}, Nest[matrix . # &, v, k - 1]], result]];

(* Fix a denominator once.  For integral B, Norm(B)/B is integral; its conjugates permit exact
   quotient coordinates from integer traces.  Uncertain traces use one lazily cached matrix. *)
powerDivider[gd_, v_] := Module[{den = LCM @@ Denominator[v], values, norm, reciprocals, matrix, divide},
  If[v == 0 v, Return[failure["ZeroDenominator", "The field denominator is zero"]]];
  reciprocals = Catch[
    values = conjugates[gd, den v]; norm = roundInteger[Times @@ values];
    If[norm == 0 || AnyTrue[values, TrueQ[# == 0] &], Throw["precision", precTag]];
    norm/values, precTag];
  matrix[] := matrix[] = multiplicationMatrixOfElement[gd, v];
  divide[num_, 0] := num;
  divide[num_, k_Integer?positiveIntegerQ] := Module[{numDen = LCM @@ Denominator[num], result},
    result = If[reciprocals === "precision", "precision", Catch[
      (den^k/(numDen norm^k)) gd["GramInverse"] .
        (roundInteger /@ (Transpose[gd["Values"]] . (conjugates[gd, numDen num] reciprocals^k))), precTag]];
    If[result === "precision", LinearSolve[MatrixPower[matrix[], k], num], result]];
  divide];

elementDegree[gd_, v_] := Module[{cnt = 0}, Do[If[aut . v == v, cnt++], {aut, gd["Automorphisms"]}]; gd["Order"]/cnt];

coordinateOfOne[gd_] := UnitVector[gd["Order"], 1];

(* exact mean of the conjugates: Tr(y)/[L:Q] with Tr(b_j) = Gram[j,1] *)
meanTrace[gd_, v_] := (v . gd["Gram"][[1]])/gd["Order"];

elementToAlgebraic[gd_, v_] := Module[{reps, d, den, prec, vals, poly, cl, k, cands, mag, need, id = gd["Identity"]},
  If[Rest[v] == 0 Rest[v], Return[First[v]]];
  reps = DeleteDuplicatesBy[Range[gd["Order"]], gd["Automorphisms"][[#]] . v &];
  d = Length[reps];
  den = LCM @@ Denominator[v];
  mag = Max[Abs[conjugates[gd, den v]]];
  need = Ceiling[d Log10[2 Max[mag, 2]]] + 30;
  prec = Max[gd["Precision"], need];
  vals = valuesAtPrecision[gd, prec] . (den v);
  poly = Expand[Times @@ (x - vals[[reps]])];
  cl = roundInteger /@ CoefficientList[poly, x];
  poly = primitiveIntegerPolynomial[FromDigits[Reverse[cl], x] /. x -> den x];
  cands = Table[N[rootObject[poly, j], prec], {j, d}];
  k = First[Ordering[Abs[cands - vals[[id]]/den], 1]];
  RootReduce[rootObject[poly, k]]];

(* ------------------------------------------------------------------ *)
(* Input-field engine: subfields of K = Q(a) by principal subfields     *)
(* (factorization of the minimal polynomial over K), no Galois group.  *)
(* Field data of both engines share the keys "Type", "Order" (dimension),*)
(* "Subgroups" (list with "Index" = field degree, "FixedField" rows).   *)
(* ------------------------------------------------------------------ *)

(* coordinates (length n) of a polynomial expression in the symbol z modulo P(z) *)
polyCoords[expr_, P_, n_] := PadRight[CoefficientList[PolynomialRemainder[Expand[expr], P, z], z], n];

intersectRowSpaces[A_, B_] := Module[{ca, cb},
  ca = NullSpace[A]; cb = NullSpace[B];
  If[ca === {}, Return[B]]; If[cb === {}, Return[A]];
  NullSpace[Join[ca, cb]]];

canonicalRows[rows_] := DeleteCases[RowReduce[rows], {0 ..}];

fieldContainsQ[big_, small_] := MatrixRank[Join[big, small]] == Length[big];

(* Newton power sums p_j = sum of j-th powers of the roots of a monic polynomial *)
powerSums[P_, n_] := Module[{s},
  s[0] = n;
  s[k_] := s[k] = -k Coefficient[P, x, n - k] - Sum[Coefficient[P, x, n - i] s[k - i], {i, k - 1}];
  Table[s[j], {j, 0, n - 1}]];

inputFieldData[poly_] := Module[{n, c, P, Pz, theta, fac, factors, principal, subfields, newS, traces, galois, m, rows, eqs, r, key, data},
  n = Exponent[poly, x];
  c = Coefficient[poly, x, n];
  P = Expand[c^(n - 1) (poly /. x -> x/c)];
  Pz = P /. x -> z;
  key = {"InputField", poly};
  If[KeyExistsQ[$galoisCache, key], Return[$galoisCache[key]]];
  theta = rootObject[P, 1];
  fac = Select[FactorList[P, Extension -> theta], Exponent[#[[1]], x] > 0 &][[All, 1]];
  factors = Map[Function[f, Expand[f /. theta -> z]], fac];
  galois = And @@ (Exponent[#, x] == 1 & /@ factors);
  principal = {};
  Do[
    m = Exponent[g, x];
    If[m == 1 && Expand[g - (x - z)] === 0, Continue[]];   (* only the factor x - theta gives K itself *)
    rows = Table[
      r = PolynomialRemainder[x^j - z^j, g, x];
      Table[polyCoords[Coefficient[r, x, i], Pz, n], {i, 0, m - 1}],
      {j, 0, n - 1}];
    eqs = Flatten[Table[Table[rows[[j + 1, i + 1, k]], {j, 0, n - 1}], {i, 0, m - 1}, {k, n}], 1];
    AppendTo[principal, canonicalRows[NullSpace[eqs]]],
    {g, factors}];
  subfields = {canonicalRows[IdentityMatrix[n]]};
  Do[
    newS = subfields;
    Do[AppendTo[newS, canonicalRows[intersectRowSpaces[S, V]]], {S, subfields}];
    subfields = DeleteDuplicates[newS],
    {V, principal}];
  subfields = DeleteDuplicates[Append[subfields, {UnitVector[n, 1]}]];
  traces = powerSums[P, n];
  data = <|"Type" -> "InputField", "Polynomial" -> P, "PolynomialZ" -> Pz, "Scale" -> c, "Degree" -> n, "Order" -> n,
    "Galois" -> galois, "FactorDegrees" -> Sort[Exponent[#, x] & /@ factors],
    "Subgroups" -> Table[<|"Index" -> Length[S], "FixedField" -> S, "Elements" -> None, "Order" -> n/Length[S]|>, {S, subfields}],
    "SubfieldDegrees" -> Sort[Length /@ subfields], "TraceVector" -> traces|>;
  $galoisCache[key] = data;
  data];

(* generic element operations dispatching on the engine type *)
toExact[fd_, v_] := If[fd["Type"] === "InputField",
  Module[{theta = fd["Theta"]}, RootReduce[Sum[v[[j + 1]] theta^j, {j, 0, fd["Degree"] - 1}]]],
  elementToAlgebraic[fd, v]];

meanTraceOf[fd_, v_] := If[fd["Type"] === "InputField", (v . fd["TraceVector"])/fd["Degree"], meanTrace[fd, v]];

multMatrix[fd_, v_] := If[fd["Type"] === "InputField",
  Module[{n = fd["Degree"], Pz = fd["PolynomialZ"], poly},
    poly = Sum[v[[j + 1]] z^j, {j, 0, n - 1}];
    Transpose[Table[polyCoords[poly z^k, Pz, n], {k, 0, n - 1}]]],
  multiplicationMatrixOfElement[fd, v]];

(* attach the actual input root: theta = c*a as a Root object of P; target coordinates (0,1/c,0,...) *)
attachTarget[fd_, a_] := Module[{P = fd["Polynomial"], c = fd["Scale"], n = fd["Degree"], k},
  k = rootIndexOf[c a, P];
  If[k === $Failed, Return[$Failed]];
  Join[fd, <|"Theta" -> rootObject[P, k], "TargetCoordinates" -> UnitVector[n, 2]/c|>]];

inputFieldAt[poly_, a_] := Module[{fd = inputFieldData[poly]},
  If[FailureQ[fd], $Failed, attachTarget[fd, a]]];

(* ------------------------------------------------------------------ *)
(* Result assembly                                                    *)
(* ------------------------------------------------------------------ *)

termDegrees[terms_] := algebraicDegree /@ terms;

RootDecompositionVerify[a_, terms_List, op : (Plus | Times)] := Module[{degs, ok},
  degs = termDegrees[terms];
  ok = FreeQ[{a, terms}, _Real] && And @@ (positiveIntegerQ /@ degs) && exactZeroQ[a - (op @@ terms)];
  <|"Verified" -> ok, "Degrees" -> degs, "MaximumDegree" -> Max[Prepend[degs, 1]]|>];

makeResult[a_, op_, terms_, lb_, scope_, method_, optimal_, scopeOptimal_, extra_: <||>] := Module[{v, degs},
  v = RootDecompositionVerify[a, terms, op];
  degs = v["Degrees"];
  If[! TrueQ[v["Verified"]], Message[RootDecomposition::verify];
    Return[failure["Verification", "A candidate failed exact verification"]]];
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
  "Engine" -> Automatic,             (* Automatic, "InputField" or "SplittingField" *)
  "Coefficients" -> "Rationals",     (* "Rationals" or "GaussianRationals" *)
  "MaxTerms" -> Infinity,
  "WorkingPrecision" -> 80,
  "MaxGroupOrder" -> 400,
  "MaxTries" -> 12
};

(* maximal fields of degree <= d (contained in the target's field when stab is given) *)
eligibleFields[fd_, d_, stab_: None] :=
  Select[fd["Subgroups"], #["Index"] <= d && (stab === None || SubsetQ[#["Elements"], stab]) &];

candidateFields[gd_, d_, stab_: None] := Module[{subs = eligibleFields[gd, d, stab]},
  Select[subs, Function[H, ! AnyTrue[subs, #["Index"] > H["Index"] &&
    If[gd["Type"] === "Galois", SubsetQ[H["Elements"], #["Elements"]],
      fieldContainsQ[#["FixedField"], H["FixedField"]]] &]]]];

rowSpaceBasis[rows_] := canonicalRows[rows];

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
  {in, n, lb, scope = OptionValue["Scope"], coeffs = OptionValue["Coefficients"], trivial, gaussian},
  If[! degreeLimitQ[dmax] || ! componentLimitQ[OptionValue["MaxTerms"]] ||
      ! MemberQ[{"Rationals", "GaussianRationals"}, coeffs] ||
      ! engineOptionsQ[scope, OptionValue["Engine"], OptionValue["WorkingPrecision"], OptionValue["MaxGroupOrder"], OptionValue["MaxTries"]],
    Return[failure["InvalidOptions", "Invalid additive decomposition options"]]];
  If[coeffs === "GaussianRationals" && OptionValue["MaxTerms"] =!= Infinity,
    Return[failure["UnsupportedOptions", "Finite MaxTerms with Gaussian coefficients requires a rank-constrained search and is not implemented"]]];
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  n = in["Degree"];
  gaussian = coeffs === "GaussianRationals";
  lb = If[n == 1, 1, If[gaussian, gaussianPrimeBound[n], lowerBoundFromPolynomial[in["Polynomial"]]]];
  If[dmax =!= Automatic && dmax < lb, Return[degreeFailure[dmax, lb]]];
  trivial := If[gaussian,
    <|"Terms" -> {{1, RootReduce[a]}}, "Degrees" -> {n}, "MaximumDegree" -> n, "LowerBound" -> lb,
      "Optimal" -> (lb == n), "ScopeOptimal" -> (lb == n), "Scope" -> scope, "Verified" -> True,
      "Expression" -> Inactive[Plus][RootReduce[a]], "Method" -> "Trivial", "Coefficients" -> "GaussianRationals"|>,
    makeResult[a, Plus, {RootReduce[a]}, lb, scope, "Trivial", lb == n, lb == n]];
  If[OptionValue["MaxTerms"] === 1,
    Return[If[dmax === Automatic || n <= dmax,
      makeResult[a, Plus, {RootReduce[a]}, lb, scope, "SingleTerm", lb == n, True],
      failure["NotFound", "The input itself exceeds the degree bound for a single term"]]]];
  If[n == 1 || (dmax =!= Automatic && dmax >= n) || lb == n, Return[trivial]];
  retryPrecision[Function[prec, sumDecompositionCore[a, in, dmax, lb, scope, gaussian, OptionValue["MaxTerms"], prec,
    OptionValue["MaxGroupOrder"], OptionValue["MaxTries"], OptionValue["Engine"]]], OptionValue["WorkingPrecision"]]];

sumDecompositionCore[a_, in_, dmax_, lb0_, scope_, gaussian_, maxTerms_, prec_, maxOrder_, maxTries_, engine_] := Module[
  {n = in["Degree"], lb = lb0, poly, gd, va, stab, res = $Failed, fd},
  poly = in["Polynomial"];
  (* fast path inside K = Q(a): complete within K; globally complete when K is Galois *)
  If[! gaussian && engine =!= "SplittingField",
    fd = inputFieldAt[poly, a];
    If[fd =!= $Failed,
      res = sumSearch[fd, a, fd["TargetCoordinates"], None, n, lb, dmax, scope, maxTerms,
        If[fd["Galois"], "GaloisInputField", "InputFieldSubfields"], fd["Galois"]];
      If[fd["Galois"] || scope === "InputField" || engine === "InputField" ||
          (! FailureQ[res] && res["MaximumDegree"] == lb), Return[res]]]];
  If[gaussian && PolynomialRemainder[poly, x^2 + 1, x] =!= 0, poly = Expand[poly (x^2 + 1)]];
  gd = RootGaloisData[poly, x, "WorkingPrecision" -> prec, "MaxGroupOrder" -> maxOrder, "MaxTries" -> maxTries];
  If[FailureQ[gd], Return[If[res =!= $Failed && ! FailureQ[res], res, gd]]];
  Module[{c = gd["Scale"], target, iCoord, iMult},
    target = locateTarget[gd, a];
    If[target === $Failed, Return[failure["RootIndex", "Could not locate the input among the roots"]]];
    va = gd["RootCoordinates"][[target]]/c;
    stab = If[scope === "InputField", stabilizerOf[gd, target], None];
    lb = Max[lb, If[gaussian, gaussianExponentBound[gd["Exponent"]], exponentBound[gd["Exponent"]]]];
    If[gaussian,
      iCoord = gd["RootCoordinates"][[First[FirstPosition[gd["Roots"], _?(exactZeroQ[# - c I] &)]]]]/c;
      iMult = multiplicationMatrix[gd, conjugates[gd, iCoord]];
      Return[gaussianSumSearch[gd, a, va, iMult, n, lb, dmax, scope, maxTerms, stab]]];
    If[lb >= n,
      If[dmax =!= Automatic && dmax < n, Return[degreeFailure[dmax, lb]]];
      Return[makeResult[a, Plus, {RootReduce[a]}, lb, scope, "CompleteSearch", True, True, <|"GroupOrder" -> gd["Order"]|>]]];
    sumSearch[gd, a, va, stab, n, lb, dmax, scope, maxTerms,
      If[scope === "Global", "SplittingFieldFixedSpaces", "InputFieldSubfields"], scope === "Global"]]];

(* additive search in a field-data structure; complete within the field, globally complete if completeQ *)
sumSearch[fd_, a_, va_, stab_, n_, lb_, dmax_, scope_, maxTerms_, method_, completeQ_] := Module[{dlist, res, extra},
  extra = If[fd["Type"] === "InputField", <|"AmbientDegree" -> fd["Degree"], "AmbientGalois" -> fd["Galois"]|>, <|"GroupOrder" -> fd["Order"]|>];
  dlist = If[dmax === Automatic, Range[lb, n - 1], {dmax}];
  res = Catch[
    Do[
      Module[{cf, spaces, rep, rational = 0, terms = {}, mean, term},
        cf = candidateFields[fd, d, stab];
        spaces = Table[<|"Index" -> H["Index"], "Field" -> H["FixedField"], "Basis" -> H["FixedField"]|>, {H, cf}];
        rep = findSumRepresentation[spaces, va, maxTerms];
        If[rep =!= $Failed,
          Do[mean = meanTraceOf[fd, e[[2]]]; rational += mean;
            term = e[[2]] - mean UnitVector[Length[va], 1];
            If[term != 0 term, AppendTo[terms, term]], {e, rep}];
          terms = toExact[fd, #] & /@ terms;
          (* Centering must not add a component beyond a finite MaxTerms cap. *)
          If[rational != 0,
            If[maxTerms =!= Infinity && Length[terms] >= maxTerms,
              terms[[1]] = RootReduce[terms[[1]] + rational], AppendTo[terms, rational]]];
          If[terms === {}, terms = {0}];
          Throw[makeResult[a, Plus, terms, lb, scope, method,
            Max[termDegrees[terms]] == lb || ((dmax === Automatic) && completeQ && maxTerms === Infinity),
            (dmax === Automatic && (completeQ || scope === "InputField")) || Max[termDegrees[terms]] == lb, extra], foundTag]]],
      {d, dlist}];
    $Failed, foundTag];
  If[res =!= $Failed, Return[res]];
  If[dmax === Automatic,
    makeResult[a, Plus, {RootReduce[a]}, lb, scope, "CompleteSearch", (completeQ && maxTerms === Infinity) || n == lb,
      completeQ || scope === "InputField" || n == lb, extra],
    failure["NotFound", "No representation with the requested maximum degree", Join[<|"MaximumDegree" -> dmax, "Scope" -> scope|>, extra]]]];

gaussianSumSearch[gd_, a_, va_, iMult_, n_, lb_, dmax_, scope_, maxTerms_, stab_] := Module[{dlist, res},
  dlist = If[dmax === Automatic, Range[lb, n - 1], {dmax}];
  res = Catch[
    Do[
      Module[{cf, spaces, rep},
        cf = candidateFields[gd, d, stab];
        spaces = Table[<|"Index" -> H["Index"], "Field" -> H["FixedField"],
          "Basis" -> rowSpaceBasis[Join[H["FixedField"], Map[iMult . # &, H["FixedField"]]]]|>, {H, cf}];
        rep = findSumRepresentation[spaces, va, maxTerms];
        If[rep =!= $Failed, Throw[gaussianResult[gd, a, rep, iMult, lb, scope, dmax === Automatic], foundTag]]],
      {d, dlist}];
    $Failed, foundTag];
  If[res =!= $Failed, Return[res]];
  If[dmax === Automatic,
    <|"Terms" -> {{1, RootReduce[a]}}, "Degrees" -> {n}, "MaximumDegree" -> n, "LowerBound" -> lb, "Optimal" -> (scope === "Global" || n == lb),
      "ScopeOptimal" -> True, "Scope" -> scope, "Verified" -> True, "Expression" -> Inactive[Plus][RootReduce[a]],
      "Method" -> "CompleteSearch", "Coefficients" -> "GaussianRationals", "GroupOrder" -> gd["Order"]|>,
    failure["NotFound", "No representation with the requested maximum degree", <|"MaximumDegree" -> dmax, "Scope" -> scope|>]]];

(* Gaussian mode: each contribution e in E + iE is split as u + i w with u, w in E. *)
gaussianResult[gd_, a_, rep_, iMult_, lb_, scope_, automatic_] := Module[{terms = {}, Bf, sol, u, w, degs, pivot, verified},
  Do[
    Bf = e[[1]]["Field"];
    sol = Quiet[Check[LinearSolve[Transpose[Join[Bf, Map[iMult . # &, Bf]]], e[[2]]], $Failed]];
    If[sol === $Failed, Throw["precision", precTag]];
    u = Take[sol, Length[Bf]] . Bf; w = Drop[sol, Length[Bf]] . Bf;
    Which[
      w == 0 w, AppendTo[terms, {1, u}],
      u == 0 u, AppendTo[terms, {I, w}],
      MatrixRank[{u, w}] == 1, pivot = First[FirstPosition[u, _?(# != 0 &)]];
        AppendTo[terms, {1 + I w[[pivot]]/u[[pivot]], u}],
      True, AppendTo[terms, {1, u}]; AppendTo[terms, {I, w}]],
    {e, rep}];
  terms = Map[{#[[1]], elementToAlgebraic[gd, #[[2]]]} &, terms];
  If[terms === {}, terms = {{1, 0}}];
  degs = algebraicDegree[#[[2]]] & /@ terms;
  verified = exactZeroQ[a - Total[Times @@@ terms]];
  If[! verified, Return[failure["Verification", "A Gaussian candidate failed exact verification"]]];
  <|"Terms" -> terms, "Degrees" -> degs, "MaximumDegree" -> Max[degs], "LowerBound" -> lb,
    "Optimal" -> (Max[degs] == lb || (automatic && scope === "Global")), "ScopeOptimal" -> (automatic || Max[degs] == lb), "Scope" -> scope,
    "Verified" -> verified,
    "Expression" -> Inactive[Plus] @@ (Times @@@ terms), "Method" -> "GaussianFixedSpaces",
    "Coefficients" -> "GaussianRationals", "GroupOrder" -> gd["Order"]|>];

(* ------------------------------------------------------------------ *)
(* Multiplicative decomposition                                       *)
(* ------------------------------------------------------------------ *)

Options[RootProductDecomposition] = {
  "Scope" -> "Global",
  "Engine" -> Automatic,
  "MaxFactors" -> Infinity,
  "RecursionDepth" -> 3,
  "TensorTest" -> True,
  "BoundedSearch" -> {2, 3},          (* {height, factors} for the final quadratic dictionary search, or None *)
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
    v[r_] := If[r == 0, Infinity, IntegerExponent[Numerator[r], p] - IntegerExponent[Denominator[r], p]];
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

compositumDegreeBound[fd_, fields_] := If[fd["Type"] === "Galois",
  fd["Order"]/Length[Intersection @@ (#["Elements"] & /@ fields)], Times @@ (#["Index"] & /@ fields)];

twoFactorSearch[fd_, va_, a_, n_, d_, stab_, scope_, ma_] := Module[{tmax, subs, pairs, mt},
  tmax = If[scope === "Global" && stab === None && (fd["Type"] === "Galois" || fd["Galois"]), Min[d, Floor[d^2/n]], 1];
  Catch[
    Do[
      subs = eligibleFields[fd, d/t, stab];
      If[subs === {}, Continue[]];
      mt = MatrixPower[ma, t];
      pairs = Select[Join @@ Table[{subs[[i]], subs[[j]]}, {i, Length[subs]}, {j, i, Length[subs]}],
        n <= t compositumDegreeBound[fd, #] &];
      pairs = SortBy[pairs, {Max[#[[1]]["Index"], #[[2]]["Index"]], #[[1]]["Index"] + #[[2]]["Index"]} &];
      Do[
        With[{res = tryPair[fd, pr, mt, t, a, d]}, If[res =!= $Failed, Throw[res, foundTag]]],
        {pr, pairs}],
      {t, 1, tmax}];
    $Failed, foundTag]];

(* choose a small nullspace vector: LLL-reduce the integer basis, take the shortest E-part *)
shortestVector[ns_, len_] := Module[{ints, red},
  ints = Map[# LCM @@ Denominator[#] &, ns];
  red = If[Length[ints] > 1, LatticeReduce[ints], ints];
  First[MinimalBy[red, Norm[Take[#, len]] &]]];

tryPair[fd_, pr_, mt_, t_, a_, d_] := Module[{EE = pr[[1]]["FixedField"], FF = pr[[2]]["FixedField"], ns, u, uExact, q, b, cc, degs},
  ns = NullSpace[Join[Transpose[EE], -mt . Transpose[FF], 2]];
  If[ns === {}, Return[$Failed]];
  u = Take[shortestVector[ns, Length[EE]], Length[EE]] . EE;
  uExact = toExact[fd, u];
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

tensorSearch[gd_, va_, d_, stab_, maxFactors_] := Module[{subs, ord = gd["Order"], fams, count = 0},
  subs = SortBy[Select[eligibleFields[gd, d, stab], #["Index"] > 1 &], #["Index"] &];
  fams = Select[familiesWithProduct[subs, ord, 3], Length[#] <= maxFactors &];
  $multCache = <||>;
  Catch[
    Do[count++; If[count > 5000, Throw[$Failed, foundTag]];
      With[{res = tensorTest[gd, fam, va]}, If[res =!= $Failed, Throw[res, foundTag]]], {fam, fams}];
    $Failed, foundTag]];

tensorTest[gd_, fam_, va_] := Module[{bases, prodBasis, mats, coords, dims, tensor, piv, pos, vecs, ok, elems, ord = gd["Order"], idx},
  bases = #["FixedField"] & /@ fam; dims = Length /@ bases;
  If[compositumDegreeBound[gd, fam] < ord, Return[$Failed]];
  mats = Map[Function[B, Map[(If[! KeyExistsQ[$multCache, #], $multCache[#] = multMatrix[gd, #]]; $multCache[#]) &, B]], bases];
  idx = Tuples[Range /@ dims];
  prodBasis = Table[Fold[#2 . #1 &, UnitVector[ord, 1], Table[mats[[j, i[[j]]]], {j, Length[fam]}]], {i, idx}];
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
cleanProductTerms[terms_, maxFactors_: Infinity] := Module[{rat, rest, q},
  rat = Times @@ Select[terms, rationalQ];
  rest = Select[terms, ! rationalQ[#] &];
  If[rest === {}, Return[{rat}]];
  Do[q = niceScale[rest[[j]]]; rest[[j]] = RootReduce[q rest[[j]]]; rat /= q, {j, 2, Length[rest]}];
  rest[[1]] = RootReduce[rat rest[[1]]];
  q = niceScale[rest[[1]]];
  rest[[1]] = RootReduce[q rest[[1]]];
  If[q != 1,
    If[Length[rest] >= maxFactors, rest[[-1]] = RootReduce[rest[[-1]]/q], AppendTo[rest, 1/q]]];
  rest];

RootProductDecomposition[a_, opts : OptionsPattern[]] := RootProductDecomposition[a, Automatic, opts];

RootProductDecomposition[a_, dmax_, OptionsPattern[]] := Module[
  {in, n, lb, scope = OptionValue["Scope"], trivial, bd = OptionValue["BoundedSearch"]},
  If[! degreeLimitQ[dmax] || ! componentLimitQ[OptionValue["MaxFactors"]] ||
      ! IntegerQ[OptionValue["RecursionDepth"]] || OptionValue["RecursionDepth"] < 0 ||
      ! MemberQ[{True, False}, OptionValue["TensorTest"]] ||
      ! (bd === None || (MatchQ[bd, {_Integer, _Integer}] && And @@ (positiveIntegerQ /@ bd))) ||
      ! engineOptionsQ[scope, OptionValue["Engine"], OptionValue["WorkingPrecision"], OptionValue["MaxGroupOrder"], OptionValue["MaxTries"]],
    Return[failure["InvalidOptions", "Invalid multiplicative decomposition options"]]];
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  n = in["Degree"];
  If[n == 1 && in["Value"] === 0,
    Return[makeResult[0, Times, {0}, 1, scope, "Trivial", True, True, <|"TwoFactorOptimal" -> True, "NormExponent" -> 1|>]]];
  lb = If[n == 1, 1, lowerBoundFromPolynomial[in["Polynomial"]]];
  If[dmax =!= Automatic && dmax < lb, Return[degreeFailure[dmax, lb]]];
  trivial := makeResult[a, Times, {RootReduce[a]}, lb, scope, "Trivial", lb == n, lb == n, <|"TwoFactorOptimal" -> (lb == n), "NormExponent" -> 1|>];
  If[OptionValue["MaxFactors"] === 1,
    Return[If[dmax === Automatic || n <= dmax,
      makeResult[a, Times, {RootReduce[a]}, lb, scope, "SingleFactor", lb == n, True,
        <|"TwoFactorOptimal" -> (lb == n), "NormExponent" -> 1|>],
      failure["NotFound", "The input itself exceeds the degree bound for a single factor"]]]];
  If[n == 1 || (dmax =!= Automatic && dmax >= n) || lb == n, Return[trivial]];
  retryPrecision[Function[prec, productDecompositionCore[a, in, dmax, lb, scope, OptionValue["MaxFactors"], OptionValue["RecursionDepth"],
    OptionValue["TensorTest"], prec, OptionValue["MaxGroupOrder"], OptionValue["MaxTries"], OptionValue["Engine"], bd]],
    OptionValue["WorkingPrecision"]]];

productDecompositionCore[a_, in_, dmax_, lb0_, scope_, maxFactors_, depth_, tensorQ_, prec_, maxOrder_, maxTries_, engine_, bounded_] := Module[
  {n = in["Degree"], lb = lb0, gd, fd, res = $Failed},
  (* fast path inside K = Q(a) *)
  If[engine =!= "SplittingField",
    fd = inputFieldAt[in["Polynomial"], a];
    If[fd =!= $Failed,
      res = productSearch[fd, a, fd["TargetCoordinates"], None, n, lb, dmax, scope, maxFactors, depth, tensorQ, prec, maxOrder, maxTries, engine,
        fd["Galois"] || scope === "InputField", bounded];
      If[fd["Galois"] || scope === "InputField" || engine === "InputField" || (! FailureQ[res] && res["MaximumDegree"] == lb),
        Return[res]]]];
  gd = RootGaloisData[in["Polynomial"], x, "WorkingPrecision" -> prec, "MaxGroupOrder" -> maxOrder, "MaxTries" -> maxTries];
  If[FailureQ[gd], Return[If[res =!= $Failed && ! FailureQ[res], res, gd]]];
  Module[{c = gd["Scale"], target, va, stab},
    target = locateTarget[gd, a];
    If[target === $Failed, Return[failure["RootIndex", "Could not locate the input among the roots"]]];
    va = gd["RootCoordinates"][[target]]/c;
    stab = If[scope === "InputField", stabilizerOf[gd, target], None];
    lb = Max[lb, exponentBound[gd["Exponent"]]];
    If[lb >= n,
      If[dmax =!= Automatic && dmax < n, Return[degreeFailure[dmax, lb]]];
      Return[makeResult[a, Times, {RootReduce[a]}, lb, scope, "Trivial", True, True, <|"TwoFactorOptimal" -> True, "NormExponent" -> 1, "GroupOrder" -> gd["Order"]|>]]];
    productSearch[gd, a, va, stab, n, lb, dmax, scope, maxFactors, depth, tensorQ, prec, maxOrder, maxTries, engine, True, bounded]]];

productSearch[fd_, a_, va_, stab_, n_, lb_, dmax_, scope_, maxFactors_, depth_, tensorQ_, prec_, maxOrder_, maxTries_, engine_, completeQ_, bounded_] := Module[
  {dlist, twoDegrees, d, two, best, terms, degs, res, tens, sub, extra, remaining, f, parts, ma},
  extra = If[fd["Type"] === "InputField", <|"AmbientDegree" -> fd["Degree"], "AmbientGalois" -> fd["Galois"]|>, <|"GroupOrder" -> fd["Order"]|>];
  dlist = If[dmax === Automatic, Range[lb, n - 1], {dmax}];
  twoDegrees = Select[dlist, #^2 >= n &];
  (* 1. two-factor algorithm (norm-intersection criterion; complete when the ambient field is Galois) *)
  two = $Failed;
  If[twoDegrees =!= {}, ma = multMatrix[fd, va]];
  Do[two = twoFactorSearch[fd, va, a, n, d, stab, scope, ma]; If[two =!= $Failed, Break[]], {d, twoDegrees}];
  If[two === $Failed && dmax === Automatic, two = <|"Terms" -> {RootReduce[a]}, "Exponent" -> 1, "FieldDegrees" -> {n}|>];
  best = If[two === $Failed, $Failed,
    makeResult[a, Times, two["Terms"], lb, scope,
      If[Length[two["Terms"]] == 1, "CompleteTwoFactorSearch", "NormIntersection"],
      Max[termDegrees[two["Terms"]]] == lb,
      Max[termDegrees[two["Terms"]]] == lb || (maxFactors === 2 && dmax === Automatic && completeQ),
      Join[<|"TwoFactorOptimal" -> (Max[termDegrees[two["Terms"]]] == lb || ((dmax === Automatic) && completeQ)),
        "NormExponent" -> two["Exponent"]|>, extra]]];
  If[maxFactors === 2,
    Return[If[best === $Failed, failure["NotFound", "No two-factor representation with the requested maximum degree", <|"MaximumDegree" -> dmax|>], best]]];
  If[best =!= $Failed && best["MaximumDegree"] == lb, Return[best]];
  (* 2. rank-one tensor test for independent families of subfields *)
  If[tensorQ,
    Do[
      If[best =!= $Failed && d >= best["MaximumDegree"], Break[]];
      tens = tensorSearch[fd, va, d, stab, maxFactors];
      If[tens =!= $Failed,
        terms = cleanProductTerms[toExact[fd, #] & /@ tens, maxFactors];
        res = makeResult[a, Times, terms, lb, scope, "TensorRankOne", Max[termDegrees[terms]] == lb, Max[termDegrees[terms]] == lb,
          Join[<|"TwoFactorOptimal" -> False, "NormExponent" -> 1|>, extra]];
        If[res["Verified"] && (best === $Failed || res["MaximumDegree"] < best["MaximumDegree"]), best = res; Break[]]],
      {d, dlist}]];
  If[best =!= $Failed && best["MaximumDegree"] == lb, Return[best]];
  (* 3. recursive splitting of the factors *)
  If[best =!= $Failed && depth > 0 && Length[best["Terms"]] >= 2,
    remaining = maxFactors; terms = {};
    Do[
      f = best["Terms"][[j]]; parts = {f};
      If[algebraicDegree[f] > lb,
        sub = RootProductDecomposition[f, "RecursionDepth" -> depth - 1, "WorkingPrecision" -> prec,
                "MaxGroupOrder" -> maxOrder, "MaxTries" -> maxTries, "TensorTest" -> tensorQ, "Engine" -> engine,
                "Scope" -> scope, "BoundedSearch" -> bounded, "MaxFactors" -> remaining - Length[best["Terms"]] + j];
        If[! FailureQ[sub] && sub["Verified"], parts = sub["Terms"]]];
      remaining -= Length[parts]; terms = Join[terms, parts],
      {j, Length[best["Terms"]]}];
    degs = termDegrees[terms];
    If[Max[degs] < best["MaximumDegree"],
      best = makeResult[a, Times, terms, lb, scope, "RecursiveSplitting", Max[degs] == lb, Max[degs] == lb,
        Join[<|"TwoFactorOptimal" -> False, "NormExponent" -> 1|>, extra]]]];
  (* 4. small bounded dictionary search (quadratic dictionary only; larger catalogs are enormous) *)
  If[scope === "Global" && bounded =!= None && (best === $Failed || best["MaximumDegree"] > lb),
    Module[{bd = bounded, dd, upper = If[best === $Failed, dmax, best["MaximumDegree"] - 1]},
      Do[
        res = RootBoundedDecomposition[a, Times, dd, bd[[1]], Min[bd[[2]], maxFactors]];
        If[! FailureQ[res] && res["Verified"] && (best === $Failed || res["MaximumDegree"] < best["MaximumDegree"]),
          best = Join[res, <|"Scope" -> scope, "TwoFactorOptimal" -> False, "NormExponent" -> 1|>, extra]; Break[]],
        {dd, lb, Min[2, upper]}]]];
  If[best === $Failed, failure["NotFound", "No representation with the requested maximum degree", <|"MaximumDegree" -> dmax|>], best]];

(* ------------------------------------------------------------------ *)
(* Bounded dictionary search                                          *)
(* ------------------------------------------------------------------ *)

RootDecompositionCatalog[d_Integer?Positive, h_Integer?Positive] := Module[{polys},
  polys = Join @@ Table[
    Select[Tuples[Append[ConstantArray[Range[-h, h], m], Range[h]]],
      GCD @@ # == 1 && IrreduciblePolynomialQ[FromDigits[Reverse[#], x]] &],
    {m, 1, d}];
  polys = FromDigits[Reverse[#], x] & /@ polys;
  DeleteDuplicates[Join @@ Table[RootReduce[rootObject[p, j]], {p, polys}, {j, Exponent[p, x]}]]];

RootDecompositionCatalog[_, _] := failure["InvalidBounds", "Degree and height must be positive integers"];

RootBoundedDecomposition[a_, op : (Plus | Times), d_Integer, h_Integer, r_Integer] := Module[
  {cat, n, lb, search, residual, in, res},
  If[! And @@ (positiveIntegerQ /@ {d, h, r}), Return[failure["InvalidBounds", "Degree, height and component count must be positive integers"]]];
  in = inputData[a];
  If[FailureQ[in], Return[in]];
  n = in["Degree"]; lb = lowerBoundFromPolynomial[in["Polynomial"]];
  If[d < lb, Return[degreeFailure[d, lb]]];
  If[n <= d, Return[makeResult[a, op, {RootReduce[a]}, lb, "Bounded", "Trivial", lb == n, lb == n || r == 1]]];
  (* Degree of a compositum is at most the product of the factor degrees.
     Reject impossible boxes before constructing an exponential-size catalog. *)
  If[n > d^r, Return[failure["NotFoundWithinBounds", "The degree exceeds the product of the component degree bounds",
    <|"Degree" -> d, "Height" -> h, "Components" -> r|>]]];
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
    makeResult[a, op, res, lb, "Bounded", "DictionarySearch", Max[termDegrees[res]] == lb, Max[termDegrees[res]] == lb]]];

RootBoundedDecomposition[_, _, _, _, _] := failure["InvalidBounds", "Expected Plus or Times and positive integer bounds"];

End[];
EndPackage[];
