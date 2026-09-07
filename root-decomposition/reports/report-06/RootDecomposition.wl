(* RootDecomposition.wl -- exact arithmetic reference implementation.
   See article.pdf for proofs and, especially, the scopes of minimality.
   No call in this file performs an unrestricted rational-point search.
   A resource-limit Failure is NOT a proof of nonexistence.
   Native Wolfram-kernel execution was unavailable during preparation;
   the underlying algorithms were independently exercised in SymPy. *)

BeginPackage["RootDecomposition`"];
AlgebraicDegree::usage = "AlgebraicDegree[a] gives [Q(a):Q] for an exact algebraic number.";
PrimeDegreeLowerBound::usage = "PrimeDegreeLowerBound[a] is a global lower bound for both decomposition problems.";
ComposedPolynomial::usage = "ComposedPolynomial[p,q,x,\"Sum\"|\"Product\"] gives the monic composed polynomial.";
ExactRootList::usage = "ExactRootList[p,x] lists all distinct roots of a rational polynomial exactly.";
PairFromPolynomials::usage = "PairFromPolynomials[a,p,q,x,operation] certifies a root pair, including its branches.";
PairFromOnePolynomial::usage = "PairFromOnePolynomial[a,p,x,operation,d] tests every root b of p and the complementary term/factor.";
BoundedTwoRootSearch::usage = "BoundedTwoRootSearch[a,operation,d,h] searches first-component minimal polynomials of degree <= d and primitive integer coefficient height <= h.";
AllSubfieldBases::usage = "AllSubfieldBases[theta] returns all embedded subfields of Q(theta) as rational row bases, or an explicit Failure.";
MinSumInField::usage = "MinSumInField[a] minimizes the largest degree for any finite sum inside Q(a). Option \"AmbientGenerator\" specifies a different ambient field.";
MinTwoFactorInField::usage = "MinTwoFactorInField[a] minimizes the largest degree for a product of at most two factors inside Q(a). It does not minimize arbitrary-length products.";
MinSumGlobally::usage = "MinSumGlobally[a] solves the unrestricted additive problem by a normal-closure reduction, subject to explicit resource limits.";
FiniteCatalogSearch::usage = "FiniteCatalogSearch[a,catalog,operation,r] searches products/sums of at most r members of a finite exact catalog.";

Begin["`Private`"];
$failureTag = "RootDecompositionFailure";
SetAttributes[guarded, HoldAll];
guarded[body_] := Catch[body, $failureTag];
require[condition_, tag_, data_: <||>] :=
  If[! TrueQ[condition], Throw[Failure[tag, data], $failureTag]];
need[x_] := If[FailureQ[x], Throw[x, $failureTag], x];
ratQ[x_] := IntegerQ[x] || Head[x] === Rational;
zeroQ[x_] := TrueQ[Quiet[Check[RootReduce[x], $Failed]] === 0];

exactNumber[a_] := Module[{b},
  require[FreeQ[a, _Real], "InexactInput", <|"Input" -> a|>];
  b = Quiet[Check[RootReduce[a], $Failed]];
  require[b =!= $Failed && FreeQ[b, _Real], "InvalidAlgebraicInput"];
  b
];
monic[p_, x_Symbol] := Module[{f = Expand[p], n, c},
  require[PolynomialQ[f, x], "NotPolynomial"];
  n = Exponent[f, x];
  require[IntegerQ[n] && n >= 1, "NonpositiveDegree"];
  c = CoefficientList[f, x];
  require[VectorQ[c, ratQ], "NonrationalCoefficients"];
  Expand[f/Last[c]]
];
minpoly[a_, x_Symbol] := Module[{p},
  p = Quiet[Check[MinimalPolynomial[exactNumber[a], x], $Failed]];
  require[p =!= $Failed, "MinimalPolynomialFailed"];
  monic[p, x]
];
degree[a_] := Module[{x = Unique["x"]}, Exponent[minpoly[a, x], x]];
AlgebraicDegree[a_] := guarded[degree[a]];
lowerBound[a_] := Module[{n = degree[a]},
  If[n == 1, 1, Max[FactorInteger[n][[All, 1]]]]
];
PrimeDegreeLowerBound[a_] := guarded[lowerBound[a]];
opHead[op_] := Switch[op, "Sum", Plus, "Product", Times,
  _, require[False, "UnknownOperation", <|"Operation" -> op|>]];

