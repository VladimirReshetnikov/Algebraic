(* ::Package:: *)
(* Exact algebraic-number decomposition over Q.
   Native Wolfram regression tests are supplied separately in Tests.wlt.
   This implementation was not executed in a native Wolfram kernel by the author.
   Resource-limited or restricted searches never assert unrestricted nonexistence. *)

BeginPackage["RootDecomposition`"];
RootDegree::usage = "RootDegree[a] gives the absolute minimal-polynomial degree over Q.";
DegreeLowerBound::usage = "DegreeLowerBound[a] gives the largest prime divisor of RootDegree[a], or 1.";
ExactRootEqualQ::usage = "ExactRootEqualQ[a,b] tests equality by exact RootReduce.";
CertifyRootDecomposition::usage = "CertifyRootDecomposition[a,terms,op] certifies a flat Sum or Product witness.";
RootCompositionPolynomial::usage = "RootCompositionPolynomial[f,g,x,z,op] forms the sum/product resultant of monic normalizations.";
FindRootPairByHeight::usage = "FindRootPairByHeight[a,op] searches bounded-height rational polynomials and certifies root branches.";
BuildRootField::usage = "BuildRootField[a] constructs exact rational coordinates in Q(a), or in its normal closure.";
EnumerateEmbeddedSubfields::usage = "EnumerateEmbeddedSubfields[field] enumerates embedded subfields up to an explicit degree bound; reports completeness.";
MinimumRootSum::usage = "MinimumRootSum[a] searches all sums in the computed subfields. With a Galois ambient field and complete enumeration, its minimum is global.";
MinimumRootProductPair::usage = "MinimumRootProductPair[a] uses powers and subfield intersections. Completeness is for TWO factors, not arbitrary arity.";
SearchRootProducts::usage = "SearchRootProducts[a,catalog] searches bounded arity, with all but the last factor from catalog and an unrestricted exact residual.";

