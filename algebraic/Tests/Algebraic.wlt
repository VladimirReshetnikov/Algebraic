(* Regression suite of the unified package algebraic/Algebraic.wl.

   The four sections are the four suites of the packages that were merged,
   with their package names mapped onto Algebraic` and Algebraic`Private`
   and the engine messages onto the package symbol Algebraic.  Nothing was
   removed.  Run with

       wolfram -script RunTests.wl        (TestReport, in the Wolfram kernel)
       python -m mathics -f RunTests.wl   (the portable runner, in Mathics3)

   from this directory; RunTests.wl loads the package.  Loading it here as
   well keeps TestReport["Algebraic.wlt"] usable on its own. *)

If[! MemberQ[$Packages, "Algebraic`"],
  Get[FileNameJoin[{DirectoryName[$TestFileName /. "" -> $InputFileName /. "" -> Directory[]], "..", "Algebraic.wl"}]]];

(* --- 1. Functional decomposition of polynomials ------------------------
   From polynomial-decompose/AlgebraicDecomposition.wlt, including adapted
   report-03 fixtures (MIT, Copyright (c) 2026 OpenAI; see
   polynomial-decompose/reports/report-03/LICENSE). *)
ClearAll[x, a, samePoly, sameChain, degrees, goodChain, original];
(* the package's coefficient list rather than CoefficientList: the latter
   aborts Mathics when an algebraic coefficient cancels only under SymPy *)
