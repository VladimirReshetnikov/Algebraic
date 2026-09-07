(* RootDecomposition.wl
   Exact, certificate-oriented reference implementation.
   See the article and README for the scope of each optimality claim.
   Independently checked mathematically with SymPy; not executed in a
   Wolfram kernel in this session (the connector returned HTTP 404).
*)
BeginPackage["RootDecomposition`"];

AlgebraicDegree::usage = "AlgebraicDegree[a] gives the absolute degree over Q of an exact algebraic number.";
DegreeLowerBound::usage = "DegreeLowerBound[a] gives the largest prime divisor of AlgebraicDegree[a], or 1 for rationals.";
RootSumPolynomial::usage = "RootSumPolynomial[p,q,x] gives the resultant polynomial for all sums of roots of p and q.";
RootProductPolynomial::usage = "RootProductPolynomial[p,q,x] gives the resultant polynomial for all products of roots of p and q.";
FieldDecompositionData::usage = "FieldDecompositionData[a] computes rational coordinate bases for every subfield of Q(a).";
AdditiveDecomposition::usage = "AdditiveDecomposition[a] minimizes the largest term degree with all terms in Q(a). AdditiveDecomposition[a,data] uses a supplied ambient field.";
GlobalAdditiveDecomposition::usage = "GlobalAdditiveDecomposition[a] minimizes the largest term degree without an ambient-field restriction, using a normal closure when necessary.";
ProductDecomposition::usage = "ProductDecomposition[a] searches all binary factorizations in Q(a), and independent subfield tensor families. Check GlobalOptimalityCertified in its result.";
BoundedDecompositionSearch::usage = "BoundedDecompositionSearch[a,mode,d,h,k] searches primitive polynomial height <= h, degree <= d, and at most k terms or factors. mode is Sum or Product, written as a string.";
VerifyDecomposition::usage = "VerifyDecomposition[a,terms,mode] certifies an exact sum or product identity.";
DecompositionExpression::usage = "DecompositionExpression[result] displays the result as an inactive sum or product, preserving its decomposition.";