Begin["`Private`"];
$failureTag = Unique["RootDecompositionFailure"];
SetAttributes[protect, HoldAll];
protect[e_] := Catch[e, $failureTag];
fail[tag_, data_: <||>] := Throw[Failure[tag, data], $failureTag];
rationalQ[a_] := IntegerQ[a] || Head[a] === Rational;
zeroVectorQ[v_List] := And @@ (TrueQ[# === 0] & /@ v);
nonzeroRows[m_List] := Select[m, ! zeroVectorQ[#] &];
validOperation[op_] := If[! MemberQ[{"Sum", "Product"}, op],
  fail["Operation", <|"Expected" -> {"Sum", "Product"}|>]];
canonical[a_] := Module[{r},
  If[! FreeQ[a, _Real], fail["InexactInput", <|"Input" -> a|>]];
  r = Quiet[Check[RootReduce[a], $Failed]];
  If[r === $Failed, fail["RootReduceFailed", <|"Input" -> a|>]]; r
];
algDegree[a_] := Module[{r = canonical[a], x = Unique["x"], p, c},
  If[rationalQ[r], Return[1]];
  p = Quiet[Check[MinimalPolynomial[r, x], $Failed]];
  If[p === $Failed || ! PolynomialQ[p, x],
    fail["NotExactAlgebraic", <|"Input" -> a|>]];
  c = CoefficientList[p, x];
  If[! AllTrue[c, rationalQ] || Exponent[p, x] < 1,
    fail["NotExactAlgebraic", <|"Input" -> a|>]];
  Exponent[p, x]
];
lowerBound[a_] := Module[{n = algDegree[a]},
  If[n == 1, 1, Max[First /@ FactorInteger[n]]]
];
exactEqual[a_, b_] := TrueQ[canonical[a - b] === 0];
RootDegree[a_] := protect[algDegree[a]];
DegreeLowerBound[a_] := protect[lowerBound[a]];
ExactRootEqualQ[a_, b_] := protect[exactEqual[a, b]];

certificate[a_, terms_List, op_] := Module[{t, degrees, b, value, d},
  validOperation[op];
  If[terms === {}, fail["EmptyWitness"]];
  t = canonical /@ terms;
  value = If[op === "Sum", Total[t], Times @@ t];
  If[! exactEqual[a, value], fail["IdentityFailed", <|"Terms" -> t|>]];
  degrees = algDegree /@ t; d = Max[degrees]; b = lowerBound[a];
  <|"Status" -> "CertifiedWitness", "Operation" -> op,
    "Terms" -> t, "Degrees" -> degrees, "MaximumDegree" -> d,
    "UniversalLowerBound" -> b, "IdentityVerified" -> True,
    "GlobalMinimumProved" -> TrueQ[d == b],
    "OptimalityReason" -> If[d == b, "PrimeDivisorBound", "NotEstablished"]|>
];
CertifyRootDecomposition[a_, terms_List, op_] := protect[certificate[a, terms, op]];

compositionPolynomial[f_, g_, x_Symbol, z_Symbol, op_] := Module[{ff, gg, m, n, h},
  validOperation[op];
  If[x === z || ! PolynomialQ[f, x] || ! PolynomialQ[g, x], fail["PolynomialInput"]];
  m = Exponent[f, x]; n = Exponent[g, x];
  If[Min[m, n] < 1, fail["PositivePolynomialDegreeRequired"]];
  ff = Expand[f/Coefficient[f, x, m]];
  gg = Expand[g/Coefficient[g, x, n]];
  h = If[op === "Sum", Expand[gg /. x -> z - x],
    Sum[Coefficient[gg, x, j] z^j x^(n - j), {j, 0, n}]];
  Expand[Resultant[ff, h, x]]
];
RootCompositionPolynomial[f_, g_, x_Symbol, z_Symbol, op_] :=
  protect[compositionPolynomial[f, g, x, z, op]];
rootList[p_, x_Symbol] := Module[{fn = Function @@ {x, p}},
  Table[Root[fn, j], {j, 1, Exponent[p, x]}]
];

(* Primitive integer polynomials of positive leading coefficient and height <= h.
   This includes NONMONIC polynomials: rational, nonintegral factors are allowed. *)
smallPolynomials[d_Integer, h_Integer, x_Symbol, maxTemplates_] := Module[
  {out = {}, c, p, fl, estimate},
  estimate = Sum[h (2 h + 1)^m, {m, 1, d}];
  If[estimate > maxTemplates,
    fail["TemplateBudget", <|"RawTemplateCount" -> estimate, "Limit" -> maxTemplates|>]];
  Do[
    Do[
      c = Append[tail, lead];
      If[Apply[GCD, c] == 1,
        p = c . (x^Range[0, m]);
        fl = Rest[FactorList[p]];
        If[Length[fl] == 1 && fl[[1, 2]] == 1 &&
          Exponent[fl[[1, 1]], x] == m, AppendTo[out, p]]
      ], {tail, Tuples[Range[-h, h], m]}, {lead, 1, h}
    ], {m, 1, d}];
  SortBy[out, {Exponent[#, x] &, Count[CoefficientList[#, x], _?(# != 0 &)] &,
    Total[Abs[CoefficientList[#, x]]] &, CoefficientList[#, x] &}]
];
Options[FindRootPairByHeight] = {"MaximumDegree" -> 3, "CoefficientHeight" -> 1,
  "MaxTemplates" -> 20000, "MaxPairs" -> 20000, "TimeConstraint" -> 60};
FindRootPairByHeight[a_, op_, OptionsPattern[]] := protect[TimeConstrained[
  Module[{aa = canonical[a], n, lb, maxd = OptionValue["MaximumDegree"],
    h = OptionValue["CoefficientHeight"], x = Unique["x"], z = Unique["z"],
    p, polys, degs, count = 0, r, rr1, rr2, ans, found = Unique["found"]},
    validOperation[op]; n = algDegree[aa]; lb = lowerBound[aa];
    If[n == 1, Return[certificate[aa, {aa}, op]]];
    If[! IntegerQ[maxd] || maxd < 1 || ! IntegerQ[h] || h < 1, fail["SearchBounds"]];
    polys = smallPolynomials[maxd, h, x, OptionValue["MaxTemplates"]];
    degs = Exponent[#, x] & /@ polys;
    p = MinimalPolynomial[aa, z]; p = p/Coefficient[p, z, n];
    Catch[
      Do[Do[
        If[Max[degs[[i]], degs[[j]]] == d && degs[[i]] degs[[j]] >= n,
          count++;
          If[count > OptionValue["MaxPairs"], fail["PairBudget", <|"Pairs" -> count - 1|>]];
          r = compositionPolynomial[polys[[i]], polys[[j]], x, z, op];
          If[TrueQ[PolynomialRemainder[r, p, z] === 0],
            rr1 = rootList[polys[[i]], x]; rr2 = rootList[polys[[j]], x];
            Do[
              If[exactEqual[aa, If[op === "Sum", b + c, b c]],
                ans = certificate[aa, {b, c}, op];
                Throw[Join[ans, <|"SearchScope" -> "TwoFactorsInPolynomialHeightBox",
                  "CoefficientHeight" -> h, "PairsTested" -> count,
                  "Polynomials" -> {polys[[i]], polys[[j]]}, "PolynomialVariable" -> x|>], found]
              ], {b, rr1}, {c, rr2}]
          ]
        ], {i, Length[polys]}, {j, i, Length[polys]}], {d, lb, maxd}];
      <|"Status" -> "NotFoundInBounds", "MaximumDegree" -> maxd,
        "CoefficientHeight" -> h, "PairsTested" -> count,
        "SearchScope" -> "TwoFactorsInPolynomialHeightBox", "GlobalNonexistenceProved" -> False|>,
      found]
  ], OptionValue["TimeConstraint"], Failure["TimeLimit", <|"SearchComplete" -> False|>]]];

(* Rational coordinate arithmetic in Q(theta). The generator theta is integral
   so ToNumberField retains it, rather than silently changing the power basis. *)
integralGenerator[a_] := Module[{r = canonical[a], x = Unique["x"], p, c, scale},
  If[rationalQ[r], Return[0]];
  p = MinimalPolynomial[r, x]; c = CoefficientList[p, x];
  scale = Apply[LCM, Denominator[c]];
  p = Expand[scale p]; c = CoefficientList[p, x];
  p = p/Apply[GCD, c];
  canonical[Coefficient[p, x, Exponent[p, x]] r]
];
coordinates[a_, ctx_Association] := Module[{r = canonical[a], n = ctx["Degree"], an, p, v},
  If[rationalQ[r], Return[PadRight[{r}, n]]];
  an = Quiet[Check[ToNumberField[r, ctx["Theta"]], $Failed]];
  If[Head[an] =!= AlgebraicNumber, fail["NotInAmbientField", <|"Element" -> r|>]];
  If[! exactEqual[an[[1]], ctx["Theta"]], fail["UnexpectedPrimitiveElement"]];
  p = AlgebraicNumberPolynomial[an, ctx["Variable"]];
  v = CoefficientList[p, ctx["Variable"]];
  If[Length[v] > n || ! AllTrue[v, rationalQ], fail["CoordinateConversionFailed"]];
  PadRight[v, n]
];
fromCoordinates[v_List, ctx_Association] := canonical[v .
  Prepend[Table[ctx["Theta"]^k, {k, 1, ctx["Degree"] - 1}], 1]];
mulCoordinates[v_List, w_List, ctx_Association] := Module[{x = ctx["Variable"], p},
  p = PolynomialRemainder[Expand[(v . ctx["Powers"])(w . ctx["Powers"])], ctx["Polynomial"], x];
  PadRight[CoefficientList[p, x], ctx["Degree"]]
];
powerCoordinates[v_List, k_Integer, ctx_Association] := Module[
  {r = PadRight[{1}, ctx["Degree"]], b = v, j = k},
  While[j > 0,
    If[OddQ[j], r = mulCoordinates[r, b, ctx]];
    j = Quotient[j, 2]; If[j > 0, b = mulCoordinates[b, b, ctx]]]; r
];
Options[BuildRootField] = {"NormalClosure" -> False, "MaximumAmbientDegree" -> 64,
  "TimeConstraint" -> 60};
BuildRootField[a_, OptionsPattern[]] := protect[TimeConstrained[
  Module[{aa = canonical[a], x = Unique["x"], p, n, theta, nf, gens, factors, ctx},
    n = algDegree[aa];
    If[n > OptionValue["MaximumAmbientDegree"], fail["AmbientDegreeBudget", <|"Degree" -> n|>]];
    If[TrueQ[OptionValue["NormalClosure"]] && n > 1,
      p = MinimalPolynomial[aa, x];
      nf = Quiet[Check[ToNumberField[rootList[p, x], All], $Failed]];
      If[! ListQ[nf], fail["NormalClosureConstructionFailed"]];
      gens = Cases[nf, AlgebraicNumber[t_, _] :> t, {1}];
      If[gens === {}, fail["PrimitiveElementMissing"]];
      theta = integralGenerator[First[gens]],
      theta = integralGenerator[aa]
    ];
    n = algDegree[theta];
    If[n > OptionValue["MaximumAmbientDegree"], fail["AmbientDegreeBudget", <|"Degree" -> n|>]];
    p = MinimalPolynomial[theta, x]; p = Expand[p/Coefficient[p, x, n]];
    factors = If[n == 1, {p},
      Quiet[Check[First /@ Rest[FactorList[p, Extension -> theta]], $Failed]]];
    If[! ListQ[factors] || factors === {}, fail["AmbientFactorizationFailed"]];
    factors = Expand[#/Coefficient[#, x, Exponent[#, x]]] & /@ factors;
    ctx = <|"Alpha" -> aa, "Theta" -> theta, "Variable" -> x,
      "Polynomial" -> p, "Powers" -> x^Range[0, n - 1], "Degree" -> n,
      "Factors" -> factors, "Galois" -> AllTrue[factors, Exponent[#, x] == 1 &]|>;
    If[TrueQ[OptionValue["NormalClosure"]] && ! TrueQ[ctx["Galois"]], fail["NormalityCheckFailed"]];
    Join[ctx, <|"AlphaCoordinates" -> coordinates[aa, ctx]|>]
  ], OptionValue["TimeConstraint"], Failure["TimeLimit", <|"Stage" -> "AmbientField"|>]]];

(* The Q-subalgebra generated by coefficient vectors is a field because it is
   a finite-dimensional domain. Row-reduced bases distinguish EMBEDDED fields. *)
generatedFieldRows[gens_List, ctx_Association, cap_: Infinity] := Module[
  {basis = {PadRight[{1}, ctx["Degree"]]}, products, next, changed = True},
  While[changed && Length[basis] <= cap,
    products = Flatten[Table[mulCoordinates[b, g, ctx], {b, basis}, {g, gens}], 1];
    next = nonzeroRows[RowReduce[Join[basis, products]]];
    changed = Length[next] != Length[basis]; basis = next
  ];
  If[Length[basis] > cap, $Failed, basis]
];
Options[EnumerateEmbeddedSubfields] = {"MaximumDegree" -> Automatic,
  "MaxNodes" -> 100000, "TimeConstraint" -> 60};
EnumerateEmbeddedSubfields[ctx_Association, OptionsPattern[]] := protect[Module[
  {n = ctx["Degree"], x = ctx["Variable"], maxd = OptionValue["MaximumDegree"],
    fields = {}, add, f = ctx["Factors"], pos, others, weights, tailWeights,
    q0, visit, process, nodes = 0, candidates = 0, stop, budget = Unique["budget"],
    maxnodes = OptionValue["MaxNodes"], ad = algDegree[ctx["Alpha"]]},
  If[maxd === Automatic, maxd = ad];
  If[! IntegerQ[maxd] || maxd < 1, fail["SubfieldDegreeBound"]];
  maxd = Min[maxd, n];
  add[rows_List] := If[! AnyTrue[fields, #["Rows"] === rows &],
    AppendTo[fields, <|"Degree" -> Length[rows], "Rows" -> rows|>]];
  add[{PadRight[{1}, n]}];
  If[n <= maxd, add[IdentityMatrix[n]]];
  If[ad <= maxd, add[nonzeroRows[RowReduce[
    Table[powerCoordinates[ctx["AlphaCoordinates"], k, ctx], {k, 0, ad - 1}]]]]];
  pos = Select[Range[Length[f]], Exponent[f[[#]], x] == 1 &&
      exactEqual[f[[#]] /. x -> ctx["Theta"], 0] &];
  If[Length[pos] != 1, fail["DistinguishedLinearFactorMissing"]];
  others = Delete[f, {First[pos]}]; weights = Exponent[#, x] & /@ others;
  tailWeights = Reverse[Accumulate[Reverse[weights]]];
  q0 = x - ctx["Theta"];
  process[chosen_List, m_Integer] := Module[{q, gens, rows},
    candidates++;
    q = Expand[q0 (Times @@ others[[chosen]])];
    gens = coordinates[#, ctx] & /@ CoefficientList[q, x];
    rows = generatedFieldRows[gens, ctx, m];
    If[rows =!= $Failed && Length[rows] == m, add[rows]]
  ];
  visit[i_Integer, remaining_Integer, chosen_List, m_Integer] := (
    nodes++;
    If[nodes > maxnodes, Throw["NodeBudget", budget]];
    If[remaining == 0, process[chosen, m],
      If[i <= Length[others] && 0 < remaining <= tailWeights[[i]],
        visit[i + 1, remaining, chosen, m];
        If[weights[[i]] <= remaining,
          visit[i + 1, remaining - weights[[i]], Append[chosen, i], m]]]]);
  stop = TimeConstrained[
    Catch[
      Do[visit[1, n/m - 1, {}, m],
        {m, Select[Divisors[n], 1 < # < n && # <= maxd &]}]; "Complete", budget],
    OptionValue["TimeConstraint"], "TimeLimit"];
  <|"Ambient" -> ctx, "Fields" -> SortBy[fields, #["Degree"] &],
    "Complete" -> (stop === "Complete"), "StopReason" -> stop,
    "MaximumDegree" -> maxd, "VisitedNodes" -> nodes,
    "CandidateProducts" -> candidates|>
]];

(* Solve M.c=b over Q; set free variables to zero. No numerical rank tests. *)
rationalSolve[m_List, b_List] := Module[{cols = Length[First[m]], rr, c, nz, pivot},
  rr = RowReduce[MapThread[Append, {m, b}]]; c = ConstantArray[0, cols];
  If[AnyTrue[rr, zeroVectorQ[Take[#, cols]] && Last[#] =!= 0 &], Return[$Failed]];
  Do[
    nz = Select[Range[cols], row[[#]] =!= 0 &];
    If[nz =!= {}, pivot = First[nz]; c[[pivot]] = row[[-1]]],
    {row, rr}]; c
];
sumFromFields[ctx_Association, fields_List, d_Integer] := Module[
  {selected, rows, coeffs, terms = {}, k = 0, len, v},
  selected = Select[fields, #["Degree"] <= d &];
  rows = Flatten[#["Rows"] & /@ selected, 1];
  coeffs = rationalSolve[Transpose[rows], ctx["AlphaCoordinates"]];
  If[coeffs === $Failed, Return[$Failed]];
  Do[
    len = field["Degree"];
    v = Take[coeffs, {k + 1, k + len}] . field["Rows"]; k += len;
    If[! zeroVectorQ[v], AppendTo[terms, fromCoordinates[v, ctx]]],
    {field, selected}];
  If[terms === {}, {0}, terms]
];
pairFromFields[ctx_Association, fields_List, d_Integer] := Module[
  {selected, aPower, frows, erows, ns, v, b, beta, gamma, found = Unique["pair"]},
  Catch[
    Do[
      selected = Select[fields, t #["Degree"] <= d &];
      aPower = powerCoordinates[ctx["AlphaCoordinates"], t, ctx];
      Do[
        frows = selected[[i]]["Rows"]; erows = selected[[j]]["Rows"];
        ns = NullSpace[Transpose[Join[frows, -mulCoordinates[aPower, #, ctx] & /@ erows]]];
        If[ns =!= {},
          v = Take[First[ns], Length[frows]] . frows;
          If[zeroVectorQ[v], fail["UnexpectedZeroIntersectionVector"]];
          b = fromCoordinates[v, ctx];
          beta = canonical[b^(1/t)]; gamma = canonical[ctx["Alpha"]/beta];
          If[Max[algDegree[beta], algDegree[gamma]] > d, fail["DegreeCertificateFailed"]];
          Throw[<|"Terms" -> {beta, gamma}, "Power" -> t,
            "SubfieldDegrees" -> {Length[frows], Length[erows]}|>, found]
        ], {i, Length[selected]}, {j, i, Length[selected]}],
      {t, 1, d}]; $Failed, found]
];
Options[MinimumRootSum] = {"NormalClosure" -> False, "MaximumAmbientDegree" -> 64,
  "MaxNodes" -> 100000, "TimeConstraint" -> 60};
Options[MinimumRootProductPair] = Options[MinimumRootSum];

(* The time limit applies separately to field construction, subfield enumeration,
   and the final bound sweep. A partial enumeration remains usable for witnesses. *)
minimumInFields[a_, op_, normal_, maxAmbient_, maxNodes_, seconds_] := Module[
  {ctx, enumeration, fields, n, lb, witness, ans, globalScope, found = Unique["answer"]},
  n = algDegree[a]; lb = lowerBound[a];
  If[n == 1, Return[certificate[a, {canonical[a]}, op]]];
  ctx = BuildRootField[a, "NormalClosure" -> normal,
    "MaximumAmbientDegree" -> maxAmbient, "TimeConstraint" -> seconds];
  If[FailureQ[ctx], Return[ctx]];
  enumeration = EnumerateEmbeddedSubfields[ctx, "MaximumDegree" -> n,
    "MaxNodes" -> maxNodes, "TimeConstraint" -> seconds];
  If[FailureQ[enumeration], Return[enumeration]];
  fields = enumeration["Fields"];
  globalScope = TrueQ[ctx["Galois"] && enumeration["Complete"]];
  TimeConstrained[
    Catch[
      Do[
        witness = If[op === "Sum", sumFromFields[ctx, fields, d], pairFromFields[ctx, fields, d]];
        If[witness =!= $Failed,
          ans = certificate[a, If[op === "Sum", witness, witness["Terms"]], op];
          ans = Join[ans, <|"AmbientDegree" -> ctx["Degree"], "AmbientGalois" -> ctx["Galois"],
            "SubfieldEnumerationComplete" -> enumeration["Complete"],
            "SubfieldsFound" -> Length[fields], "ExcludedBoundsInSearchScope" -> Range[lb, d - 1]|>];
          If[op === "Sum",
            ans = Join[ans, <|"GlobalMinimumProved" -> (ans["GlobalMinimumProved"] || globalScope),
              "AmbientMinimumProved" -> enumeration["Complete"],
              "OptimalityReason" -> If[ans["GlobalMinimumProved"], "PrimeDivisorBound",
                If[globalScope, "TraceDescentAndExhaustiveSubfields", "RestrictedSearch"]]|>],
            ans = Join[ans, <|"TwoFactorMinimumProved" -> (ans["GlobalMinimumProved"] || globalScope),
              "Power" -> witness["Power"], "SubfieldDegrees" -> witness["SubfieldDegrees"],
              "SearchScope" -> If[globalScope, "AllAlgebraicTwoFactorDecompositions", "ComputedPowerSubfieldFamily"]|>]
          ];
          Throw[ans, found]
        ], {d, lb, n}];
      fail["InternalNoTrivialWitness"], found],
    seconds, Failure["TimeLimit", <|"Stage" -> "DegreeSweep", "SearchComplete" -> False|>]]
];
MinimumRootSum[a_, OptionsPattern[]] := protect[minimumInFields[a, "Sum",
  OptionValue["NormalClosure"], OptionValue["MaximumAmbientDegree"],
  OptionValue["MaxNodes"], OptionValue["TimeConstraint"]]];
MinimumRootProductPair[a_, OptionsPattern[]] := protect[minimumInFields[a, "Product",
  OptionValue["NormalClosure"], OptionValue["MaximumAmbientDegree"],
  OptionValue["MaxNodes"], OptionValue["TimeConstraint"]]];

Options[SearchRootProducts] = {"MaximumDegree" -> 3, "MaximumFactors" -> 3,
  "IncludeInverses" -> True, "MaxNodes" -> 100000, "TimeConstraint" -> 60};
SearchRootProducts[a_, catalog_List, OptionsPattern[]] := protect[TimeConstrained[
  Module[{aa = canonical[a], lb, maxd = OptionValue["MaximumDegree"],
    maxk = OptionValue["MaximumFactors"], maxnodes = OptionValue["MaxNodes"],
    cats, active, nodes = 0, visit, ans, found = Unique["catalogWitness"], d},
    If[! IntegerQ[maxd] || maxd < 1 || ! IntegerQ[maxk] || maxk < 1, fail["SearchBounds"]];
    lb = lowerBound[aa];
    If[algDegree[aa] == 1, Return[certificate[aa, {aa}, "Product"]]];
    cats = canonical /@ catalog;
    cats = Select[cats, ! exactEqual[#, 0] && ! exactEqual[#, 1] &];
    If[TrueQ[OptionValue["IncludeInverses"]], cats = Join[cats, canonical[1/#] & /@ cats]];
    cats = DeleteDuplicates[cats, exactEqual];
    visit[start_Integer, remaining_Integer, prefix_List, product_] := Module[{residual},
      nodes++;
      If[nodes > maxnodes, fail["NodeBudget", <|"VisitedNodes" -> nodes - 1|>]];
      If[remaining == 0,
        residual = canonical[aa/product];
        If[algDegree[residual] <= d,
          ans = certificate[aa, Append[prefix, residual], "Product"];
          Throw[Join[ans, <|"SearchScope" -> "AllButLastFactorFromCatalog",
            "MaximumFactors" -> maxk, "NodesTested" -> nodes|>], found]],
        Do[visit[j, remaining - 1, Append[prefix, active[[j]]], canonical[product active[[j]]]],
          {j, start, Length[active]}]]
    ];
    Catch[
      Do[active = Select[cats, algDegree[#] <= d &];
        Do[visit[1, k - 1, {}, 1], {k, 1, maxk}], {d, lb, maxd}];
      <|"Status" -> "NotFoundInBounds", "SearchScope" -> "AllButLastFactorFromCatalog",
        "MaximumDegree" -> maxd, "MaximumFactors" -> maxk, "NodesTested" -> nodes,
        "GlobalNonexistenceProved" -> False|>, found]
  ], OptionValue["TimeConstraint"], Failure["TimeLimit", <|"SearchComplete" -> False|>]]];

End[];
EndPackage[];
