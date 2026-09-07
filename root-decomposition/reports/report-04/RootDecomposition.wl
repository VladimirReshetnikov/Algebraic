(* RootDecomposition.wl -- exact, certificate-oriented algebraic decomposition.
   See article.pdf and README.md for the precise completeness contracts.
   Exact identities were independently checked with SymPy. This file has not
   been executed in a Wolfram kernel in the preparation environment. *)

BeginPackage["RootDecomposition`"];
RDZeroQ::usage = "RDZeroQ[z] tests exact algebraic equality to zero.";
RDDegree::usage = "RDDegree[a] gives the absolute algebraic degree of an exact input.";
RDPrimeLowerBound::usage = "RDPrimeLowerBound[a] is a global lower bound for either decomposition problem.";
RDRoots::usage = "RDRoots[p,x] lists all exact roots of a rational polynomial.";
RDCompose::usage = "RDCompose[p,q,x,op] forms the sum/product composed polynomial; op is \"Sum\" or \"Product\".";
RDPair::usage = "RDPair[a,p,q,x,op] finds and certifies a matching pair of roots.";
RDComplementPolynomials::usage = "RDComplementPolynomials[P,A,x,d,op] finds all irreducible complementary polynomials of degree at most d.";
RDSplitWithPolynomial::usage = "RDSplitWithPolynomial[a,A,x,d,op] searches all roots of A for a two-term decomposition.";
RDCatalog::usage = "RDCatalog[d,h,x] enumerates primitive irreducible integer polynomials of degree 2 through d and coefficient height at most h.";
RDBoundedSplit::usage = "RDBoundedSplit[a,d,h,op] is a complete two-term search with one polynomial bounded by degree d and height h.";
RDPoolSplit::usage = "RDPoolSplit[a,pool,d,k,op] searches at most k terms, with all but the last drawn from pool.";
RDSumInFields::usage = "RDSumInFields[a,generators] finds the smallest sufficient threshold on the degrees of the supplied fields; this is not generally the true degree optimum.";
RDGlobalSum::usage = "RDGlobalSum[a] computes a globally degree-minimal pure sum, subject to explicit resource limits.";
RDVerify::usage = "RDVerify[a,result] independently rechecks a returned decomposition and its reported degrees.";

Begin["`Private`"];

ratQ[z_] := MatchQ[z, _Integer | _Rational];
validOpQ[op_] := MemberQ[{"Sum", "Product"}, op];
combine[ts_List, op_] := If[op === "Sum", Total[ts], Times @@ ts];
exactFailure[tag_, msg_] := Failure[tag, <|"MessageTemplate" -> msg|>];

zeroDecision[z_] := Module[{r},
  If[! FreeQ[z, _Real], Return[exactFailure["InexactInput", "An equality test received inexact input."]]];
  r = Quiet[Check[RootReduce[z], $Failed]];
  If[r === $Failed || ! FreeQ[r, _RootReduce] || ! TrueQ[Element[r, Algebraics]],
    exactFailure["Equality", "Exact algebraic equality could not be decided."], r === 0]
];
RDZeroQ[z_] := TrueQ[zeroDecision[z]];

RDDegree[a_] := Module[{x, p},
  If[! FreeQ[a, _Real],
    Return[exactFailure["InexactInput", "Use an exact algebraic input."]]];
  p = Quiet[Check[MinimalPolynomial[a, x], $Failed]];
  If[p === $Failed || ! PolynomialQ[p, x] ||
     ! VectorQ[CoefficientList[p, x], ratQ] || Exponent[p, x] < 1,
    exactFailure["NotAlgebraic", "The input must be an exact algebraic number."],
    Exponent[p, x]]
];

primeBound[n_Integer] := If[n == 1, 1, Max[First /@ FactorInteger[n]]];
RDPrimeLowerBound[a_] := Module[{n = RDDegree[a]},
  If[FailureQ[n], n, primeBound[n]]];

rationalPolyQ[p_, x_] := PolynomialQ[p, x] &&
  VectorQ[CoefficientList[p, x], ratQ] && Exponent[p, x] >= 1;
monic[p_, x_] := Expand[p/Coefficient[p, x, Exponent[p, x]]];

RDRoots[p_, x_Symbol] := Module[{q = Expand[p], fn, n},
  If[! rationalPolyQ[q, x],
    Return[exactFailure["Polynomial", "A nonconstant rational polynomial is required."]]];
  n = Exponent[q, x];
  fn = Function[Evaluate[q /. x -> Slot[1]]];
  With[{f = fn}, Table[Root[f, j], {j, n}]]
];

