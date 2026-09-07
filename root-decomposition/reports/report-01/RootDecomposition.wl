(* ::Package:: *)
(* Exact algebraic Root decomposition.  See article.pdf for guarantees.
   This source was reviewed but NOT executed in a native Wolfram kernel
   during preparation: the available evaluator endpoint returned HTTP 404. *)

BeginPackage["RootDecomposition`"];

AlgebraicDegree::usage = "AlgebraicDegree[a] gives the absolute degree of an exact algebraic number.";
DegreeLowerBound::usage = "DegreeLowerBound[a] gives a global lower bound for the maximum degree in any sum or product decomposition.";
ComposedRootPolynomial::usage = "ComposedRootPolynomial[p,q,x,op] constructs the monic composed polynomial; op is \"Sum\" or \"Product\".";
PolynomialRootList::usage = "PolynomialRootList[p,x] lists the distinct exact roots of a rational polynomial in square-free Root order.";
VerifyRootDecomposition::usage = "VerifyRootDecomposition[a,terms,op] verifies equality and reports degrees and any prime-bound optimality certificate.";
SelectRootPair::usage = "SelectRootPair[a,p,q,x,op] selects an exactly matching pair of conjugates from rational polynomials p and q.";
SolveRootTemplate::usage = "SolveRootTemplate[a,p,q,vars,x,op] solves a fixed polynomial template and accepts only fully instantiated rational-coefficient candidates. It is not a global negative decision procedure.";
PolynomialCatalog::usage = "PolynomialCatalog[d,h,x] enumerates primitive integer polynomials of degree at most d and coefficient height at most h, retaining irreducible polynomials and returning monic rational versions.";
SearchRootCatalog::usage = "SearchRootCatalog[a,polys,x,op] searches pairs from a finite polynomial catalog.";
SearchProductResidual::usage = "SearchProductResidual[a,d,polys,x,k] searches products with at most k factors, choosing all but the last factor from polys and testing the exact residual degree.";
SplitOverFields::usage = "SplitOverFields[a,e,f,op] decides whether a is a sum/product of elements of Q(e) and Q(f), by exact rational linear algebra.";
MinimumSumDecomposition::usage = "MinimumSumDecomposition[a] computes a globally degree-minimal sum decomposition by the conjugate-subset theorem, subject to explicit resource guards.";

Begin["`Private`"];

rationalQ[z_] := MatchQ[z, _Integer | _Rational];
exactAlgebraicQ[z_] := FreeQ[z, _Real] && TrueQ[Element[z, Algebraics]];
zeroQ[z_] := TrueQ[Quiet[Check[RootReduce[z], $Failed]] === 0];
err[tag_, text_, extra_: <||>] := Failure[tag, Join[<|"MessageTemplate" -> text|>, extra]];
operationQ[op_] := MemberQ[{"Sum", "Product"}, op];
rationalPolynomialQ[p_, x_Symbol] := PolynomialQ[p, x] &&
  Exponent[p, x] >= 1 && AllTrue[CoefficientList[Expand[p], x], rationalQ];
monic[p_, x_Symbol] := Expand[p/Coefficient[p, x, Exponent[p, x]]];
squareFreeMonic[p_, x_Symbol] := monic[Cancel[p/PolynomialGCD[p, D[p, x]]], x];

AlgebraicDegree[a_] := Module[{x = Unique["x$"], p},
  If[!exactAlgebraicQ[a], Return[err["NotExactAlgebraic", "Expected an exact algebraic number."]]];
  p = Quiet[Check[MinimalPolynomial[a, x], $Failed]];
  If[p === $Failed || !rationalPolynomialQ[p, x],
    err["MinimalPolynomialFailed", "Could not compute a rational minimal polynomial."],
    Exponent[p, x]]
];

DegreeLowerBound[a_] := Module[{n = AlgebraicDegree[a]},
  If[FailureQ[n], Return[n]];
  If[n == 1, 1, Max[First /@ FactorInteger[n]]]
];

