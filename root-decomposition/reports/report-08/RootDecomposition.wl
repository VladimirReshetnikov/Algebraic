(* RootDecomposition.wl -- exact, certificate-oriented reference code.
   Wolfram Language source, prepared 2026-09-06.
   See article.pdf and README.md for guarantees and testing status.
   No claims of a terminating unrestricted multiplicative optimizer.
*)
BeginPackage["RootDecomposition`"];
AlgebraicDegree::usage = "AlgebraicDegree[a] gives the absolute degree of an exact algebraic number.";
DegreeLowerBound::usage = "DegreeLowerBound[a] gives the largest prime divisor of the degree of a (1 for rational a).";
ComposedPolynomial::usage = "ComposedPolynomial[p,q,x,z,mode] gives the monic polynomial of all pairwise sums or products of roots; mode is \"Sum\" or \"Product\".";
RootPairFromPolynomials::usage = "RootPairFromPolynomials[a,{p,q},x,mode] selects and certifies an exact root pair.";
BoundedPairDecompose::usage = "BoundedPairDecompose[a,mode,d,h] exhaustively searches pairs of irreducible primitive integer polynomials of degree <= d and coefficient height <= h. Failure within bounds is not global impossibility.";
BoundedDecompose::usage = "BoundedDecompose[a,mode,d,h,r] performs a finite exhaustive search with degree <= d, primitive coefficient height <= h, and at most r components. Use small bounds.";
PairCoefficientEquations::usage = "PairCoefficientEquations[a,{m,n},mode] constructs rational-coefficient inverse-resultant equations, using divisibility rather than unjustified equality.";
SumOverSubfields::usage = "SumOverSubfields[a,theta,{eta1,...}] solves for a sum of elements of the specified subfields of Q(theta). A failed span test concerns only those fields.";
GlobalSumDecompose::usage = "GlobalSumDecompose[a] implements the finite normal-closure/fixed-space algorithm, with resource caps. Options \"MaxFieldDegree\" and \"MaxSubgroups\" may be Infinity. Success certifies the global minimum over complex algebraic summands.";
Begin["`Private`"];

ratQ[q_] := MatchQ[q, _Integer | _Rational];
failQ[a_] := MatchQ[a, _Failure];
modeQ[s_] := MemberQ[{"Sum", "Product"}, s];
positiveIntegerQ[n_] := IntegerQ[n] && n > 0;
exactZeroQ[a_] := TrueQ[Quiet[RootReduce[a]] === 0];
combine[terms_List, mode_] := If[mode === "Sum", Total[terms], Times @@ terms];
error[tag_, text_] := Failure[tag, <|"MessageTemplate" -> text|>];

minimal[a_, x_Symbol] := Module[{p},
  If[!FreeQ[a, _Real], Return[error["InexactInput", "Use exact algebraic input, not a floating-point approximation."]]];
  p = Quiet[Check[MinimalPolynomial[RootReduce[a], x], $Failed]];
  If[p === $Failed || !TrueQ[PolynomialQ[p, x]],
    Return[error["NotAlgebraic", "Could not obtain an exact rational minimal polynomial."]]];
  If[!VectorQ[CoefficientList[p, x], ratQ] || Exponent[p, x] < 1,
    Return[error["NotAlgebraic", "The minimal polynomial must have rational coefficients and positive degree."]]];
  Expand[p/Coefficient[p, x, Exponent[p, x]]]
];
AlgebraicDegree[a_] := Module[{x = Unique["x"], p},
  p = minimal[a, x]; If[failQ[p], p, Exponent[p, x]]
];
DegreeLowerBound[a_] := Module[{n = AlgebraicDegree[a]},
  If[failQ[n], Return[n]];
  If[n === 1, 1, Max[First /@ FactorInteger[n]]]
];
rationalPolynomialQ[p_, x_] := TrueQ[PolynomialQ[p, x]] &&
  Exponent[p, x] >= 1 && VectorQ[CoefficientList[p, x], ratQ];
rootList[p_, x_Symbol] := Module[{q = Expand[p]},
  Table[Root[Function[Evaluate[q /. x -> Slot[1]]], k],
    {k, 1, Exponent[q, x]}]
];