(* Coefficients of p and q may be symbolic here. *)
RDCompose[p_, q_, x_Symbol, op_] := Module[{t, m, n, a, b, h},
  If[! validOpQ[op], Return[exactFailure["Operation", "Use Sum or Product."]]];
  m = Exponent[p, x]; n = Exponent[q, x];
  If[! IntegerQ[m] || ! IntegerQ[n] || Min[m, n] < 1,
    Return[exactFailure["Polynomial", "Both polynomials must have positive degree."]]];
  a = monic[p, x] /. x -> t; b = monic[q, x];
  h = If[op === "Sum", Expand[b /. x -> x - t],
    Sum[Coefficient[b, x, j] x^j t^(n-j), {j, 0, n}]];
  Expand[Resultant[a, h, t]]
];

certificate[a_, terms_List, op_, scope_] := Module[{ds, n, lo, value, test},
  ds = RDDegree /@ terms; n = RDDegree[a];
  If[AnyTrue[Join[ds, {n}], FailureQ],
    Return[exactFailure["Degree", "Could not certify every absolute degree."]]];
  value = combine[terms, op];
  test = zeroDecision[a - value]; If[FailureQ[test], Return[test]];
  If[! TrueQ[test],
    Return[exactFailure["Verification", "Exact equality verification failed."]]];
  lo = primeBound[n];
  <|"Status" -> "Found", "Operation" -> op, "Terms" -> terms,
    "Expression" -> If[op === "Sum", Inactive[Plus] @@ terms,
                                            Inactive[Times] @@ terms],
    "Degrees" -> ds, "MaximumDegree" -> Max[ds],
    "InputDegree" -> n, "GlobalLowerBound" -> lo,
    "GlobalOptimal" -> (Max[ds] == lo),
    "Certificate" -> "Exact RootReduce equality and absolute degrees",
    "SearchScope" -> scope|>
];

RDVerify[a_, r_Association] := Module[{ts, ds},
  If[Lookup[r, "Status", ""] =!= "Found" ||
     ! validOpQ[Lookup[r, "Operation", ""]], Return[False]];
  ts = r["Terms"]; ds = RDDegree /@ ts;
  ListQ[ts] && Length[ts] > 0 && FreeQ[ds, _Failure] &&
    ds === r["Degrees"] && Max[ds] === r["MaximumDegree"] &&
    RDZeroQ[a - combine[ts, r["Operation"]]]
];
RDVerify[_, _] := False;

RDPair[a_, p_, q_, x_Symbol, op_] := Module[{rs, ss, b, c, test},
  If[! validOpQ[op], Return[exactFailure["Operation", "Use Sum or Product."]]];
  rs = RDRoots[p, x]; ss = RDRoots[q, x];
  If[FailureQ[rs] || FailureQ[ss], Return[exactFailure["Polynomial", "Invalid root polynomial."]]];
  Do[test = zeroDecision[a - combine[{b, c}, op]];
    If[FailureQ[test], Return[test]];
    If[TrueQ[test],
      Return[certificate[a, {b, c}, op, "All root pairs of the supplied polynomials"]]],
    {b, rs}, {c, ss}];
  <|"Status" -> "NotFound", "SearchComplete" -> True,
    "SearchScope" -> "All root pairs of the supplied polynomials",
    "GlobalOptimal" -> False|>
];

(* Inverse composition. The signs/scalar contents of resultants are irrelevant
   to FactorList. Multiplicities are deliberately discarded after factoring. *)
