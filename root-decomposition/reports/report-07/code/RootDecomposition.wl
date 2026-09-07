(* ::Package:: *)

(* Exact algebraic-number decompositions.
   See article.pdf for proofs, scope and verification status.
   All degree bounds are absolute degrees over Q. *)

BeginPackage["RootDecomposition`"];

RootDecomposition`AlgebraicDegree::usage = "AlgebraicDegree[a] is the degree over Q of an exact algebraic number.";
RootDecomposition`PrimeDegreeBound::usage = "PrimeDegreeBound[a] is a universal lower bound for the maximum degree in any finite sum or product representation.";
RootDecomposition`PolynomialRoots::usage = "PolynomialRoots[p,x] lists all exact roots of a nonconstant rational polynomial.";
RootDecomposition`SumPolynomial::usage = "SumPolynomial[p,q,x,z] gives the resultant for pairwise sums of roots.";
RootDecomposition`ProductPolynomial::usage = "ProductPolynomial[p,q,x,z] gives the resultant for pairwise products of roots.";
RootDecomposition`CheckDecomposition::usage = "CheckDecomposition[a,parts,op] verifies an exact sum/product and returns a certificate association. op is \"Sum\" or \"Product\".";
RootDecomposition`PairFromPolynomial::usage = "PairFromPolynomial[a,p,x,op,d] tries every root b of p and tests the degree of a-b or a/b.";
RootDecomposition`RootDictionary::usage = "RootDictionary[d,h] enumerates roots of primitive irreducible integer polynomials of degree at most d and coefficient height at most h.";
RootDecomposition`SearchRootDecomposition::usage = "SearchRootDecomposition[a,op,d,h,r] searches at most r parts; the first r-1 parts come from RootDictionary[d,h], while the final part is unrestricted apart from its degree.";
RootDecomposition`BuildGaloisData::usage = "BuildGaloisData[a] constructs the exact splitting field, automorphism matrices, all subgroups and fixed-field bases. This exhaustive backend is intended for small Galois groups.";
RootDecomposition`CompleteSumDecomposition::usage = "CompleteSumDecomposition[a,data] minimizes the maximum degree over all finite sums. data may be Automatic or BuildGaloisData[a].";
RootDecomposition`CompleteTwoFactorDecomposition::usage = "CompleteTwoFactorDecomposition[a,data] minimizes the maximum degree over two factors, including factors outside the splitting field. This is NOT a general many-factor minimizer.";

Begin["`Private`"];

(* Tagged exits are intentional. A bare Return inside Do can leave only
   the loop, not the enclosing routine. Each recursive call has its own tag. *)
SetAttributes[returnScope, HoldAll];
returnScope[body_] := Block[{$returnTag = Unique["return"]},
  Catch[body, $returnTag]];
returnValue[value_] := Throw[value, $returnTag];

rationalQ[x_] := IntegerQ[x] || Head[x] === Rational;
zeroQ[x_] := SameQ[Quiet[RootReduce[x]], 0];
validOpQ[op_] := MemberQ[{"Sum", "Product"}, op];
fail[tag_, text_] := Failure[tag, <|"MessageTemplate" -> text|>];

AlgebraicDegree[a_] := returnScope[Module[{x, p, v},
  If[!FreeQ[a, _Real],
    returnValue[fail["InexactInput", "Use an exact algebraic input, not a decimal approximation."]]];
  p = Quiet[Check[MinimalPolynomial[RootReduce[a], x], $Failed]];
  If[p === $Failed || !PolynomialQ[p, x],
    returnValue[fail["NotAlgebraic", "A rational minimal polynomial could not be computed."]]];
  v = CoefficientList[p, x];
  If[!VectorQ[v, rationalQ] || Exponent[p, x] < 1,
    returnValue[fail["NotAlgebraic", "A rational minimal polynomial could not be computed."]]];
  Exponent[p, x]
]];

