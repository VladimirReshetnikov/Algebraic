(* ::Package:: *)
(* Exact low-degree algebraic decomposition.
   See article.pdf for proofs, guarantees, and the limits of each search.
   This source uses only documented Wolfram Language functionality.
   The accompanying .wlt tests are intended for an actual Wolfram kernel.
*)

BeginPackage["RootDecomposition`"];
RootDegree::usage = "RootDegree[a] gives the degree of an exact algebraic number over Q.";
DegreePrimeLowerBound::usage = "DegreePrimeLowerBound[a] is a lower bound on the largest degree in ANY finite sum or product representing a.";
SumComposedPolynomial::usage = "SumComposedPolynomial[f,g,x] is the monic polynomial of all pairwise sums of roots of f and g.";
ProductComposedPolynomial::usage = "ProductComposedPolynomial[f,g,x] is the monic polynomial of all pairwise products of roots of f and g.";
VerifyRootDecomposition::usage = "VerifyRootDecomposition[a,parts,Plus|Times] verifies the identity exactly and reports the actual degrees.";
RootPairFromPolynomial::usage = "RootPairFromPolynomial[a,f,x,Plus|Times,d] searches all conjugates of f and recovers a second factor/summand of degree at most d.";
FindRootPair::usage = "FindRootPair[a,Plus|Times,d,h] searches primitive integer first polynomials of degree at most d and coefficient height at most h. The other polynomial has no height bound.";
DictionaryRootDecomposition::usage = "DictionaryRootDecomposition[a,atoms,Plus|Times,d,r] searches up to r parts, all but the last drawn with repetition from atoms. The last part may be any algebraic number of degree at most d.";
BuildNormalFieldModel::usage = "BuildNormalFieldModel[a] constructs a normal field containing a, its automorphisms, and the complete subfield lattice. This can be very expensive.";
CompleteSumDecomposition::usage = "CompleteSumDecomposition[a,model] minimizes the largest degree over ALL finite sums. Omit model to construct it. Resource failures are not negative answers.";
CompleteProductPairDecomposition::usage = "CompleteProductPairDecomposition[a,model] minimizes the largest degree over products of AT MOST TWO factors, allowing factors outside the normal field. It does not optimize arbitrary-length products.";