RDComplementPolynomials[p_, a_, x_Symbol, d_Integer?Positive, op_] :=
 Module[{t, res, fs},
  If[! validOpQ[op] || ! rationalPolyQ[p, x] || ! rationalPolyQ[a, x],
    Return[exactFailure["Arguments", "Use rational polynomials and a valid operation."]]];
  If[op === "Product" && TrueQ[(a /. x -> 0) == 0],
    Return[exactFailure["ZeroFactor", "The first polynomial must not have zero as a root."]]];
  res = Quiet[Check[Resultant[a /. x -> t,
    p /. x -> If[op === "Sum", x + t, x*t], t], $Failed]];
  If[res === $Failed || ! rationalPolyQ[res, x],
    Return[exactFailure["Resultant", "Inverse composition did not produce a rational polynomial."]]];
  fs = Quiet[Check[FactorList[res], $Failed]];
  If[fs === $Failed || ! ListQ[fs],
    Return[exactFailure["Factorization", "Exact rational factorization failed."]]];
  fs = First /@ Rest[fs];
  monic[#, x] & /@ Select[fs, 1 <= Exponent[#, x] <= d &]
];

RDSplitWithPolynomial[a_, p_, x_Symbol, d_Integer?Positive, op_] :=
 Module[{n, f, qs, q, ans},
  n = RDDegree[a]; If[FailureQ[n], Return[n]];
  If[! validOpQ[op] || ! rationalPolyQ[p, x] || Exponent[p, x] > d,
    Return[exactFailure["Arguments", "Check the candidate polynomial and degree cap."]]];
  f = MinimalPolynomial[a, x];
  qs = RDComplementPolynomials[f, p, x, d, op];
  If[FailureQ[qs], Return[qs]];
  Do[ans = RDPair[a, p, q, x, op];
    If[FailureQ[ans], Return[ans]];
    If[AssociationQ[ans] && ans["Status"] === "Found", Return[ans]], {q, qs}];
  <|"Status" -> "NotFound", "SearchComplete" -> True,
    "SearchScope" -> "First component a root of the supplied polynomial; complementary degree bounded",
    "GlobalOptimal" -> False|>
];

Options[RDCatalog] = {"MaxCandidates" -> 1000000};
RDCatalog[d_Integer?Positive, h_Integer?Positive, x_Symbol, OptionsPattern[]] :=
 Module[{rawCount, bags, n, lead, cs, v, p, cap},
  cap = OptionValue["MaxCandidates"];
  rawCount = Sum[h (2 h + 1)^n, {n, 2, d}];
  If[rawCount > cap,
    Return[exactFailure["ResourceLimit", "The polynomial catalog exceeds MaxCandidates."]]];
  bags = Reap[
    Do[Do[v = Append[cs, lead];
      If[Apply[GCD, v] == 1,
        p = Expand[v . x^Range[0, n]];
        If[TrueQ[IrreduciblePolynomialQ[p]], Sow[p]]],
      {lead, 1, h}, {cs, Tuples[Range[-h, h], n]}], {n, 2, d}]
    ][[2]];
  If[bags === {}, {}, First[bags]]
];

Options[RDBoundedSplit] = {"MaxCandidates" -> 1000000};
RDBoundedSplit[a_, d_Integer?Positive, h_Integer?Positive, op_, OptionsPattern[]] :=
 Module[{n, x, ps, ans, p},
  n = RDDegree[a]; If[FailureQ[n], Return[n]];
  If[! validOpQ[op], Return[exactFailure["Operation", "Use Sum or Product."]]];
  If[n <= d, Return[certificate[a, {RootReduce[a]}, op, "Trivial permitted decomposition"]]];
  If[n > d^2,
    Return[<|"Status" -> "NoTwoTermDecomposition", "SearchComplete" -> True,
      "Reason" -> "Input degree exceeds d^2", "GlobalOptimal" -> False|>]];
  ps = RDCatalog[d, h, x, "MaxCandidates" -> OptionValue["MaxCandidates"]];
  If[FailureQ[ps], Return[ps]];
  Do[If[n <= d Exponent[p, x],
    ans = RDSplitWithPolynomial[a, p, x, d, op];
    If[FailureQ[ans], Return[ans]];
    If[ans["Status"] === "Found",
      Return[Join[ans, <|"HeightBound" -> h,
        "SearchScope" -> "Two terms; first primitive integer polynomial has height <= h; both degrees <= d"|>]]]],
    {p, ps}];
  <|"Status" -> "NotFoundWithinBounds", "SearchComplete" -> True,
    "DegreeBound" -> d, "HeightBound" -> h,
    "SearchScope" -> "Two terms; first primitive integer polynomial has height <= h; both degrees <= d",
    "GlobalOptimal" -> False|>
];

(* Finite many-term search. It is NOT restricted to low-degree intermediate
   residuals. A final component is allowed outside the supplied pool. *)
RDPoolSplit[a_, pool_List, d_Integer?Positive, k_Integer?Positive, op_] :=
 Module[{n, ps, walk, ans, tag = Unique["found"], ds},
  n = RDDegree[a]; If[FailureQ[n], Return[n]];
  If[! validOpQ[op], Return[exactFailure["Operation", "Use Sum or Product."]]];
  ds = RDDegree /@ pool;
  If[AnyTrue[ds, FailureQ] || AnyTrue[ds, # > d &],
    Return[exactFailure["Pool", "Every pool element must be exact and have degree at most d."]]];
  ps = If[op === "Product", Select[pool, ! RDZeroQ[#] &], pool];
  walk[res_, left_, start_, prefix_] := Module[{nr, j, next},
    nr = RDDegree[res]; If[FailureQ[nr], Throw[nr, tag]];
    If[nr <= d, Throw[Append[prefix, RootReduce[res]], tag]];
    If[left <= 1 || nr > d^left, Return[Null]];
    Do[next = RootReduce[If[op === "Sum", res - ps[[j]], res/ps[[j]]]];
      walk[next, left - 1, j, Append[prefix, ps[[j]]]], {j, start, Length[ps]}]
  ];
  ans = Catch[walk[a, k, 1, {}]; Missing["NotFound"], tag];
  Which[FailureQ[ans], ans, ListQ[ans],
    certificate[a, ans, op, "At most k terms; all but the last from the finite pool"],
    True, <|"Status" -> "NotFoundWithinPool", "SearchComplete" -> True,
      "SearchScope" -> "At most k terms; all but the last from the finite pool",
      "GlobalOptimal" -> False|>]
];

(* Coordinates use the same integral primitive generator throughout.
   The All argument is important: it requests the smallest common field. *)
primitive[els_List] := Module[{a, ts},
  a = Quiet[Check[ToNumberField[els, All], $Failed]];
  If[a === $Failed, Return[exactFailure["NumberField", "Primitive-element construction failed."]]];
  ts = Cases[a, AlgebraicNumber[t_, _List] :> t, {1}];
  If[ts === {}, If[VectorQ[els, ratQ], 0,
    exactFailure["NumberField", "No common primitive generator was returned."]], First[ts]]
];

coords[a_, theta_, dd_Integer] := Module[{u, z, q},
  u = Quiet[Check[ToNumberField[a, theta], $Failed]];
  If[u === $Failed || !(ratQ[u] || Head[u] === AlgebraicNumber),
    Return[exactFailure["Embedding", "An element was not represented in the specified field."]]];
  If[Head[u] === AlgebraicNumber && ! RDZeroQ[u[[1]] - theta],
    Return[exactFailure["Generator", "The number-field generator changed unexpectedly."]]];
  q = AlgebraicNumberPolynomial[u, z];
  If[! PolynomialQ[q, z] || ! VectorQ[CoefficientList[q, z], ratQ] || Exponent[q, z] >= dd,
    Return[exactFailure["Coordinates", "Invalid rational power-basis coordinates."]]];
  PadRight[CoefficientList[q, z], dd]
];

(* Select independent vectors without ever merging them: merging vectors from
   different fields could increase their algebraic degrees. *)
independentRows[rows_List] := Module[{out = {}, r = 0, nr, v},
  Do[nr = MatrixRank[Append[out, v]];
    If[nr > r, AppendTo[out, v]; r = nr], {v, rows}]; out
];
canonicalRows[rows_List] := Select[RowReduce[rows], ! AllTrue[#, # == 0 &] &];

sumFromSpaces[a_, theta_, spaces_List, global_] := Module[
  {dd, av, n, lo, d, eligible, rows, basis, co, ts, ans, bp, dmax},
  dd = RDDegree[theta]; av = coords[a, theta, dd];
  If[FailureQ[av], Return[av]];
  n = RDDegree[a]; lo = primeBound[n]; bp = theta^Range[0, dd-1];
  dmax = If[TrueQ[global], n, Max[Lookup[spaces, "Degree"]]];
  Do[eligible = Select[spaces, #["Degree"] <= d &];
    rows = If[eligible === {}, {}, Join @@ Lookup[eligible, "Basis"]];
    If[rows === {}, Continue[]];
    basis = independentRows[rows];
    If[MatrixRank[Append[basis, av]] > Length[basis], Continue[]];
    co = Quiet[Check[LinearSolve[Transpose[basis], av], $Failed]];
    If[co === $Failed, Return[exactFailure["LinearSolve", "Exact span solving failed."]]];
    ts = MapThread[RootReduce[#1 (#2 . bp)] &, {co, basis}];
    ts = Select[ts, ! RDZeroQ[#] &]; If[ts === {}, ts = {0}];
    ans = certificate[a, ts, "Sum", If[global,
      "All subfields of a normal closure; normalized-trace reduction",
      "All elements of the supplied number fields"]];
    If[FailureQ[ans], Return[ans]];
    Return[Join[ans, <|"GlobalOptimal" -> (TrueQ[global] || ans["GlobalOptimal"]),
      "MinimalSuppliedFieldThreshold" -> True, "FieldDegreeThreshold" -> d,
      "FieldDegree" -> dd,
      "RationalCoefficients" -> co, "PowerBasisVectors" -> basis,
      "PrimitiveGenerator" -> theta|>]], {d, lo, dmax}];
  <|"Status" -> "NotInSuppliedFieldSum", "SearchComplete" -> True,
    "GlobalOptimal" -> False|>
];

RDSumInFields[a_, gens_List] := Module[{n, dg, theta, dd, spaces, bas, g, e},
  n = RDDegree[a]; If[FailureQ[n], Return[n]];
  If[n == 1, Return[certificate[a, {a}, "Sum", "Rational input"]]];
  dg = RDDegree /@ gens;
  If[AnyTrue[dg, FailureQ], Return[exactFailure["Generators", "Use exact algebraic generators."]]];
  theta = primitive[Join[{a}, gens]]; If[FailureQ[theta], Return[theta]];
  dd = RDDegree[theta]; spaces = {<|"Degree" -> 1, "Basis" -> {UnitVector[dd, 1]}|>};
  Do[g = gens[[j]]; e = dg[[j]];
    bas = Table[coords[g^i, theta, dd], {i, 0, e-1}];
    If[AnyTrue[bas, FailureQ], Return[exactFailure["Coordinates", "Field-basis conversion failed."]]];
    AppendTo[spaces, <|"Degree" -> e, "Basis" -> bas|>], {j, Length[gens]}];
  sumFromSpaces[a, theta, spaces, False]
];

Options[RDGlobalSum] = {"TimeLimit" -> 300, "MaxFieldDegree" -> 48,
                       "MaxFixedSpaces" -> 10000};
RDGlobalSum[a_, OptionsPattern[]] := TimeConstrained[
  globalSum[a, OptionValue["MaxFieldDegree"], OptionValue["MaxFixedSpaces"]],
  OptionValue["TimeLimit"],
  exactFailure["Timeout", "The global additive computation exceeded TimeLimit; no nonexistence claim is made."]
];

globalSum[a_, maxD_, maxSpaces_] := Module[
  {n, x, rs, theta, dd, pt, cr, qs, mats, id, spaces, queue, w, v, aMat,
   pos = 1, records, z, c, q, j, done},
  n = RDDegree[a]; If[FailureQ[n], Return[n]];
  If[n == 1, Return[certificate[a, {a}, "Sum", "Rational input"]]];
  (* A prime input degree is already a global obstruction to improvement. *)
  If[primeBound[n] == n,
    Return[certificate[a, {RootReduce[a]}, "Sum", "Prime-degree obstruction"]]];
  rs = RDRoots[MinimalPolynomial[a, x], x];
  theta = primitive[rs]; If[FailureQ[theta], Return[theta]];
  dd = RDDegree[theta]; If[FailureQ[dd], Return[dd]];
  If[dd > maxD,
    Return[exactFailure["ResourceLimit", "The normal-closure degree exceeds MaxFieldDegree."]]];
  pt = MinimalPolynomial[theta, z]; cr = RDRoots[pt, z];
  c = coords[#, theta, dd] & /@ cr;
  If[AnyTrue[c, FailureQ], Return[exactFailure["NormalClosure", "Not every conjugate embeds into the constructed field."]]];
  qs = (# . z^Range[0, dd-1]) & /@ c;
  mats = Table[Transpose[Table[
    PadRight[CoefficientList[PolynomialRemainder[q^j, pt, z], z], dd],
    {j, 0, dd-1}]], {q, qs}];
  id = IdentityMatrix[dd];
  spaces = {id}; queue = {id};
  While[pos <= Length[queue],
    w = queue[[pos]]; pos++;
    Do[v = canonicalRows[NullSpace[(aMat-id) . Transpose[w]] . w];
      If[! MemberQ[spaces, v],
        If[Length[spaces] >= maxSpaces,
          Return[exactFailure["ResourceLimit", "Fixed-space enumeration exceeded MaxFixedSpaces."]]];
        AppendTo[spaces, v]; AppendTo[queue, v]], {aMat, mats}]
  ];
  records = (<|"Degree" -> Length[#], "Basis" -> #|> &) /@ spaces;
  done = sumFromSpaces[a, theta, records, True];
  If[AssociationQ[done], Join[done, <|"EnumeratedSubfields" -> Length[spaces]|>], done]
];

End[];
EndPackage[];