primeBoundFromDegree[n_Integer] := If[n == 1, 1, Max[First /@ FactorInteger[n]]];
PrimeDegreeBound[a_] := returnScope[Module[{n = AlgebraicDegree[a]},
  If[FailureQ[n], n, primeBoundFromDegree[n]]
]];

PolynomialRoots[p_, x_Symbol] := returnScope[Module[{f, n},
  If[!PolynomialQ[p, x] || !VectorQ[CoefficientList[p, x], rationalQ],
    returnValue[fail["Polynomial", "Expected a polynomial with rational coefficients."]]];
  n = Exponent[p, x];
  If[n < 1, returnValue[fail["Polynomial", "Expected a nonconstant polynomial."]]];
  f = Function[Evaluate[p /. x -> Slot[1]]];
  Table[With[{j = k}, Root[f, j]], {k, n}]
]];

SumPolynomial[p_, q_, x_Symbol, z_Symbol] := returnScope[Module[{y},
  Expand[Resultant[p /. x -> y, q /. x -> z - y, y]]
]];
ProductPolynomial[p_, q_, x_Symbol, z_Symbol] := returnScope[Module[{y, m},
  m = Exponent[q, x];
  Expand[Resultant[p /. x -> y,
    Expand[Cancel[y^m (q /. x -> z/y)]], y]]
]];

CheckDecomposition[a_, parts_List, op_String] := returnScope[Module[
  {ps, ds, value, n, lb, expr},
  If[!validOpQ[op] || parts === {},
    returnValue[fail["Arguments", "Supply a nonempty list and operation Sum or Product."]]];
  ps = RootReduce /@ parts;
  ds = AlgebraicDegree /@ ps;
  n = AlgebraicDegree[a];
  If[FailureQ[n] || AnyTrue[ds, FailureQ],
    returnValue[fail["NotAlgebraic", "All entries must be exact algebraic numbers."]]];
  value = If[op == "Sum", Total[ps], Times @@ ps];
  If[!zeroQ[value - a],
    returnValue[fail["Equality", "The proposed decomposition failed exact verification."]]];
  lb = primeBoundFromDegree[n];
  expr = If[op == "Sum", Inactive[Plus] @@ ps, Inactive[Times] @@ ps];
  <|"Status" -> "Verified", "Input" -> RootReduce[a],
    "Operation" -> op, "Parts" -> ps, "Expression" -> expr,
    "Degrees" -> ds, "MaximumDegree" -> Max[ds], "InputDegree" -> n,
    "LowerBound" -> lb, "GlobalOptimal" -> (Max[ds] == lb),
    "OptimalityReason" -> If[Max[ds] == lb, "PrimeDivisorBound", "NotEstablished"]|>
]];

PairFromPolynomial[a_, p_, x_Symbol, op_String, d_Integer?Positive] := returnScope[Module[
  {rs, b, c, db, dc, result},
  If[!validOpQ[op], returnValue[fail["Operation", "Use Sum or Product."]]];
  rs = PolynomialRoots[p, x];
  If[FailureQ[rs], returnValue[rs]];
  Do[
    db = AlgebraicDegree[b];
    If[FailureQ[db] || db > d || (op == "Product" && zeroQ[b]), Continue[]];
    c = RootReduce[If[op == "Sum", a - b, a/b]];
    dc = AlgebraicDegree[c];
    If[IntegerQ[dc] && dc <= d,
      result = CheckDecomposition[a, {b, c}, op];
      If[!FailureQ[result], returnValue[result]]],
    {b, rs}];
  <|"Status" -> "NotFoundForThisPolynomial", "GlobalImpossibility" -> False|>
]];

