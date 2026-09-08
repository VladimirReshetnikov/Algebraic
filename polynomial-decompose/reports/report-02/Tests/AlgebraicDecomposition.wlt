(* Run with TestReport[".../Tests/AlgebraicDecomposition.wlt"].
   These tests are supplied for a Wolfram kernel; they were not executed in
   the authoring environment. See validation/VALIDATION.md. *)
Get[FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]],
  "Kernel", "AlgebraicDecomposition.wl"}]];
Clear[x, t, adAlpha, adP, adExpected, adNested, adNestedExpected,
 adZero, adSameChain, adRootP, adRootG, adRootH, adT6];
adZero[e_] := And @@ (SameQ[#, 0] & /@
  RootReduce[CoefficientList[Expand[e], x]]);
adSameChain[a_, b_] := ListQ[a] && ListQ[b] && Length[a] == Length[b] &&
  And @@ MapThread[adZero[#1 - #2] &, {a, b}];
adP = 3 + 3 Sqrt[2] + (14 + 4 Sqrt[2]) x +
 (12 + 26 Sqrt[2]) x^2 + (56 + 8 Sqrt[2]) x^3 +
 (8 + 48 Sqrt[2]) x^4 + 48 x^5 + 16 Sqrt[2] x^6;
adExpected = {3 + 3 Sqrt[2] + (8 + 14 Sqrt[2]) x +
 (8 + 24 Sqrt[2]) x^2 + 16 Sqrt[2] x^3, x^2 + x/Sqrt[2]};
adNested = Expand[adP /. x -> x^4 - x + 1];
adNestedExpected = {141 + 105 Sqrt[2] + (168 + 142 Sqrt[2]) x +
 (56 + 72 Sqrt[2]) x^2 + 16 Sqrt[2] x^3,
 x^2 + (2 + 1/Sqrt[2]) x, x^4 - x};
adAlpha = Root[#^5 - # - 1 &, 1];
adRootG = (1 + adAlpha) x^2 + adAlpha^2 x + Sqrt[3];
adRootH = x^3 + adAlpha x;
adRootP = Expand[adRootG /. x -> adRootH];
adT6 = ChebyshevT[6, x];

VerificationTest[adSameChain[AlgebraicDecompose[adP, x], adExpected], True,
 TestID -> "user-sextic-normalized"]
VerificationTest[adZero[ComposeAlgebraicPolynomials[adExpected, x] - adP], True,
 TestID -> "user-sextic-independent-coefficient-check"]
VerificationTest[VerifyAlgebraicDecomposition[adP, adExpected, x]["ValidCompleteDecomposition"], True,
 TestID -> "user-sextic-completeness"]
VerificationTest[adSameChain[AlgebraicDecompose[adNested, x], adNestedExpected], True,
 TestID -> "user-degree24-normalized"]
VerificationTest[VerifyAlgebraicDecomposition[adNested, adNestedExpected, x]["Degrees"], {3, 2, 4},
 TestID -> "user-degree24-degrees"]
VerificationTest[adSameChain[AlgebraicDecompose[adRootP, x], {adRootG, adRootH}], True,
 TestID -> "quintic-Root-and-independent-radical"]
VerificationTest[VerifyAlgebraicDecomposition[adRootP, AlgebraicDecompose[adRootP, x], x]["ValidCompleteDecomposition"], True,
 TestID -> "quintic-Root-recomposition-and-primality"]
VerificationTest[adSameChain[AlgebraicDecompose[adP + (adAlpha^5-adAlpha-1) x^9, x], adExpected], True,
 TestID -> "algebraically-zero-leading-coefficient"]
VerificationTest[adSameChain[AlgebraicDecompose[Expand[(x^2+I x)^3 + (x^2+I x)], x], {x^3+x, x^2+I x}], True,
 TestID -> "complex-algebraic-coefficients"]
VerificationTest[adSameChain[AlgebraicDecompose[Expand[(x^2+2^(1/3) x)^2+1], x], {x^2+1, x^2+2^(1/3) x}], True,
 TestID -> "real-cubic-radical"]
VerificationTest[adSameChain[AlgebraicDecompose[Expand[(x^2+(Sqrt[2]+Sqrt[3]) x)^2+1], x], {x^2+1, x^2+(Sqrt[2]+Sqrt[3]) x}], True,
 TestID -> "biquadratic-compositum"]
VerificationTest[adSameChain[AlgebraicDecompose[Expand[(x^2+AlgebraicNumber[Sqrt[2], {0,1}] x)^2+1], x], {x^2+1, x^2+Sqrt[2] x}], True,
 TestID -> "AlgebraicNumber-input"]
VerificationTest[adSameChain[AlgebraicDecompose[(x+1)^6, x], {(x+1)^3, x^2+2 x}], True,
 TestID -> "single-distinct-derivative-factor-regression"]
VerificationTest[Length[AlgebraicRightDecompositions[(x+1)^6, x]], 2,
 TestID -> "shifted-power-all-pairs"]
VerificationTest[AlgebraicDecompose[x^12, x], {x^3, x^2, x^2},
 TestID -> "power-exponents-multiply-not-add"]
VerificationTest[Sort[AlgebraicDecompositions[x^6, x]], Sort[{{x^3,x^2},{x^2,x^3}}],
 TestID -> "two-complete-power-decompositions"]
VerificationTest[Length[AlgebraicDecompositions[x^12, x]], 3,
 TestID -> "three-complete-power-decompositions"]
VerificationTest[Length[AlgebraicDecompositions[ChebyshevT[12, x], x]], 3,
 TestID -> "three-complete-Chebyshev-decompositions"]
VerificationTest[Length[AlgebraicDecompositions[adT6, x]], 2,
 TestID -> "Ritt-collision-degree6"]
VerificationTest[And @@ (VerifyAlgebraicDecomposition[adT6,#,x]["ValidCompleteDecomposition"] & /@ AlgebraicDecompositions[adT6,x]), True,
 TestID -> "Ritt-collision-all-identities"]
VerificationTest[AlgebraicDecompositions[x^12,x,"MaxDecompositions"->Infinity], AlgebraicDecompositions[x^12,x],
 TestID -> "unlimited-enumeration"]
VerificationTest[MatchQ[AlgebraicDecompositions[x^12,x,"MaxDecompositions"->1], Failure["EnumerationLimit",_Association]], True,
 TestID -> "enumeration-cap-is-a-failure"]
VerificationTest[AlgebraicDecompositions[x^12,x,"MaxDecompositions"->1][[2]]["Complete"], False,
 TestID -> "cap-does-not-claim-completeness"]
VerificationTest[Length[AlgebraicDecompositions[x^12,x,"MaxDecompositions"->1][[2]]["PartialDecompositions"]], 1,
 TestID -> "cap-partial-result-count"]
VerificationTest[MatchQ[AlgebraicDecompositions[x^12,x,"MaxDecompositions"->0], Failure["InvalidLimit",_Association]], True,
 TestID -> "reject-invalid-cap"]
VerificationTest[AlgebraicRightDecompositions[x^6+x,x], {},
 TestID -> "composite-degree-absolutely-indecomposable"]
VerificationTest[AlgebraicDecompositionAttempt[x^6+x,x,2]["Residual"], x,
 TestID -> "negative-certificate-residual"]
VerificationTest[AlgebraicDecompositionAttempt[x^6+x,x,2]["NonzeroWitness"], <|"Exponent"->1,"Coefficient"->1|>,
 TestID -> "negative-certificate-witness"]
VerificationTest[AlgebraicRightDecompositions[x^6+x/10^100,x], {},
 TestID -> "tiny-exact-nonzero-residual"]
VerificationTest[AlgebraicDecompose[x^7+Sqrt[2] x+1,x], {x^7+Sqrt[2] x+1},
 TestID -> "prime-degree"]
VerificationTest[AlgebraicDecompose[0,x], {0}, TestID -> "zero"]
VerificationTest[AlgebraicDecompositions[0,x], {{0}}, TestID -> "zero-all-convention"]
VerificationTest[AlgebraicDecompose[Sqrt[2],x], {Sqrt[2]}, TestID -> "constant"]
VerificationTest[AlgebraicDecompose[2 x+Sqrt[3],x], {2 x+Sqrt[3]}, TestID -> "linear"]
VerificationTest[AlgebraicRightDecompositions[3,x], {}, TestID -> "constant-no-proper-pairs"]
VerificationTest[AlgebraicDecompose[x^4+1,x], {x^2+1,x^2}, TestID -> "multiplicatively-irreducible-but-composite"]
VerificationTest[AlgebraicDecompose[x^4+x,x], {x^4+x}, TestID -> "multiplicatively-reducible-but-indecomposable"]
VerificationTest[MatchQ[AlgebraicDecompose[x^4+1.0 x,x],Failure["InexactInput",_Association]], True,
 TestID -> "reject-machine-real"]
VerificationTest[MatchQ[AlgebraicDecompose[x^4+N[Sqrt[2],60] x,x],Failure["InexactInput",_Association]], True,
 TestID -> "reject-arbitrary-precision-real"]
VerificationTest[MatchQ[AlgebraicDecompose[x^4+(1.0+I) x,x],Failure["InexactInput",_Association]], True,
 TestID -> "reject-inexact-complex-real-part"]
VerificationTest[MatchQ[AlgebraicDecompose[x^4+(1+N[Sqrt[2],60] I) x,x],Failure["InexactInput",_Association]], True,
 TestID -> "reject-inexact-complex-imaginary-part"]
VerificationTest[MatchQ[AlgebraicDecompose[x^4+Pi x,x],Failure["NonAlgebraicCoefficient",_Association]], True,
 TestID -> "reject-transcendental-coefficient"]
VerificationTest[MatchQ[AlgebraicDecompose[x^4+t x,x],Failure["NonAlgebraicCoefficient",_Association]], True,
 TestID -> "reject-unassigned-parameter"]
VerificationTest[MatchQ[AlgebraicDecompose[1/(x+1),x],Failure["NotPolynomial",_Association]], True,
 TestID -> "reject-rational-function"]
VerificationTest[MatchQ[AlgebraicDecompositionAttempt[x^6,x,4],Failure["InvalidRightDegree",_Association]], True,
 TestID -> "reject-nondivisor"]
VerificationTest[MatchQ[AlgebraicDecompositionAttempt[x^6,x,0],Failure["InvalidRightDegree",_Association]], True,
 TestID -> "reject-zero-degree"]
VerificationTest[MatchQ[ComposeAlgebraicPolynomials[{},x],Failure["EmptyChain",_Association]], True,
 TestID -> "reject-empty-composition"]
VerificationTest[VerifyAlgebraicDecomposition[x^6,{x^2,x^2},x]["IdentityVerified"], False,
 TestID -> "reject-false-identity"]
VerificationTest[VerifyAlgebraicDecomposition[x^6,{x^6},x]["ValidCompleteDecomposition"], False,
 TestID -> "correct-identity-is-not-completeness"]
VerificationTest[VerifyAlgebraicDecomposition[x^4,{4 x^2,x^2/2},x]["Normalized"], False,
 TestID -> "nonmonic-inner-detected"]
VerificationTest[VerifyAlgebraicDecomposition[x^4,{4 x^2,x^2/2},x]["ValidCompleteDecomposition"], True,
 TestID -> "unnormalized-complete-identity-accepted-by-verifier"]
VerificationTest[VerifyAlgebraicDecomposition[0,{0},x]["ValidConstantOrLinearConvention"], True,
 TestID -> "constant-convention-distinguished"]

VerificationTest[
 BlockRandom[SeedRandom[206618]; And @@ Flatten[Table[
   Module[{g,h,p,chain},
    g = x^m + Sum[RandomInteger[{-3,3}] x^j,{j,0,m-1}];
    h = x^d + (Sqrt[2]+RandomInteger[{-2,2}]) x + RandomInteger[{-2,2}];
    p = Expand[g /. x->h]; chain = AlgebraicDecompose[p,x];
    VerifyAlgebraicDecomposition[p,chain,x]["ValidCompleteDecomposition"]],
   {m,2,4},{d,2,5}]]], True, TestID -> "12-generated-radical-composites"]