ComposedPolynomial[p_, q_, x_Symbol, op_] := guarded[Module[
  {f = monic[p, x], g = monic[q, x], t = Unique["t"], m, c, h},
  m = Exponent[g, x]; c = CoefficientList[g, x];
  h = Switch[op,
    "Sum", Expand[g /. x -> x - t],
    "Product", Sum[c[[j + 1]] x^j t^(m - j), {j, 0, m}],
    _, require[False, "UnknownOperation"]
  ];
  monic[Resultant[f /. x -> t, h, t], x]
]];
ExactRootList[p_, x_Symbol] := guarded[Module[{f = monic[p, x], fun},
  f = PolynomialQuotient[f, PolynomialGCD[f, D[f, x]], x];
  fun = Function[Evaluate[f /. x -> Slot[1]]];
  Table[Root[fun, j], {j, Exponent[f, x]}]
]];
certificate[a_, pieces_List, op_, scope_] := Module[{d, h = opHead[op]},
  require[Length[pieces] >= 1, "EmptyCertificate"];
  require[zeroQ[(h @@ pieces) - a], "IdentityCertificationFailed"];
  d = Max[degree /@ pieces];
  <|"Components" -> pieces,
    "InactiveExpression" -> Switch[op, "Sum", Apply[Inactive[Plus], pieces],
      "Product", Apply[Inactive[Times], pieces]],
    "ComponentDegrees" -> (degree /@ pieces),
    "MaxDegree" -> d,
    "ExactIdentityVerified" -> True,
    "Scope" -> scope,
    "GlobalLowerBound" -> lowerBound[a],
    "GlobalMinimumCertified" -> (d == lowerBound[a])|>
];
PairFromPolynomials[a_, p_, q_, x_Symbol, op_] := guarded[Module[
  {aa = exactNumber[a], h = opHead[op], r, pairs, hit},
  r = need[ComposedPolynomial[p, q, x, op]];
  require[Expand[PolynomialRemainder[r, minpoly[aa, x], x]] === 0,
    "NoPairForThesePolynomials"];
  pairs = Tuples[{need[ExactRootList[p, x]], need[ExactRootList[q, x]]}];
  hit = SelectFirst[pairs, zeroQ[(h @@ #) - aa] &, Missing["NotFound"]];
  require[! MissingQ[hit], "BranchSearchFailed"];
  certificate[aa, hit, op, "Specified polynomial pair"]
]];
PairFromOnePolynomial[a_, p_, x_Symbol, op_, d_Integer?Positive] := guarded[
 Module[{aa = exactNumber[a], roots, b, c},
  opHead[op]; roots = need[ExactRootList[p, x]];
  Do[
    b = roots[[j]];
    If[degree[b] > d || (op == "Product" && zeroQ[b]), Continue[]];
    c = RootReduce[If[op == "Sum", aa - b, aa/b]];
    If[degree[c] <= d,
      Return[certificate[aa, {b, c}, op, "One specified polynomial"]]],
    {j, Length[roots]}];
  Failure["NoPairForThisPolynomial", <|"DegreeBound" -> d|>]
 ]
];
Options[BoundedTwoRootSearch] = {"MaxCoefficientVectors" -> 100000};
BoundedTwoRootSearch[a_, op_, d_Integer?Positive, h_Integer?Positive,
  OptionsPattern[]] := guarded[Module[
  {aa = exactNumber[a], x = Unique["x"], count, checked = 0,
   cs, p, result, top, tuple, lo},
  opHead[op]; lo = lowerBound[aa];
  require[d >= lo, "ImpossibleDegreeBound",
    <|"ProvedGlobalLowerBound" -> lo|>];
  If[degree[aa] <= d,
    Return[certificate[aa, {aa}, op, "One-component solution"]]];
  count = Sum[h (2 h + 1)^m, {m, 2, d}];
  require[count <= OptionValue["MaxCoefficientVectors"], "ResourceLimit",
    <|"CoefficientVectorsRequired" -> count|>];
  Do[
    Do[
      cs = Append[tuple, top];
      If[Apply[GCD, Abs[cs]] != 1, Continue[]];
      p = cs . x^Range[0, m];
      If[! TrueQ[IrreduciblePolynomialQ[p]], Continue[]];
      checked++;
      result = PairFromOnePolynomial[aa, p, x, op, d];
      If[FailureQ[result] && result[[1]] =!= "NoPairForThisPolynomial",
        need[result]];
      If[! FailureQ[result],
        Return[Join[result, <|"FirstPolynomial" -> p,
          "PolynomialVariable" -> x,
          "CheckedPolynomials" -> checked|>]]],
      {top, 1, h}, {tuple, Tuples[Range[-h, h], m]}],
    {m, 2, d}];
  Failure["NoPairInHeightBound", <|"DegreeBound" -> d,
    "FirstPolynomialHeightBound" -> h,
    "CheckedPolynomials" -> checked,
    "GlobalNonexistenceProved" -> False|>]
]];

(* A single, integral ambient generator prevents silent basis changes. *)
fieldData[a_] := Module[{theta = exactNumber[a], x = Unique["z"], p, s, n},
  p = minpoly[theta, x];
  s = Apply[LCM, Denominator /@ CoefficientList[p, x]];
  theta = RootReduce[s theta]; p = minpoly[theta, x];
  n = Exponent[p, x];
  require[VectorQ[CoefficientList[p, x], IntegerQ], "IntegralGeneratorFailed"];
  <|"Generator" -> theta, "Variable" -> x, "Polynomial" -> p,
    "Degree" -> n, "One" -> UnitVector[n, 1]|>
];
coordinates[b_, f_Association] := Module[{r, n = f["Degree"], v},
  r = exactNumber[b];
  If[ratQ[r], Return[PadRight[{r}, n]]];
  r = Quiet[Check[ToNumberField[r, f["Generator"]], $Failed]];
  require[Head[r] === AlgebraicNumber, "NotInAmbientField", <|"Element" -> b|>];
  require[zeroQ[r[[1]] - f["Generator"]], "UnexpectedGenerator"];
  v = PadRight[r[[2]], n];
  require[Length[v] == n && VectorQ[v, ratQ], "InvalidCoordinates"];
  v
];
fromCoordinates[v_List, f_Association] :=
  RootReduce[AlgebraicNumber[f["Generator"], v]];
fieldMultiply[u_List, v_List, f_Association] := Module[
  {x = f["Variable"], n = f["Degree"], powers, p},
  powers = x^Range[0, n - 1];
  p = PolynomialRemainder[Expand[(u . powers) (v . powers)], f["Polynomial"], x];
  PadRight[CoefficientList[p, x], n]
];
rowBasis[m_List] := Select[RowReduce[m], ! AllTrue[#, (# === 0) &] &];
algebraBasis[generators_List, f_Association] := Module[{b = {f["One"]}, c},
  While[True,
    c = rowBasis[Join[b, Flatten[Table[fieldMultiply[u, v, f],
      {u, b}, {v, generators}], 1]]];
    If[Length[c] == Length[b], Return[c]];
    b = c
  ]
];
subfieldBases[f_Association, cap_] := Module[
  {t = Unique["t"], x = f["Variable"], n = f["Degree"], fac,
   polys, linear, rest, count, subset, g, k, gens, b, out = {}},
  If[n == 1, Return[{{1}}]];
  fac = Quiet[Check[FactorList[f["Polynomial"] /. x -> t,
    Extension -> f["Generator"]], $Failed]];
  require[ListQ[fac] && Length[fac] >= 2, "NumberFieldFactorizationFailed"];
  require[AllTrue[Rest[fac], Last[#] == 1 &], "UnexpectedRepeatedFactor"];
  polys = (Expand[#[[1]]/Coefficient[#[[1]], t, Exponent[#[[1]], t]]] &) /@ Rest[fac];
  require[AllTrue[CoefficientList[Expand[Times @@ polys -
      (f["Polynomial"] /. x -> t)], t], zeroQ], "FactorizationCheckFailed"];
  linear = Select[Range[Length[polys]],
    Exponent[polys[[#]], t] == 1 && zeroQ[polys[[#]] /. t -> f["Generator"]] &];
  require[Length[linear] == 1, "DistinguishedLinearFactorMissing"];
  rest = Delete[polys, {First[linear]}]; count = 2^Length[rest];
  require[count <= cap, "ResourceLimit", <|"DivisorsRequired" -> count,
    "AmbientDegree" -> n, "NoNonexistenceConclusion" -> True|>];
  Do[
    subset = If[rest === {}, {}, Pick[rest, IntegerDigits[mask, 2, Length[rest]], 1]];
    g = Expand[polys[[First[linear]]] (Times @@ subset)];
    k = Exponent[g, t];
    If[Mod[n, k] != 0, Continue[]];
    gens = coordinates[#, f] & /@ Most[CoefficientList[g, t]];
    b = algebraBasis[gens, f];
    If[Length[b] == n/k && ! MemberQ[out, b], AppendTo[out, b]],
    {mask, 0, count - 1}];
  require[MemberQ[out, {f["One"]}] && MemberQ[out, IdentityMatrix[n]],
    "SubfieldEnumerationCheckFailed"];
  SortBy[out, Length]
];
Options[AllSubfieldBases] = {"MaxDivisors" -> 65536};
AllSubfieldBases[theta_, OptionsPattern[]] := guarded[Module[{f, b},
  f = fieldData[theta]; b = subfieldBases[f, OptionValue["MaxDivisors"]];
  <|"AmbientField" -> f, "Bases" -> b, "Degrees" -> (Length /@ b),
    "Complete" -> True|>
]];

meanTrace[a_] := Module[{x = Unique["x"], p, n},
  p = minpoly[a, x]; n = Exponent[p, x];
  -Coefficient[p, x, n - 1]/n
];
centerSum[terms_List] := Module[{means, centered, q},
  means = meanTrace /@ terms;
  centered = MapThread[RootReduce[#1 - #2] &, {terms, means}];
  q = Total[means];
  centered = DeleteCases[centered, 0];
  If[q =!= 0, AppendTo[centered, q]];
  If[centered === {}, {0}, centered]
];
sumInField[a_, f_Association, bases_List] := Module[
  {target = coordinates[a, f], chosen, rows, w, terms, cursor, piece, ds},
  ds = Union[Length /@ bases];
  Do[
    chosen = Select[bases, Length[#] <= d &]; rows = Join @@ chosen;
    If[MatrixRank[Append[rows, target]] > MatrixRank[rows], Continue[]];
    w = Quiet[Check[LinearSolve[Transpose[rows], target], $Failed]];
    require[ListQ[w] && VectorQ[w, ratQ], "RationalLinearSolveFailed"];
    require[Transpose[rows] . w === target, "LinearSolveCheckFailed"];
    cursor = 1;
    terms = Table[
      piece = Take[w, {cursor, cursor + Length[b] - 1}] . b;
      cursor += Length[b]; fromCoordinates[piece, f], {b, chosen}];
    terms = centerSum[terms];
    Return[Join[certificate[a, terms, "Sum", "All finite sums in the specified ambient field"],
      <|"MinimalWithinScope" -> True, "AmbientGenerator" -> f["Generator"],
        "AmbientDegree" -> f["Degree"], "SubfieldDegreeThreshold" -> d|>]],
    {d, ds}];
  require[False, "InternalAdditiveSearchFailed"]
];
Options[MinSumInField] = {"AmbientGenerator" -> Automatic, "MaxDivisors" -> 65536};
MinSumInField[a_, OptionsPattern[]] := guarded[Module[{aa, theta, f, b},
  aa = exactNumber[a]; theta = OptionValue["AmbientGenerator"];
  f = fieldData[If[theta === Automatic, aa, theta]];
  coordinates[aa, f]; b = subfieldBases[f, OptionValue["MaxDivisors"]];
  sumInField[aa, f, b]
]];
Options[MinTwoFactorInField] = Options[MinSumInField];
MinTwoFactorInField[a_, OptionsPattern[]] := guarded[Module[
  {aa, theta, f, bases, target, pairs, e, g, scaled, ns, w, u, v, pieces},
  aa = exactNumber[a]; theta = OptionValue["AmbientGenerator"];
  f = fieldData[If[theta === Automatic, aa, theta]];
  target = coordinates[aa, f];
  If[zeroQ[aa], Return[Join[certificate[aa, {0}, "Product", "Zero input"],
    <|"MinimalWithinScope" -> True|>]]];
  bases = subfieldBases[f, OptionValue["MaxDivisors"]];
  pairs = Flatten[Table[{i, j}, {i, Length[bases]}, {j, i, Length[bases]}], 1];
  pairs = SortBy[pairs, Max[Length[bases[[#[[1]]]]], Length[bases[[#[[2]]]]]] &];
  Do[
    e = bases[[pair[[1]]]]; g = bases[[pair[[2]]]];
    scaled = fieldMultiply[target, #, f] & /@ g;
    ns = NullSpace[Transpose[Join[e, -scaled]]];
    If[ns === {}, Continue[]];
    w = First[ns]; u = Take[w, Length[e]] . e; v = Drop[w, Length[e]] . g;
    require[! AllTrue[v, (# === 0) &], "ZeroDenominatorInIntersection"];
    pieces = {fromCoordinates[u, f], RootReduce[1/fromCoordinates[v, f]]};
    Return[Join[certificate[aa, pieces, "Product", "At most two factors in the specified ambient field"],
      <|"MinimalWithinScope" -> True, "AmbientGenerator" -> f["Generator"],
        "AmbientDegree" -> f["Degree"]|>]],
    {pair, pairs}];
  require[False, "InternalProductSearchFailed"]
]];

Options[MinSumGlobally] = {"MaxDivisors" -> 65536, "MaxNormalDegree" -> 96};
MinSumGlobally[a_, OptionsPattern[]] := guarded[Module[
  {aa = exactNumber[a], quick, x = Unique["x"], roots, common, generators, f, bases, answer},
  quick = need[MinSumInField[aa, "MaxDivisors" -> OptionValue["MaxDivisors"]]];
  If[TrueQ[quick["GlobalMinimumCertified"]],
    Return[Join[quick, <|"Scope" -> "All finite sums over the algebraic numbers",
      "GlobalProof" -> "Witness meets prime-divisor lower bound"|>]]];
  roots = need[ExactRootList[minpoly[aa, x], x]];
  common = Quiet[Check[ToNumberField[roots, All], $Failed]];
  require[ListQ[common], "NormalClosureConstructionFailed"];
  generators = Cases[common, AlgebraicNumber[g_, _List] :> g];
  require[generators =!= {}, "NormalClosureGeneratorMissing"];
  f = fieldData[First[generators]];
  require[f["Degree"] <= OptionValue["MaxNormalDegree"], "ResourceLimit",
    <|"NormalClosureDegree" -> f["Degree"], "BestInternalResult" -> quick|>];
  Scan[coordinates[#, f] &, roots];
  bases = subfieldBases[f, OptionValue["MaxDivisors"]];
  answer = sumInField[aa, f, bases];
  Join[answer, <|"Scope" -> "All finite sums over the algebraic numbers",
    "GlobalMinimumCertified" -> True,
    "GlobalProof" -> "Complete normal-closure subfield enumeration and normalized-trace descent"|>]
]];

Options[FiniteCatalogSearch] = {"MaxTuples" -> 1000000};
FiniteCatalogSearch[a_, catalog_List, op_, r_Integer?Positive, OptionsPattern[]] := guarded[
 Module[{aa = exactNumber[a], h = opHead[op], c, count, pieces, k},
  c = DeleteDuplicates[exactNumber /@ catalog, zeroQ[#1 - #2] &];
  Scan[degree, c];
  If[op == "Product" && ! zeroQ[aa], c = Select[c, ! zeroQ[#] &]];
  require[c =!= {}, "EmptyCatalog"];
  k = Length[c]; count = Sum[k^j, {j, 1, r}];
  require[count <= OptionValue["MaxTuples"], "ResourceLimit", <|"TuplesRequired" -> count|>];
  Do[
    Do[
      pieces = c[[If[k == 1, ConstantArray[1, j],
        1 + IntegerDigits[mask, k, j]]]];
      If[zeroQ[(h @@ pieces) - aa],
        Return[certificate[aa, pieces, op, "Finite catalog and bounded component count"]]],
      {mask, 0, k^j - 1}],
    {j, 1, r}];
  Failure["NoRepresentationInCatalog", <|"MaxComponents" -> r,
    "GlobalNonexistenceProved" -> False|>]
 ]
];
End[];
EndPackage[];