Options[RootDictionary] = {"MaxPolynomials" -> 100000};
RootDictionary[d_Integer?Positive, h_Integer?Positive, OptionsPattern[]] := returnScope[Module[
  {x, m, lead, tail, coeff, p, roots = {}, count = 0,
   limit = OptionValue["MaxPolynomials"], cap, code, base},
  (* Streaming coefficient enumeration: do not allocate Tuples[-h..h,d]. *)
  base = 2 h + 1;
  Do[
    cap = base^m;
    Do[
      Do[
        count++;
        If[count > limit,
          returnValue[fail["ResourceLimit", "The polynomial-enumeration limit was reached."]]];
        tail = IntegerDigits[code, base, m] - h;
        coeff = Append[tail, lead];
        If[Apply[GCD, coeff] != 1, Continue[]];
        p = coeff . x^Range[0, m];
        If[TrueQ[IrreduciblePolynomialQ[p]],
          roots = Join[roots, PolynomialRoots[p, x]]],
        {code, 0, cap - 1}],
      {lead, 1, h}],
    {m, 1, d}];
  DeleteDuplicates[RootReduce /@ roots]
]];

Options[SearchRootDecomposition] = {
  "MaxNodes" -> 100000, "MaxPolynomials" -> 100000};
SearchRootDecomposition[a_, op_String, d_Integer?Positive,
    h_Integer?Positive, r_Integer?Positive, OptionsPattern[]] := returnScope[Module[
  {dict, walk, nodes = 0, limit = OptionValue["MaxNodes"], tag,
   parts, n, result},
  If[!validOpQ[op], returnValue[fail["Operation", "Use Sum or Product."]]];
  n = AlgebraicDegree[a];
  If[FailureQ[n], returnValue[n]];
  If[n <= d, returnValue[CheckDecomposition[a, {a}, op]]];
  If[primeBoundFromDegree[n] > d || n > d^r,
    returnValue[<|"Status" -> "ExcludedByDegreeBound", "DegreeCap" -> d,
      "MaximumParts" -> r,
      "GlobalImpossibilityAtDegreeCap" -> (primeBoundFromDegree[n] > d)|>]];
  dict = RootDictionary[d, h,
    "MaxPolynomials" -> OptionValue["MaxPolynomials"]];
  If[FailureQ[dict], returnValue[dict]];
  If[op == "Product", dict = Select[dict, !zeroQ[#] &]];
  tag = Unique["search"];
  walk[res_, slots_, start_, prefix_] := returnScope[Module[{nd, next, got, j},
    nodes++;
    If[nodes > limit, Throw[fail["ResourceLimit", "The search-node limit was reached."], tag]];
    nd = AlgebraicDegree[res];
    If[FailureQ[nd], Throw[nd, tag]];
    If[nd <= d, returnValue[Append[prefix, res]]];
    If[slots <= 1 || nd > d^slots || primeBoundFromDegree[nd] > d,
      returnValue[Missing["NotFound"]]];
    Do[
      next = RootReduce[If[op == "Sum", res - dict[[j]], res/dict[[j]]]];
      got = walk[next, slots - 1, j, Append[prefix, dict[[j]]]];
      If[ListQ[got], returnValue[got]],
      {j, start, Length[dict]}];
    Missing["NotFound"]
  ]];
  parts = Catch[walk[RootReduce[a], r, 1, {}], tag];
  If[FailureQ[parts], returnValue[parts]];
  If[!ListQ[parts], returnValue[<|"Status" -> "NotFoundWithinBounds",
    "DegreeCap" -> d, "HeightCap" -> h, "MaximumParts" -> r,
    "Nodes" -> nodes, "GlobalImpossibility" -> False|>]];
  result = CheckDecomposition[a, parts, op];
  If[FailureQ[result], result, Join[result, <|"Nodes" -> nodes|>]]
]];

(* The small-field exact backend. Vectors use 1,theta,...,theta^(N-1).
   Fixed-field bases are stored as ROW vectors. Automorphisms and
   multiplication operators act on COLUMN coordinate vectors. *)

integerPolynomial[a_, x_] := returnScope[Module[{p, c, den, gcd},
  p = MinimalPolynomial[a, x]; c = CoefficientList[p, x];
  den = Apply[LCM, Denominator /@ c]; c = den c;
  gcd = Apply[GCD, c];
  Expand[(Sign[Last[c]]/gcd) den p]
]];

makeField[theta0_] := returnScope[Module[{x, p, theta, n},
  p = integerPolynomial[theta0, x];
  theta = RootReduce[Coefficient[p, x, Exponent[p, x]] theta0];
  p = integerPolynomial[theta, x]; n = Exponent[p, x];
  <|"Generator" -> theta, "Polynomial" -> p,
    "Variable" -> x, "Dimension" -> n|>
]];

fieldVector[field_, a_] := returnScope[Module[{an, p, c, x = field["Variable"], n},
  n = field["Dimension"];
  an = Quiet[Check[ToNumberField[RootReduce[a], field["Generator"]], $Failed]];
  If[an === $Failed || !(rationalQ[an] || Head[an] === AlgebraicNumber),
    returnValue[fail["FieldMembership", "Could not express an element in the chosen field."]]];
  If[Head[an] === AlgebraicNumber && !zeroQ[an[[1]] - field["Generator"]],
    returnValue[fail["GeneratorChanged", "The coordinate generator changed unexpectedly."]]];
  p = AlgebraicNumberPolynomial[an, x];
  c = CoefficientList[p, x];
  If[!VectorQ[c, rationalQ] || Length[c] > n,
    returnValue[fail["Coordinates", "Expected rational power-basis coordinates."]]];
  PadRight[c, n]
]];

fieldElement[field_, v_List] := RootReduce[
  v . field["Generator"]^Range[0, field["Dimension"] - 1]];

polyVector[field_, p_] := PadRight[
  CoefficientList[p, field["Variable"]], field["Dimension"]];

powerMatrix[field_, cv_] := returnScope[Module[
  {x = field["Variable"], p = field["Polynomial"], n = field["Dimension"],
   c, w = 1, rows = {}, j},
  c = cv . x^Range[0, n - 1];
  Do[
    AppendTo[rows, polyVector[field, w]];
    w = PolynomialRemainder[Expand[w c], p, x], {j, n}];
  Transpose[rows]
]];

multiplicationMatrix[field_, av_] := returnScope[Module[
  {x = field["Variable"], p = field["Polynomial"], n = field["Dimension"], f},
  f = av . x^Range[0, n - 1];
  Transpose[Table[polyVector[field,
    PolynomialRemainder[Expand[f x^j], p, x]], {j, 0, n - 1}]]
]];

groupClosure[gens_List, table_, id_Integer] := returnScope[Module[
  {elts = {id}, cursor = 1, x, y, g},
  While[cursor <= Length[elts],
    x = elts[[cursor]]; cursor++;
    Do[y = table[[x, g]];
      If[!MemberQ[elts, y], AppendTo[elts, y]], {g, gens}]];
  Sort[elts]
]];

allSubgroups[table_, id_Integer, limit_] := returnScope[Module[
  {groups = {{id}}, cursor = 1, h, k, g, m = Length[table]},
  While[cursor <= Length[groups],
    h = groups[[cursor]]; cursor++;
    Do[
      If[MemberQ[h, g], Continue[]];
      k = groupClosure[Append[h, g], table, id];
      If[!MemberQ[groups, k],
        AppendTo[groups, k];
        If[Length[groups] > limit,
          returnValue[fail["ResourceLimit", "The subgroup-enumeration limit was reached."]]]],
      {g, m}]];
  groups
]];

groupExponent[table_, id_] := returnScope[Module[{orders, x, k, i},
  orders = Table[x = i; k = 1;
    While[x != id, x = table[[x, i]]; k++]; k,
    {i, Length[table]}];
  Apply[LCM, orders]
]];

Options[BuildGaloisData] = {"MaxFieldDegree" -> 128, "MaxSubgroups" -> 10000};
BuildGaloisData[a_, OptionsPattern[]] := returnScope[Module[
  {n, x, roots, common, entries, theta, field, m, conjugates, cvs, mats,
   idpos, id, table, pos, groups, subfields, h, basis, exponent},
  n = AlgebraicDegree[a]; If[FailureQ[n], returnValue[n]];
  If[n == 1, theta = 1,
    roots = PolynomialRoots[MinimalPolynomial[a, x], x];
    (* All is important: Automatic may introduce an unnecessarily large field. *)
    common = Quiet[Check[ToNumberField[roots, All], $Failed]];
    If[common === $Failed,
      returnValue[fail["PrimitiveElement", "Could not construct the splitting field."]]];
    entries = Cases[common, _AlgebraicNumber, {1}];
    If[entries === {}, returnValue[fail["PrimitiveElement", "No primitive generator was returned."]]];
    theta = entries[[1, 1]]];
  field = makeField[theta]; m = field["Dimension"];
  If[m > OptionValue["MaxFieldDegree"],
    returnValue[fail["ResourceLimit", "The splitting field exceeds MaxFieldDegree."]]];
  conjugates = PolynomialRoots[field["Polynomial"], field["Variable"]];
  cvs = fieldVector[field, #] & /@ conjugates;
  If[AnyTrue[cvs, FailureQ],
    returnValue[fail["NotGalois", "Not all conjugates could be embedded in the constructed field."]]];
  mats = powerMatrix[field, #] & /@ cvs;
  If[Length[DeleteDuplicates[mats]] != m,
    returnValue[fail["Automorphisms", "The automorphism matrices were not distinct."]]];
  idpos = FirstPosition[mats, IdentityMatrix[m]];
  If[MissingQ[idpos], returnValue[fail["Automorphisms", "Identity automorphism missing."]]];
  id = First[idpos];
  table = Table[
    pos = FirstPosition[cvs, mats[[i]] . cvs[[j]]];
    If[MissingQ[pos], 0, First[pos]], {i, m}, {j, m}];
  If[MemberQ[table, 0, Infinity],
    returnValue[fail["Automorphisms", "Automorphisms did not form a closed group."]]];
  groups = allSubgroups[table, id, OptionValue["MaxSubgroups"]];
  If[FailureQ[groups], returnValue[groups]];
  subfields = Table[
    basis = NullSpace[Join @@ ((# - IdentityMatrix[m]) & /@ mats[[h]])];
    If[Length[basis] != m/Length[h],
      returnValue[fail["FixedField", "A fixed-field dimension failed the index check."]]];
    <|"Subgroup" -> h, "Degree" -> Length[basis], "BasisRows" -> basis|>,
    {h, groups}];
  exponent = groupExponent[table, id];
  <|"Input" -> RootReduce[a], "InputDegree" -> n, "Field" -> field,
    "GroupOrder" -> m, "GroupExponent" -> exponent,
    "Automorphisms" -> mats, "GroupTable" -> table, "Identity" -> id,
    "Subfields" -> SortBy[subfields, #["Degree"] &],
    "CompleteSubfieldLattice" -> True|>
]];

galoisBound[data_] := returnScope[Module[{n = data["InputDegree"], e = data["GroupExponent"], b},
  b = SelectFirst[Range[n], Mod[Apply[LCM, Range[#]], e] == 0 &];
  Max[primeBoundFromDegree[n], b]
]];

resolveData[a_, data_] := returnScope[Module[{g},
  g = If[data === Automatic, BuildGaloisData[a], data];
  If[FailureQ[g], returnValue[g]];
  If[!AssociationQ[g] || !TrueQ[Lookup[g, "CompleteSubfieldLattice", False]] ||
      !zeroQ[g["Input"] - a],
    returnValue[fail["Data", "Use the complete BuildGaloisData result for this exact input."]]];
  g
]];

CompleteSumDecomposition[a_, data_: Automatic] := returnScope[Module[
  {g, field, n, low, target, eligible, rows, mat, coefficients,
   parts, offset, b, k, result, d},
  n = AlgebraicDegree[a]; If[FailureQ[n], returnValue[n]];
  If[n == 1, returnValue[CheckDecomposition[a, {a}, "Sum"]]];
  g = resolveData[a, data]; If[FailureQ[g], returnValue[g]];
  field = g["Field"]; low = galoisBound[g]; target = fieldVector[field, a];
  If[FailureQ[target], returnValue[target]];
  Do[
    eligible = Select[g["Subfields"], #["Degree"] <= d &];
    rows = Join @@ (#["BasisRows"] & /@ eligible);
    mat = Transpose[rows];
    coefficients = Quiet[Check[LinearSolve[mat, target], $Failed]];
    If[!ListQ[coefficients] || !VectorQ[coefficients, rationalQ], Continue[]];
    If[mat . coefficients =!= target, Continue[]];
    parts = {}; offset = 0;
    Do[
      b = entry["BasisRows"]; k = Length[b];
      AppendTo[parts, fieldElement[field,
        Take[coefficients, {offset + 1, offset + k}] . b]];
      offset += k,
      {entry, eligible}];
    parts = Select[parts, !zeroQ[#] &];
    If[parts === {}, parts = {0}];
    result = CheckDecomposition[a, parts, "Sum"];
    If[FailureQ[result], returnValue[result]];
    returnValue[Join[result, <|"LowerBound" -> d, "GlobalOptimal" -> True,
      "OptimalityReason" -> "CompleteGaloisFixedSpaceSearch",
      "GaloisGroupOrder" -> g["GroupOrder"]|>]],
    {d, low, n}];
  fail["InternalCheck", "The full field should contain a valid sum decomposition."]
]];

CompleteTwoFactorDecomposition[a_, data_: Automatic] := returnScope[Module[
  {g, field, n, low, eligible, av, mult, e, f, mat, ns, c, uv, u,
   beta, gamma, result, i, j, d, t},
  n = AlgebraicDegree[a]; If[FailureQ[n], returnValue[n]];
  If[n == 1,
    result = CheckDecomposition[a, {a, 1}, "Product"];
    returnValue[Join[result, <|"OptimalAmongTwoFactors" -> True|>]]];
  g = resolveData[a, data]; If[FailureQ[g], returnValue[g]];
  field = g["Field"]; low = Max[galoisBound[g], Ceiling[Sqrt[n]]];
  Do[
    Do[
      eligible = Select[g["Subfields"], t #["Degree"] <= d &];
      av = fieldVector[field, RootReduce[a^t]];
      If[FailureQ[av], returnValue[av]];
      mult = multiplicationMatrix[field, av];
      Do[
        e = eligible[[i]]["BasisRows"];
        Do[
          f = eligible[[j]]["BasisRows"];
          mat = Join[Transpose[e], -mult . Transpose[f], 2];
          ns = NullSpace[mat]; If[ns === {}, Continue[]];
          c = First[ns]; uv = Take[c, Length[e]] . e;
          u = fieldElement[field, uv];
          If[zeroQ[u], returnValue[fail["InternalCheck", "An intersection basis gave zero."]]];
          beta = RootReduce[u^(1/t)]; gamma = RootReduce[a/beta];
          result = CheckDecomposition[a, {beta, gamma}, "Product"];
          If[FailureQ[result], returnValue[result]];
          If[result["MaximumDegree"] > d,
            returnValue[fail["InternalCheck", "The norm-descent degree bound failed."]]];
          returnValue[Join[result, <|"OptimalAmongTwoFactors" -> True,
            "TwoFactorLowerBound" -> d, "NormExponent" -> t,
            "LowerBound" -> galoisBound[g],
            "GlobalOptimal" -> (result["MaximumDegree"] == galoisBound[g]),
            "OptimalityReason" -> If[result["MaximumDegree"] == galoisBound[g],
              "GaloisExponentAndDegreeBound", "TwoFactorsOnly"],
            "GaloisGroupOrder" -> g["GroupOrder"]|>]],
          {j, i, Length[eligible]}],
        {i, Length[eligible]}],
      {t, 1, Min[d, Floor[d^2/n]]}],
    {d, low, n}];
  fail["InternalCheck", "The pair {a,1} should always be found."]
]];

End[];
EndPackage[];