ComposedPolynomial[p_, q_, x_Symbol, z_Symbol, mode_?modeQ] :=
 Module[{f, g, n, c, lifted},
  If[x === z, Return[error["Variables", "The input and output polynomial variables must differ."]]];
  If[!FreeQ[{p, q}, _Real],
    Return[error["InexactInput", "Polynomial coefficients must be exact."]]];
  If[!TrueQ[PolynomialQ[p, x] && PolynomialQ[q, x]] ||
     Exponent[p, x] < 1 || Exponent[q, x] < 1,
    Return[error["Polynomials", "Both inputs must be nonconstant polynomials."]]];
  f = Expand[p/Coefficient[p, x, Exponent[p, x]]];
  g = Expand[q/Coefficient[q, x, Exponent[q, x]]];
  If[mode === "Sum", Return[Expand[Resultant[f, g /. x -> z - x, x]]]];
  n = Exponent[g, x]; c = CoefficientList[g, x];
  (* Homogenization avoids uncancelled negative powers of x. *)
  lifted = Sum[c[[j + 1]] z^j x^(n - j), {j, 0, n}];
  Expand[Resultant[f, lifted, x]]
];

certificate[a_, terms_List, mode_, scope_] := Module[{v, ds, lb},
  v = combine[terms, mode];
  If[!exactZeroQ[v - a], Return[error["Uncertified", "Exact equality verification did not succeed."]]];
  ds = AlgebraicDegree /@ terms;
  If[AnyTrue[ds, failQ], Return[error["DegreeFailure", "A component degree could not be certified."]]];
  lb = DegreeLowerBound[a]; If[failQ[lb], Return[lb]];
  <|"Status" -> "Found", "Operation" -> mode,
    "Components" -> terms, "Expression" -> v,
    "Degrees" -> ds, "MaximumDegree" -> Max[ds],
    "ElementaryLowerBound" -> lb,
    "GloballyOptimal" -> TrueQ[Max[ds] == lb],
    "ExactResidual" -> 0, "SearchScope" -> scope|>
];