ComposedRootPolynomial[p_, q_, x_Symbol, op_] := Module[
  {t = Unique["t$"], pp, qq, s, transformed, r},
  If[!operationQ[op], Return[err["Operation", "Operation must be Sum or Product."]]];
  If[!PolynomialQ[p, x] || !PolynomialQ[q, x] ||
     Exponent[p, x] < 1 || Exponent[q, x] < 1,
    Return[err["Polynomial", "Expected two nonconstant polynomials."]]];
  pp = monic[p, x]; qq = monic[q, x]; s = Exponent[qq, x];
  transformed = If[op === "Sum", qq /. x -> (x - t),
    Sum[Coefficient[qq, x, j] x^j t^(s - j), {j, 0, s}]];
  r = Resultant[pp /. x -> t, transformed, t];
  Expand[r]
];

PolynomialRootList[p_, x_Symbol] := Module[{q, fun, n},
  If[!rationalPolynomialQ[p, x],
    Return[err["RationalPolynomial", "Root polynomials must have rational coefficients."]]];
  q = squareFreeMonic[p, x]; n = Exponent[q, x];
  fun = Function[Evaluate[q /. x -> Slot[1]]];
  Table[Root[fun, j], {j, 1, n}]
];

VerifyRootDecomposition[a_, supplied_List, op_] := Module[
  {terms, value, degrees, n, lb, d, optimal},
  If[!operationQ[op], Return[err["Operation", "Operation must be Sum or Product."]]];
  If[!exactAlgebraicQ[a] || supplied === {} || !AllTrue[supplied, exactAlgebraicQ],
    Return[err["Input", "Expected exact algebraic input and a nonempty list of exact terms."]]];
  terms = RootReduce /@ supplied;
  value = If[op === "Sum", Total[terms], Times @@ terms];
  If[!zeroQ[a - value], Return[err["NotEqual", "The proposed decomposition is not exactly equal to the input."]]];
  terms = If[op === "Sum", Select[terms, !zeroQ[#] &], Select[terms, !zeroQ[# - 1] &]];
  If[terms === {}, terms = {If[op === "Sum", 0, 1]}];
  degrees = AlgebraicDegree /@ terms; n = AlgebraicDegree[a];
  If[AnyTrue[degrees, FailureQ] || FailureQ[n], Return[err["DegreeFailed", "Degree computation failed."]]];
  lb = DegreeLowerBound[a]; d = Max[degrees]; optimal = (d == lb);
  <|"Input" -> a, "Operation" -> op, "Terms" -> terms,
    "Expression" -> If[op === "Sum", Inactive[Plus] @@ terms, Inactive[Times] @@ terms],
    "Verified" -> True, "Degrees" -> degrees, "MaximumDegree" -> d,
    "InputDegree" -> n, "LowerBound" -> lb,
    "Status" -> If[optimal, "GloballyOptimal", "CertifiedUpperBound"],
    "OptimalityReason" -> If[optimal, "LargestPrimeDivisorBound", "NotEstablished"]|>
];

SelectRootPair[a_, p_, q_, x_Symbol, op_] := Module[
  {f, r, pr, qr, v, cert, tag = Unique["pair$"]},
  If[!operationQ[op] || !exactAlgebraicQ[a], Return[err["Input", "Invalid input or operation."]]];
  If[!rationalPolynomialQ[p, x] || !rationalPolynomialQ[q, x],
    Return[err["RationalPolynomial", "Candidate coefficients must all be rational."]]];
  f = monic[MinimalPolynomial[a, x], x];
  r = ComposedRootPolynomial[p, q, x, op];
  If[Expand[PolynomialRemainder[r, f, x]] =!= 0,
    Return[err["NoPair", "The minimal polynomial does not divide the composed polynomial."]]];
  pr = PolynomialRootList[p, x]; qr = PolynomialRootList[q, x];
  Catch[
    Do[
      v = If[op === "Sum", pr[[i]] + qr[[j]], pr[[i]] qr[[j]]];
      If[zeroQ[a - v],
        cert = VerifyRootDecomposition[a, {pr[[i]], qr[[j]]}, op];
        If[!FailureQ[cert], Throw[Join[cert,
          <|"Polynomials" -> {squareFreeMonic[p, x], squareFreeMonic[q, x]},
            "RootIndices" -> {i, j}|>], tag]]],
      {i, Length[pr]}, {j, Length[qr]}];
    err["RootSelectionFailed", "Divisibility held but no exact conjugate pair was selected."],
    tag]
];

SolveRootTemplate[a_, p_, q_, vars_List, x_Symbol, op_] := Module[
  {f, r, remainder, equations, solutions, pp, qq, cert, out = {}, rejected = 0},
  If[!exactAlgebraicQ[a] || !operationQ[op], Return[err["Input", "Invalid exact input or operation."]]];
  f = monic[MinimalPolynomial[a, x], x];
  r = ComposedRootPolynomial[p, q, x, op];
  If[FailureQ[r], Return[r]];
  remainder = Expand[PolynomialRemainder[r, f, x]];
  equations = (# == 0 &) /@ CoefficientList[remainder, x];
  solutions = Quiet[Check[Solve[equations, vars], $Failed]];
  If[solutions === $Failed || !ListQ[solutions] || !AllTrue[solutions, ListQ],
    Return[err["SolverUnresolved", "Solve did not return a usable list of rule lists.",
      <|"Equations" -> equations|>]]];
  Do[
    pp = Expand[p /. rules]; qq = Expand[q /. rules];
    If[rationalPolynomialQ[pp, x] && rationalPolynomialQ[qq, x],
      cert = SelectRootPair[a, pp, qq, x, op];
      If[!FailureQ[cert], AppendTo[out, cert], rejected++], rejected++],
    {rules, solutions}];
  <|"Status" -> "TemplateSearchCompleted", "Candidates" -> DeleteDuplicates[out],
    "Equations" -> equations, "SolverRules" -> solutions,
    "RejectedOrUnresolvedCount" -> rejected,
    "NegativeGlobalConclusion" -> False|>
];

Options[PolynomialCatalog] = {"MonicOnly" -> False};
PolynomialCatalog[d_Integer?Positive, h_Integer?Positive, x_Symbol, OptionsPattern[]] := Module[
  {out = {}, leading, v, p},
  leading = If[TrueQ[OptionValue["MonicOnly"]], {1}, Range[h]];
  Do[
    Do[
      v = Append[c, lc];
      If[Apply[GCD, Abs[v]] == 1,
        p = v . x^Range[0, m];
        If[TrueQ[IrreduciblePolynomialQ[p]], AppendTo[out, monic[p, x]]]],
      {lc, leading}, {c, Tuples[Range[-h, h], m]}],
    {m, 1, d}];
  DeleteDuplicates[out]
];

SearchRootCatalog[a_, polys_List, x_Symbol, op_] := Module[
  {ps, n, pairs, cert, tag = Unique["catalog$"]},
  If[!exactAlgebraicQ[a] || !operationQ[op], Return[err["Input", "Invalid input."]]];
  If[!AllTrue[polys, rationalPolynomialQ[#, x] &], Return[err["Catalog", "Invalid polynomial catalog."]]];
  ps = DeleteDuplicates[monic[#, x] & /@ polys]; n = AlgebraicDegree[a];
  pairs = Flatten[Table[{i, j}, {i, Length[ps]}, {j, i, Length[ps]}], 1];
  pairs = Select[pairs, Exponent[ps[[#[[1]]]], x] Exponent[ps[[#[[2]]]], x] >= n &];
  pairs = SortBy[pairs, Max[Exponent[ps[[#[[1]]]], x], Exponent[ps[[#[[2]]]], x]] &];
  Catch[
    Do[
      cert = SelectRootPair[a, ps[[ij[[1]]]], ps[[ij[[2]]]], x, op];
      If[!FailureQ[cert], Throw[cert, tag]];
      If[cert[[1]] =!= "NoPair", Throw[cert, tag]], {ij, pairs}];
    err["NotFoundInCatalog", "No matching pair was found in this finite catalog; this is not global nonexistence."],
    tag]
];

SearchProductResidual[a_, d_Integer?Positive, polys_List, x_Symbol, k_Integer?Positive] := Module[
  {roots, degrees, walk, answer, tag = Unique["found$"]},
  If[!exactAlgebraicQ[a] || !AllTrue[polys, rationalPolynomialQ[#, x] &],
    Return[err["Input", "Invalid exact input or catalog."]]];
  roots = Quiet[Check[DeleteDuplicates[RootReduce /@
    Flatten[PolynomialRootList[#, x] & /@ polys]], $Failed]];
  If[roots === $Failed, Return[err["CatalogEvaluationFailed", "Could not evaluate the exact catalog roots."]]];
  degrees = AlgebraicDegree /@ roots;
  If[AnyTrue[degrees, FailureQ], Return[err["DegreeFailed", "A catalog root degree could not be computed."]]];
  roots = Pick[roots, MapThread[TrueQ[#2 <= d] && !zeroQ[#1] && !zeroQ[#1 - 1] &, {roots, degrees}]];
  walk[residual_, prefix_List, start_Integer] := Module[{degree, next, cert},
    degree = AlgebraicDegree[residual];
    If[FailureQ[degree], Throw[degree, tag]];
    If[degree <= d,
      cert = VerifyRootDecomposition[a, Append[prefix, residual], "Product"];
      If[!FailureQ[cert], Throw[cert, tag]]];
    If[Length[prefix] >= k - 1, Return[Null]];
    Do[next = RootReduce[residual/roots[[i]]];
      walk[next, Append[prefix, roots[[i]]], i], {i, start, Length[roots]}]
  ];
  answer = Catch[walk[a, {}, 1]; Missing["NotFound"], tag];
  If[MissingQ[answer], err["NotFoundWithinBounds", "No decomposition was found within the supplied catalog and factor-count bound."], answer]
];

(* Consistent rational coordinates in one integral primitive-element basis. *)
commonCoordinates[values_List] := Module[{nf, sample, theta, n, vectors, z},
  nf = Quiet[Check[ToNumberField[values, All], $Failed]];
  If[nf === $Failed || !ListQ[nf], Return[err["NumberFieldFailed", "ToNumberField did not produce a common field."]]];
  If[AllTrue[nf, rationalQ], Return[<|"Generator" -> 0, "Degree" -> 1, "Rows" -> (List /@ nf)|>]];
  sample = SelectFirst[nf, MatchQ[#, _AlgebraicNumber] &, Missing["Generator"]];
  If[MissingQ[sample], Return[err["GeneratorFailed", "No explicit common-field generator was returned."]]];
  theta = sample[[1]]; n = AlgebraicDegree[theta];
  If[FailureQ[n], Return[n]];
  vectors = Table[
    z = If[rationalQ[v], v, Quiet[Check[ToNumberField[v, theta], $Failed]]];
    Which[rationalQ[z], PadRight[{z}, n],
      MatchQ[z, _AlgebraicNumber] && SameQ[z[[1]], theta] &&
        Length[z[[2]]] <= n && AllTrue[z[[2]], rationalQ], PadRight[z[[2]], n],
      True, $Failed], {v, nf}];
  If[MemberQ[vectors, $Failed], Return[err["CoordinatesFailed", "Could not establish a consistent rational power basis."]]];
  <|"Generator" -> theta, "Degree" -> n, "Rows" -> vectors|>
];

SplitOverFields[a_, e_, f_, op_] := Module[
  {r, s, eb, fb, data, rows, target, mat, sol, null, beta, gamma, cert},
  If[!operationQ[op] || !AllTrue[{a, e, f}, exactAlgebraicQ], Return[err["Input", "Expected exact algebraic inputs."]]];
  If[op === "Product" && zeroQ[a], Return[VerifyRootDecomposition[a, {0, 1}, op]]];
  r = AlgebraicDegree[e]; s = AlgebraicDegree[f];
  If[FailureQ[r] || FailureQ[s], Return[err["DegreeFailed", "Field-degree computation failed."]]];
  eb = e^Range[0, r - 1]; fb = f^Range[0, s - 1];
  If[op === "Sum",
    data = commonCoordinates[Join[{a}, eb, fb]];
    If[FailureQ[data], Return[data]];
    rows = data["Rows"]; target = First[rows]; mat = Transpose[Rest[rows]];
    If[MatrixRank[Rest[rows]] != MatrixRank[rows],
      Return[err["NoSplitInFields", "The input is not in the sum of the specified fields."]]];
    sol = Quiet[Check[LinearSolve[mat, target], $Failed]];
    If[sol === $Failed, Return[err["LinearSolveFailed", "Exact linear solving failed."]]];
    beta = Take[sol, r] . eb; gamma = Drop[sol, r] . fb,
    data = commonCoordinates[Join[eb, a fb]];
    If[FailureQ[data], Return[data]];
    rows = data["Rows"];
    mat = Transpose[Join[Take[rows, r], -Drop[rows, r]]];
    null = NullSpace[mat];
    If[null === {}, Return[err["NoSplitInFields", "The intersection E with a F is zero."]]];
    sol = First[null]; beta = Take[sol, r] . eb;
    gamma = 1/(Drop[sol, r] . fb)
  ];
  cert = VerifyRootDecomposition[a, {beta, gamma}, op];
  If[FailureQ[cert], cert, Join[cert, <|"FieldGenerators" -> {e, f}, "Method" -> "RationalLinearAlgebra"|>]]
];

Options[MinimumSumDecomposition] = {"MaxConjugates" -> 10, "MaxFieldDegree" -> 4096};
MinimumSumDecomposition[a_, OptionsPattern[]] := Module[
  {n, lb, x = Unique["x$"], f, roots, data, theta, dimension, rootRows,
   target, candidates, entries, basis = {}, row, proposed, rank, sol,
   terms, cert, one, zero, candidateCount, tag = Unique["sum$"]},
  n = AlgebraicDegree[a]; If[FailureQ[n], Return[n]];
  lb = DegreeLowerBound[a];
  If[n == lb, Return[VerifyRootDecomposition[a, {a}, "Sum"]]];
  If[TrueQ[n > OptionValue["MaxConjugates"]],
    Return[err["ConjugateBudget", "Increase MaxConjugates to permit the exponential subset search.", <|"InputDegree" -> n|>]]];
  f = monic[MinimalPolynomial[a, x], x]; roots = PolynomialRootList[f, x];
  data = commonCoordinates[Prepend[roots, a]];
  If[FailureQ[data], Return[data]];
  theta = data["Generator"]; dimension = data["Degree"];
  If[TrueQ[dimension > OptionValue["MaxFieldDegree"]],
    Return[err["FieldBudget", "The constructed splitting field exceeds MaxFieldDegree.", <|"FieldDegree" -> dimension|>]]];
  target = First[data["Rows"]]; rootRows = Rest[data["Rows"]];
  one = UnitVector[dimension, 1]; zero = ConstantArray[0, dimension];
  candidates = DeleteDuplicates[Join[{one}, Total /@ Subsets[Most[rootRows], {1, n - 1}]]];
  candidates = Select[candidates, !SameQ[#, zero] &]; candidateCount = Length[candidates];
  entries = {AlgebraicDegree[AlgebraicNumber[theta, #]], #} & /@ candidates;
  If[AnyTrue[entries, FailureQ[First[#]] &], Return[err["CandidateDegreeFailed", "A subset-sum degree could not be computed."]]];
  (* Values of degree n or greater cannot improve on the trivial answer. *)
  entries = SortBy[Select[entries, First[#] < n &], First];
  Catch[
    Do[
      row = entry[[2]]; proposed = Append[basis, row]; rank = MatrixRank[proposed];
      If[rank > Length[basis],
        basis = proposed;
        If[MatrixRank[Append[basis, target]] == rank,
          sol = Quiet[Check[LinearSolve[Transpose[basis], target], $Failed]];
          If[sol === $Failed, Throw[err["LinearSolveFailed", "Exact subset-span solving failed."], tag]];
          terms = MapThread[#1 AlgebraicNumber[theta, #2] &, {sol, basis}];
          cert = VerifyRootDecomposition[a, terms, "Sum"];
          If[FailureQ[cert], Throw[cert, tag]];
          Throw[Join[cert, <|"Status" -> "GloballyOptimal",
            "OptimalityReason" -> "CompleteConjugateSubsetTheorem",
            "SplittingFieldDegree" -> dimension, "CandidateCount" -> candidateCount|>], tag]
        ]
      ], {entry, entries}];
    cert = VerifyRootDecomposition[a, {a}, "Sum"];
    If[FailureQ[cert], cert, Join[cert, <|"Status" -> "GloballyOptimal",
      "OptimalityReason" -> "CompleteConjugateSubsetTheorem",
      "SplittingFieldDegree" -> dimension, "CandidateCount" -> candidateCount|>]],
    tag]
];

End[];
EndPackage[];