Begin["`Private`"];
$failureTag = Unique["RootDecompositionFailure"];
fail[tag_, data_:<||>] := Throw[Failure[tag, data], $failureTag];
rationalQ[a_] := MatchQ[a, _Integer | _Rational];
zeroVectorQ[v_List] := AllTrue[v, TrueQ[# == 0] &];

minimalPolynomial[a_, x_] := Module[{b, p},
  If[!FreeQ[a, _Real], fail["InexactInput", <|"Input" -> a|>]];
  b = Quiet[Check[RootReduce[a], $Failed]];
  p = Quiet[Check[MinimalPolynomial[b, x], $Failed]];
  If[p === $Failed || !PolynomialQ[p, x] ||
     !TrueQ[Exponent[p, x] >= 1] ||
     !VectorQ[CoefficientList[p, x], rationalQ],
    fail["NotExactAlgebraic", <|"Input" -> a|>]];
  p
];

degree[a_] := Module[{x = Unique["x"]},
  Exponent[minimalPolynomial[a, x], x]
];
lowerBoundFromDegree[n_Integer] := If[n == 1, 1, Max[First /@ FactorInteger[n]]];
AlgebraicDegree[a_] := Catch[degree[a], $failureTag];
DegreeLowerBound[a_] := Catch[lowerBoundFromDegree[degree[a]], $failureTag];

monic[p_, x_] := Expand[p/Coefficient[p, x, Exponent[p, x]]];
rootList[p_, x_] := Module[{fun, n = Exponent[p, x]},
  fun = Function[Evaluate[p /. x -> Slot[1]]];
  Table[Root[fun, j], {j, n}]
];
RootSumPolynomial[p_, q_, x_Symbol] := Module[{y = Unique["y"]},
  Expand[Resultant[p /. x -> y, q /. x -> x - y, y]]
];
RootProductPolynomial[p_, q_, x_Symbol] := Module[
  {y = Unique["y"], m = Exponent[q, x], reversed},
  reversed = Expand[Sum[Coefficient[q, x, j] x^j y^(m-j), {j, 0, m}]];
  Expand[Resultant[p /. x -> y, reversed, y]]
];

canonicalRows[rows_List, n_Integer] := If[rows === {}, {},
  Select[RowReduce[rows], !zeroVectorQ[#] &]
];
spaceIntersection[u_List, v_List, n_Integer] := Module[{ann},
  ann = Join[NullSpace[u], NullSpace[v]];
  If[ann === {}, IdentityMatrix[n], canonicalRows[NullSpace[ann], n]]
];

coordinates[a_, data_Association] := Module[
  {n = data["Degree"], theta = data["Generator"],
   x = data["Variable"], b, an, p, v},
  b = RootReduce[a];
  If[rationalQ[b], Return[PadRight[{b}, n]]];
  an = Quiet[Check[ToNumberField[b, theta], $Failed]];
  If[Head[an] =!= AlgebraicNumber,
    fail["NotInAmbientField", <|"Element" -> b|>]];
  (* Never assume that a changed primitive element uses the same coordinates. *)
  If[!TrueQ[RootReduce[an[[1]] - theta] == 0],
    fail["UnexpectedPrimitiveElement", <|"Returned" -> an[[1]],
      "Expected" -> theta|>]];
  p = AlgebraicNumberPolynomial[an, x];
  p = PolynomialRemainder[p, data["MinimalPolynomial"], x];
  v = PadRight[CoefficientList[p, x], n];
  If[Length[v] != n || !VectorQ[v, rationalQ],
    fail["InvalidCoordinates", <|"Element" -> b|>]];
  v
];
fromCoordinates[v_List, data_Association] := If[data["Degree"] == 1,
  First[v], RootReduce[v . data["Generator"]^Range[0, data["Degree"]-1]]
];
multiplyCoordinates[u_List, v_List, data_Association] := Module[
  {x = data["Variable"], n = data["Degree"], powers, p},
  powers = x^Range[0, n-1];
  p = PolynomialRemainder[Expand[(u . powers) (v . powers)],
    data["MinimalPolynomial"], x];
  PadRight[CoefficientList[p, x], n]
];

principalBasis[g_, data_Association] := Module[
  {x = data["Variable"], theta = data["Generator"],
   n = data["Degree"], m, columns, rem, coeff},
  m = Exponent[g, x];
  columns = Table[
    rem = PolynomialRemainder[x^j - theta^j, g, x];
    coeff = PadRight[CoefficientList[Expand[rem], x], m];
    Flatten[coordinates[#, data] & /@ coeff],
    {j, 0, n-1}];
  canonicalRows[NullSpace[Transpose[columns]], n]
];

Options[FieldDecompositionData] = {
  "MaxFieldDegree" -> 64, "MaxSubfields" -> 4096
};
FieldDecompositionData[a_, OptionsPattern[]] := Catch[Module[
  {x = Unique["x"], p, n, theta, data, fl, factors,
   principal, fields, next, dmax = OptionValue["MaxFieldDegree"],
   fmax = OptionValue["MaxSubfields"]},
  p = minimalPolynomial[a, x]; n = Exponent[p, x];
  If[n > dmax, fail["FieldDegreeLimit", <|"Degree" -> n, "Limit" -> dmax|>]];
  (* If c is the leading coefficient of a primitive integral minimal
     polynomial of a, c a is an algebraic integer and generates Q(a). *)
  theta = If[n == 1, 0, RootReduce[Coefficient[p, x, n] a]];
  p = monic[minimalPolynomial[theta, x], x];
  data = <|"Generator" -> theta, "Variable" -> x,
    "MinimalPolynomial" -> p, "Degree" -> n|>;
  If[n == 1, Return[Join[data, <|"Factors" -> {x},
    "PrincipalFields" -> {{{1}}}, "Subfields" -> {{{1}}},
    "IsGalois" -> True|>]]];
  fl = Quiet[Check[FactorList[p, Extension -> theta], $Failed]];
  If[fl === $Failed || Head[fl] =!= List,
    fail["FactorizationFailed"]];
  fl = Rest[fl];
  If[!AllTrue[fl, Last[#] == 1 &], fail["UnexpectedMultiplicity"]];
  factors = monic[First[#], x] & /@ fl;
  If[Total[Exponent[#, x] & /@ factors] != n,
    fail["IncompleteFactorization"]];
  If[!AllTrue[CoefficientList[Expand[(Times @@ factors) - p], x],
      TrueQ[RootReduce[#] == 0] &], fail["FactorizationCheckFailed"]];
  principal = DeleteDuplicates[principalBasis[#, data] & /@ factors];
  fields = {IdentityMatrix[n]};
  Do[
    next = DeleteDuplicates[Join[fields,
      spaceIntersection[#, b, n] & /@ fields]];
    If[Length[next] > fmax,
      fail["SubfieldLimit", <|"Limit" -> fmax|>]];
    fields = next,
    {b, principal}];
  fields = SortBy[fields, Function[b, {Length[b], ToString[b, InputForm]}]];
  If[!AllTrue[fields, Length[#] > 0 && Mod[n, Length[#]] == 0 &],
    fail["InvalidSubfieldDimensions"]];
  Join[data, <|"Factors" -> factors, "PrincipalFields" -> principal,
    "Subfields" -> fields, "IsGalois" -> (Length[factors] == n)|>]
], $failureTag];

VerifyDecomposition[a_, terms_List, mode_String] := Module[{value},
  If[!MemberQ[{"Sum", "Product"}, mode], Return[False]];
  value = If[mode == "Sum", Total[terms], Times @@ terms];
  TrueQ[RootReduce[a - value] == 0]
];
DecompositionExpression[result_Association] :=
  Apply[If[result["Operation"] == "Sum", Inactive[Plus], Inactive[Times]],
    result["Terms"]];

traceMean[a_] := Module[{x = Unique["x"], p, d},
  p = minimalPolynomial[a, x]; d = Exponent[p, x];
  -Coefficient[p, x, d-1]/(d Coefficient[p, x, d])
];
centerTerms[terms_List] := Module[{means, centered, c},
  means = traceMean /@ terms;
  centered = MapThread[RootReduce[#1 - #2] &, {terms, means}];
  centered = Select[centered, !TrueQ[# == 0] &];
  c = Total[means];
  If[c != 0, AppendTo[centered, c]];
  If[centered === {}, {0}, centered]
];
normalizeProductFactors[terms_List] := Module[
  {out = terms, x = Unique["x"], p, d, ratio, scale},
  Do[
    p = minimalPolynomial[out[[j]], x]; d = Exponent[p, x];
    If[d > 1 && OddQ[d] && Coefficient[p, x, 0] < 0,
      out[[j]] = RootReduce[-out[[j]]];
      out[[-1]] = RootReduce[-out[[-1]]];
      p = minimalPolynomial[out[[j]], x]];
    (* Normalize an odd-degree constant term only when the required
       scaling is rational. Never introduce an algebraic scaling. *)
    If[d > 1 && OddQ[d],
      ratio = Coefficient[p, x, 0]/Coefficient[p, x, d];
      scale = RootReduce[ratio^(1/d)];
      If[rationalQ[scale] && scale != 0,
        out[[j]] = RootReduce[out[[j]]/scale];
        out[[-1]] = RootReduce[scale out[[-1]]]]],
    {j, Max[0, Length[out]-1]}];
  out
];
record[a_, terms_List, mode_, method_, scope_, global_:False] := Module[
  {ts, ds, lo},
  ts = RootReduce /@ terms;
  If[ts === {}, ts = {If[mode == "Sum", 0, 1]}];
  If[!VerifyDecomposition[a, ts, mode], fail["IdentityCheckFailed"]];
  ds = degree /@ ts; lo = lowerBoundFromDegree[degree[a]];
  <|"Operation" -> mode, "Terms" -> ts, "Degrees" -> ds,
    "MaximumDegree" -> Max[ds], "LowerBound" -> lo,
    "IdentityVerified" -> True,
    "GlobalOptimalityCertified" -> (TrueQ[global] || Max[ds] == lo),
    "OptimalityScope" -> scope, "Method" -> method|>
];

sumAtDegree[a_, data_Association, d_Integer] := Module[
  {blocks, rows, matrix, target, c, terms = {}, pos = 1, v},
  blocks = Select[data["Subfields"], Length[#] <= d &];
  rows = Join @@ blocks; matrix = Transpose[rows];
  target = coordinates[a, data];
  If[MatrixRank[Join[matrix, Transpose[{target}], 2]] != MatrixRank[matrix],
    Return[Missing["NoSumAtThisDegree"]]];
  c = LinearSolve[matrix, target];
  Do[
    v = Take[c, {pos, pos+Length[b]-1}] . b;
    If[!zeroVectorQ[v], AppendTo[terms, fromCoordinates[v, data]]];
    pos += Length[b],
    {b, blocks}];
  centerTerms[terms]
];
minimumSum[a_, data_Association] := Module[{terms},
  Do[
    terms = sumAtDegree[a, data, d];
    If[ListQ[terms], Return[record[a, terms, "Sum", "SubfieldLinearAlgebra",
      "Minimum in the supplied ambient field", data["IsGalois"]]]],
    {d, Sort[DeleteDuplicates[Length /@ data["Subfields"]]]}];
  fail["TargetNotInAmbientField"]
];
Options[AdditiveDecomposition] = Options[FieldDecompositionData];
AdditiveDecomposition[a_, data_Association] := Catch[minimumSum[a, data], $failureTag];
AdditiveDecomposition[a_, OptionsPattern[]] := Catch[Module[{data},
  data = FieldDecompositionData[a,
    "MaxFieldDegree" -> OptionValue["MaxFieldDegree"],
    "MaxSubfields" -> OptionValue["MaxSubfields"]];
  If[FailureQ[data], Return[data]];
  minimumSum[a, data]
], $failureTag];

Options[GlobalAdditiveDecomposition] = Options[FieldDecompositionData];
GlobalAdditiveDecomposition[a_, OptionsPattern[]] := Catch[Module[
  {data, ans, roots, common, theta, normalData},
  data = FieldDecompositionData[a,
    "MaxFieldDegree" -> OptionValue["MaxFieldDegree"],
    "MaxSubfields" -> OptionValue["MaxSubfields"]];
  If[FailureQ[data], Return[data]];
  ans = minimumSum[a, data];
  If[TrueQ[ans["GlobalOptimalityCertified"]], Return[ans]];
  roots = rootList[data["MinimalPolynomial"], data["Variable"]];
  common = Quiet[Check[ToNumberField[roots, All], $Failed]];
  If[common === $Failed || !ListQ[common] ||
     Head[First[common]] =!= AlgebraicNumber,
    fail["NormalClosureConstructionFailed", <|"InputFieldCandidate" -> ans|>]];
  theta = common[[1, 1]];
  normalData = FieldDecompositionData[theta,
    "MaxFieldDegree" -> OptionValue["MaxFieldDegree"],
    "MaxSubfields" -> OptionValue["MaxSubfields"]];
  If[FailureQ[normalData], Return[Failure["NormalClosureLimitOrFailure",
    <|"Cause" -> normalData, "InputFieldCandidate" -> ans|>]]];
  If[!TrueQ[normalData["IsGalois"]],
    fail["NormalClosureNotGalois", <|"InputFieldCandidate" -> ans|>]];
  ans = minimumSum[a, normalData];
  Join[ans, <|"GlobalOptimalityCertified" -> True,
    "OptimalityScope" -> "Global, by normal-closure trace descent",
    "AmbientFieldDegree" -> normalData["Degree"]|>]
], $failureTag];

binaryProductAtDegree[a_, data_Association, d_Integer] := Module[
  {fields, av, e, f, ae, ns, v, u, factors},
  fields = Select[data["Subfields"], Length[#] <= d &];
  av = coordinates[a, data];
  Do[
    e = fields[[i]];
    ae = multiplyCoordinates[av, #, data] & /@ e;
    Do[
      f = fields[[j]];
      ns = NullSpace[Transpose[Join[ae, -f]]];
      If[ns =!= {},
        v = Take[First[ns], Length[e]] . e;
        u = fromCoordinates[v, data];
        If[TrueQ[u == 0], fail["UnexpectedZeroKernelVector"]];
        factors = RootReduce /@ {1/u, a u};
        Return[normalizeProductFactors[factors]]],
      {j, i, Length[fields]}],
    {i, Length[fields]}];
  Missing["NoBinaryProductAtThisDegree"]
];

tensorProductForFamily[a_, data_Association, family_List] := Module[
  {dims = Length /@ family, n = data["Degree"], tuples,
   one, products, matrix, c, pivotPosition, pivotIndex, pivot,
   tensor, vectors, predicted, factors},
  If[(Times @@ dims) != n, Return[Missing["WrongDegreeProduct"]]];
  tuples = Tuples[Range /@ dims]; one = UnitVector[n, 1];
  products = Table[
    Fold[multiplyCoordinates[#1, #2, data] &, one,
      MapThread[Part, {family, index}]],
    {index, tuples}];
  matrix = Transpose[products];
  If[MatrixRank[matrix] != n, Return[Missing["NotIndependent"]]];
  c = LinearSolve[matrix, coordinates[a, data]];
  pivotPosition = First[Select[Range[Length[c]], c[[#]] != 0 &, 1]];
  pivotIndex = tuples[[pivotPosition]]; pivot = c[[pivotPosition]];
  tensor = ArrayReshape[c, dims];
  vectors = Table[
    Table[Extract[tensor, ReplacePart[pivotIndex, k -> j]]/pivot,
      {j, dims[[k]]}], {k, Length[dims]}];
  predicted = Table[pivot (Times @@ MapThread[Part, {vectors, index}]),
    {index, tuples}];
  If[predicted =!= c, Return[Missing["TensorRankNotOne"]]];
  factors = MapThread[fromCoordinates[#1 . #2, data] &, {vectors, family}];
  factors[[1]] = RootReduce[pivot factors[[1]]];
  normalizeProductFactors[factors]
];

Options[ProductDecomposition] = Join[Options[FieldDecompositionData], {
  "TensorFamilies" -> True, "MaxTensorFamilies" -> 10000
}];
ProductDecomposition[a_, OptionsPattern[]] := Catch[Module[
  {data, n, thresholds, terms, eligible, count, families, budget,
   spent, complete = True, useTensors = OptionValue["TensorFamilies"],
   scope, method, found = False},
  n = degree[a];
  If[n == 1, Return[record[a, {RootReduce[a]}, "Product", "Rational",
    "Global", True]]];
  data = FieldDecompositionData[a,
    "MaxFieldDegree" -> OptionValue["MaxFieldDegree"],
    "MaxSubfields" -> OptionValue["MaxSubfields"]];
  If[FailureQ[data], Return[data]];
  thresholds = Sort[DeleteDuplicates[Length /@ data["Subfields"]]];
  Do[
    terms = binaryProductAtDegree[a, data, d];
    If[ListQ[terms], method = "BinarySubfieldIntersection"; found = True];
    If[!found && TrueQ[useTensors],
      eligible = Select[data["Subfields"], 1 < Length[#] <= d && Length[#] < n &];
      spent = 0; budget = OptionValue["MaxTensorFamilies"];
      Do[
        count = Binomial[Length[eligible], k];
        If[count > 0,
          If[budget === Infinity,
            families = Subsets[eligible, {k}],
            families = Subsets[eligible, {k}, Max[0, budget-spent]];
            If[count > Max[0, budget-spent], complete = False]];
          spent += Length[families];
          Do[
            If[(Times @@ (Length /@ family)) == n,
              terms = tensorProductForFamily[a, data, family];
              If[ListQ[terms], method = "IndependentSubfieldTensor";
                found = True; Break[]]],
            {family, families}]];
        If[found, Break[]],
        {k, 3, Floor[Log[2, n]]}]];
    If[found,
      scope = Which[
        !complete, "Candidate only; tensor-family enumeration was truncated",
        !TrueQ[useTensors], "Minimum for two factors in Q(a)",
        True, "Minimum over binary and independent-family products in Q(a)"];
      Return[Join[record[a, terms, "Product", method, scope],
        <|"TensorSearchComplete" -> complete|>]]],
    {d, thresholds}];
  fail["InternalProductSearchFailure"]
], $failureTag];

(* Exhaustive search under EXPLICIT finite bounds. The last term/factor is
   reconstructed exactly rather than independently enumerated. *)
Options[BoundedDecompositionSearch] = {
  "MaxPolynomials" -> 20000, "MaxCandidates" -> 10000,
  "MaxTuples" -> 100000
};
BoundedDecompositionSearch[a_, mode_String, maxDegree_Integer,
    height_Integer, maxTerms_Integer, OptionsPattern[]] :=
 Catch[Module[
  {x = Unique["x"], catalog = {}, p, roots, polys, candidates,
   combinations, indices, chosen, residual, terms, mp, count, used,
   inBox, polyBudget = OptionValue["MaxPolynomials"],
   tupleBudget = OptionValue["MaxTuples"]},
  If[!MemberQ[{"Sum", "Product"}, mode], fail["InvalidOperation"]];
  If[Min[maxDegree, height, maxTerms] < 1, fail["InvalidSearchBounds"]];
  degree[a];
  polys = Sum[height (2 height+1)^j, {j, 1, maxDegree}];
  If[polys > polyBudget, fail["PolynomialEnumerationLimit",
    <|"Required" -> polys, "Limit" -> polyBudget|>]];
  Do[
    Do[
      Do[
        If[(GCD @@ Append[Abs[cs], lead]) == 1,
          p = Append[cs, lead] . x^Range[0, j];
          If[IrreduciblePolynomialQ[p],
            roots = rootList[p, x];
            If[mode == "Product", roots = Select[roots, !TrueQ[# == 0] &]];
            catalog = Join[catalog, ({#, j} & /@ roots)];
            If[Length[catalog] > OptionValue["MaxCandidates"],
              fail["CandidateEnumerationLimit"]]]],
        {lead, 1, height}],
      {cs, Tuples[Range[-height, height], j]}],
    {j, 1, maxDegree}];
  inBox[b_, d_] := Module[{f = minimalPolynomial[b, x]},
    Exponent[f, x] <= d && Max[Abs[CoefficientList[f, x]]] <= height];
  Do[
    candidates = First /@ Select[catalog, Last[#] <= d &];
    used = 0;
    Do[
      If[k == 1,
        combinations = {{}},
        count = Binomial[Length[candidates]+k-2, k-1];
        If[used+count > tupleBudget, fail["TupleEnumerationLimit",
          <|"RequiredAtThisDegree" -> used+count, "Limit" -> tupleBudget|>]];
        combinations = Subsets[Range[Length[candidates]+k-2], {k-1}]];
      used += Length[combinations];
      Do[
        indices = If[k == 1, {}, comb - Range[0, k-2]];
        chosen = candidates[[indices]];
        residual = RootReduce[If[mode == "Sum",
          a - Total[chosen], a/(Times @@ chosen)]];
        If[inBox[residual, d],
          terms = Append[chosen, residual];
          Return[Join[record[a, terms, mode, "BoundedEnumeration",
            "Minimum within the specified degree, height, and length box"],
            <|"HeightBound" -> height, "LengthBound" -> maxTerms|>]]],
        {comb, combinations}],
      {k, 1, maxTerms}],
    {d, 1, maxDegree}];
  Missing["NoDecompositionWithinBounds",
    <|"DegreeBound" -> maxDegree, "HeightBound" -> height,
      "LengthBound" -> maxTerms|>]
 ], $failureTag];

End[];
EndPackage[];