RootPairFromPolynomials[a_, pq : {_, _}, x_Symbol, mode_?modeQ] :=
 Module[{p = pq[[1]], q = pq[[2]], pair, n},
  n = AlgebraicDegree[a]; If[failQ[n], Return[n]];
  If[!AllTrue[pq, rationalPolynomialQ[#, x] &],
    Return[error["CoefficientField", "Candidate polynomials must have exact rational coefficients."]]];
  pair = SelectFirst[Tuples[{rootList[p, x], rootList[q, x]}],
    exactZeroQ[combine[#, mode] - a] &, Missing["NoRootPair"]];
  If[MissingQ[pair], pair, certificate[a, pair, mode, "Specified polynomial pair"]]
];

(* Search and subgroup routines use local tagged Catch/Throw so that an
   exit crosses every nested Do/Table/While instead of leaving one loop. *)

(* Finite catalog: nonmonic primitive integer polynomials are included. *)
polynomialCatalog[m_Integer, h_Integer, x_Symbol] := Module[{data, p, c},
  data = Reap[
    Do[
      c = Append[low, lead];
      If[Apply[GCD, c] === 1,
        p = c . (x^Range[0, m]);
        If[TrueQ[IrreduciblePolynomialQ[p]], Sow[p]]],
      {lead, 1, h}, {low, Tuples[Range[-h, h], m]}]
  ][[2]];
  If[data === {}, {}, First[data]]
];

BoundedPairDecompose[a_, mode_?modeQ, dmax_?positiveIntegerQ,
   h_?positiveIntegerQ] := Module[
  {x = Unique["x"], z = Unique["z"], p0, n0, lb, cap,
   catalog, pp, qq, r, ans, lo, exitTag = Unique["RootDecompositionExit"]}, Catch[
  p0 = minimal[a, z]; If[failQ[p0], Throw[p0, exitTag]];
  n0 = Exponent[p0, z]; lb = DegreeLowerBound[a];
  If[n0 === 1, Throw[certificate[a, {RootReduce[a]}, mode, "Rational input"], exitTag]];
  If[dmax < lb,
    Throw[<|"Status" -> "ImpossibleByDegreeLowerBound",
      "DegreeBound" -> dmax, "ProvenLowerBound" -> lb,
      "AppliesToAnyNumberOfComponents" -> True|>, exitTag]];
  cap = Min[dmax, n0 - 1];
  catalog[m_] := catalog[m] = polynomialCatalog[m, h, x];
  Do[
    Do[
      If[Max[m, n] != d || m n < n0, Continue[]];
      pp = catalog[m]; qq = catalog[n];
      Do[
        lo = If[m === n, i, 1];
        Do[
          If[mode === "Product" &&
             (Coefficient[pp[[i]], x, 0] === 0 ||
              Coefficient[qq[[j]], x, 0] === 0), Continue[]];
          r = ComposedPolynomial[pp[[i]], qq[[j]], x, z, mode];
          If[failQ[r], Throw[r, exitTag]];
          If[Expand[PolynomialRemainder[r, p0, z]] === 0,
            ans = RootPairFromPolynomials[a, {pp[[i]], qq[[j]]}, x, mode];
            If[AssociationQ[ans],
              Throw[Join[ans, <|"SearchScope" -> "Bounded two-component search",
                "HeightBound" -> h,
                "PolynomialPair" -> {pp[[i]], qq[[j]]},
                "PolynomialVariable" -> x|>], exitTag]];
            Throw[error["RootSelection", "Resultant divisibility held, but exact root selection did not finish successfully."], exitTag]
          ], {j, lo, Length[qq]}], {i, 1, Length[pp]}],
      {m, 1, d}, {n, m, d}],
    {d, lb, cap}];
  If[dmax >= n0,
    Throw[certificate[a, {RootReduce[a]}, mode, "Trivial fallback after a bounded pair search"], exitTag]];
  <|"Status" -> "NotFoundWithinBounds", "DegreeBound" -> dmax,
    "HeightBound" -> h, "NumberOfComponents" -> 2,
    "BoundedSearchExhausted" -> True,
    "GlobalImpossibilityProved" -> False|>

  , exitTag]
];

(* General finite search. This intentionally favors transparency over speed. *)
BoundedDecompose[a_, mode_?modeQ, dmax_?positiveIntegerQ,
   h_?positiveIntegerQ, rmax_?positiveIntegerQ] := Module[
  {x = Unique["x"], z = Unique["z"], p0, n0, lb, cap,
   catalog, polys, ds, ps, r, tuple, ans, exitTag = Unique["RootDecompositionExit"]}, Catch[
  If[rmax === 2, Throw[BoundedPairDecompose[a, mode, dmax, h], exitTag]];
  p0 = minimal[a, x]; If[failQ[p0], Throw[p0, exitTag]];
  n0 = Exponent[p0, x]; lb = DegreeLowerBound[a];
  If[n0 === 1, Throw[certificate[a, {RootReduce[a]}, mode, "Rational input"], exitTag]];
  If[dmax < lb, Throw[<|"Status" -> "ImpossibleByDegreeLowerBound",
    "ProvenLowerBound" -> lb, "AppliesToAnyNumberOfComponents" -> True|>, exitTag]];
  cap = Min[dmax, n0 - 1];
  catalog[m_] := catalog[m] = polynomialCatalog[m, h, x];
  Do[
    polys = Join @@ Table[catalog[m], {m, 1, d}];
    If[mode === "Product", polys = Select[polys, Coefficient[#, x, 0] =!= 0 &]];
    ds = Exponent[#, x] & /@ polys;
    Do[
      Do[
        If[!OrderedQ[ids] || Max[ds[[ids]]] != d || (Times @@ ds[[ids]]) < n0, Continue[]];
        ps = polys[[ids]]; r = First[ps];
        Do[r = ComposedPolynomial[r, next, x, z, mode];
          If[failQ[r], Throw[r, exitTag]]; r = r /. z -> x,
          {next, Rest[ps]}];
        If[Expand[PolynomialRemainder[r, p0, x]] === 0,
          tuple = SelectFirst[Tuples[rootList[#, x] & /@ ps],
            exactZeroQ[combine[#, mode] - a] &, Missing["RootTuple"]];
          If[MissingQ[tuple], Throw[error["RootSelection", "The exact root-tuple search did not certify the resultant witness."], exitTag]];
          ans = certificate[a, tuple, mode, "Bounded multicomponent search"];
          If[failQ[ans], Throw[ans, exitTag]];
          Throw[Join[ans, <|"HeightBound" -> h, "ComponentCountBound" -> rmax,
            "PolynomialTuple" -> ps, "PolynomialVariable" -> x|>], exitTag]
        ], {ids, Tuples[Range[Length[polys]], count]}],
      {count, 2, rmax}],
    {d, lb, cap}];
  If[dmax >= n0, Throw[certificate[a, {RootReduce[a]}, mode, "Trivial fallback after bounded search"], exitTag]];
  <|"Status" -> "NotFoundWithinBounds", "DegreeBound" -> dmax,
    "HeightBound" -> h, "ComponentCountBound" -> rmax,
    "BoundedSearchExhausted" -> True, "GlobalImpossibilityProved" -> False|>

  , exitTag]
];

PairCoefficientEquations[a_, mn : {_?positiveIntegerQ, _?positiveIntegerQ},
   mode_?modeQ] := Module[{x = Unique["x"], z = Unique["z"],
   aa, bb, p, q, r, p0, m = mn[[1]], n = mn[[2]], rem},
  p0 = minimal[a, z]; If[failQ[p0], Return[p0]];
  aa = Table[Unique["a"], {m}]; bb = Table[Unique["b"], {n}];
  p = x^m + aa . (x^Range[0, m - 1]);
  q = x^n + bb . (x^Range[0, n - 1]);
  r = ComposedPolynomial[p, q, x, z, mode];
  If[failQ[r], Return[r]];
  rem = Expand[PolynomialRemainder[r, p0, z]];
  <|"Equations" -> Thread[CoefficientList[rem, z] == 0],
    "Unknowns" -> Join[aa, bb], "FactorPolynomials" -> {p, q},
    "Variable" -> x, "OutputVariable" -> z,
    "RequiredCoefficientDomain" -> Rationals|>
];

(* Coordinate work uses an algebraic-integer primitive element. *)
integralGenerator[t_] := Module[{x = Unique["x"], p, c},
  p = minimal[t, x]; If[failQ[p], Return[p]];
  c = Apply[LCM, Denominator /@ CoefficientList[p, x]];
  RootReduce[c t]
];
coordinates[a_, theta_, n_Integer] := Module[{an, p, x = Unique["x"], c},
  an = Quiet[Check[ToNumberField[a, theta], $Failed]];
  If[an === $Failed || !FreeQ[an, _ToNumberField],
    Return[error["FieldMembership", "The number could not be represented in the specified field."]]];
  If[Head[an] === AlgebraicNumber && !exactZeroQ[First[an] - theta],
    Return[error["GeneratorChanged", "The coordinate generator changed unexpectedly."]]];
  p = Quiet[Check[AlgebraicNumberPolynomial[an, x], $Failed]];
  If[p === $Failed || !TrueQ[PolynomialQ[p, x]],
    Return[error["Coordinates", "Could not obtain a polynomial coordinate representation."]]];
  c = CoefficientList[p, x];
  If[Length[c] > n || !VectorQ[c, ratQ],
    Return[error["Coordinates", "Coordinates were not a rational power-basis vector."]]];
  PadRight[c, n]
];

(* Each block is a basis of a supplied subfield; contributions are grouped. *)
solveBlocks[target_List, blocks_List] := Module[{rows, mat, b, c, offset = 0, parts},
  rows = Join @@ blocks;
  If[rows === {}, Return[Missing["OutsideSpan"]]];
  mat = Transpose[rows];
  If[MatrixRank[mat] < MatrixRank[Join[mat, List /@ target, 2]],
    Return[Missing["OutsideSpan"]]];
  c = Quiet[Check[LinearSolve[mat, target], $Failed]];
  If[c === $Failed || !VectorQ[c, ratQ] || mat . c =!= target,
    Return[error["LinearSolve", "Exact coordinate solving did not succeed."]]];
  parts = Table[
    b = c[[offset + 1 ;; offset + Length[block]]] . block;
    offset += Length[block]; b,
    {block, blocks}];
  parts
];
SumOverSubfields[a_, t_, etas_List] := Module[{theta, n, av, blocks,
   degs, coords, parts, terms, powers, ans, exitTag = Unique["RootDecompositionExit"]}, Catch[
  theta = integralGenerator[t]; If[failQ[theta], Throw[theta, exitTag]];
  n = AlgebraicDegree[theta]; av = coordinates[a, theta, n];
  If[failQ[av], Throw[av, exitTag]];
  degs = AlgebraicDegree /@ etas;
  If[AnyTrue[degs, failQ], Throw[error["Subfield", "A subfield generator is not exact algebraic."], exitTag]];
  blocks = Table[
    coords = Table[coordinates[etas[[i]]^j, theta, n], {j, 0, degs[[i]] - 1}];
    If[AnyTrue[coords, failQ], Throw[error["Subfield", "A supplied subfield is not contained in the ambient field."], exitTag]];
    coords, {i, Length[etas]}];
  parts = solveBlocks[av, blocks];
  If[failQ[parts] || MissingQ[parts], Throw[parts, exitTag]];
  powers = theta^Range[0, n - 1];
  terms = Select[RootReduce[# . powers] & /@ parts, !exactZeroQ[#] &];
  If[terms === {}, terms = {0}];
  ans = certificate[a, terms, "Sum", "Specified subfields only"];
  ans

  , exitTag]
];

(* All subgroups of a small group, from its exact multiplication table. *)
subgroupClosure[generators_List, table_List, id_Integer] :=
  FixedPoint[Union[#, Flatten[table[[#, generators]]]] &, {id}];
allSubgroups[table_List, id_Integer, limit_] := Module[
  {groups = {{id}}, at = 1, h, k, count = Length[table], exitTag = Unique["RootDecompositionExit"]}, Catch[
  While[at <= Length[groups],
    h = groups[[at]];
    Do[
      If[!MemberQ[h, g],
        k = subgroupClosure[Append[h, g], table, id];
        If[!MemberQ[groups, k],
          If[Length[groups] >= limit,
            Throw[error["SubgroupLimit", "Subgroup enumeration exceeded the configured resource cap."], exitTag]];
          AppendTo[groups, k]]], {g, 1, count}];
    at++];
  groups

  , exitTag]
];

Options[GlobalSumDecompose] = {"MaxFieldDegree" -> 72, "MaxSubgroups" -> 10000};
GlobalSumDecompose[a_, OptionsPattern[]] := Module[
  {x = Unique["x"], p, roots, nf, gens, theta, n, q, images,
   imageVectors, polynomials, matrices, id, table, pos, groups,
   fields, av, powers, chosen, blocks, parts, terms, ans,
   separators = {}, mat, w, n0, lb, fieldCap, subgroupCap, exitTag = Unique["RootDecompositionExit"]}, Catch[
  fieldCap = OptionValue["MaxFieldDegree"];
  subgroupCap = OptionValue["MaxSubgroups"];
  If[!(fieldCap === Infinity || positiveIntegerQ[fieldCap]) ||
     !(subgroupCap === Infinity || positiveIntegerQ[subgroupCap]),
    Throw[error["Options", "Resource caps must be positive integers or Infinity."], exitTag]];
  p = minimal[a, x]; If[failQ[p], Throw[p, exitTag]];
  n0 = Exponent[p, x]; lb = DegreeLowerBound[a];
  If[n0 === 1, Throw[certificate[a, {RootReduce[a]}, "Sum", "Rational input"], exitTag]];
  roots = rootList[p, x];
  (* All is essential: request the smallest common field. *)
  nf = Quiet[Check[ToNumberField[roots, All], $Failed]];
  If[nf === $Failed || !ListQ[nf],
    Throw[error["SplittingField", "Could not construct a common splitting field."], exitTag]];
  gens = Cases[nf, an_AlgebraicNumber :> First[an], {1}];
  If[gens === {}, Throw[error["SplittingField", "No primitive generator was returned."], exitTag]];
  theta = integralGenerator[First[gens]];
  If[failQ[theta], Throw[theta, exitTag]];
  q = minimal[theta, x]; If[failQ[q], Throw[q, exitTag]];
  n = Exponent[q, x];
  If[n > fieldCap, Throw[Failure["FieldDegreeLimit",
    <|"MessageTemplate" -> "The splitting-field degree exceeds the configured cap.",
      "FieldDegree" -> n, "Cap" -> fieldCap|>], exitTag]];
  (* Verify containment; then all conjugates of theta must lie in this field. *)
  If[AnyTrue[coordinates[#, theta, n] & /@ roots, failQ],
    Throw[error["SplittingField", "A target conjugate is missing from the proposed field."], exitTag]];
  images = rootList[q, x];
  imageVectors = coordinates[#, theta, n] & /@ images;
  If[AnyTrue[imageVectors, failQ],
    Throw[error["NotNormal", "The proposed common field is not normal."], exitTag]];
  polynomials = (# . (x^Range[0, n - 1])) & /@ imageVectors;
  matrices = Table[Transpose[Table[
    PadRight[CoefficientList[PolynomialRemainder[polynomials[[i]]^j, q, x], x], n],
    {j, 0, n - 1}]], {i, 1, n}];
  id = SelectFirst[Range[n], matrices[[#]] === IdentityMatrix[n] &, Missing["Identity"]];
  If[MissingQ[id], Throw[error["Automorphisms", "The identity automorphism was not located."], exitTag]];
  table = Table[
    pos = FirstPosition[imageVectors, matrices[[i]] . imageVectors[[j]], Missing["Product"]];
    If[MissingQ[pos], Throw[error["Automorphisms", "The proposed automorphisms are not closed under composition."], exitTag]];
    First[pos], {i, 1, n}, {j, 1, n}];
  groups = allSubgroups[table, id, subgroupCap]; If[failQ[groups], Throw[groups, exitTag]];
  fields = Table[
    <|"Index" -> n/Length[h], "Subgroup" -> h,
      "Basis" -> NullSpace[Join @@ (matrices[[#]] - IdentityMatrix[n] & /@ h)]|>,
    {h, Select[groups, n/Length[#] <= n0 &]}];
  av = coordinates[a, theta, n]; If[failQ[av], Throw[av, exitTag]];
  powers = theta^Range[0, n - 1];
  Do[
    chosen = Select[fields, #["Index"] <= d &];
    blocks = #["Basis"] & /@ chosen;
    parts = solveBlocks[av, blocks];
    If[failQ[parts], Throw[parts, exitTag]];
    If[!MissingQ[parts],
      terms = Select[RootReduce[# . powers] & /@ parts, !exactZeroQ[#] &];
      If[terms === {}, terms = {0}];
      ans = certificate[a, terms, "Sum", "All subfields of the normal closure"];
      If[failQ[ans], Throw[ans, exitTag]];
      If[ans["MaximumDegree"] =!= d,
        Throw[error["InternalConsistency", "The attained degree disagrees with the first successful fixed-space threshold."], exitTag]];
      Throw[Join[ans, <|"GloballyOptimal" -> True,
        "ProvenMinimum" -> d,
        "OptimalityMethod" -> "Exhaustive fixed-space criterion in the normal closure",
        "PrimitiveElement" -> theta, "FieldDegree" -> n,
        "AutomorphismMatrices" -> matrices, "MultiplicationTable" -> table,
        "Subgroups" -> groups, "SeparatingFunctionals" -> separators|>], exitTag]
    ];
    mat = Transpose[Join @@ blocks];
    w = SelectFirst[NullSpace[Transpose[mat]], # . av =!= 0 &, Missing["Separator"]];
    AppendTo[separators, <|"DegreeBound" -> d, "Functional" -> w|>],
    {d, lb, n0}];
  error["InternalConsistency", "The full-degree field should always provide a representation."]

  , exitTag]
];

End[];
EndPackage[];