samePoly[u_, v_] := AllTrue[
  RootReduce /@ Algebraic`Private`kCoefficientList[Expand[u - v], x], # === 0 &];
sameChain[u_List, v_List] := Length[u] === Length[v] &&
  And @@ MapThread[samePoly, {u, v}];
degrees[c_List] := Exponent[#, x] & /@ c;
goodChain[p_, c_List] := TrueQ[VerifyAlgebraicDecomposition[p, c, x]] &&
  AllTrue[c, AlgebraicDecompositionPairs[#, x] === {} &] &&
  AllTrue[Rest[c], samePoly[Coefficient[#, x, Exponent[#, x]], 1] &&
    samePoly[# /. x -> 0, 0] &];
original = 3 + 3 Sqrt[2] + (14 + 4 Sqrt[2]) x +
  (12 + 26 Sqrt[2]) x^2 + (56 + 8 Sqrt[2]) x^3 +
  (8 + 48 Sqrt[2]) x^4 + 48 x^5 + 16 Sqrt[2] x^6;

VerificationTest[
  sameChain[AlgebraicRightDecompose[original, x, 2],
    {3 + 3 Sqrt[2] + (8 + 14 Sqrt[2]) x +
      (8 + 24 Sqrt[2]) x^2 + 16 Sqrt[2] x^3,
     x^2 + x/Sqrt[2]}], True, TestID -> "original-normalized-pair"]
VerificationTest[AlgebraicRightDecompose[original, x, 3],
  Missing["NotDecomposable", 3], TestID -> "original-rejected-degree-three"]
VerificationTest[degrees[AlgebraicDecompose[original, x]], {3, 2},
  TestID -> "original-degree-pattern"]
VerificationTest[goodChain[original, AlgebraicDecompose[original, x]], True,
  TestID -> "original-complete-identity"]
VerificationTest[Length[AlgebraicDecompositions[original, x]], 1,
  TestID -> "original-only-one-normalized-chain"]
VerificationTest[AlgebraicDecompositionData[original, x]["AcceptedRightDegrees"],
  {2}, TestID -> "original-accepted-degrees"]
VerificationTest[VerifyAlgebraicDecompositionData[original,
  AlgebraicDecompositionData[original, x], x], True,
  TestID -> "original-exhaustive-certificate"]
VerificationTest[VerifyAlgebraicDecompositionData[original,
  AlgebraicDecompositionData[original, x, 3], x], True,
  TestID -> "original-negative-certificate"]
VerificationTest[Module[{p = Expand[original /. x -> x^4 - x + 1], c},
  c = AlgebraicDecompose[p, x]; {degrees[c], goodChain[p, c]}],
  {{3, 2, 4}, True}, TestID -> "nested-degree-twenty-four"]
VerificationTest[AlgebraicDecompose[x^4, x], {x^2, x^2},
  TestID -> "single-derivative-factor-counterexample"]
VerificationTest[AlgebraicDecompose[x^8, x], {x^2, x^2, x^2},
  TestID -> "do-not-merge-powers"]
VerificationTest[Sort[degrees /@ AlgebraicDecompositions[x^12, x]],
  {{2, 2, 3}, {2, 3, 2}, {3, 2, 2}},
  TestID -> "all-power-chains-no-duplicates"]
VerificationTest[Length[AlgebraicDecompositions[x^30, x]], 6,
  TestID -> "six-permutations-for-x-thirty"]
VerificationTest[Module[{p = ChebyshevT[6, x], cs},
  cs = AlgebraicDecompositions[p, x];
  {Sort[degrees /@ cs], AllTrue[cs, goodChain[p, #] &]}],
  {{{2, 3}, {3, 2}}, True}, TestID -> "chebyshev-ritt-collision"]
VerificationTest[AlgebraicDecompositionPairs[x^4 + x, x], {},
  TestID -> "composite-degree-indecomposable"]
VerificationTest[degrees[AlgebraicDecompose[(x^4 + x)^2, x]], {2, 4},
  TestID -> "composite-atomic-right-degree-is-essential"]
VerificationTest[AlgebraicDecompositionData[x^6 + x, x]["Indecomposable"], True,
  TestID -> "degree-six-indecomposable"]
VerificationTest[VerifyAlgebraicDecompositionData[x^6 + x,
  AlgebraicDecompositionData[x^6 + x, x], x], True,
  TestID -> "negative-exhaustive-certificate"]
VerificationTest[AlgebraicDecompositionData[x^6 + x, x, 2]["Obstruction"],
  <|"DigitIndex" -> 0, "Power" -> 1, "Coefficient" -> 1|>,
  TestID -> "exact-negative-obstruction"]
VerificationTest[AlgebraicDecompose[x^5 + Sqrt[2] x + 1, x],
  {x^5 + Sqrt[2] x + 1}, TestID -> "prime-degree"]
VerificationTest[AlgebraicDecompose[0, x], {0}, TestID -> "zero-convention"]
VerificationTest[AlgebraicDecompositions[0, x], {{0}},
  TestID -> "zero-all-chains-convention"]
VerificationTest[AlgebraicDecompose[7, x], {7}, TestID -> "constant-convention"]
VerificationTest[AlgebraicDecompose[2 x + 3, x], {3 + 2 x},
  TestID -> "linear-convention"]
VerificationTest[AlgebraicDecompositionData[0, x]["InputDegree"], -Infinity,
  TestID -> "zero-degree-metadata"]
VerificationTest[AlgebraicDecompositionData[7, x]["Indecomposable"],
  Missing["NotApplicable", "DegreeBelowTwo"],
  TestID -> "constants-not-called-indecomposable"]
VerificationTest[VerifyAlgebraicDecompositionData[0,
  AlgebraicDecompositionData[0, x], x], True,
  TestID -> "zero-exhaustive-certificate"]
VerificationTest[ComposeDecomposition[{}, x], x,
  TestID -> "empty-composition-is-identity"]
VerificationTest[ComposeDecomposition[{x^3 + 1, x^2 + 2}, x],
  9 + 12 x^2 + 6 x^4 + x^6, TestID -> "composition-orientation"]
VerificationTest[VerifyAlgebraicDecomposition[x^4, {x^4}, x], True,
  TestID -> "identity-check-is-not-completeness-check"]
VerificationTest[VerifyAlgebraicDecomposition[x^4, {x^2, x^3}, x], False,
  TestID -> "false-composition-rejected"]
VerificationTest[Module[{b = Sqrt[2], c = Sqrt[3], f, g, p, pair},
  f = (1 + b) x^2 + (2 - c) x + 7;
  g = (2 + c) x^3 + b x + c; p = Expand[f /. x -> g];
  pair = AlgebraicRightDecompose[p, x, 3];
  sameChain[pair, {Expand[f /. x -> (2 + c) x + c],
    x^3 + b x/(2 + c)}]], True, TestID -> "affine-normalization-mixed-field"]
VerificationTest[Module[{p = Expand[(1 + I) (x^3 + I x)^2 + Sqrt[2]]},
  sameChain[AlgebraicRightDecompose[p, x, 3],
    {(1 + I) x^2 + Sqrt[2], x^3 + I x}]], True,
  TestID -> "complex-algebraic-coefficients"]
VerificationTest[Module[{b = Root[#^5 - # - 1 &, 1], p},
  p = Expand[(x^3 + b x)^2 + (1 + b) (x^3 + b x) + 2];
  sameChain[AlgebraicRightDecompose[p, x, 3],
    {x^2 + (1 + b) x + 2, x^3 + b x}]], True,
  TestID -> "quintic-root-coefficient"]
VerificationTest[Module[{b = Root[#^5 - # - 1 &, 2], p},
  p = Expand[(x^3 + b x)^2 + 3];
  sameChain[AlgebraicRightDecompose[p, x, 3], {x^2 + 3, x^3 + b x}]],
  True, TestID -> "nonreal-quintic-root-coefficient"]
VerificationTest[Module[{b = AlgebraicNumber[Sqrt[2], {1, 2}], p},
  p = Expand[(x^2 + b x)^3 + 2];
  sameChain[AlgebraicRightDecompose[p, x, 2], {x^3 + 2, x^2 + b x}]],
  True, TestID -> "algebraicnumber-coefficient"]
VerificationTest[Module[{p = Expand[(x^2 + Sqrt[2] x)^3 + 1], q},
  q = p /. Sqrt[2] -> Root[#^2 - 2 &, 2];
  sameChain[AlgebraicDecompose[p, x], AlgebraicDecompose[q, x]]], True,
  TestID -> "equivalent-radical-root-representations"]
VerificationTest[Module[{b = Root[#^5 - # - 1 &, 1], p},
  p = (b^5 - b - 1) x^40 + x^4;
  AlgebraicDecompose[p, x]], {x^2, x^2},
  TestID -> "algebraic-cancellation-lowers-degree"]
VerificationTest[Module[{b = Root[#^5 - # - 1 &, 1]},
  AlgebraicDecompositionData[(b^5 - b - 1) x^12, x]["InputDegree"]],
  -Infinity, TestID -> "algebraic-cancellation-to-zero"]
VerificationTest[Module[{b = Root[#^5 - # - 1 &, 1], exact, inexactFailure},
  exact = {0, 1, -7, 2/3, 10^30/7, I, Sqrt[2], 1 + Sqrt[3], b, b^5 - b - 1};
  inexactFailure = Failure["InexactCoefficient", <|"MessageTemplate" ->
    "Approximate coefficients are not accepted."|>];
  (Algebraic`Private`red /@ exact) === (RootReduce /@ exact) &&
    AllTrue[{1., N[Sqrt[2], 40]},
      Catch[Algebraic`Private`red[#],
        Algebraic`Private`$failureTag] === inexactFailure &]], True,
  TestID -> "scalar dispatch preserves exact normalization and inexact failure details"]
VerificationTest[Module[{exact = {0, 1, -7, 2/3, 10^30/7}, invalidVariable},
  invalidVariable = Failure["InvalidVariable", <|"MessageTemplate" ->
    "The polynomial variable must be an unassigned nonnumeric symbol."|>];
  AllTrue[exact, AlgebraicDecompose[#, x] === {#} && ComposeDecomposition[{#}, x] === # &] &&
    AllTrue[Join[exact, {1., Sqrt[2], Pi, True, {1}, 1/(x + 1)}],
      AlgebraicDecompose[#, Pi] === invalidVariable &&
        ComposeDecomposition[{#}, Pi] === invalidVariable &] &&
    ComposeDecomposition[{}, Pi] === invalidVariable], True,
  TestID -> "scalar preparation and empty composition preserve variable validation before input errors"]
VerificationTest[MatchQ[AlgebraicDecompose[1.0 x^4, x], _Failure], True,
  TestID -> "reject-machine-coefficient"]
VerificationTest[MatchQ[AlgebraicDecompose[N[Sqrt[2], 40] x^4, x], _Failure],
  True, TestID -> "reject-arbitrary-precision-approximation"]
VerificationTest[MatchQ[AlgebraicDecompose[x^4 + Pi x, x], _Failure], True,
  TestID -> "reject-transcendental-coefficient"]
VerificationTest[MatchQ[AlgebraicDecompose[x^4 + a x, x], _Failure], True,
  TestID -> "reject-symbolic-parameter"]
VerificationTest[MatchQ[AlgebraicDecompose[1/(x + 1), x], _Failure], True,
  TestID -> "reject-rational-function"]
VerificationTest[MatchQ[AlgebraicDecompose[x^4, x^2], _Failure], True,
  TestID -> "reject-invalid-variable"]
VerificationTest[And @@ (MatchQ[AlgebraicRightDecompose[x^6, x, #], _Failure] &
  /@ {0, 1, 4, 6, 12, 3/2}), True, TestID -> "invalid-right-degrees"]
VerificationTest[Module[{bad, failure},
  bad = {2., N[2, 30], True, False, a, Blank[], Blank[Integer],
    Pattern[a, Blank[Integer]], Alternatives[2, 3]};
  failure = Failure["InvalidRightDegree", <|"MessageTemplate" ->
    "The right degree must be a proper divisor d of the polynomial degree with 1<d<n."|>];
  And @@ Flatten[Table[api[x^6, x, d] === failure,
    {api, {AlgebraicRightDecompose, AlgebraicDecompositionData}}, {d, bad}]]],
  True, TestID -> "fixed degree APIs preserve exact type rejection and failure details"]
VerificationTest[Module[{bad, calls = 0, data, accepted},
  bad = {0, 1, 4, 6, -1, 3/2, 2., N[2, 30], True, False, a,
    Blank[], Blank[Integer], Pattern[a, Blank[Integer]], Alternatives[2, 3],
    PatternTest[Blank[Integer], (calls++; True) &]};
  accepted = Table[data = AlgebraicDecompositionData[p, x, 2];
    Table[VerifyAlgebraicDecompositionData[p, Join[data, <|"RightDegree" -> d|>], x],
      {d, bad}], {p, {x^6, x^6 + x}}];
  {Union[Flatten[accepted]], calls}], {{False}, 0},
  TestID -> "certificate degrees reject malformed values without interpreting patterns"]
VerificationTest[MatchQ[AlgebraicRightDecompose[0, x, 2], _Failure], True,
  TestID -> "invalid-right-degree-zero-polynomial"]
VerificationTest[Module[{d = AlgebraicDecompositionData[x^4, x, 2]},
  VerifyAlgebraicDecompositionData[x^4, Join[d, <|"Inner" -> x^2 + x|>], x]],
  False, TestID -> "tamper-inner"]
VerificationTest[Module[{d = AlgebraicDecompositionData[x^4, x, 2]},
  VerifyAlgebraicDecompositionData[x^4, Join[d, <|"Digits" -> {1, 0, 1}|>], x]],
  False, TestID -> "tamper-digits"]
VerificationTest[Module[{d = AlgebraicDecompositionData[x^4, x, 2]},
  VerifyAlgebraicDecompositionData[x^4,
    Join[d, <|"Decomposable" -> False|>], x]], False,
  TestID -> "tamper-status"]
VerificationTest[Module[{d = AlgebraicDecompositionData[x^6 + x, x, 2]},
  VerifyAlgebraicDecompositionData[x^6 + x,
    Join[d, <|"Obstruction" -> None|>], x]], False,
  TestID -> "tamper-negative-obstruction"]
VerificationTest[Module[{d = AlgebraicDecompositionData[x^6, x]},
  VerifyAlgebraicDecompositionData[x^6,
    Join[d, <|"Tests" -> Take[d["Tests"], 1]|>], x]], False,
  TestID -> "cannot-omit-a-divisor-test"]
VerificationTest[Module[{d = AlgebraicDecompositionData[x^6, x]},
  VerifyAlgebraicDecompositionData[x^6,
    Join[d, <|"AcceptedRightDegrees" -> {}|>], x]], False,
  TestID -> "tamper-accepted-degree-list"]
VerificationTest[Module[{d = AlgebraicDecompositionData[x^4, x, 2]},
  VerifyAlgebraicDecompositionData[x^4, Join[d, <|"Residual" -> 1|>], x]],
  False, TestID -> "tamper-residual"]
VerificationTest[VerifyAlgebraicDecompositionData[x^4, <||>, x], False,
  TestID -> "malformed-certificate"]
VerificationTest[Module[{d = AlgebraicDecompositionData[x^4, x, 2]},
  VerifyAlgebraicDecompositionData[x^4, Join[d, <|"Inner" -> Pi x^2|>], x]],
  False, TestID -> "nonalgebraic-certificate-coefficient"]
VerificationTest[MatchQ[VerifyAlgebraicDecompositionData[Pi x^4, <||>, x],
  _Failure], True, TestID -> "invalid-input-versus-invalid-certificate"]
VerificationTest[BlockRandom[SeedRandom[206618];
  And @@ Table[Module[{d, m, f, g, p, pair, b, c},
    d = RandomInteger[{2, 4}]; m = RandomInteger[{2, 3}];   (* RandomChoice gives a list in Mathics *)
    f = Sum[RandomInteger[{-2, 2}] x^j, {j, 0, m - 1}] + 2 x^m;
    g = Sum[RandomInteger[{-2, 2}] Sqrt[2] x^j, {j, 0, d - 1}] + 3 x^d;
    b = Coefficient[g, x, d]; c = g /. x -> 0;
    p = Expand[f /. x -> g]; pair = AlgebraicRightDecompose[p, x, d];
    sameChain[pair, {Expand[f /. x -> b x + c], Expand[(g - c)/b]}] &&
      goodChain[p, AlgebraicDecompose[p, x]] &&
      VerifyAlgebraicDecompositionData[p, AlgebraicDecompositionData[p, x], x]
  ], {24}]], True, TestID -> "seeded-composition-properties"]

VerificationTest[Module[{d},
  d = <|"Type" -> "DegreeTest", "RightDegree" -> 2, "OuterDegree" -> 2,
    "Inner" -> x^2 + x, "OuterCandidate" -> x^2 + x,
    "Digits" -> {-x, 1 - 2 x, 1}, "Decomposable" -> False,
    "Obstruction" -> <|"DigitIndex" -> 0, "Power" -> 1, "Coefficient" -> -1|>,
    "Residual" -> -2 x^3 - 2 x^2 - x|>;
  VerifyAlgebraicDecompositionData[x^4, d, x]], False,
  TestID -> "leading-congruence-cannot-be-skipped"]
VerificationTest[Exponent[Last[#], x] & /@
  AlgebraicDecompositionPairs[x^12, x], {2, 3, 4, 6},
  TestID -> "every-proper-right-degree-of-power"]

VerificationTest[AlgebraicDecompositions[x^12, x, "MaxDecompositions" -> 3],
  AlgebraicDecompositions[x^12, x], TestID -> "cap equal to exact count remains exhaustive"]
VerificationTest[Module[{r = AlgebraicDecompositions[x^12, x, "MaxDecompositions" -> 2]},
  {FailureQ[r], r["Complete"], r["Limit"], Length[r["PartialDecompositions"]],
    AllTrue[r["PartialDecompositions"], VerifyAlgebraicDecomposition[x^12, #, x,
      "RequireComplete" -> True, "RequireNormalized" -> True] &]}],
  {True, False, 2, 2, True}, TestID -> "capped enumeration detects an omitted distinct chain"]
VerificationTest[AlgebraicDecompositions[0, x, "MaxDecompositions" -> 1], {{0}},
  TestID -> "cap one preserves zero convention"]
VerificationTest[Length[AlgebraicDecompositions[x^64, x, "MaxDecompositions" -> 1]], 1,
  TestID -> "many binary parenthesizations yield one normalized chain"]
VerificationTest[And @@ (FailureQ[AlgebraicDecompositions[x^12, x, "MaxDecompositions" -> #]] & /@
  {0, -1, 1/2, 2.0, "All"}), True, TestID -> "invalid enumeration limits rejected"]
VerificationTest[FailureQ[AlgebraicDecompositions[x^4, x, "Unknown" -> True]], True,
  TestID -> "unknown enumeration option rejected"]
VerificationTest[VerifyAlgebraicDecomposition[x^4, {x^4}, x, "RequireComplete" -> True], False,
  TestID -> "identity alone cannot certify completeness"]
VerificationTest[VerifyAlgebraicDecomposition[x^4, {x^2, x^2}, x,
  "RequireComplete" -> True, "RequireNormalized" -> True], True,
  TestID -> "complete normalized chain verification"]
VerificationTest[VerifyAlgebraicDecomposition[x^4, {4 x^2, x^2/2}, x,
  "RequireComplete" -> True, "RequireNormalized" -> True], False,
  TestID -> "affine equivalent unnormalized chain is rejected when required"]
VerificationTest[VerifyAlgebraicDecomposition[x^4, {4 x^2, x^2/2}, x,
  "RequireComplete" -> True], True, TestID -> "normalization is an optional verification constraint"]
VerificationTest[VerifyAlgebraicDecomposition[x, {}, x, "RequireNormalized" -> True], True,
  TestID -> "empty identity composition has no internal normalization interfaces"]
VerificationTest[VerifyAlgebraicDecomposition[x, {}, x, "RequireComplete" -> True], False,
  TestID -> "complete affine convention requires a singleton"]
VerificationTest[VerifyAlgebraicDecomposition[0, {0}, x, "RequireComplete" -> True], True,
  TestID -> "complete zero convention requires a singleton"]
VerificationTest[FailureQ[VerifyAlgebraicDecomposition[x, {x}, x, "RequireComplete" -> 1]], True,
  TestID -> "verification flags must be boolean"]
VerificationTest[And @@ (FailureQ /@ {AlgebraicDecompose[Pi^4, Pi], ComposeDecomposition[{}, Pi],
  AlgebraicDecompose[x^4, 2], AlgebraicDecompose[x^4 + Infinity, x],
  AlgebraicDecompose[x^4 + Sin[1] x, x]}), True, TestID -> "numeric variables and unsupported coefficients rejected"]
VerificationTest[Module[{d = AlgebraicDecompositionData[x^6 + x, x, 2]},
  VerifyAlgebraicDecompositionData[x^6 + x,
    Join[d, <|"Obstruction" -> <|"DigitIndex" -> 0, "Power" -> 1, "Coefficient" -> 1.0|>|>], x]],
  False, TestID -> "inexact obstruction cannot masquerade as exact witness"]
VerificationTest[Module[{d = AlgebraicDecompositionData[x^12 + x, x]},
  VerifyAlgebraicDecompositionData[x^12 + x,
    Join[d, <|"Tests" -> Reverse[d["Tests"]]|>], x]], False,
  TestID -> "certificate divisor order and coverage are checked"]
VerificationTest[Module[{d = AlgebraicDecompositionData[x^4, x, 2]},
  VerifyAlgebraicDecompositionData[x^4, Join[d, <|"Digits" -> {0, 0, 1, 0}|>], x]], False,
  TestID -> "certificate digit length cannot include redundant padding"]
VerificationTest[AlgebraicRightDecompose[x^6 + x, x, 2], Missing["NotDecomposable", 2],
  TestID -> "early h adic rejection agrees with full negative certificate"]
VerificationTest[With[{p = Expand[(x^3 + Sqrt[2] x)^8 + 2 (x^3 + Sqrt[2] x)^4 + 1]},
  VerifyAlgebraicDecomposition[p, AlgebraicDecompose[p, x], x,
    "RequireComplete" -> True, "RequireNormalized" -> True]], True,
  TestID -> "sparse high degree chain with algebraic coefficients"]

VerificationTest[Module[{h = x^4 + 2 x^3 + 3 x^2 + 5 x, p, data},
  p = Expand[h^8 + 7 h + 1]; data = AlgebraicDecompositionData[p, x, 4];
  VerifyAlgebraicDecompositionData[p, data, x] &&
    AllTrue[Range[0, 4], !VerifyAlgebraicDecompositionData[p,
      Join[data, <|"Inner" -> h + x^#|>], x] &]], True,
  TestID -> "truncated congruence checks every inner coefficient"]
VerificationTest[And @@ Flatten[Table[
  With[{a = {1, 2, 0, -3, 1}},
    Algebraic`Private`truncatedPower[a, m, d] ===
      PadRight[Take[CoefficientList[(1 + 2 x - 3 x^3 + x^4)^m, x], Min[d, m 4 + 1]], d]],
  {m, {1, 2, 3, 8, 17}}, {d, {1, 2, 4, 9}}]], True,
  TestID -> "truncated binary powers match full polynomial arithmetic"]
VerificationTest[Module[{vectors, product, size},
  vectors = {{0}, {1}, {1, 2}, {0, 0, 3}, {1/3, -2/5, 7},
    {Sqrt[2], 1, -Sqrt[2]}, {I, 2 + I, -3}, {Root[#^5 - # - 1 &, 1], 1, 2}};
  And @@ Flatten[Table[
    size = Min[Length[a] + Length[b] - 1, d];
    product = CoefficientList[Expand[FromDigits[Reverse[a], x] FromDigits[Reverse[b], x]], x];
    Algebraic`Private`multiply[a, b, d] ===
      Algebraic`Private`trim[RootReduce /@ Take[product, Min[size, Length[product]]]],
    {a, vectors}, {b, vectors}, {d, {1, 2, 5, Infinity}}]]], True,
  TestID -> "exact convolution matches symbolic polynomial products"]
VerificationTest[Module[{bases, digitSets},
  bases = {{0, 1}, {0, 0, 1}, {0, 0, 0, 1}, {0, 0, 2}, {1}, {0}, {0, Sqrt[2], 1}};
  digitSets = {{}, {{0}}, {{1}}, {{1}, {2}, {3}}, {{Sqrt[2], 1}, {I, 2}, {3}},
    {{1, 2, 3, 4}, {0, Sqrt[3]}, {2}}, {{Root[#^5 - # - 1 &, 1], 1}, {2}}};
  And @@ Flatten[Table[
    Algebraic`Private`digitCompose[digits, h] ===
      Algebraic`Private`trim[RootReduce /@ CoefficientList[Expand[Sum[
        FromDigits[Reverse[digits[[j]]], x] If[j === 1, 1, FromDigits[Reverse[h], x]^(j - 1)],
        {j, Length[digits]}]], x]], {h, bases}, {digits, digitSets}]]], True,
  TestID -> "monomial digit blocks and Horner fallbacks match independent exact arithmetic"]
VerificationTest[Module[{p, data, calls},
  And @@ Flatten[Table[
    p = (2 + a) x^24 + tail + a;
    calls = Trace[data = AlgebraicDecompositionData[p, x, 4],
      Algebraic`Private`monicDivide[___]];
    calls === {} && Length[data["Digits"]] === 7 && data["Inner"] === x^4 &&
      data["Decomposable"] === (tail =!= x^5) && VerifyAlgebraicDecompositionData[p, data, x],
    {a, {Sqrt[2], I}}, {tail, {a x^12, x^5}}]] &&
    Algebraic`Private`baseDigits[{0}, {0, 0, 1}] === {{0}}], True,
  TestID -> "monomial coefficient chunks preserve scaled algebraic certificates"]
VerificationTest[Module[{h = x^3 + Sqrt[2] x, p, data, accepted, calls},
  p = (2 + Sqrt[2]) h^4 + 7 h + 3;
  calls = Trace[data = AlgebraicDecompositionData[p, x, 3];
    accepted = VerifyAlgebraicDecompositionData[p, data, x],
    Algebraic`Private`compose[___]];
  calls === {} && accepted && !VerifyAlgebraicDecompositionData[p + 1, data, x] &&
    AllTrue[{x, 1, 0., False},
      !VerifyAlgebraicDecompositionData[p, Join[data, <|"Residual" -> #|>], x] &]], True,
  TestID -> "positive residual reuses exact reconstruction but checks supplied residual"]
VerificationTest[Module[{data, headers, bad},
  headers = {"Type", "InputDegree", "TestedRightDegrees", "AcceptedRightDegrees", "Indecomposable", "Tests"};
  And @@ Table[
    data = AlgebraicDecompositionData[p, x];
    bad = {"Unknown", True, False, False, "False", False};
    VerifyAlgebraicDecompositionData[p, Association @@ Reverse[Normal[data]], x] &&
      VerifyAlgebraicDecompositionData[p, Append[data, "Extra" -> True], x] &&
      And @@ MapThread[!VerifyAlgebraicDecompositionData[p, Join[data, <|#1 -> #2|>], x] &,
        {headers, bad}] &&
      AllTrue[headers, !VerifyAlgebraicDecompositionData[p, KeyDrop[data, #], x] &],
    {p, {0, 7, 3 x + 1, x^12, x^12 + x}}]], True,
  TestID -> "exhaustive headers preserve exact types required keys and key order independence"]

(* --- 2. Galois engine, sums and products ------------------------------
   From root-decomposition/RootDecomposition.wlt. *)
ClearAll[ap, as, u, v, x];



ap = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
as = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];
u = Root[1 + # + #^3 &, 1];
v = Root[1 - # + #^3 &, 1];

VerificationTest[RootDecompositionLowerBound[ap], 3, TestID -> "lower bound of the product example"];
VerificationTest[RootDecompositionLowerBound[Sqrt[2] + Sqrt[3]], 2, TestID -> "lower bound of sqrt2+sqrt3"];
VerificationTest[RootDecompositionLowerBound[Root[#^5 - # - 1 &, 1]], 5, TestID -> "prime degree"];
VerificationTest[RootDecompositionLowerBound[Root[#^4 - # - 1 &, 1]], 4, TestID -> "S4 exponent bound"];

VerificationTest[RootDecompositionVerify[ap, {u, v}, Times]["Verified"], True, TestID -> "verify product identity"];
VerificationTest[RootDecompositionVerify[as, {u, v}, Plus]["Verified"], True, TestID -> "verify sum identity"];

gd = RootGaloisData[ap];
VerificationTest[gd["Order"], 36, TestID -> "Galois group order S3 x S3"];
VerificationTest[gd["Exponent"], 6, TestID -> "Galois group exponent"];
VerificationTest[Tally[gd["SubfieldDegrees"]], {{1, 1}, {2, 3}, {3, 6}, {4, 1}, {6, 20}, {9, 9}, {12, 4}, {18, 15}, {36, 1}}, TestID -> "subfield degree distribution"];

VerificationTest[Module[{data, matrices, one, auts, perms, products},
  data = RootGaloisData[Root[#^4 - # - 1 &, 1]];
  matrices = Algebraic`Private`multiplicationMatrixOfElement[data, #] & /@ data["RootCoordinates"];
  one = UnitVector[data["Order"], 1]; auts = data["Automorphisms"]; perms = data["Permutations"];
  products = Association[Thread[perms -> auts]];
  And @@ Flatten[Table[auts[[s]] . one == one &&
      And @@ Table[auts[[s]] . matrices[[i]] == matrices[[perms[[s, i]]]] . auts[[s]], {i, Length[matrices]}],
    {s, data["Order"]}]] &&
    And @@ Flatten[Table[auts[[s]] . auts[[t]] == products[perms[[s]][[perms[[t]]]]],
      {s, data["Order"]}, {t, data["Order"]}]]],
  True, TestID -> "S4 automorphisms preserve field multiplication and noncommutative composition"];

VerificationTest[Module[{data = RootGaloisData[Algebraic`Private`x - 2, Algebraic`Private`x]},
  data["Automorphisms"]], {{{1}}}, TestID -> "trivial Galois action with no generators"];

rp = RootProductDecomposition[ap];
VerificationTest[Sort[rp["Terms"]], Sort[{u, v}], TestID -> "product example recovers the two cubics"];
VerificationTest[rp["MaximumDegree"], 3, TestID -> "product example maximum degree"];
VerificationTest[rp["Optimal"], True, TestID -> "product example optimal"];
VerificationTest[rp["Verified"], True, TestID -> "product example verified"];

rs = RootSumDecomposition[as];
VerificationTest[Sort[rs["Terms"]], Sort[{u, v}], TestID -> "sum example recovers the two cubics"];
VerificationTest[rs["MaximumDegree"], 3, TestID -> "sum example maximum degree"];
VerificationTest[rs["Optimal"], True, TestID -> "sum example optimal"];

rs6 = RootSumDecomposition[ap];
VerificationTest[rs6["MaximumDegree"], 6, TestID -> "product root as a sum needs sextics"];
VerificationTest[rs6["Optimal"], True, TestID -> "sextic sum is globally optimal"];
VerificationTest[rs6["Verified"], True, TestID -> "sextic sum verified"];
VerificationTest[RootSumDecomposition[ap, "Scope" -> "InputField"]["MaximumDegree"], 9, TestID -> "inside Q(a) the product root is additively indecomposable"];

e3 = RootReduce[Sqrt[2] + Sqrt[3] + Sqrt[6]];
VerificationTest[RootSumDecomposition[e3]["MaximumDegree"], 2, TestID -> "sqrt2+sqrt3+sqrt6 is a sum of quadratics"];
VerificationTest[FailureQ[RootSumDecomposition[e3, 3, "MaxTerms" -> 2]], True, TestID -> "sqrt2+sqrt3+sqrt6 is not a binary sum"];
VerificationTest[RootProductDecomposition[e3, "MaxFactors" -> 2]["MaximumDegree"], 4, TestID -> "sqrt2+sqrt3+sqrt6 is not a binary product"];

g1 = RootReduce[I + Sqrt[2] + I Sqrt[2]];
VerificationTest[FailureQ[RootSumDecomposition[g1, 3, "MaxTerms" -> 2]], True, TestID -> "i+sqrt2+i sqrt2 is not a binary sum"];
VerificationTest[RootSumDecomposition[g1, "Coefficients" -> "GaussianRationals"]["MaximumDegree"], 2, TestID -> "Gaussian coefficients"];

eta = RootReduce[(1 + Sqrt[2]) (1 + Sqrt[3]) (1 + Sqrt[5])];
VerificationTest[RootProductDecomposition[eta]["MaximumDegree"], 2, TestID -> "three quadratic factors"];
VerificationTest[RootProductDecomposition[eta, "MaxFactors" -> 2]["MaximumDegree"], 4, TestID -> "two-factor optimum is four"];

q = RootReduce[1 + Sqrt[2] + Sqrt[3]];
VerificationTest[RootSumDecomposition[q]["MaximumDegree"], 2, TestID -> "1+sqrt2+sqrt3 sum"];
VerificationTest[RootProductDecomposition[q, "MaxFactors" -> 2]["MaximumDegree"], 4, TestID -> "1+sqrt2+sqrt3 two-factor product"];

ext = RootReduce[Sqrt[(1 + Sqrt[2]) (1 + Sqrt[3])]];
rext = RootProductDecomposition[ext];
VerificationTest[rext["MaximumDegree"], 4, TestID -> "external quartic factors"];
VerificationTest[rext["NormExponent"], 2, TestID -> "norm exponent two"];
VerificationTest[RootSumDecomposition[ext]["MaximumDegree"], 8, TestID -> "external example is additively indecomposable"];

s6 = Root[-1 + 4 #^2 + #^6 &, 3];
VerificationTest[RootSumDecomposition[s6]["MaximumDegree"], 4, TestID -> "pair sum of quartic roots"];
VerificationTest[RootSumDecomposition[s6, "Scope" -> "InputField"]["MaximumDegree"], 6, TestID -> "pair sum inside its own field"];

VerificationTest[RootSumDecomposition[RootReduce[Exp[2 Pi I/5]]]["MaximumDegree"], 4, TestID -> "fifth root of unity"];
VerificationTest[RootSumDecomposition[7/3]["Terms"], {7/3}, TestID -> "rational input"];
VerificationTest[Map[Algebraic`Private`primitiveIntegerCoefficients,
  {{1/2, -1/3, 1/4}, {-2/9, 0, -4/15}, {-7/5}, {0, 0, 2/3}, {0, 2^-1100, 0, 2^1100}}],
  {{6, -4, 3}, {5, 0, 6}, {1}, {0, 0, 1}, {0, 1, 0, 2^2200}},
  TestID -> "shared coefficient normalization preserves signs zeros and exact large denominators"];
VerificationTest[Algebraic`Private`niceScale /@
  {0, 1/7, -11/13, Sqrt[2], (1 + Sqrt[2])/7, Sqrt[2]/2^1100, 2^1100 Sqrt[2]},
  {1, -7, 13/11, 1, 7, 2^1100, 2^-1100},
  TestID -> "coefficient scale scoring preserves sparse rational and extreme scale choices"];
VerificationTest[FailureQ[RootSumDecomposition[1.5]], True, {Algebraic::inexact}, TestID -> "inexact input rejected"];

VerificationTest[RootBoundedDecomposition[ap, Times, 3, 1, 2]["MaximumDegree"], 3, TestID -> "bounded product search"];
VerificationTest[RootBoundedDecomposition[as, Plus, 3, 1, 2]["MaximumDegree"], 3, TestID -> "bounded sum search"];
VerificationTest[Module[{catalog, nonrational},
  And @@ Flatten[Table[
    catalog = RootDecompositionCatalog[d, h];
    nonrational = Algebraic`Private`catalogRoots[d, h, 2];
    nonrational === Select[catalog, Exponent[MinimalPolynomial[#, x], x] > 1 &] &&
      AllTrue[nonrational, ! TrueQ[RootReduce[#] === 0] &],
    {d, 1, 3}, {h, 1, 2}]]], True,
  TestID -> "bounded catalog preserves nonrational root order and excludes zero"];

(* Public bounds and certificate semantics, including paths that return early. *)
VerificationTest[FailureQ[RootSumDecomposition[Sqrt[2], 1]], True, TestID -> "sum degree bound survives trivial shortcut"];
VerificationTest[FailureQ[RootProductDecomposition[Sqrt[2], 1]], True, TestID -> "product degree bound survives trivial shortcut"];
VerificationTest[And @@ (FailureQ /@ {RootSumDecomposition[1, 0], RootProductDecomposition[0, 0],
  RootSumDecomposition[e3, "MaxTerms" -> 0], RootProductDecomposition[eta, "MaxFactors" -> 0],
  RootProductDecomposition[eta, "Scope" -> "Typo"], RootGaloisData[Sqrt[2], "WorkingPrecision" -> 0]}),
  True, TestID -> "invalid options rejected before early returns"];
VerificationTest[And @@ (FailureQ /@ {RootGaloisData[0, x], RootGaloisData[1, x], RootGaloisData[x^2 + Pi, x],
  RootGaloisData[x^2 + 1., x], RootGaloisData[(x - 1)^2, x]}), True, TestID -> "invalid Galois polynomials rejected"];
VerificationTest[And @@ (FailureQ /@ {RootBoundedDecomposition[1, Plus, 1, 1, 0],
  RootBoundedDecomposition[1, Times, 0, 1, 1], RootDecompositionCatalog[1, 0]}), True, TestID -> "invalid dictionary bounds rejected"];
VerificationTest[RootSumDecomposition[q, "MaxTerms" -> 1]["MaximumDegree"], 4, TestID -> "single summand means input itself"];
VerificationTest[RootProductDecomposition[eta, "MaxFactors" -> 1]["MaximumDegree"], 8, TestID -> "single factor means input itself"];
VerificationTest[FailureQ[RootProductDecomposition[eta, 2, "MaxFactors" -> 1]], True, TestID -> "single factor degree bound enforced"];
VerificationTest[With[{r = RootSumDecomposition[q, 2, "MaxTerms" -> 2]},
  {r["Verified"], Length[r["Terms"]], r["MaximumDegree"], r["Optimal"]}],
  {True, 2, 2, True}, TestID -> "trace centering respects two summands and certifies explicit bound"];
VerificationTest[With[{r = RootSumDecomposition[e3, "MaxTerms" -> 2]},
  {r["MaximumDegree"], r["Optimal"], r["ScopeOptimal"]}], {4, False, True},
  TestID -> "binary optimum does not certify unrestricted sum optimum"];
VerificationTest[With[{r = RootProductDecomposition[q, "MaxFactors" -> 2]},
  {r["Optimal"], r["ScopeOptimal"], r["TwoFactorOptimal"]}], {False, True, True},
  TestID -> "binary product certificate has explicit scope"];

(* These inputs share an integral model but have different scaling metadata. *)
cacheA = RootGaloisData[x^2 - 2, x];
cacheB = RootGaloisData[2 x^2 - 1, x];
VerificationTest[{cacheA["Scale"], cacheB["Scale"]}, {1, 2}, TestID -> "Galois cache preserves input scale"];
VerificationTest[Quiet[FailureQ[RootGaloisData[Sqrt[2], "MaxGroupOrder" -> 1]]], True,
  TestID -> "cached Galois data respects a tighter group limit"];
VerificationTest[With[{xx = Algebraic`Private`x},
  {Algebraic`Private`inputFieldData[xx^4 - 10 xx^2 + 8]["Scale"],
   Algebraic`Private`inputFieldData[2 xx^4 - 5 xx^2 + 1]["Scale"]}], {1, 2},
  TestID -> "input field cache preserves input scale"];

VerificationTest[FailureQ[RootSumDecomposition[g1, "Coefficients" -> "GaussianRationals", "MaxTerms" -> 2]],
  True, TestID -> "finite Gaussian term count is explicitly unsupported"];
VerificationTest[RootSumDecomposition[7/3, "Coefficients" -> "GaussianRationals"]["Terms"], {{1, 7/3}},
  TestID -> "Gaussian trivial result uses coefficient root pairs"];
VerificationTest[With[{r = RootSumDecomposition[I/2, "Coefficients" -> "GaussianRationals"]},
  {r["Verified"], r["MaximumDegree"]}], {True, 1}, TestID -> "Gaussian imaginary unit coordinates respect integral scaling"];
VerificationTest[With[{r = RootSumDecomposition[I Sqrt[2], "Coefficients" -> "GaussianRationals", "Scope" -> "InputField"]},
  {r["Verified"], r["MaximumDegree"]}], {True, 2}, TestID -> "Gaussian input field scope retains permitted roots"];

VerificationTest[With[{r = RootProductDecomposition[eta, "MaxFactors" -> 3, "BoundedSearch" -> None, "RecursionDepth" -> 0]},
  {r["Verified"], r["MaximumDegree"], Length[r["Terms"]], r["Method"], r["ScopeOptimal"]}], {True, 2, 3, "TensorRankOne", True},
  TestID -> "tensor search starts at many factor lower bound and respects factor count"];
VerificationTest[With[{r = RootProductDecomposition[3 eta/2, 2, "MaxFactors" -> 3, "BoundedSearch" -> None, "RecursionDepth" -> 0]},
  {r["Verified"], r["MaximumDegree"], Length[r["Terms"]]}], {True, 2, 3},
  TestID -> "product normalization absorbs rational factor within cap"];
VerificationTest[FailureQ[RootProductDecomposition[ext, 4, "Scope" -> "InputField", "MaxFactors" -> 2]], True,
  TestID -> "input field scope excludes external radical factors"];
VerificationTest[RootDecompositionVerify[0, {}, Plus]["MaximumDegree"], 1, TestID -> "empty sum degree convention"];
VerificationTest[RootDecompositionVerify[Sqrt[2], {N[Sqrt[2]]}, Plus]["Verified"], False,
  TestID -> "inexact terms cannot obtain exact verification"];
VerificationTest[With[{r = RootSumDecomposition[ap, "Engine" -> "InputField"]},
  {r["Optimal"], r["ScopeOptimal"]}], {False, False}, TestID -> "forced input field sum cannot certify global exhaustion"];
VerificationTest[With[{r = RootProductDecomposition[ext, "Engine" -> "InputField", "MaxFactors" -> 2]},
  {r["Optimal"], r["ScopeOptimal"], r["TwoFactorOptimal"]}], {False, False, False},
  TestID -> "forced input field product cannot certify global exhaustion"];
VerificationTest[With[{r = RootProductDecomposition[ext, "Scope" -> "InputField", "MaxFactors" -> 2]},
  {r["Optimal"], r["ScopeOptimal"], r["TwoFactorOptimal"]}], {False, True, True},
  TestID -> "two factor certificate is relative to requested input field scope"];
VerificationTest[RootSumDecomposition[10^100 + Sqrt[2]]["Verified"], True,
  TestID -> "exact branch identification survives indistinguishable numerical roots"];
VerificationTest[RootBoundedDecomposition[Sqrt[2] + Sqrt[3], Plus, 4, 3, 2]["ScopeOptimal"], False,
  TestID -> "bounded feasibility shortcut does not certify minimal degree"];

VerificationTest[Algebraic`Private`groupClosure[Table[Mod[i + j - 2, 4] + 1, {i, 4}, {j, 4}], 1, {3}],
  {1, 3}, TestID -> "shared subgroup closure generates the order two subgroup"];
VerificationTest[Module[{attempts = {}, result},
  result = Quiet[Algebraic`Private`retryPrecision[Function[p, AppendTo[attempts, p];
    If[p < 40, Throw["precision", Algebraic`Private`precTag], p]], 10], Algebraic::prec];
  {result, attempts}], {40, {10, 20, 40}}, TestID -> "shared precision retry doubles until success"];
VerificationTest[Module[{attempts = {}, result},
  result = Quiet[Algebraic`Private`retryPrecision[Function[p, AppendTo[attempts, p];
    Throw["precision", Algebraic`Private`precTag]], 10], Algebraic::prec];
  {FailureQ[result], attempts}], {True, {10, 20, 40, 80}}, TestID -> "shared precision retry preserves four attempt limit"];

VerificationTest[Module[{data = RootGaloisData[x^3 - 2, x], one, result},
  one = UnitVector[data["Order"], 1];
  And @@ Table[Algebraic`Private`elementToAlgebraic[data, q one] === q, {q, {0, -2/7, 7/3}}] &&
    And @@ Table[
      result = Algebraic`Private`elementToAlgebraic[data, one + data["RootCoordinates"][[j]]/3];
      RootReduce[result - 1 - data["Roots"][[j]]/3] === 0 &&
        MinimalPolynomial[result, x] === Expand[27 (x - 1)^3 - 2], {j, 3}]],
  True, TestID -> "exact element orbits preserve rational real complex and nonintegral branches"];
VerificationTest[Module[{data = RootGaloisData[x^2 - 2, x, "WorkingPrecision" -> 30], result, den = 10^40},
  And @@ Table[
    result = Algebraic`Private`elementToAlgebraic[data, UnitVector[2, 1] + data["RootCoordinates"][[j]]/den];
    RootReduce[result - 1 - data["Roots"][[j]]/den] === 0 &&
      MinimalPolynomial[result, x] === Expand[(den^2 (x - 1)^2 - 2)/2], {j, 2}]],
  True, TestID -> "exact element orbits preserve extremely close conjugate branches"];

VerificationTest[And @@ Table[Module[{data = RootGaloisData[p, x], snapshot, one, pairs, den},
  snapshot = data; one = UnitVector[data["Order"], 1];
  pairs = Join[{{0 one, 0}, {one/7, 1/7}},
    Table[{one + data["RootCoordinates"][[j]]/3, 1 + data["Roots"][[j]]/3}, {j, Length[data["Roots"]]}],
    {{10^40 one + data["RootCoordinates"][[1]]/7, 10^40 + data["Roots"][[1]]/7}}];
  AllTrue[pairs, Function[pair, den = LCM @@ Denominator[pair[[1]]];
    Algebraic`Private`coordinatesFromConjugates[data,
      Algebraic`Private`conjugates[data, den pair[[1]]]]/den === pair[[1]] &&
      Algebraic`Private`elementDegree[data, pair[[1]]] === Exponent[MinimalPolynomial[pair[[2]], x], x]]] &&
    data === snapshot], {p, {x - 2, x^3 - 2, x^3 - 3 x + 1, x^4 + 1}}], True,
  TestID -> "shared trace coordinates and stabilizer degrees preserve exact real complex and rational elements"];
VerificationTest[With[{data = <|"Values" -> IdentityMatrix[2], "GramInverse" -> IdentityMatrix[2]|>},
  Algebraic`Private`coordinatesFromConjugates[data, {2, -3}] === {2, -3} &&
    AllTrue[{{1/3, 0}, {I, 0}, {N[1, 8], 0}},
      Catch[Algebraic`Private`coordinatesFromConjugates[data, #], Algebraic`Private`precTag] === "precision" &]],
  True, TestID -> "shared trace coordinates retain tagged noninteger imaginary and low accuracy failures"];

VerificationTest[And @@ Table[
  Module[{data = RootGaloisData[p, x], values},
    values = Algebraic`Private`valuesAtPrecision[data, 2 data["Precision"]];
    Algebraic`Private`basisValues[data["NumericRoots"], data["Permutations"], data["Tower"],
      data["BasisExponents"]] === data["Values"] &&
      Algebraic`Private`roundIntegerMatrix[Transpose[values] . values] === data["Gram"]],
  {p, {x - 2, x^3 - 2, x^4 - x - 1}}], True,
  TestID -> "shared basis evaluation preserves exact trace matrices at higher precision"];

VerificationTest[RootDecompositionCatalog[1, 2], {2, 1, 1/2, 0, -1, -1/2, -2},
  TestID -> "catalog preserves positive leading coefficient enumeration order"];
VerificationTest[RootDecompositionCatalog[2, 1], Join[{1, 0, -1}, Flatten[Table[
  Algebraic`Private`rootObject[p /. x -> Algebraic`Private`x, j],
  {p, {-1 - x + x^2, -1 + x + x^2, 1 - x + x^2, 1 + x^2, 1 + x + x^2}}, {j, 2}]]],
  TestID -> "catalog preserves quadratic polynomial and branch order"];
VerificationTest[Check[Module[{data = RootGaloisData[x, x, "Cache" -> False]},
  {data["Order"], data["Values"], data["RootCoordinates"],
   Algebraic`Private`valuesAtPrecision[data, 2 data["Precision"]]}], $Failed],
  {1, {{1}}, {{0}}, {{1}}}, TestID -> "zero root field avoids indeterminate zero powers"];
VerificationTest[Check[Module[{data = RootGaloisData[x (x^2 - 2), x, "Cache" -> False], values},
  values = Algebraic`Private`valuesAtPrecision[data, 2 data["Precision"]];
  {data["Order"], Algebraic`Private`roundIntegerMatrix[Transpose[values] . values] === data["Gram"]}], $Failed],
  {2, True}, TestID -> "splitting field containing zero preserves trace matrices without messages"];

VerificationTest[With[{xx = Algebraic`Private`x},
  {Algebraic`Private`frobeniusCycleType[xx^2 - xx - 1, 2],
   Algebraic`Private`frobeniusCycleType[xx^2 - xx - 1, 11],
   Algebraic`Private`frobeniusCycleType[2 xx^2 - 1, 3]}],
  {{2}, {1, 1}, {2}}, TestID -> "shared Frobenius helper returns sorted nonconstant factor degrees"];
VerificationTest[Check[Algebraic`Private`frobeniusExponentMultiple[Algebraic`Private`x^3 - 2, 0], $Failed],
  1, TestID -> "zero Frobenius prime budget gives neutral exponent without messages"];
VerificationTest[Check[With[{p = Algebraic`Private`x^4 - Times @@ Prime[Range[60]]},
  {Algebraic`Private`frobeniusExponentMultiple[p, 40], Algebraic`Private`lowerBoundFromPolynomial[p]}], $Failed],
  {1, 2}, TestID -> "finite Frobenius prime window with no good primes preserves valid lower bound"];

VerificationTest[Algebraic`Private`powerSums[1, 0], {}, TestID -> "Newton sums preserve the empty degree zero range"];
VerificationTest[And @@ Table[With[{xx = Algebraic`Private`x, n = Length[roots]},
  Algebraic`Private`powerSums[Expand[Times @@ (xx - roots)], n] ===
    Prepend[Table[Total[roots^k], {k, 1, n - 1}], n]],
  {roots, {{0}, {-3, 0, 0, 2}, {1, 1, 1, 1, 1}, {-5, -2, 1, 3, 4, 7}}}], True,
  TestID -> "Newton sums match independent root powers including repeated and zero roots"];
VerificationTest[And @@ Table[Module[{xx = Algebraic`Private`x, n, matrix},
  n = Exponent[p, x];
  matrix = Table[If[i == j + 1, 1, 0] - If[j == n, Coefficient[p, x, i - 1], 0], {i, n}, {j, n}];
  Algebraic`Private`powerSums[p /. x -> xx, n] === Table[Tr[MatrixPower[matrix, k]], {k, 0, n - 1}]],
  {p, {2 - 3 x + x^2, x^3 - 2, 1 + x + x^2 + x^3 + x^4}}], True,
  TestID -> "Newton sums match exact companion matrix traces for real and complex roots"];

VerificationTest[Module[{spaces = Table[<|"Basis" -> {UnitVector[4, i]}|>, {i, 4}]},
  And @@ Table[Algebraic`Private`findSumRepresentation[Take[spaces, count], UnitVector[4, 4], Infinity] === $Failed,
    {count, 0, 3}] &&
  Algebraic`Private`findSumRepresentation[spaces, {1, 1, 0, 0}, Infinity] ===
    Table[{spaces[[i]], UnitVector[4, i]}, {i, 2}]], True,
  TestID -> "sum span search preserves empty failures and first successful subset order"];
VerificationTest[Module[{spaces = Table[<|"Basis" -> {UnitVector[4, i]}|>, {i, 4}], expected},
  expected = Table[{spaces[[i]], UnitVector[4, i]}, {i, 4}];
  Algebraic`Private`findSumRepresentation[spaces, {1, 1, 1, 1}, Infinity] === expected &&
    Algebraic`Private`findSumRepresentation[spaces, {1, 1, 1, 1}, 3] === $Failed &&
    Algebraic`Private`findSumRepresentation[spaces, {1, 1, 1, 1}, 4] === expected], True,
  TestID -> "sum span search retains full space fallback and finite term caps"];
VerificationTest[With[{spaces = Table[<|"Basis" -> {UnitVector[5, i]}|>, {i, 4}]},
  Algebraic`Private`findSumRepresentation[spaces, UnitVector[5, 5], Infinity]], $Failed,
  TestID -> "unrestricted sum rejects an impossible full span"];

VerificationTest[Module[{x = Algebraic`Private`x, roots, data, a, poly},
  roots = Join[Flatten[Table[Root[Function @@ {p /. x -> Slot[1]}, k, mode],
      {p, {x^5 - x - 1, x^8 - 2}}, {k, Exponent[p, x]}, {mode, {0, 1}}]],
    {1 + Sqrt[2], Sqrt[2] + I Sqrt[3], 1 + Sqrt[2]/10^50}];
  a = Root[#^5 - # - 1 &, 2]; poly = (x^5 - x - 1) (x^2 - 2);
  (* The stored index is 2, but this larger polynomial places the same root at 4. *)
  Algebraic`Private`rootIndexOf[a, poly] === 4 && AllTrue[roots,
    Function[value, data = Algebraic`Private`inputData[value];
      IntegerQ[data["Index"]] && 1 <= data["Index"] <= data["Degree"] &&
        RootReduce[value - Algebraic`Private`rootObject[data["Polynomial"], data["Index"]]] === 0]]],
  True, TestID -> "stored Root indices are verified and mismatched candidates retain exact fallback"];

(* --- 3. Radical expressions -------------------------------------------
   From root-to-radicals/RootToRadicals.wlt. *)
ClearAll[a6, a5, c5, x];



a6 = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2];          (* first example of the question *)
a5 = Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5];            (* second example of the question *)
c5 = Root[#^5 + #^4 - 4 #^3 - 3 #^2 + 3 # + 1 &, 1];  (* cyclic quintic, 2 cos(2 Pi/11) *)

(* radical grammar *)
VerificationTest[RadicalExpressionQ[(1 + Sqrt[5])/2], True, TestID -> "grammar: golden ratio"];
VerificationTest[RadicalExpressionQ[(-1)^(2/5) 7^(1/5) + I/3], True, TestID -> "grammar: roots of unity and I"];
VerificationTest[RadicalExpressionQ[Root[#^5 - # - 1 &, 1]], False, TestID -> "grammar: Root is not a radical"];
VerificationTest[RadicalExpressionQ[Cos[Pi/7]], False, TestID -> "grammar: trigonometric"];
VerificationTest[RadicalExpressionQ[2^Sqrt[2]], False, TestID -> "grammar: irrational exponent"];
VerificationTest[RadicalDepth[Sqrt[1 + Sqrt[2]]], 2, TestID -> "depth: nested"];
VerificationTest[RadicalDepth[Sqrt[2]^3 + 1/Sqrt[3]], 1, TestID -> "depth: integer powers do not nest"];
VerificationTest[RadicalDepth[7/3], 0, TestID -> "depth: rational"];
VerificationTest[Module[{y}, AllTrue[{
    {2/3, True, 0}, {-2 + 3 I, True, 0}, {1. + I, False, 0},
    {(1 + Sqrt[2])^(2/3), True, 2}, {2^Sqrt[2], False, 1},
    {y^2, False, 0}, {y^(1/3), False, 1}, {(y + Sqrt[2])^(1/3), False, 2},
    {Sin[Sqrt[2]], False, 0}, {HoldForm[Sqrt[2]], False, 0}, {{Sqrt[2]}, False, 0},
    {True, False, 0}, {Root[#^5 - # - 1 &, 1], False, 0}},
  {RadicalExpressionQ[First[#]], RadicalDepth[First[#]]} === Rest[#] &]], True,
  TestID -> "typed grammar and depth preserve exact approximate symbolic and unsupported heads"];

(* the built-in function fails on all three *)
VerificationTest[Head[ToRadicals[a6]], Root, TestID -> "built-in ToRadicals fails on the sextic"];
VerificationTest[Head[ToRadicals[a5]], Root, TestID -> "built-in ToRadicals fails on the quintic"];
VerificationTest[Head[ToRadicals[c5]], Root, TestID -> "built-in ToRadicals fails on the cyclic quintic"];

(* first example: generalized reciprocal symmetry *)
r6 = RootRadicalReport[a6];
VerificationTest[r6["Verified"], True, TestID -> "sextic example verified"];
VerificationTest[r6["Method"], "Reciprocal", TestID -> "sextic example method"];
VerificationTest[RootReduce[r6["Expression"] - a6], 0, TestID -> "sextic example exact identity"];
VerificationTest[RadicalExpressionQ[r6["Expression"]], True, TestID -> "sextic example is a radical expression"];
VerificationTest[Table[RootRadicalReport[Root[-1 - #^2 - #^3 + #^4 + #^6 &, k]]["Verified"], {k, 6}],
  ConstantArray[True, 6], TestID -> "sextic example all conjugates"];

(* second example: Dickson polynomial 5 (D_5(x, 1) + 6/5) *)
r5 = RootRadicalReport[a5];
VerificationTest[r5["Verified"], True, TestID -> "quintic example verified"];
VerificationTest[r5["Method"], "Dickson", TestID -> "quintic example method"];
VerificationTest[r5["RadicalDepth"], 1, TestID -> "quintic example depth"];
VerificationTest[RootReduce[r5["Expression"] - (((-3 + 4 I)/5)^(1/5) + ((-3 - 4 I)/5)^(1/5))], 0,
  TestID -> "quintic example equals the closed form of the question"];
VerificationTest[Table[RootRadicalReport[Root[6 + 25 # - 25 #^3 + 5 #^5 &, k]]["Verified"], {k, 5}],
  ConstantArray[True, 5], TestID -> "quintic example all conjugates"];

(* the cyclic quintic needs the general descent *)
rc = RootRadicalReport[c5];
VerificationTest[rc["Verified"], True, TestID -> "cyclic quintic verified"];
VerificationTest[rc["Method"], "Galois", TestID -> "cyclic quintic method"];
VerificationTest[{rc["GaloisGroupOrder"], rc["ExtendedGroupOrder"], rc["SeriesPrimes"]}, {5, 20, {5}},
  TestID -> "cyclic quintic group data"];
VerificationTest[RootRadicalReport[c5, "Resolvents" -> "Fourier"]["Verified"], True, TestID -> "cyclic quintic Fourier form"];
VerificationTest[RootRadicalReport[c5, "Resolvents" -> "Eigenvector"]["Verified"], True, TestID -> "cyclic quintic eigenvector form"];
VerificationTest[RootToRadicals[Root[#^5 + #^4 - 4 #^3 - 3 #^2 + 3 # + 1 &, 3]] // RadicalExpressionQ, True,
  TestID -> "cyclic quintic other conjugate"];

(* forced descent on small solvable cases *)
VerificationTest[RootRadicalReport[Root[#^3 - 2 &, 2], Method -> "Galois"]["Verified"], True, TestID -> "descent x^3-2"];
VerificationTest[RootRadicalReport[Root[#^3 - 3 # + 1 &, 1], Method -> "Galois"]["Verified"], True, TestID -> "descent x^3-3x+1"];
VerificationTest[RootRadicalReport[Root[#^4 - 2 &, 4], Method -> "Galois"]["Verified"], True, TestID -> "descent x^4-2"];
VerificationTest[RootRadicalReport[Root[#^4 - 10 #^2 + 1 &, 4], Method -> "Galois"]["Verified"], True, TestID -> "descent x^4-10x^2+1"];
VerificationTest[RootRadicalReport[Root[#^5 - 2 &, 3], Method -> "Galois"]["Verified"], True, TestID -> "descent x^5-2"];
VerificationTest[RootRadicalReport[Root[#^8 + 1 &, 1], Method -> "Galois"]["Verified"], True, TestID -> "descent x^8+1"];
VerificationTest[RootRadicalReport[Root[Cyclotomic[7, #] &, 1], Method -> "Galois"]["Verified"], True, TestID -> "descent Phi_7"];
VerificationTest[RootRadicalReport[Root[#^6 - 2 #^3 - 1 &, 1], Method -> "Galois"]["Verified"], True, TestID -> "descent x^6-2x^3-1"];

VerificationTest[Module[{run},
  run[failures_] := Module[{precisions = {}, result},
    result = Block[{Algebraic`Private`$opts = {"WorkingPrecision" -> 80},
        Algebraic`Private`$galoisInfo, Algebraic`Private`descend},
      Algebraic`Private`descend[gd_, a_, primes_, form_] := (
        AppendTo[precisions, gd["Precision"]];
        If[Length[precisions] <= failures, Throw["precision", Algebraic`Private`precTag]];
        <|"Expression" -> Sqrt[2], "ExtendedGroupOrder" -> gd["Order"], "SeriesPrimes" -> {2}|>);
      Algebraic`Private`galoisRadicals[Sqrt[2], Algebraic`Private`x^2 - 2]];
    {precisions, If[FailureQ[result], result[[1]], result]}];
  {run[1], run[3]}], {{{80, 160}, Sqrt[2]}, {{80, 160, 320}, "Precision"}},
  TestID -> "descent without odd primes refreshes field precision and retains three-attempt limit"];

(* forced descent on the two examples of the question *)
rg6 = RootRadicalReport[a6, Method -> "Galois"];
VerificationTest[rg6["Verified"], True, TestID -> "sextic example by descent"];
VerificationTest[{rg6["GaloisGroupOrder"], rg6["ExtendedGroupOrder"]}, {24, 48}, TestID -> "sextic example group orders"];
rg5 = RootRadicalReport[a5, Method -> "Galois"];
VerificationTest[rg5["Verified"], True, TestID -> "quintic example by descent"];
VerificationTest[{rg5["GaloisGroupOrder"], rg5["ExtendedGroupOrder"]}, {20, 40}, TestID -> "quintic example group orders"];

(* Each suffix of quotient generators generates the corresponding subgroup. *)
VerificationTest[Module[{x, gd, H, index, steps, generators, identity, fixedSpace, basis},
  And @@ Table[
    gd = RootGaloisData[case[[1]], x]; H = Range[gd["Order"]];
    If[case[[2]] != 0,
      index = First@FirstPosition[gd["Roots"], _?(RootReduce[# - gd["Scale"] Exp[2 Pi I/case[[2]]]] === 0 &)];
      H = Select[H, gd["Permutations"][[#, index]] == index &]];
    identity = IdentityMatrix[gd["Order"]];
    fixedSpace[group_] := RowReduce[NullSpace[Join @@ (gd["Automorphisms"][[#]] - identity & /@ group)]];
    steps = Algebraic`Private`primeSeries[gd["MultiplicationTable"], gd["Identity"], H];
    {gd["Order"], Length[H]} == case[[3]] && And @@ Table[
      generators = steps[[i ;;, "Generator"]]; basis = fixedSpace[generators];
      Algebraic`Private`groupClosure[gd["MultiplicationTable"], gd["Identity"], generators] == steps[[i, "Group"]] &&
        basis == fixedSpace[steps[[i, "Group"]]] && Length[basis] Length[steps[[i, "Group"]]] == gd["Order"] &&
        AllTrue[basis, Algebraic`Private`fixedByQ[gd, #, steps[[i, "Group"]]] &], {i, Length[steps]}],
    {case, {{x^3 - 3 x + 1, 0, {3, 3}}, {x^4 - x - 1, 0, {24, 24}},
      {(x^5 + x^4 - 4 x^3 - 3 x^2 + 3 x + 1) Cyclotomic[5, x], 5, {20, 5}}}}]],
  True, TestID -> "series generator suffixes preserve exact fixed spaces including extended base"];

VerificationTest[Module[{perms, mt, H, allPairs, expected, actual, collections},
  allPairs[table_, id_, group_] := Module[{inv = Association @@ Table[g -> First[FirstPosition[table[[g]], id]], {g, group}]},
    Algebraic`Private`groupClosure[table, id,
      DeleteDuplicates[Flatten[Table[table[[table[[inv[g], inv[h]]], table[[g, h]]]], {g, group}, {h, group}]]]]];
  And @@ Table[
    perms = Permutations[Range[n]]; H = Range[Length[perms]];
    mt = Table[First@FirstPosition[perms, g[[h]]], {g, perms}, {h, perms}];
    actual = Algebraic`Private`primeSeries[mt, 1, H];
    expected = Block[{Algebraic`Private`commutatorSubgroup},
      Algebraic`Private`commutatorSubgroup[table_, id_, group_] := allPairs[table, id, group];
      Algebraic`Private`primeSeries[mt, 1, H]];
    collections = {{}, {1}, H, Reverse[H], Take[H, 3], Join[Take[H, 3], Take[H, 3]]};
    actual === expected && Algebraic`Private`solvableQ[mt, 1, H] === (n == 4) &&
      Algebraic`Private`commutatorSubgroup[mt, 1, H] === Pick[H, Signature /@ perms, 1] &&
      And @@ Table[Algebraic`Private`commutatorSubgroup[mt, 1, collection] === allPairs[mt, 1, collection],
        {collection, collections}], {n, {4, 5}}]],
  True, TestID -> "unordered commutators preserve derived groups, exact series, and partial collections"];

(* Exact coordinate powers agree with the former matrix route, including nonintegral elements. *)
VerificationTest[Module[{gd, vectors, one},
  gd = RootGaloisData[Algebraic`Private`x^3 - 2,
    Algebraic`Private`x, "WorkingPrecision" -> 80];
  one = UnitVector[gd["Order"], 1];
  vectors = {0 one, gd["RootCoordinates"][[2]],
    gd["RootCoordinates"][[1]]/3 + gd["RootCoordinates"][[2]]/7,
    10^40 one + ConstantArray[1/7, gd["Order"]]};
  And @@ Flatten[Table[
    Algebraic`Private`powerCoordinates[gd, v, k] ==
      If[k == 0, one, MatrixPower[Algebraic`Private`multiplicationMatrixOfElement[gd, v], k] . one],
    {v, vectors}, {k, {0, 1, 2, 3, 5}}]]],
  True, TestID -> "coordinate powers match matrices including precision fallback"];

VerificationTest[Module[{gd, one, numerators, denominators, divide, matrix},
  gd = RootGaloisData[Algebraic`Private`x^3 - 2, Algebraic`Private`x, "WorkingPrecision" -> 80];
  one = UnitVector[gd["Order"], 1];
  numerators = {0 one, one, gd["RootCoordinates"][[2]], 10^100 one + ConstantArray[1, gd["Order"]]};
  denominators = {one, gd["RootCoordinates"][[2]],
    gd["RootCoordinates"][[1]]/3 + gd["RootCoordinates"][[2]]/7,
    10^40 one + ConstantArray[1/7, gd["Order"]], one/10^100};
  FailureQ[Algebraic`Private`powerDivider[gd, 0 one]] && And @@ Flatten[Table[
    divide = Algebraic`Private`powerDivider[gd, denominator];
    matrix = Algebraic`Private`multiplicationMatrixOfElement[gd, denominator];
    Table[divide[numerator, k] == If[k == 0, numerator, LinearSolve[MatrixPower[matrix, k], numerator]],
      {numerator, numerators}, {k, {0, 1, 2, 3, 5}}], {denominator, denominators}]]],
  True, TestID -> "coordinate quotients match solves including norm and trace fallback"];

VerificationTest[Module[{gd, denominator, numerator, divide, matrix},
  gd = RootGaloisData[Algebraic`Private`x^3 - 3 Algebraic`Private`x + 1,
    Algebraic`Private`x, "WorkingPrecision" -> 80];
  denominator = gd["RootCoordinates"][[1]];
  numerator = UnitVector[gd["Order"], 1]/5 + gd["RootCoordinates"][[2]]/7;
  divide = Algebraic`Private`powerDivider[gd, denominator];
  matrix = Algebraic`Private`multiplicationMatrixOfElement[gd, denominator];
  Algebraic`Private`roundInteger[Times @@ Algebraic`Private`conjugates[gd, denominator]] == -1 &&
    And @@ Table[divide[numerator, k] == LinearSolve[MatrixPower[matrix, k], numerator], {k, {1, 2, 3, 5}}]],
  True, TestID -> "coordinate quotients preserve negative norm signs in odd degree"];

(* structural families *)
rd10 = RootRadicalReport[Root[#^10 + #^8 - 4 #^6 - 3 #^4 + 3 #^2 + 1 &, 5]];   (* c5's polynomial composed with x^2 *)
VerificationTest[rd10["Verified"], True, TestID -> "decomposition verified"];
VerificationTest[rd10["Method"], "Decompose", TestID -> "decomposition method"];
VerificationTest[
  And @@ Table[With[{a = Root[#^8 - 2 &, k]},
    RootReduce[Algebraic`Private`structuralDecompose[a,
      Algebraic`Private`x^8 - 2, 6] - a] === 0], {k, 8}],
  True, TestID -> "three-component decomposition all conjugates"];
rd7 = RootRadicalReport[Root[#^7 - 7 #^5 + 14 #^3 - 7 # - 3 &, 1]];             (* D_7(x, 1) - 3 *)
VerificationTest[rd7["Verified"], True, TestID -> "Dickson verified"];
VerificationTest[rd7["Method"], "Dickson", TestID -> "Dickson method"];
rps = RootRadicalReport[Root[3 - 9 # + 6 #^2 - 7 #^3 - #^6 &, 1], Method -> "Structural"];   (* pair sums of degree 3 *)
VerificationTest[rps["Verified"], True, TestID -> "pair-sum verified"];
VerificationTest[rps["Method"], "PairSum", TestID -> "pair-sum method"];
VerificationTest[RootRadicalReport[c5, Method -> "Structural"][[1]], "NotFound", TestID -> "structural search exhausted"];
rext = RootRadicalReport[a6, "Extension" -> {Root[#^3 + 4 # - 1 &, 1]}];   (* the subfield Q(a - 1/a) given explicitly *)
VerificationTest[rext["Verified"], True, TestID -> "extension option verified"];
VerificationTest[rext["Method"], "Extension", TestID -> "extension option method"];
VerificationTest[RootRadicalReport[a6, "Extension" -> {1.5}][[1]], "InvalidOptions", {RootToRadicals::opts}, TestID -> "extension option validation"];

(* negative results *)
VerificationTest[RootRadicalReport[Root[#^5 - # - 1 &, 1]][[1]], "NotSolvable", {RootToRadicals::notsolv}, TestID -> "x^5-x-1 not solvable"];
VerificationTest[RootRadicalReport[Root[#^7 - # - 1 &, 1]][[1]], "NotSolvable", {RootToRadicals::notsolv}, TestID -> "x^7-x-1 not solvable"];
VerificationTest[RootRadicalReport[Root[#^6 - # - 1 &, 1]][[1]], "NotSolvable", {RootToRadicals::notsolv}, TestID -> "x^6-x-1 not solvable (long prime cycle)"];
VerificationTest[RootRadicalReport[Root[#^6 + #^4 + 3 #^2 - 2 # + 5 &, 1]][[1]], "NotSolvable", {RootToRadicals::notsolv}, TestID -> "sextic with group of order 120"];
VerificationTest[RootRadicalReport[Root[#^8 - # - 1 &, 1]][[1]], "NotSolvable", {RootToRadicals::notsolv}, TestID -> "x^8-x-1 not solvable (prime-power degree)"];
VerificationTest[RootRadicalReport[Root[#^9 - # - 1 &, 1]][[1]], "NotSolvable", {RootToRadicals::notsolv}, TestID -> "x^9-x-1 not solvable (prime-power degree)"];
VerificationTest[RootSolvableQ[Root[#^5 - # - 1 &, 1]], False, TestID -> "RootSolvableQ negative"];
VerificationTest[RootSolvableQ[Root[#^9 - # - 1 &, 1]], False, TestID -> "RootSolvableQ negative, degree 9"];
VerificationTest[RootSolvableQ[c5], True, TestID -> "RootSolvableQ cyclic quintic"];
VerificationTest[RootSolvableQ[a6], True, TestID -> "RootSolvableQ sextic example"];
VerificationTest[RootSolvableQ[Root[#^4 - # - 1 &, 1]], True, TestID -> "RootSolvableQ quartic"];

(* resource limits, trivial and invalid input *)
VerificationTest[RootRadicalReport[Root[#^4 - # - 1 &, 1], Method -> "Galois", "MaxGroupOrder" -> 10][[1]], "ResourceLimit",
  TestID -> "group order limit (Frobenius order multiple)"];
VerificationTest[RootRadicalReport[Root[#^4 - # - 1 &, 1], Method -> "Galois", "MaxGroupOrder" -> 12][[1]], "ResourceLimit",
  {Algebraic::order}, TestID -> "group order limit (engine)"];
VerificationTest[RootToRadicals[3/4], 3/4, TestID -> "rational input"];
VerificationTest[RootToRadicals[1 + Sqrt[2]], 1 + Sqrt[2], TestID -> "radical input is returned"];
VerificationTest[RootRadicalReport[1.5][[1]], "Inexact", {RootToRadicals::inexact}, TestID -> "inexact input"];
VerificationTest[RootRadicalReport[Pi][[1]], "NotAlgebraic", {Algebraic::notalg}, TestID -> "transcendental input"];
VerificationTest[RootRadicalReport[Root[#^3 - 2 &, 1], Method -> "Nope"][[1]], "InvalidOptions", {RootToRadicals::opts}, TestID -> "invalid option"];

(* Regression suite for radical-denest/corrected/StradFixed3.wl
   (context Algebraic`).

   Groups:  R4-*, R5-*, R6-* translate the suites of review-4/5/6 (kept from unified-B),
            G-*  are the fifteen inputs of radical-denest/corrected/KNOWN_GAPS.md,
            A-*  are contracts kept from the unified-A battery,
            C-*  translate the suites of review-7 (C-R7), review-8 (C-R8) and
                 review-9 (C-R9) onto the names, arities and contracts of
                 StradFixed3, plus the unified-C controls (C-U).
   Options and report keys of the reviews' proposals were mapped onto those of
   StradFixed3 (see unified-C, Section "Translating the reviews' test suites").
   Run with tests/run_tests.wls in a fresh kernel. *)

Begin["AlgebraicTests`Denest`"];
ClearAll[d, eq, depth, improves, x, y, f, h];
d[e_, opts___] := Algebraic`DenestRadicals[e, opts];
eq[a_, b_] := TrueQ[RootReduce[a - b] === 0];
depth[e_] := Algebraic`RadicalDepth[e];
improves[e_, target_, opts___] := Module[{v = d[e, opts]}, eq[v, target] && depth[v] < depth[e]];

(* ---------------- R4: review-4, tests/Regression.wlt ---------------- *)
VerificationTest[Algebraic`CertifiedEqualQ[Sqrt[5 + 2 Sqrt[6]], Sqrt[2] + Sqrt[3]], True, TestID -> "R4-exact-equality-positive"]
VerificationTest[Algebraic`CertifiedEqualQ[Sqrt[3 - 2 Sqrt[2]], 1 - Sqrt[2]], False, TestID -> "R4-reject-wrong-square-root-branch"]
VerificationTest[Algebraic`CertifiedEqualQ[Sqrt[2], Sqrt[2] + 10^-100], False, TestID -> "R4-no-numerical-tolerance-acceptance"]
VerificationTest[Algebraic`CertifiedEqualQ[x, x], False, TestID -> "R4-symbolic-equality-is-not-algebraic-certificate"]
VerificationTest[{Algebraic`ExactAlgebraicQ[Pi], Algebraic`ExactAlgebraicQ[N[Sqrt[2]]], Algebraic`ExactAlgebraicQ[(1 + I)/2]}, {False, False, True}, TestID -> "R4-supported-exact-domain"]
VerificationTest[Block[{Algebraic`Private`$cfg = Association[Options[Algebraic`DenestRadicals]]}, Algebraic`Private`validPolynomialQ[$Failed, x]], False, TestID -> "R4-failed-is-not-an-accepted-polynomial"]
VerificationTest[Block[{Algebraic`Private`$cfg = Association[Options[Algebraic`DenestRadicals]]}, Algebraic`Private`validPolynomialQ[7, x]], False, TestID -> "R4-constant-is-not-a-minimal-polynomial"]
VerificationTest[Algebraic`RadicalDepth[Root[#^5 - # - 1 &, 1]], 0, TestID -> "R4-root-payload-is-opaque"]
VerificationTest[First[Algebraic`RadicalCost[Root[#^5 - # - 1 &, 1]]], 1, TestID -> "R4-root-representation-is-not-free"]
VerificationTest[Algebraic`RadicalCost[{}], {0, 0, 0, LeafCount[{}], 0}, TestID -> "R4-empty-list-metrics"]
VerificationTest[improves[Sqrt[5 + 2 Sqrt[6]], Sqrt[2] + Sqrt[3]], True, TestID -> "R4-direct-quadratic-denesting"]
VerificationTest[improves[Sqrt[3 - 2 Sqrt[2]], Sqrt[2] - 1], True, TestID -> "R4-negative-coefficient-positive-root"]
VerificationTest[improves[Sqrt[4 + 3 Sqrt[2]], 2^(1/4) (1 + Sqrt[2])], True, TestID -> "R4-indirect-fourth-root-minus-sign"]
VerificationTest[improves[Sqrt[-4 + 3 Sqrt[2]], 2^(1/4) (Sqrt[2] - 1)], True, TestID -> "R4-indirect-negative-rational-part"]
VerificationTest[eq[d[Sqrt[-3 - 2 Sqrt[2]]], I (1 + Sqrt[2])], True, TestID -> "R4-negative-radicand-principal-square-root"]
VerificationTest[improves[(49 + 20 Sqrt[6])^(1/4), Sqrt[2] + Sqrt[3], True], True, TestID -> "R4-composite-index-without-cost-neutral-stall"]
VerificationTest[eq[d[(3 + 2 Sqrt[2])^(-1/2)], Sqrt[2] - 1], True, TestID -> "R4-negative-rational-exponent"]
VerificationTest[improves[(7 + 5 Sqrt[2])^(1/3), 1 + Sqrt[2]], True, TestID -> "R4-cubic-trace-norm"]
VerificationTest[Module[{e = (7 - 5 Sqrt[2])^(1/3), r}, r = d[e]; eq[r, e] && ! eq[r, 1 - Sqrt[2]]], True, TestID -> "R4-negative-real-cubic-is-not-real-root"]
VerificationTest[improves[Sqrt[5^(1/3) - 4^(1/3)], (2^(1/3) + 20^(1/3) - 25^(1/3))/3], True, TestID -> "R4-honsbeek-ramanujan-square-of-cube-roots"]
VerificationTest[Module[{e = x + Sqrt[5 + 2 Sqrt[6]], r}, r = d[e, "Solver" -> (0 &), "Factor" -> False]; eq[(r - x) - (e - x), 0]], True, TestID -> "R4-untrusted-solver-in-symbolic-host"]
VerificationTest[Module[{e = Sqrt[x^2] + Sqrt[5 + 2 Sqrt[6]], r}, r = Block[{$Assumptions = x > 0}, d[e]]; eq[(r - e) /. x -> -2, 0]], True, TestID -> "R4-ambient-assumptions-do-not-rewrite-host"]
VerificationTest[Module[{e = f[Sqrt[5 + 2 Sqrt[6]]]}, SameQ[d[e], e]], True, TestID -> "R4-unknown-head-is-opaque"]
VerificationTest[SameQ[d[HoldComplete[Sqrt[5 + 2 Sqrt[6]]]], HoldComplete[Sqrt[5 + 2 Sqrt[6]]]], True, TestID -> "R4-held-input-is-opaque"]
VerificationTest[Module[{e = (x + 1) (x - 1)}, SameQ[Algebraic`Factorc[e], e]], True, TestID -> "R4-symbolic-factorc-is-conservative"]
VerificationTest[Algebraic`CertifiedEqualQ[Algebraic`RationalizeDenominator[1/(1 + Sqrt[2])], Sqrt[2] - 1], True, TestID -> "R4-horner-inverse"]
VerificationTest[Algebraic`CertifiedEqualQ[Algebraic`RationalizeDenominator[x/(1 + Sqrt[2])] /. x -> 1, Sqrt[2] - 1], True, TestID -> "R4-symbolic-numerator-local-inverse-certificate"]
VerificationTest[Algebraic`CertifiedEqualQ[Sqrt[I] (-1 + I), -Sqrt[2]], True, TestID -> "R4-aggregate-positive-factor-is-not-termwise-license"]
VerificationTest[Module[{saved = Options[Algebraic`DenestRadicals], e = Sqrt[5 + 2 Sqrt[6]], r}, SetOptions[Algebraic`DenestRadicals, "TimeBudget" -> 0]; r = d[e]; SetOptions[Algebraic`DenestRadicals, Sequence @@ saved]; SameQ[r, e]], True, TestID -> "R4-setoptions-strad-is-effective"]
VerificationTest[Module[{saved = Options[Algebraic`DenestRadicals], e = Sqrt[5 + 2 Sqrt[6]], r}, SetOptions[Algebraic`DenestRadicals, "TimeBudget" -> 0]; r = Algebraic`DenestRadicals[e]; SetOptions[Algebraic`DenestRadicals, Sequence @@ saved]; SameQ[r, e]], True, TestID -> "R4-setoptions-wrapper-is-effective"]
VerificationTest[Module[{r = Algebraic`DenestReport[Sqrt[5 + 2 Sqrt[6]], "TimeBudget" -> 0]}, r["Statistics"]["Trials"] === 0 && MemberQ[r["Limits"], "TimeBudget"] && SameQ[r["Result"], Sqrt[5 + 2 Sqrt[6]]]], True, TestID -> "R4-zero-budget-no-work"]
VerificationTest[And @@ (FailureQ[d[Sqrt[1 + Sqrt[2]], #]] & /@ {"MultiplierCap" -> Infinity, "MultiplierCap" -> -1, "MultiplierCap" -> 1/2, "MaxTrials" -> -1, "TimeBudget" -> Infinity, "TimeBudget" -> -1, "MaxRootIndex" -> 0, "AllLevels" -> "yes", "Bogus" -> 1}), True, TestID -> "R4-invalid-options-fail-explicitly"]
VerificationTest[Module[{r = Algebraic`DenestReport[Sqrt[1 + Sqrt[2]], "Multipliers" -> Range[20], "MultiplierCap" -> 1, "TimeBudget" -> 20]}, r["Statistics"]["MultipliersAdmitted"] <= 1 && r["Statistics"]["Trials"] <= 1], True, TestID -> "R4-forced-list-obeys-cap"]
VerificationTest[Module[{r = Algebraic`DenestReport[{Sqrt[1 + Sqrt[2]], Sqrt[1 + Sqrt[3]]}, "MaxTrials" -> 1, "Multipliers" -> {1}, "TimeBudget" -> 30]}, r["Statistics"]["Trials"] <= 2], True, TestID -> "R4-trial-budget-per-island-across-list"]
VerificationTest[Module[{r = Algebraic`DenestReport[Sqrt[1 + Sqrt[2]], "Trace" -> True, "MaxTraceEntries" -> 1, "MaxTrials" -> 2, "TimeBudget" -> 20]}, Length[r["Trace"]] <= 1], True, TestID -> "R4-bounded-diagnostics"]
VerificationTest[Module[{e = Sqrt[5 + 2 Sqrt[6]], r}, r = d[e, "Solver" -> (Throw["bad", "callback"] &)]; eq[r, e]], True, TestID -> "R4-callback-throw-is-not-a-rewrite"]
VerificationTest[Module[{examples = {Sqrt[2 + Sqrt[3]], Sqrt[4 + 3 Sqrt[2]], (7 - 5 Sqrt[2])^(1/3), (49 + 20 Sqrt[6])^(1/4)}, results}, results = d[examples, True]; And @@ MapThread[(eq[#1, #2] && Order[Algebraic`RadicalCost[#1], Algebraic`RadicalCost[#2]] =!= -1) &, {results, examples}]], True, TestID -> "R4-each-example-equal-and-no-more-expensive"]

(* ---------------- R5: review-5, tests/regression.wlt ---------------- *)
VerificationTest[eq[d[Sqrt[5 + 2 Sqrt[6]]], Sqrt[2] + Sqrt[3]], True, TestID -> "R5-direct-square-value"]
VerificationTest[depth[d[Sqrt[5 + 2 Sqrt[6]]]], 1, TestID -> "R5-direct-square-depth"]
VerificationTest[eq[d[Sqrt[4 + 3 Sqrt[2]]], 2^(1/4) (1 + Sqrt[2])], True, TestID -> "R5-indirect-fourth-root-value"]
VerificationTest[depth[d[Sqrt[4 + 3 Sqrt[2]]]], 1, TestID -> "R5-indirect-fourth-root-depth"]
VerificationTest[eq[d[Sqrt[3 - 2 Sqrt[2]]], Sqrt[2] - 1], True, TestID -> "R5-small-positive-branch"]
VerificationTest[eq[d[Sqrt[-5 - 2 Sqrt[6]]], I (Sqrt[2] + Sqrt[3])], True, TestID -> "R5-negative-radicand-principal-square-root"]
VerificationTest[eq[d[(41 - 29 Sqrt[2])^(1/5)], (41 - 29 Sqrt[2])^(1/5)], True, TestID -> "R5-principal-fifth-power-preserved"]
VerificationTest[Algebraic`CertifiedEqualQ[1 - Sqrt[2], (41 - 29 Sqrt[2])^(1/5)], False, TestID -> "R5-real-fifth-root-is-not-principal-power"]
VerificationTest[Module[{a = Sqrt[5 + 2 Sqrt[6]], r}, r = d[x + a, "Solver" -> Function[z, 0]]; eq[r - x, a]], True, TestID -> "R5-bad-zero-solver-in-symbolic-host-rejected"]
VerificationTest[Module[{a = Sqrt[5 + 2 Sqrt[6]], r}, r = d[x + a, "Solver" -> Function[z, $Failed]]; FreeQ[r, $Failed] && eq[r - x, a]], True, TestID -> "R5-failed-solver-does-not-leak"]
VerificationTest[Module[{a = Sqrt[5 + 2 Sqrt[6]], r}, r = d[x + a, "Solver" -> Function[z, 1.41421356237]]; FreeQ[r, _Real] && eq[r - x, a]], True, TestID -> "R5-approximate-solver-does-not-leak"]
VerificationTest[Block[{$Assumptions = x > 0}, SameQ[d[Sqrt[x^2]], Sqrt[x^2]]], True, TestID -> "R5-ambient-assumptions-do-not-rewrite-host"]
VerificationTest[SameQ[d[h[Sqrt[5 + 2 Sqrt[6]]]], h[Sqrt[5 + 2 Sqrt[6]]]], True, TestID -> "R5-unknown-head-is-opaque"]
VerificationTest[Algebraic`ExactAlgebraicQ[Pi], False, TestID -> "R5-transcendental-constant-rejected"]
VerificationTest[Algebraic`ExactAlgebraicQ[Sqrt[2] + 3^(1/3)], True, TestID -> "R5-explicit-algebraic-grammar"]
VerificationTest[Algebraic`EqualityStatus[Sqrt[2], -Sqrt[2]], "Different", TestID -> "R5-conjugates-distinguished"]
VerificationTest[Algebraic`EqualityStatus[Sqrt[2], x], "Unknown", TestID -> "R5-non-algebraic-comparison-is-unknown"]
VerificationTest[Module[{a = Sqrt[5 + 2 Sqrt[6]], r}, r = Algebraic`DenestReport[a, {"TimeBudget" -> 0}]; {r["Result"] === a, r["Statistics"]["Trials"], r["Status"]}], {True, 0, "Disabled"}, TestID -> "R5-zero-total-budget-is-noop"]
VerificationTest[FailureQ[Algebraic`DenestReport[Sqrt[5 + 2 Sqrt[6]], "MaxTrials" -> -1]], True, TestID -> "R5-invalid-integer-option"]
VerificationTest[FailureQ[Algebraic`DenestReport[Sqrt[5 + 2 Sqrt[6]], "TimeBudget" -> "bad"]], True, TestID -> "R5-invalid-time-option"]
VerificationTest[FailureQ[Algebraic`DenestReport[Sqrt[5 + 2 Sqrt[6]], "UnknownOption" -> 1]], True, TestID -> "R5-unknown-option-rejected"]
VerificationTest[Module[{defaults = Options[Algebraic`DenestRadicals], a = Sqrt[5 + 2 Sqrt[6]], result}, SetOptions[Algebraic`DenestRadicals, "TimeBudget" -> 0]; result = d[a]; SetOptions[Algebraic`DenestRadicals, Sequence @@ defaults]; SameQ[result, a]], True, TestID -> "R5-SetOptions-on-alias-is-honored"]
VerificationTest[Module[{a = Sqrt[5 + 2 Sqrt[6]], r}, r = Algebraic`DenestReport[a, "MaxTrials" -> 0]; r["Statistics"]["Trials"] === 0 && eq[r["Result"], a] && depth[r["Result"]] === 1], True, TestID -> "R5-zero-trials-disables-only-multiplier-search"]
VerificationTest[Module[{r = Algebraic`DenestReport[{Sqrt[2 + Sqrt[2]], Sqrt[3 + Sqrt[3]]}, "MaxTrials" -> 1, "TimeBudget" -> 30]}, r["Statistics"]["Trials"] <= 2], True, TestID -> "R5-per-island-list-trial-budget"]
VerificationTest[Module[{a = Sqrt[5 + 2 Sqrt[6]], b}, b = d[a, True]; SameQ[d[b, True], b]], True, TestID -> "R5-simple-idempotence"]
VerificationTest[Module[{mixed = {1.0, Sqrt[5 + 2 Sqrt[6]]}}, SameQ[d[mixed], mixed]], True, TestID -> "R5-inexact-tree-policy-is-conservative"]
VerificationTest[Algebraic`CertifiedEqualQ[Algebraic`RationalizeDenominator[1/(1 + Sqrt[2])], Sqrt[2] - 1], True, TestID -> "R5-rationalization-certificate"]
VerificationTest[SameQ[Algebraic`Factorc[Sqrt[x^2]], Sqrt[x^2]], True, TestID -> "R5-factor-helper-refuses-symbolic-transform"]
VerificationTest[Module[{a = Sqrt[5 + 2 Sqrt[6]], r}, r = Algebraic`DenestReport[a, "Multipliers" -> {0, Pi, 1.0, 2}]; eq[r["Result"], a]], True, TestID -> "R5-invalid-seeds-do-not-change-value"]
VerificationTest[Module[{a = Sqrt[5 + 2 Sqrt[6]], r}, r = Algebraic`DenestReport[a, "MaxTraceEntries" -> 0]; r["Certificates"] === {} && eq[r["Result"], a]], True, TestID -> "R5-bounded-certificate-records"]
VerificationTest[Module[{a = (2^(1/3) - 1)^(1/3), b}, b = Algebraic`DenestCore[a, "Multipliers" -> {9}, "Factor" -> False]; eq[b, a] && depth[b] == 1], True, TestID -> "R5-ramanujan-cubic-multiplier-nine"]

(* ---------------- R6: review-6, tests/DenestRadicalsImproved.wlt ---------------- *)
VerificationTest[improves[Sqrt[3 + 2 Sqrt[2]], 1 + Sqrt[2], "MaxTrials" -> 0], True, TestID -> "R6-direct-plus"]
VerificationTest[improves[Sqrt[3 - 2 Sqrt[2]], Sqrt[2] - 1, "MaxTrials" -> 0], True, TestID -> "R6-direct-minus"]
VerificationTest[improves[Sqrt[5 + 2 Sqrt[6]], Sqrt[2] + Sqrt[3], "MaxTrials" -> 0], True, TestID -> "R6-two-surds"]
VerificationTest[improves[Sqrt[4 + 3 Sqrt[2]], 2^(1/4) (1 + Sqrt[2]), "MaxTrials" -> 0], True, TestID -> "R6-indirect-plus"]
VerificationTest[improves[Sqrt[-4 + 3 Sqrt[2]], 2^(1/4) (Sqrt[2] - 1), "MaxTrials" -> 0], True, TestID -> "R6-indirect-minus"]
VerificationTest[eq[d[Sqrt[-3 - 2 Sqrt[2]], "MaxTrials" -> 0], I (1 + Sqrt[2])], True, TestID -> "R6-imaginary-square-root"]
VerificationTest[Module[{v = d[Sqrt[3 + 4 I], "MaxTrials" -> 0]}, eq[v, 2 + I] && depth[v] === 0], True, TestID -> "R6-complex-square-root"]
VerificationTest[improves[(26 + 15 Sqrt[3])^(1/3), 2 + Sqrt[3], "MaxTrials" -> 0], True, TestID -> "R6-cubic-quadratic"]
VerificationTest[improves[(2 + Sqrt[5])^(1/3), (1 + Sqrt[5])/2, "MaxTrials" -> 0], True, TestID -> "R6-cubic-golden-ratio"]
VerificationTest[eq[d[(-26 - 15 Sqrt[3])^(1/3), "MaxTrials" -> 0], (-1)^(1/3) (2 + Sqrt[3])], True, TestID -> "R6-principal-negative-cube"]
VerificationTest[improves[(3 + 2 Sqrt[2])^(3/2), (1 + Sqrt[2])^3, "MaxTrials" -> 0], True, TestID -> "R6-rational-power-numerator"]
VerificationTest[eq[d[(3 + 2 Sqrt[2])^(-1/2), "MaxTrials" -> 0], Sqrt[2] - 1], True, TestID -> "R6-reciprocal-root"]
VerificationTest[eq[d[x + Sqrt[3 + 2 Sqrt[2]], "Solver" -> (0 &)] - x, 1 + Sqrt[2]], True, TestID -> "R6-symbolic-host-reject-zero"]
VerificationTest[eq[d[Sqrt[3 + 2 Sqrt[2]], "Solver" -> (-1 - Sqrt[2] &)], 1 + Sqrt[2]], True, TestID -> "R6-reject-opposite-branch"]
VerificationTest[FreeQ[d[Sqrt[3 + 2 Sqrt[2]], "Solver" -> (N[#, 20] &)], _Real], True, TestID -> "R6-reject-inexact-candidate"]
VerificationTest[d[x + Sqrt[2 + Sqrt[2]], "Solver" -> (0 &)] =!= x, True, TestID -> "R6-symbolic-host-without-fastpath"]
VerificationTest[Algebraic`RadicalExpressionQ[Inactive[Cos][Pi/8]], False, TestID -> "R6-grammar-reject-hidden-function"]
VerificationTest[Algebraic`RadicalExpressionQ[Root[#^5 - # - 1 &, 1]], False, TestID -> "R6-grammar-reject-root-object"]
VerificationTest[Algebraic`CertifiedEqualQ[Sqrt[2] + Sqrt[3], Sqrt[3] - Sqrt[2]], False, TestID -> "R6-same-minpoly-not-equality"]
VerificationTest[Algebraic`CertifiedEqualQ[Sqrt[3 + 2 Sqrt[2]], 1 + Sqrt[2]], True, TestID -> "R6-exact-certificate"]
VerificationTest[Block[{$Assumptions = x > 0}, d[Sqrt[x^2]]], Sqrt[x^2], TestID -> "R6-ambient-assumptions-isolated"]
VerificationTest[d[HoldComplete[Sqrt[3 + 2 Sqrt[2]]]], HoldComplete[Sqrt[3 + 2 Sqrt[2]]], TestID -> "R6-held-input-unchanged"]
VerificationTest[d[f[Sqrt[3 + 2 Sqrt[2]]]], f[Sqrt[3 + 2 Sqrt[2]]], TestID -> "R6-unknown-head-not-traversed"]
VerificationTest[d[{1.25, Sqrt[3 + 2 Sqrt[2]]}, "MaxTrials" -> 0], {1.25, Sqrt[3 + 2 Sqrt[2]]}, TestID -> "R6-mixed-exact-inexact-list-is-conservative"]
VerificationTest[d[0], 0, TestID -> "R6-zero"]
VerificationTest[d[7/5], 7/5, TestID -> "R6-rational-no-op"]
VerificationTest[d[Indeterminate], Indeterminate, TestID -> "R6-invalid-value-preserved"]
VerificationTest[d[Sqrt[3 + 2 Sqrt[2]], "TimeBudget" -> 0], Sqrt[3 + 2 Sqrt[2]], TestID -> "R6-zero-budget-no-op"]
VerificationTest[FailureQ[d[Sqrt[2], "MultiplierCap" -> Infinity]], True, TestID -> "R6-infinite-cap-invalid"]
VerificationTest[FailureQ[d[Sqrt[2], "MaxTrials" -> -1]], True, TestID -> "R6-negative-trials-invalid"]
VerificationTest[FailureQ[d[Sqrt[2], "TimeBudget" -> -1]], True, TestID -> "R6-negative-budget-invalid"]
VerificationTest[FailureQ[d[Sqrt[2], "AllLevels" -> "yes"]], True, TestID -> "R6-boolean-option-invalid"]
VerificationTest[FailureQ[d[Sqrt[2], "NotAnOption" -> 1]], True, TestID -> "R6-unknown-option-invalid"]
VerificationTest[Module[{saved = Options[Algebraic`DenestRadicals], out}, SetOptions[Algebraic`DenestRadicals, "TimeBudget" -> 0]; out = d[Sqrt[3 + 2 Sqrt[2]]]; SetOptions[Algebraic`DenestRadicals, Sequence @@ saved]; out], Sqrt[3 + 2 Sqrt[2]], TestID -> "R6-setoptions-respected"]
VerificationTest[d[Sqrt[3 + 2 Sqrt[2]], "TimeBudget" -> 0, "TimeBudget" -> 30], Sqrt[3 + 2 Sqrt[2]], TestID -> "R6-first-explicit-option-wins"]
VerificationTest[Algebraic`DenestReport[Sqrt[1 + Sqrt[2]], "MultiplierCap" -> 0]["Statistics"]["Trials"], 0, TestID -> "R6-zero-cap-no-search"]
VerificationTest[Module[{r = Algebraic`DenestReport[{Sqrt[2 + Sqrt[2]], Sqrt[1 + Sqrt[3]]}, "MaxTrials" -> 1, "MultiplierCap" -> 2, "TimeBudget" -> 10]}, r["Statistics"]["Trials"] <= 2], True, TestID -> "R6-per-island-list-trials"]
VerificationTest[Module[{r = Algebraic`DenestReport[Sqrt[2 + Sqrt[2]], "MultiplierCap" -> 1, "MaxTrials" -> 2, "TimeBudget" -> 10]}, r["Statistics"]["MultipliersAdmitted"] <= 1], True, TestID -> "R6-queue-cap-one-node"]
VerificationTest[Module[{r = Algebraic`DenestReport[Sqrt[3 + 2 Sqrt[2]], "MaxTrials" -> 0]}, Length[r["Certificates"]] > 0 && AllTrue[r["Certificates"], eq[#["After"], #["Before"]] &]], True, TestID -> "R6-recheck-certificate-log"]
VerificationTest[Module[{e = 1/(1 + Sqrt[2])}, eq[e, Algebraic`RationalizeDenominator[e]]], True, TestID -> "R6-rationalization-equality"]
VerificationTest[Algebraic`Factorc[x^2 - 1], x^2 - 1, TestID -> "R6-symbolic-factorc-conservative"]
VerificationTest[Order[{0, 1, 2}, {0, 2, 1}], 1, TestID -> "R6-cost-order-direction"]
VerificationTest[Module[{e = (2^(1/3) - 1)^(1/3), v}, v = Algebraic`DenestCore[e, "Multipliers" -> {9}, "MultiplierCap" -> 1, "MaxTrials" -> 1, "TimeBudget" -> 30]; eq[e, v] && depth[v] < depth[e]], True, TestID -> "R6-ramanujan-forced-multiplier-nine"]

(* ---------------- G: the fifteen misses of KNOWN_GAPS.md ---------------- *)
VerificationTest[improves[(41 - 29 Sqrt[2])^(1/5), (-1)^(1/5) (Sqrt[2] - 1)], True, TestID -> "G-A-C05-negative-fifth-root"]
VerificationTest[improves[(-99 - 70 Sqrt[2])^(1/6), (-1)^(1/6) (1 + Sqrt[2])], True, TestID -> "G-A-C14-negative-sixth-root"]
VerificationTest[improves[Expand[-(1 + 2^(1/3))^5]^(1/5), (-1)^(1/5) (1 + 2^(1/3))], True, TestID -> "G-A-S11"]
VerificationTest[improves[(-239 - 169 Sqrt[2])^(1/7), (-1)^(1/7) (1 + Sqrt[2])], True, TestID -> "G-A-S12"]
VerificationTest[improves[(76 - 44 Sqrt[3])^(1/5), (-1)^(1/5) (Sqrt[3] - 1)], True, TestID -> "G-A-S13"]
VerificationTest[improves[(682 - 305 Sqrt[5])^(1/5), (-1)^(1/5) (Sqrt[5] - 2)], True, TestID -> "G-A-S14"]
VerificationTest[improves[(1393 - 985 Sqrt[2])^(1/9), (-1)^(1/9) (Sqrt[2] - 1)], True, TestID -> "G-A-S15"]
VerificationTest[improves[Expand[(Sqrt[2] - Sqrt[3])^5]^(1/5), (-1)^(1/5) (Sqrt[3] - Sqrt[2])], True, TestID -> "G-A-S20"]
VerificationTest[improves[(7 20^(1/3) - 19)^(1/6), (5/3)^(1/3) - (2/3)^(1/3)], True, TestID -> "G-B-R03-ramanujan-sixth-root"]
VerificationTest[improves[Expand[(2^(1/3) + 3^(1/3))^6]^(1/6), 2^(1/3) + 3^(1/3)], True, TestID -> "G-B-P02"]
VerificationTest[improves[Expand[(2^(1/3) + 5^(1/3))^6]^(1/6), 2^(1/3) + 5^(1/3)], True, TestID -> "G-B-S10"]
VerificationTest[improves[Expand[(2^(1/3) + 3^(1/3))^9]^(1/9), 2^(1/3) + 3^(1/3)], True, TestID -> "G-B-S04"]
VerificationTest[improves[(1296 + 880 Sqrt[2] + 720 Sqrt[3] + 528 Sqrt[6])^(1/6), 1 + Sqrt[2] + Sqrt[3]], True, TestID -> "G-C-S05-factor-extraction"]
VerificationTest[d[Sqrt[1 + Sqrt[3]] + Sqrt[3 + 3 Sqrt[3]] - Sqrt[10 + 6 Sqrt[3]]], 0, TestID -> "G-D-Q21-cancellation"]
VerificationTest[Module[{e = Expand[(Sqrt[2] + Sqrt[3] + Sqrt[5] + Sqrt[7] + Sqrt[11])^2]^(1/2), t, r}, {t, r} = AbsoluteTiming[d[e, "TimeBudget" -> 60]]; eq[r, Sqrt[2] + Sqrt[3] + Sqrt[5] + Sqrt[7] + Sqrt[11]] && t < 60], True, TestID -> "G-E-P13-five-primes-within-budget"]

(* ---------------- A: contracts kept from unified-A ---------------- *)
VerificationTest[improves[(2^(1/3) - 1)^(1/3), (1 - 2^(1/3) + 4^(1/3))/9^(1/3)], True, TestID -> "A-A12-ramanujan-cube-root"]
VerificationTest[improves[Sqrt[28^(1/3) - 3], (98^(1/3) - 28^(1/3) - 1)/3], True, TestID -> "A-K01-ramanujan-square-root"]
VerificationTest[eq[d[(-1 + 2 I Sqrt[2])^(3/2)], -5 + I Sqrt[2]], True, TestID -> "A-C02-complex-three-halves-power"]
VerificationTest[eq[d[Sqrt[-1 + 2 I Sqrt[2]] Sqrt[-2 + 2 I Sqrt[3]]], (1 + I Sqrt[2]) (1 + I Sqrt[3])], True, TestID -> "A-C03-complex-product"]
VerificationTest[eq[d[-Sqrt[3 + 2 Sqrt[2]]], -1 - Sqrt[2]], True, TestID -> "A-C01-negative-target"]
VerificationTest[Module[{r = d[Sqrt[16 - 2 Sqrt[29] + 2 Sqrt[55 - 10 Sqrt[29]]], True]}, eq[r, Sqrt[5] + Sqrt[11 - 2 Sqrt[29]]] && depth[r] === 2], True, TestID -> "A-A30-bfht-partial-denesting"]
VerificationTest[Module[{r = d[Sqrt[16 - 2 Sqrt[29] + 2 Sqrt[55 - 10 Sqrt[29]]]]}, eq[r, Sqrt[5] + Sqrt[11 - 2 Sqrt[29]]] && depth[r] === 2], True, TestID -> "A-A31-bfht-default-levels"]
VerificationTest[eq[d[Root[#^4 - 10 #^2 + 1 &, 4]], Sqrt[2] + Sqrt[3]], True, TestID -> "A-B07-root-input"]
VerificationTest[d[Sqrt[2 + Sqrt[2]]], Sqrt[2 + Sqrt[2]], TestID -> "A-B01-non-denestable-unchanged"]
VerificationTest[d[(1 + Sqrt[2])^(1/3)], (1 + Sqrt[2])^(1/3), TestID -> "A-B03-non-denestable-cube-root-unchanged"]
VerificationTest[d[Sqrt[z^2]], Sqrt[z^2], TestID -> "A-E01-symbolic-untouched"]
VerificationTest[d[Sqrt[x] Sqrt[3 + 2 Sqrt[2]]], Sqrt[x] (1 + Sqrt[2]), TestID -> "A-E06-numeric-factor-inside-symbolic-product"]
VerificationTest[d[Sqrt[3 + 2 Sqrt[2]] + Pi], 1 + Sqrt[2] + Pi, TestID -> "A-K11-transcendental-host"]
VerificationTest[eq[d[Sqrt[2 + Sqrt[3]] + Sqrt[2 - Sqrt[3]]], Sqrt[6]], True, TestID -> "A-A23-sum-recombined"]
VerificationTest[Module[{r = Algebraic`DenestReport[Sqrt[5 + 2 Sqrt[6]] + Sqrt[1 + Sqrt[2]]]}, r["Status"] === "Improved" && eq[r["Result"], Sqrt[2] + Sqrt[3] + Sqrt[1 + Sqrt[2]]]], True, TestID -> "A-report-status-improved"]
VerificationTest[Module[{r = d[1/(Sqrt[2] + Sqrt[3 + 2 Sqrt[2]])]}, eq[r, (2 Sqrt[2] - 1)/7] && depth[r] === 1], True, TestID -> "A-M02-reciprocal-of-a-sum-island"]
VerificationTest[d[(Sqrt[2 - Sqrt[3]] + Sqrt[2 + Sqrt[3]])^2], 6, TestID -> "A-M15-integer-power-of-a-sum-island"]
VerificationTest[Attributes[Print], {Protected}, TestID -> "A-print-untouched"]

(* ---------------- C: round 3 ---------------- *)
ClearAll[session, memberEq];
SetAttributes[session, HoldAll];
session[body_] := Algebraic`Private`standalone[Block[{Algebraic`Private`$cfg = Join[Algebraic`Private`$cfg, <|"MaxRecursion" -> 0, "MaxTrials" -> 0|>]}, body], $Failed];
memberEq[list_, v_] := ListQ[list] && AnyTrue[list, eq[#, v] &];

(* review-7 *)
VerificationTest[Algebraic`ExactAlgebraicQ /@ {3/7, 2 + 3 I, Pi, 1.2}, {True, True, False, False}, TestID -> "C-R7-admission-basics"]
VerificationTest[Algebraic`ExactAlgebraicQ[Root[#^5 + # - 1 &, 1]], True, TestID -> "C-R7-rational-root-admission"]
VerificationTest[Algebraic`ExactAlgebraicQ[Root[#^5 + # - Pi &, 1]], False, TestID -> "C-R7-transcendental-root-rejected"]
VerificationTest[Module[{a}, Algebraic`ExactAlgebraicQ[Root[#^5 + # + a &, 1]]], False, TestID -> "C-R7-parametric-root-rejected"]
VerificationTest[Algebraic`EqualityStatus[Root[#^5 + # - Pi &, 1], 0], "Unknown", TestID -> "C-R7-unsupported-root-equality-unknown"]
VerificationTest[Algebraic`EqualityStatus[0, 10^-100], "Different", TestID -> "C-R7-small-nonzero-exact"]
VerificationTest[Algebraic`EqualityStatus[(-8)^(1/3), -2], "Different", TestID -> "C-R7-principal-not-real-cube-root"]
VerificationTest[Algebraic`CertifiedEqualQ[Pi, Pi], False, TestID -> "C-R7-outside-grammar-not-certified"]
VerificationTest[Block[{Algebraic`Private`numericallyDifferentQ = (True &)}, Algebraic`EqualityStatus[Sqrt[5 + 2 Sqrt[6]], Sqrt[2] + Sqrt[3]]], "Equal", TestID -> "C-R7-injected-numeric-hint-cannot-decide"]
VerificationTest[FailureQ /@ {Algebraic`DenestRadicals[1, 17], Algebraic`DenestRadicals[], Algebraic`DenestRadicals[1, "Typo" -> 1], Algebraic`DenestRadicals[1, "TimeBudget" -> Infinity], Algebraic`DenestRadicals[1, "MaxTrials" -> -1], Algebraic`DenestRadicals[1, "AllLevels" -> 1], Algebraic`DenestRadicals[1, "MaxSolveDegree" -> 5]}, ConstantArray[True, 7], TestID -> "C-R7-malformed-and-invalid-options-fail"]
VerificationTest[FailureQ /@ {Algebraic`DenestRadicals[], Algebraic`DenestCore[], Algebraic`DenestReport[], Algebraic`DenestReport[1, 2, 3]}, {True, True, True, True}, TestID -> "C-R7-every-entry-point-rejects-malformed-calls"]
VerificationTest[Algebraic`DenestReport[Sqrt[5 + 2 Sqrt[6]], "TimeBudget" -> 0]["Status"], "Disabled", TestID -> "C-R7-zero-budget-disabled"]
VerificationTest[Algebraic`DenestReport[1, "TimeBudget" -> 0][[{"InitialCost", "FinalCost"}]], <|"InitialCost" -> Missing["NotComputed"], "FinalCost" -> Missing["NotComputed"]|>, TestID -> "C-R7-disabled-no-unbudgeted-cost"]
VerificationTest[Algebraic`DenestReport[1, {"MaxTrials" -> 0}, "TimeBudget" -> 0]["Options"]["MaxTrials"], 0, TestID -> "C-R7-nested-option-list"]
VerificationTest[Algebraic`DenestReport[1, "MaxTrials" -> 0, "MaxTrials" -> 3]["Options"]["MaxTrials"], 0, TestID -> "C-R7-first-option-wins"]
VerificationTest[Module[{old = Options[Algebraic`DenestRadicals], r}, SetOptions[Algebraic`DenestRadicals, "TimeBudget" -> 0]; r = Algebraic`DenestRadicals[Sqrt[5 + 2 Sqrt[6]]]; Options[Algebraic`DenestRadicals] = old; r], Sqrt[5 + 2 Sqrt[6]], TestID -> "C-R7-setoptions-entrypoint"]
VerificationTest[{Algebraic`RadicalDepth[Sqrt[1 + Sqrt[2]]], Algebraic`RadicalDepth[Root[#^5 + Sqrt[2] # + 1 &, 1]], Algebraic`RadicalCost[Root[#^5 + Sqrt[2] # + 1 &, 1]][[3]]}, {2, 0, 0}, TestID -> "C-R7-opaque-depth-and-radical-count"]
VerificationTest[Algebraic`RadicalCost[1 + 2^100 I][[5]] > Algebraic`RadicalCost[1 + I][[5]], True, TestID -> "C-R7-complex-bit-size"]
VerificationTest[improves[(41 - 29 Sqrt[2])^(1/5), (-1)^(1/5) (Sqrt[2] - 1)], True, TestID -> "C-R7-negative-fifth-root"]
VerificationTest[improves[(239 + 169 Sqrt[2])^(1/7), 1 + Sqrt[2]], True, TestID -> "C-R7-higher-odd-seventh"]
VerificationTest[session[Module[{z = 1 + Sqrt[2], rho}, rho = Expand[z^9]; AnyTrue[Algebraic`Private`quadraticOddRoots[Algebraic`Private`quadraticParts[rho], 9], eq[#, z] &]]], True, TestID -> "C-R7-higher-odd-ninth-private-recipe"]
VerificationTest[Module[{e = Sqrt[15 + 2 Sqrt[6] + 2 Sqrt[10] + 2 Sqrt[15]]}, eq[d[e], e]], True, TestID -> "C-R7-multisurd-safety"]
VerificationTest[Module[{e = x + Sqrt[1 + Sqrt[2]], r}, r = Block[{$Assumptions = x == 0}, d[e, "Solver" -> (0 &), "MaxTrials" -> 0]]; ! FreeQ[r, x] && eq[(r - x) - (e - x), 0]], True, TestID -> "C-R7-assumptions-isolation"]
VerificationTest[Module[{e = 1.0 + Sqrt[1 + Sqrt[2]]}, d[e] === e], True, TestID -> "C-R7-inexact-tree-noop"]
VerificationTest[d[HoldComplete[Sqrt[5 + 2 Sqrt[6]]]], HoldComplete[Sqrt[5 + 2 Sqrt[6]]], TestID -> "C-R7-held-host-opaque"]
VerificationTest[Module[{e = Sqrt[1 + Sqrt[2]], r}, r = Algebraic`DenestReport[e, "MaxTrials" -> 0, "Multipliers" -> {}, "Solver" -> (0 &)]; eq[r["Result"], e] && r["Statistics"]["Trials"] === 0], True, TestID -> "C-R7-zero-trials-safe"]
VerificationTest[Module[{e = Sqrt[1 + Sqrt[2]], r}, r = Algebraic`DenestReport[e, "MaxTrials" -> 1, "MultiplierCap" -> 1, "MaxRecursion" -> 0]; eq[r["Result"], e] && r["Statistics"]["Trials"] <= 1], True, TestID -> "C-R7-single-visit-trial-cap"]
VerificationTest[Module[{e = Sqrt[1 + Sqrt[2]], r}, r = Algebraic`DenestReport[e, "Solver" -> (Throw[0] &), "MaxTrials" -> 0]; eq[r["Result"], e]], True, TestID -> "C-R7-throwing-solver-quarantined"]
VerificationTest[Module[{e = Sqrt[5 + 2 Sqrt[6]], r}, r = Algebraic`DenestReport[e]; r["FinalCost"] === Algebraic`RadicalCost[r["Result"]] && StringQ[r["CertificateKind"]] && r["ResultChanged"] === True && r["CertificatesTruncated"] === False], True, TestID -> "C-R7-report-cost-and-evidence-kind"]
VerificationTest[session[Module[{t = (3 + 2 Sqrt[2])^(1/4), i = Sqrt[1 + Sqrt[2]]}, Algebraic`Private`negativeRadicandCandidate[t, 3 + 2 Sqrt[2], 1, 4, i] === i]], True, TestID -> "C-R7-positive-radicand-preserves-incumbent"]
VerificationTest[session[Block[{Algebraic`Private`linearRoots = Function[{r, k}, {}], Algebraic`Private`recurse = Identity}, Module[{t = (3 + 2 Sqrt[2])^(1/4), i = Sqrt[1 + Sqrt[2]], r}, r = Algebraic`Private`powerProposals[t, i]; eq[r, t] && Algebraic`Private`cheaperQ[r, t]]]], True, TestID -> "C-R7-power-stage-monotonicity-mocked-search"]
VerificationTest[session[Block[{Algebraic`Private`linearRoots = Function[{r, k}, If[k === 2, {1 + Sqrt[2]}, {}]], Algebraic`Private`recurse = Identity}, Module[{t = (3 + 2 Sqrt[2])^(1/4), r}, r = Algebraic`Private`kummerCandidates[t, 3 + 2 Sqrt[2], 1, 4, t]; eq[r, t] && Algebraic`Private`cheaperQ[r, t]]]], True, TestID -> "C-R7-unchanged-subproblem-admitted-mocked-factors"]

(* review-8 *)
VerificationTest[Algebraic`ExactAlgebraicQ /@ {3/7 + I/5, Root[#^5 - # - 1 &, 1], Root[#^3 + Pi # + 1 &, 1], Root[#^3 - # + parameter &, 1], Root[#^3 + Sqrt[2] # + 1 &, 1], AlgebraicNumber[Sqrt[2], {1, 2}], Pi, 1.0, Infinity}, {True, True, False, False, True, True, False, False, False}, TestID -> "C-R8-grammar"]
VerificationTest[Algebraic`RadicalExpressionQ[Root[#^5 - # - 1 &, 1]], False, TestID -> "C-R8-opaque-not-output"]
VerificationTest[Algebraic`EqualityStatus @@@ {{Sqrt[5 + 2 Sqrt[6]], Sqrt[2] + Sqrt[3]}, {Sqrt[2], -Sqrt[2]}, {1, 1 + 10^-1000}, {Pi, Pi}}, {"Equal", "Different", "Different", "Unknown"}, TestID -> "C-R8-equality-status"]
VerificationTest[Module[{e = Sqrt[3/2 + Sqrt[3]], r}, r = d[e]; eq[r, e] && depth[r] < depth[e]], True, TestID -> "C-R8-indirect-rational"]
VerificationTest[improves[(-239 - 169 Sqrt[2])^(1/7), (-1)^(1/7) (1 + Sqrt[2])], True, TestID -> "C-R8-negative-seventh"]
VerificationTest[improves[(1393 - 985 Sqrt[2])^(1/9), (-1)^(1/9) (Sqrt[2] - 1)], True, TestID -> "C-R8-negative-ninth"]
VerificationTest[session[Algebraic`Private`negativeRadicandCandidate[(3 + 2 Sqrt[2])^(1/6), 3 + 2 Sqrt[2], 1, 6, (1 + Sqrt[2])^(1/3)]] === (1 + Sqrt[2])^(1/3), True, TestID -> "C-R8-negative-stage-preserves-incumbent"]
VerificationTest[Module[{t = (3 + 2 Sqrt[2])^(1/6), r}, r = session[Algebraic`Private`kummerCandidates[t, 3 + 2 Sqrt[2], 1, 6, t]]; {eq[r, t], Algebraic`Private`cheaperQ[r, t]}], {True, True}, TestID -> "C-R8-raw-index-reduction-without-recursion"]
VerificationTest[memberEq[session[Algebraic`Private`honsbeekSquareRoots[28^(1/3) - 3]], Sqrt[28^(1/3) - 3]], True, TestID -> "C-R8-honsbeek-rational-summand"]
VerificationTest[memberEq[session[Algebraic`Private`honsbeekSquareRoots[5^(1/3) - 4^(1/3)]], Sqrt[5^(1/3) - 4^(1/3)]], True, TestID -> "C-R8-honsbeek-classical"]
VerificationTest[MemberQ[session[Algebraic`Private`cosetBases[{55, 210, 462}, {2, 3, 5, 7, 11}]], {6, 35, 77, 330}], True, TestID -> "C-R8-coset-enumeration"]
VerificationTest[memberEq[session[Algebraic`Private`surdSystem[{6, 35, 77, 330}, <|1 -> 118, 55 -> 14, 210 -> 2, 462 -> 2|>]], Sqrt[6] + Sqrt[35] + Sqrt[77]], True, TestID -> "C-R8-coset-coefficient-solver"]
VerificationTest[memberEq[session[Algebraic`Private`surdRelation[{6, 35, 77, 330}, 118 + 2 Sqrt[210] + 14 Sqrt[55] + 2 Sqrt[462]]], Sqrt[6] + Sqrt[35] + Sqrt[77]], True, TestID -> "C-R8-coset-integer-relation"]
VerificationTest[Algebraic`Private`radicalNodes[AlgebraicNumber[Root[#^5 + Sqrt[2] # + 1 &, 1], {1, 1}]], 0, TestID -> "C-R8-opaque-node-count"]
VerificationTest[eq[Algebraic`RationalizeDenominator[1/(2 + I)], 1/(2 + I)], True, TestID -> "C-R8-gaussian-denominator"]
VerificationTest[{d[1.0 + symbolic] === 1.0 + symbolic, d[{1.0, Sqrt[5 + 2 Sqrt[6]]}] === {1.0, Sqrt[5 + 2 Sqrt[6]]}, d[f[Sqrt[5 + 2 Sqrt[6]]]] === f[Sqrt[5 + 2 Sqrt[6]]]}, {True, True, True}, TestID -> "C-R8-inexact-and-unknown-heads-untouched"]
VerificationTest[FailureQ /@ {d[Sqrt[3 + 2 Sqrt[2]], "MultiplierCap" -> Infinity], d[Sqrt[3 + 2 Sqrt[2]], "MaxOddIndex" -> 0], d[Sqrt[3 + 2 Sqrt[2]], "MaxCosets" -> -1], d[Sqrt[3 + 2 Sqrt[2]], "DiscriminantBatchCap" -> 1/2]}, {True, True, True, True}, TestID -> "C-R8-new-options-validated"]
VerificationTest[Module[{r = Algebraic`DenestReport[Sqrt[3 + 2 Sqrt[2]], "MaxTraceEntries" -> 0]}, {StringQ[r["CertificateKind"]], r["Certificates"], r["CertificatesTruncated"], r["CompletenessClaim"]}], {True, {}, True, False}, TestID -> "C-R8-report-scopes"]
VerificationTest[session[Block[{Algebraic`Private`powerProposals = Function[{target, best}, best], Algebraic`Private`genericProposals = Function[{target, best}, best], Algebraic`Private`multiplierSearch = Function[{target, best}, best]}, Algebraic`Private`improveNumber[Sqrt[2 + Sqrt[2]]]; Algebraic`Private`$memo[Sqrt[2 + Sqrt[2]]][[{"Result", "Complete"}]]]], <|"Result" -> Sqrt[2 + Sqrt[2]], "Complete" -> True|>, TestID -> "C-R8-failed-search-cached-with-budget"]

(* review-9 *)
VerificationTest[Algebraic`ExactAlgebraicQ[AlgebraicNumber[Root[#^3 - # - 1 &, 1], {1, 2, 3}]], True, TestID -> "C-R9-domain-algebraic-number"]
VerificationTest[Algebraic`EqualityStatus[Sqrt[3 + 2 Sqrt[2]], -1 - Sqrt[2]], "Different", TestID -> "C-R9-equality-wrong-branch"]
VerificationTest[Algebraic`Private`bitSize[1 + I] > 0, True, TestID -> "C-R9-cost-gaussian-bits"]
VerificationTest[FailureQ /@ {Algebraic`DenestCore[Sqrt[2], "MaxTrials" -> -1], Algebraic`DenestReport[Sqrt[2], "MaxCosets" -> 5/2], Algebraic`DenestRadicals[Sqrt[2], 123]}, {True, True, True}, TestID -> "C-R9-option-failures"]
VerificationTest[MissingQ[Algebraic`DenestReport[Sqrt[2], "TimeBudget" -> 0]["InitialCost"]], True, TestID -> "C-R9-zero-budget-no-post-cost"]
VerificationTest[Algebraic`DenestCore[Sqrt[3 + 2 Sqrt[2]], "MaxTrials" -> 0], 1 + Sqrt[2], TestID -> "C-R9-direct-quadratic"]
VerificationTest[Algebraic`DenestCore[Sqrt[3 - 2 Sqrt[2]], "MaxTrials" -> 0], Sqrt[2] - 1, TestID -> "C-R9-quadratic-negative-coefficient"]
VerificationTest[eq[Algebraic`DenestCore[(-7 - 5 Sqrt[2])^(1/3), "MaxTrials" -> 0], (-1)^(1/3) (1 + Sqrt[2])], True, TestID -> "C-R9-principal-negative-cube"]
VerificationTest[eq[Algebraic`DenestCore[(41 + 29 Sqrt[2])^(1/5), "MaxTrials" -> 0], 1 + Sqrt[2]], True, TestID -> "C-R9-fifth-root-Dickson"]
VerificationTest[Module[{r = Algebraic`DenestCore[Sqrt[37 + 4 Sqrt[15] + 6 Sqrt[14] + 2 Sqrt[210]], "MaxTrials" -> 0]}, eq[r, Sqrt[6] + Sqrt[10] + Sqrt[21]] && depth[r] === 1], True, TestID -> "C-R9-character-missing-coset"]
VerificationTest[d[x + Sqrt[3 + 2 Sqrt[2]], "MaxTrials" -> 0], x + 1 + Sqrt[2], TestID -> "C-R9-symbolic-host-congruence"]
VerificationTest[Module[{calls = 0, target = Sqrt[2 + Sqrt[2]], result}, result = Algebraic`DenestCore[target, "Solver" -> Function[e, calls++; 0], "MaxTrials" -> 0]; calls > 0 && result =!= 0 && eq[result, target]], True, TestID -> "C-R9-incorrect-callback-cannot-override"]
VerificationTest[Algebraic`Private`standalone[Block[{Algebraic`Private`recurse = Function[e, e]}, Algebraic`Private`kummerCandidates[(3 + 2 Sqrt[2])^(1/4), 3 + 2 Sqrt[2], 1, 4]], $Failed], Sqrt[1 + Sqrt[2]], TestID -> "C-R9-index-reduction-without-recursive-progress"]
VerificationTest[Algebraic`Private`standalone[Module[{target = (-7 - 5 Sqrt[2])^(1/3), partial = 1 + Sqrt[2], r}, Block[{Algebraic`Private`rootCandidates = Function[{rr, q}, {}], Algebraic`Private`recurse = Function[e, partial], Algebraic`Private`linearRoots = Function[{rr, q}, {}]}, r = Algebraic`Private`powerProposals[target, target]]; eq[r, (-1)^(1/3) partial] && depth[r] === 1], $Failed], True, TestID -> "C-R9-partial-negative-improvement-survives-later-noop"]
VerificationTest[Algebraic`Private`standalone[Module[{calls = 0, target = Sqrt[2 + Sqrt[2]]}, Block[{Algebraic`Private`powerProposals = Function[{t, b}, b], Algebraic`Private`genericProposals = Function[{t, b}, b], Algebraic`Private`multiplierSearch = Function[{t, b}, calls++; b]}, Block[{Algebraic`Private`$recursion = 1}, Algebraic`Private`improveNumber[target]]; Algebraic`Private`improveNumber[target]; Algebraic`Private`improveNumber[target]; calls]], $Failed], 2, TestID -> "C-R9-weak-negative-result-not-reused-by-stronger-search"]
VerificationTest[Algebraic`Private`standalone[Module[{target = Sqrt[2 + Sqrt[2]]}, AssociateTo[Algebraic`Private`$inProgress, target -> True]; Algebraic`Private`improveNumber[target] === target], $Failed], True, TestID -> "C-R9-in-progress-cycle-cut"]
VerificationTest[Algebraic`Private`standalone[Block[{Algebraic`Private`$cfg = Append[Algebraic`Private`$cfg, "NumericPrefilter" -> True], Algebraic`Private`numericallyDifferentQ = Function[e, True]}, Algebraic`Private`certify[Sqrt[3 + 2 Sqrt[2]], 1 + Sqrt[2]]], $Failed], "Equal", TestID -> "C-R9-numeric-diagnostic-never-suppresses-exact-proof"]
VerificationTest[Module[{rep = Algebraic`DenestReport[Sqrt[3 + 2 Sqrt[2]], "MaxTrials" -> 0]}, AllTrue[rep["Certificates"], Algebraic`CertifiedEqualQ[#["Before"], #["After"]] && StringQ[#["EqualityMethod"]] &]], True, TestID -> "C-R9-every-reported-proposal-recertifies"]

(* unified-C controls *)
VerificationTest[improves[Sqrt[118 + 2 Sqrt[210] + 14 Sqrt[55] + 2 Sqrt[462]], Sqrt[6] + Sqrt[35] + Sqrt[77], "MaxTrials" -> 0], True, TestID -> "C-U-coset-1"]
VerificationTest[improves[Sqrt[60 + 10 Sqrt[6] + 10 Sqrt[14] + 10 Sqrt[21]], Sqrt[10] + Sqrt[15] + Sqrt[35], "MaxTrials" -> 0], True, TestID -> "C-U-coset-2"]
VerificationTest[improves[Sqrt[142 + 28 Sqrt[15] + 20 Sqrt[21] + 12 Sqrt[35]], Sqrt[30] + Sqrt[42] + Sqrt[70], "MaxTrials" -> 0], True, TestID -> "C-U-coset-3"]
VerificationTest[improves[Sqrt[(5 + Sqrt[6] + Sqrt[10] + Sqrt[15])/2], (Sqrt[2] + Sqrt[3] + Sqrt[5])/2, "MaxTrials" -> 0], True, TestID -> "C-U-coset-rational-coefficients"]
VerificationTest[improves[Sqrt[280 + 16 Sqrt[6] - 48 Sqrt[10] - 32 Sqrt[15]], -4 - 2 Sqrt[6] + 4 Sqrt[15], "MaxTrials" -> 0], True, TestID -> "C-U-coset-negative-coefficients"]
VerificationTest[Module[{r = Algebraic`DenestReport[(3 + 2 Sqrt[2])^(1/6), "MaxRecursion" -> 0]}, eq[r["Result"], (1 + Sqrt[2])^(1/3)] && MemberQ[r["Limits"], "Patience"] && r["Statistics"]["Trials"] <= r["Options"]["Patience"] + 1], True, TestID -> "C-U-patience-counts-from-earlier-improvement"]
VerificationTest[Module[{r = Algebraic`DenestReport[Sqrt[54 - 4 Sqrt[33] + 4 Sqrt[39] - 4 Sqrt[143]], "MaxTrials" -> 0]}, eq[r["Result"], Sqrt[6] - Sqrt[22] + Sqrt[26]] && r["Statistics"]["CosetSystems"] === 0 && r["Statistics"]["FastPathAccepted"] === 1], True, TestID -> "C-U-coset-relation-stage-suffices"]
VerificationTest[Module[{e = (3 + 2 Sqrt[2])^(1/4), r}, r = d[e]; eq[r, Sqrt[1 + Sqrt[2]]] && Algebraic`Private`cheaperQ[r, e]], True, TestID -> "C-U-quartic-index-reduction"]
VerificationTest[Module[{e = (3 + 2 Sqrt[2])^(1/6), r}, r = d[e, "MaxRecursion" -> 0]; eq[r, (1 + Sqrt[2])^(1/3)] && Algebraic`Private`cheaperQ[r, e]], True, TestID -> "C-U-sixth-index-reduction-no-recursion"]
VerificationTest[Module[{e = Expand[(1 + Sqrt[5])^11]^(1/11)}, {session[Algebraic`Private`rootCandidates[First[e], 11]], eq[d[e, "MaxTrials" -> 0], 1 + Sqrt[5]], memberEq[session[Block[{Algebraic`Private`$cfg = Append[Algebraic`Private`$cfg, "MaxOddIndex" -> 11]}, Algebraic`Private`rootCandidates[First[e], 11]]], 1 + Sqrt[5]]}], {{}, True, True}, TestID -> "C-U-max-odd-index"]
VerificationTest[d[Sqrt[2], "NumericPrefilter" -> True] === Sqrt[2] && improves[Sqrt[5 + 2 Sqrt[6]], Sqrt[2] + Sqrt[3], "NumericPrefilter" -> True], True, TestID -> "C-U-prefilter-is-optional-pruning"]
VerificationTest[Module[{r = Algebraic`DenestReport[Sqrt[1 + Sqrt[2]], "MaxTrials" -> 2, "NumericPrefilter" -> False]["Statistics"]}, r["NumericRejections"] === 0 && r["Certificates"] === r["CertificatesEqual"] + r["CertificatesDifferent"] + r["CertificatesUnknown"]], True, TestID -> "C-U-certificate-counters-exact-only"]
VerificationTest[d[Root[#^5 + # - Pi &, 1] + Sqrt[5 + 2 Sqrt[6]]], Root[#^5 + # - Pi &, 1] + Sqrt[2] + Sqrt[3], TestID -> "C-U-unsupported-root-is-an-opaque-host"]
VerificationTest[Algebraic`RadicalCost[Sqrt[2] + Root[#^5 + # - 1 &, 1]] === {1, 1, 1, LeafCount[Sqrt[2] + Root[#^5 + # - 1 &, 1]], Algebraic`Private`bitSize[Sqrt[2] + Root[#^5 + # - 1 &, 1]]}, True, TestID -> "C-U-cost-recursive-counters"]
VerificationTest[Module[{r = Algebraic`DenestReport[Sqrt[5 + 2 Sqrt[6]] + N[Pi]]}, {r["Status"], r["Limits"], r["InitialCost"]}], {"Unchanged", {"InexactInput"}, Missing["NotComputed"]}, TestID -> "C-U-inexact-input-classified-inside-region"]
VerificationTest[Module[{r = Algebraic`DenestReport[Sqrt[1 + Sqrt[2]], "MaxTrials" -> 0]}, {r["ResultChanged"], r["Status"], r["InitialCost"] === r["FinalCost"]}], {False, "Unchanged", True}, TestID -> "C-U-unchanged-report"]
VerificationTest[improves[Sqrt[-(16 - 2 Sqrt[29] + 2 Sqrt[55 - 10 Sqrt[29]])], I (Sqrt[5] + Sqrt[11 - 2 Sqrt[29]])], True, TestID -> "C-U-negative-radicand-partial-denesting"]

End[];