Begin["`Private`"];
qQ[t_] := MatchQ[t, _Integer | _Rational];
qPolyQ[p_, x_] := PolynomialQ[p, x] && AllTrue[CoefficientList[p, x], qQ];
fail[tag_, text_] := Failure[tag, <|"MessageTemplate" -> text|>];
rr[a_] := Quiet[Check[RootReduce[a], $Failed]];
eqQ[a_, b_] := SameQ[rr[a - b], 0];
nonzeroVectorQ[v_List] := AnyTrue[v, ! SameQ[#, 0] &];
monic[p_, x_] := Expand[p/Coefficient[p, x, Exponent[p, x]]];

RootDegree[a_] := Module[{x, p},
  If[! FreeQ[a, _Real], Return[fail["InexactInput", "Use exact algebraic input, not floating-point numbers."]]];
  p = Quiet[Check[MinimalPolynomial[a, x], $Failed]];
  If[p === $Failed || ! qPolyQ[p, x] || Exponent[p, x] < 1,
    Return[fail["NotExactAlgebraic", "Could not obtain a rational minimal polynomial."]]];
  Exponent[p, x]
];

DegreePrimeLowerBound[a_] := Module[{n = RootDegree[a]},
  If[FailureQ[n], Return[n]];
  If[n == 1, 1, Max[First /@ FactorInteger[n]]]
];

rootAt[p_, x_, j_Integer] := With[
  {fun = Function @@ {p /. x -> Slot[1]}, index = j}, Root[fun, index]
];

SumComposedPolynomial[f_, g_, x_Symbol] := Module[{y},
  If[! qPolyQ[f, x] || ! qPolyQ[g, x] || Min[Exponent[f, x], Exponent[g, x]] < 1,
    Return[fail["PolynomialInput", "Supply nonconstant rational polynomials in an unassigned variable."]]];
  monic[Resultant[f /. x -> y, g /. x -> x - y, y], x]
];

ProductComposedPolynomial[f_, g_, x_Symbol] := Module[{y, n, transformed},
  If[! qPolyQ[f, x] || ! qPolyQ[g, x] || Min[Exponent[f, x], Exponent[g, x]] < 1,
    Return[fail["PolynomialInput", "Supply nonconstant rational polynomials in an unassigned variable."]]];
  n = Exponent[g, x];
  (* Homogenize explicitly: no spurious denominator or zero-root loss. *)
  transformed = Sum[Coefficient[g, x, j] x^j y^(n - j), {j, 0, n}];
  monic[Resultant[f /. x -> y, transformed, y], x]
];

VerifyRootDecomposition[a_, parts_List, op : (Plus | Times)] := Module[
  {degrees, n, value, residual, lower, largest},
  If[Length[parts] == 0, Return[fail["EmptyParts", "Supply at least one part."]]];
  n = RootDegree[a]; If[FailureQ[n], Return[n]];
  degrees = RootDegree /@ parts;
  If[AnyTrue[degrees, FailureQ], Return[fail["InvalidPart", "Every part must be exact and algebraic."]]];
  value = Apply[op, parts]; residual = rr[a - value];
  If[residual === $Failed, Return[fail["VerificationFailure", "Exact verification did not complete."]]];
  lower = If[n == 1, 1, Max[First /@ FactorInteger[n]]];
  largest = Max[degrees];
  <|"Verified" -> SameQ[residual, 0], "Residual" -> residual,
    "InputDegree" -> n, "Degrees" -> degrees, "LargestDegree" -> largest,
    "GlobalLowerBound" -> lower,
    "GloballyOptimalByPrimeBound" -> (SameQ[residual, 0] && largest == lower)|>
];

certificate[a_, parts_List, op_, scope_String] := Module[{v},
  v = VerifyRootDecomposition[a, parts, op];
  If[FailureQ[v] || ! TrueQ[v["Verified"]],
    Return[fail["CertificateFailure", "The proposed identity was not certified."]]];
  Join[<|"Status" -> If[TrueQ[v["GloballyOptimalByPrimeBound"]],
        "CertifiedGloballyOptimal", "CertifiedDecomposition"],
      "Parts" -> parts, "Operation" -> op,
      "Expression" -> Apply[Inactive[op], parts], "SearchScope" -> scope|>, v]
];

pairFromPolynomial[a_, p_, f_, x_, op_, d_] := Module[
  {y, z, h, gs, beta, gamma, c, tag}, Catch[
  h = Switch[op,
    Plus, Resultant[f /. x -> y, p /. x -> z + y, y],
    Times, Resultant[f /. x -> y, p /. x -> z y, y]];
  If[! qPolyQ[h, z] || SameQ[h, 0],
    Throw[fail["ResultantFailure", "Residual resultant computation failed."], tag]];
  gs = Select[First /@ FactorList[h], 1 <= Exponent[#, z] <= d &];
  Do[
    beta = rootAt[f, x, i];
    If[op === Times && eqQ[beta, 0], Continue[]];
    Do[
      gamma = rootAt[g, z, j];
      If[eqQ[a, op[beta, gamma]],
        c = certificate[a, {beta, gamma}, op, "Two parts; specified first polynomial"];
        Throw[Join[c, <|"FirstPolynomial" -> f,
          "SecondPolynomial" -> (monic[g, z] /. z -> x)|>], tag]],
      {g, gs}, {j, 1, Exponent[g, z]}],
    {i, 1, Exponent[f, x]}];
  <|"Status" -> "NoPairFromCandidate", "FirstPolynomial" -> f|>
, tag]];

RootPairFromPolynomial[a_, f_, x_Symbol, op : (Plus | Times), d_Integer?Positive] := Module[{p, n},
  n = RootDegree[a]; If[FailureQ[n], Return[n]];
  If[! qPolyQ[f, x] || ! TrueQ[IrreduciblePolynomialQ[f]] ||
      ! (1 <= Exponent[f, x] <= d),
    Return[fail["CandidateInput", "The candidate must be irreducible over Q, with degree from 1 through d."]]];
  If[op === Times && SameQ[f /. x -> 0, 0],
    Return[fail["ZeroCandidate", "The multiplicative candidate cannot have zero as a root."]]];
  p = MinimalPolynomial[a, x];
  pairFromPolynomial[a, p, f, x, op, d]
];

Options[FindRootPair] = {"TimeLimit" -> 60, "MaxCandidates" -> Infinity};
FindRootPair[a_, op : (Plus | Times), d_Integer?Positive, h_Integer?Positive,
    OptionsPattern[]] := Module[
  {x, p, n, tag, tried = 0, coeffs, f, answer, lowerDegree, cap, seconds},
  n = RootDegree[a]; If[FailureQ[n], Return[n]];
  If[n <= d, Return[certificate[a, {rr[a]}, op, "Trivial one-part representation"]]];
  If[n > d^2, Return[<|"Status" -> "NoTwoFactorDecomposition",
      "Reason" -> "Input degree exceeds d^2", "InputDegree" -> n,
      "DegreeBound" -> d, "Scope" -> "At most two parts only"|>]];
  p = MinimalPolynomial[a, x]; lowerDegree = Max[2, Ceiling[n/d]];
  cap = OptionValue["MaxCandidates"]; seconds = OptionValue["TimeLimit"];
  TimeConstrained[
    Catch[
      Do[
        coeffs = Join[IntegerDigits[index, 2 height + 1, m] - height, {lead}];
        If[Max[Abs[coeffs]] != height || Apply[GCD, coeffs] != 1, Continue[]];
        f = Expand[coeffs . x^Range[0, m]];
        If[op === Times && First[coeffs] == 0, Continue[]];
        If[! TrueQ[IrreduciblePolynomialQ[f]], Continue[]];
        If[tried >= cap, Throw[<|"Status" -> "CandidateLimit", "CandidatesTested" -> tried|>, tag]];
        tried++;
        answer = pairFromPolynomial[a, p, f, x, op, d];
        If[FailureQ[answer], Throw[answer, tag]];
        If[KeyExistsQ[answer, "Parts"],
          Throw[Join[answer, <|"CandidatesTested" -> tried,
            "FirstPolynomialHeightBound" -> h, "DegreeBound" -> d|>], tag]],
        {height, 1, h}, {m, lowerDegree, d}, {lead, 1, height},
        {index, 0, (2 height + 1)^m - 1}];
      <|"Status" -> "NotFoundWithinBounds", "CandidatesTested" -> tried,
        "DegreeBound" -> d, "FirstPolynomialHeightBound" -> h,
        "Scope" -> "At most two parts; at least one primitive integer minimal polynomial has height <= h"|>,
      tag],
    seconds,
    <|"Status" -> "TimedOut", "CandidatesTested" -> tried,
      "DegreeBound" -> d, "FirstPolynomialHeightBound" -> h|>]
];

Options[DictionaryRootDecomposition] = {"TimeLimit" -> 60};
DictionaryRootDecomposition[a_, atoms_List, op : (Plus | Times),
    d_Integer?Positive, maxParts_Integer?Positive, OptionsPattern[]] := Module[
  {n, ds, pool, tag, indices, chosen, last, lastDegree, tried = 0},
  n = RootDegree[a]; If[FailureQ[n], Return[n]];
  ds = RootDegree /@ atoms;
  If[AnyTrue[ds, FailureQ] || AnyTrue[ds, # > d &],
    Return[fail["DictionaryInput", "All dictionary entries must be exact algebraic numbers of degree <= d."]]];
  pool = DeleteDuplicates[rr /@ atoms];
  If[op === Times, pool = Select[pool, ! eqQ[#, 0] &]];
  If[n <= d, Return[certificate[a, {rr[a]}, op, "One part"]]];
  If[pool === {}, Return[<|"Status" -> "NotFoundWithinDictionary"|>]];
  TimeConstrained[
    Catch[
      Do[
        indices = If[Length[pool] == 1, ConstantArray[1, r - 1],
          1 + IntegerDigits[index, Length[pool], r - 1]];
        If[! OrderedQ[indices], Continue[]];
        chosen = pool[[indices]]; tried++;
        last = rr[If[op === Plus, a - Total[chosen], a/Apply[Times, chosen]]];
        If[last === $Failed, Throw[fail["ArithmeticFailure", "Residual reduction failed."], tag]];
        lastDegree = RootDegree[last];
        If[FailureQ[lastDegree], Throw[lastDegree, tag]];
        If[lastDegree <= d,
          Throw[certificate[a, Append[chosen, last], op,
            "Bounded dictionary, all but the last part"], tag]],
        {r, 2, maxParts}, {index, 0, Length[pool]^(r - 1) - 1}];
      <|"Status" -> "NotFoundWithinDictionary", "CombinationsTested" -> tried,
        "MaxParts" -> maxParts, "DegreeBound" -> d|>, tag],
    OptionValue["TimeLimit"], <|"Status" -> "TimedOut", "CombinationsTested" -> tried|>]
];

(* Power-basis coordinates. The model generator is an algebraic integer;
   otherwise ToNumberField can silently change the generator. *)
fieldCoordinates[a_, theta_, p_, z_, n_] := Module[{u, h},
  u = Quiet[Check[ToNumberField[a, theta], $Failed]];
  If[u === $Failed || ! FreeQ[u, ToNumberField], Return[$Failed]];
  If[Head[u] === AlgebraicNumber && ! eqQ[u[[1]], theta], Return[$Failed]];
  h = Quiet[Check[AlgebraicNumberPolynomial[u, z], $Failed]];
  If[h === $Failed || ! qPolyQ[h, z], Return[$Failed]];
  PadRight[CoefficientList[PolynomialRemainder[h, p, z], z], n]
];

fieldMulMatrix[v_List, p_, z_, n_] := Transpose[
  Table[PadRight[CoefficientList[
    PolynomialRemainder[(v . z^Range[0, n - 1]) z^j, p, z], z], n],
    {j, 0, n - 1}]
];

allSubgroups[table_List, id_Integer, limit_] := Module[
  {groups = {{id}}, pos = 1, h, k, closure, order = Length[table], tag}, Catch[
  closure[seed_] := FixedPoint[Union[#, Flatten[table[[#, #]]]] &, Union[seed, {id}]];
  While[pos <= Length[groups],
    h = groups[[pos]];
    Do[
      k = closure[Append[h, g]];
      If[! MemberQ[groups, k],
        If[Length[groups] >= limit, Throw[$Failed, tag]];
        AppendTo[groups, k]],
      {g, Complement[Range[order], h]}];
    pos++];
  groups
, tag]];

Options[BuildNormalFieldModel] = {
  "TimeLimit" -> 300, "MaxNormalDegree" -> 48, "MaxSubgroups" -> 20000};
BuildNormalFieldModel[a_, OptionsPattern[]] := Module[
  {x, z, p0, n0, roots, reps, generators, theta, p, n, images,
   autos, id, table, groups, fields, coords, imagePoly, loc},
  n0 = RootDegree[a]; If[FailureQ[n0], Return[n0]];
  TimeConstrained[
    If[n0 == 1,
      Return[<|"Generator" -> 1, "Polynomial" -> z - 1,
        "Variable" -> z, "Dimension" -> 1,
        "Automorphisms" -> {{{1}}}, "MultiplicationTable" -> {{1}},
        "Subfields" -> {<|"Degree" -> 1, "Basis" -> {{1}}, "Subgroup" -> {1}|>},
        "CompleteSubfieldLattice" -> True|>]];
    p0 = MinimalPolynomial[a, x];
    roots = Table[rootAt[p0, x, j], {j, n0}];
    reps = Quiet[Check[ToNumberField[roots, All], $Failed]];
    If[reps === $Failed, Return[fail["PrimitiveElementFailure", "Could not construct the splitting field."]]];
    generators = Cases[reps, AlgebraicNumber[t_, _List] :> t, Infinity];
    If[generators === {}, Return[fail["PrimitiveElementFailure", "No primitive-element representation was returned."]]];
    theta = First[generators]; p = MinimalPolynomial[theta, z]; n = Exponent[p, z];
    If[n > OptionValue["MaxNormalDegree"],
      Return[fail["NormalDegreeLimit", "Normal-field degree exceeds the configured limit; no negative conclusion follows."]]];
    coords[t_] := fieldCoordinates[t, theta, p, z, n];
    images = Table[coords[rootAt[p, z, j]], {j, n}];
    If[MemberQ[images, $Failed], Return[fail["NonNormalModel", "Not all conjugates could be expressed in the chosen field."]]];
    autos = Table[
      imagePoly = images[[i]] . z^Range[0, n - 1];
      Transpose[Table[PadRight[CoefficientList[
        PolynomialRemainder[imagePoly^j, p, z], z], n], {j, 0, n - 1}]],
      {i, n}];
    loc = FirstPosition[images, coords[theta]];
    If[MissingQ[loc], Return[fail["AutomorphismFailure", "Could not identify the identity automorphism."]]];
    id = First[loc];
    table = Table[
      loc = FirstPosition[images, autos[[i]] . images[[j]]];
      If[MissingQ[loc], $Failed, First[loc]], {i, n}, {j, n}];
    If[! FreeQ[table, $Failed], Return[fail["AutomorphismFailure", "The automorphism table did not close."]]];
    groups = allSubgroups[table, id, OptionValue["MaxSubgroups"]];
    If[groups === $Failed, Return[fail["SubgroupLimit", "Subgroup enumeration exceeded its limit; no negative conclusion follows."]]];
    fields = Table[
      <|"Degree" -> n/Length[h], "Subgroup" -> h,
        "Basis" -> NullSpace[Join @@ ((# - IdentityMatrix[n] &) /@ autos[[h]])]|>,
      {h, groups}];
    If[AnyTrue[fields, Length[#["Basis"]] != #["Degree"] &],
      Return[fail["FixedFieldFailure", "Fixed-field dimensions failed the index check."]]];
    fields = SortBy[fields, #["Degree"] &];
    <|"Generator" -> theta, "Polynomial" -> p, "Variable" -> z,
      "Dimension" -> n, "Automorphisms" -> autos,
      "MultiplicationTable" -> table, "Subfields" -> fields,
      "CompleteSubfieldLattice" -> True|>,
    OptionValue["TimeLimit"], fail["TimedOut", "Normal-field construction timed out; no negative conclusion follows."]]
];

modelCoordinates[a_, model_Association] := fieldCoordinates[a,
  model["Generator"], model["Polynomial"], model["Variable"], model["Dimension"]];
modelValue[v_List, model_Association] := rr[v . model["Generator"]^Range[0, model["Dimension"] - 1]];
validModelQ[m_] := AssociationQ[m] && TrueQ[Lookup[m, "CompleteSubfieldLattice", False]];

CompleteSumDecomposition[a_, supplied_ : Automatic] := Module[
  {n, model, target, fields, candidates, basis, matrix, sol, parts, result, lower, tag}, Catch[
  n = RootDegree[a]; If[FailureQ[n], Throw[n, tag]];
  If[n == 1, Throw[Join[certificate[a, {rr[a]}, Plus, "All finite sums"],
    <|"MinimumLargestDegree" -> 1, "OptimalityScope" -> "All finite sums"|>], tag]];
  model = If[supplied === Automatic, BuildNormalFieldModel[a], supplied];
  If[FailureQ[model], Throw[model, tag]];
  If[! validModelQ[model], Throw[fail["ModelInput", "Supply an unmodified complete model from BuildNormalFieldModel."], tag]];
  target = modelCoordinates[a, model];
  If[target === $Failed, Throw[fail["FieldMembership", "The target is not in the model field."], tag]];
  lower = DegreePrimeLowerBound[a];
  Do[
    fields = Select[model["Subfields"], #["Degree"] <= d &];
    candidates = Join @@ (#["Basis"] & /@ fields);
    (* Retain original basis vectors, not mixed RowReduce vectors. *)
    basis = {};
    Do[If[MatrixRank[Append[basis, v]] > Length[basis], AppendTo[basis, v]], {v, candidates}];
    matrix = Transpose[basis];
    If[MatrixRank[Append[basis, target]] == Length[basis],
      sol = Quiet[Check[LinearSolve[matrix, target], $Failed]];
      If[sol === $Failed || ! SameQ[matrix . sol, target],
        Throw[fail["LinearSolveFailure", "The exact additive linear system failed verification."], tag]];
      parts = DeleteCases[MapThread[rr[#1 modelValue[#2, model]] &, {sol, basis}], 0];
      result = certificate[a, parts, Plus, "All finite sums, with no coefficient or length bound"];
      If[FailureQ[result], Throw[result, tag]];
      If[result["LargestDegree"] > d,
        Throw[fail["DegreeVerification", "The additive parts violated the degree bound."], tag]];
      Throw[Join[result, <|"Status" -> "CertifiedGloballyOptimal",
        "OptimalityScope" -> "All finite sums", "MinimumLargestDegree" -> d|>], tag]],
    {d, lower, n}];
  fail["InternalFailure", "The search should have succeeded by the input degree."]
, tag]];

CompleteProductPairDecomposition[a_, supplied_ : Automatic] := Module[
  {n, model, fields, power, powerVector, mult, b1, b2, matrix, kernel,
   vector, delta, beta, gamma, result, lower, tag}, Catch[
  n = RootDegree[a]; If[FailureQ[n], Throw[n, tag]];
  If[n == 1, Throw[Join[certificate[a, {rr[a]}, Times, "At most two factors"],
    <|"MinimumLargestDegreeForTwoFactors" -> 1,
      "OptimalityScope" -> "At most two factors"|>], tag]];
  model = If[supplied === Automatic, BuildNormalFieldModel[a], supplied];
  If[FailureQ[model], Throw[model, tag]];
  If[! validModelQ[model], Throw[fail["ModelInput", "Supply an unmodified complete model from BuildNormalFieldModel."], tag]];
  If[modelCoordinates[a, model] === $Failed,
    Throw[fail["FieldMembership", "The target is not in the model field."], tag]];
  lower = Max[DegreePrimeLowerBound[a], Ceiling[Sqrt[n]]];
  Do[
    Do[
      fields = Select[model["Subfields"], k #["Degree"] <= d &];
      power = rr[a^k]; powerVector = modelCoordinates[power, model];
      If[powerVector === $Failed, Throw[fail["FieldArithmetic", "Could not compute a target power in the model."], tag]];
      mult = fieldMulMatrix[powerVector, model["Polynomial"], model["Variable"], model["Dimension"]];
      Do[
        b1 = fields[[i]]["Basis"]; b2 = fields[[j]]["Basis"];
        matrix = Join[Transpose[b1], -mult . Transpose[b2], 2];
        kernel = NullSpace[matrix];
        If[kernel =!= {},
          vector = Take[First[kernel], Length[b1]] . b1;
          If[! nonzeroVectorQ[vector], Throw[fail["IntersectionFailure", "Unexpected zero vector in a nonzero intersection."], tag]];
          delta = modelValue[vector, model];
          beta = rr[delta^(1/k)]; gamma = rr[a/beta];
          result = certificate[a, {beta, gamma}, Times, "At most two factors, unrestricted algebraic fields"];
          If[FailureQ[result], Throw[result, tag]];
          If[result["LargestDegree"] > d,
            Throw[fail["DegreeVerification", "The constructed factors violated the proven degree bound."], tag]];
          Throw[Join[result, <|"OptimalityScope" -> "At most two factors",
            "MinimumLargestDegreeForTwoFactors" -> d,
            "NormExponent" -> k,
            "SubfieldDegrees" -> {fields[[i]]["Degree"], fields[[j]]["Degree"]}|>], tag]],
        {i, Length[fields]}, {j, i, Length[fields]}],
      {k, 1, d}],
    {d, lower, n}];
  fail["InternalFailure", "The two-factor search should succeed by the input degree."]
, tag]];

End[];
EndPackage[];
