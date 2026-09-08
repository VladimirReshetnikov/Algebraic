(* Native Wolfram Language regression suite. NOT executed in the delivery
   environment: the remote Wolfram kernel endpoint returned HTTP 404.
   Run TestReport["/path/to/Tests/AlgebraicDecomposition.wlt"] in a fresh kernel. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "Kernel",
  "AlgebraicDecomposition.wl"}]];
ClearAll[x, a, samePoly, sameChain, degrees, goodChain, original];
samePoly[u_, v_] := AllTrue[
  RootReduce /@ CoefficientList[Expand[u - v], x], # === 0 &];
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
    d = RandomChoice[{2, 3, 4}]; m = RandomChoice[{2, 3}];
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
