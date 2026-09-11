(* The basic Mathics3 check: one light case per operation, a few minutes.

       cd algebraic/Tests
       python -X utf8 run_mathics.py MathicsSmoke.wlt

   The full suite (Algebraic.wlt, hours under Mathics) is not part of routine
   verification; the Wolfram kernel runs it in two minutes.  In the Wolfram
   kernel this file runs through TestReport["MathicsSmoke.wlt"] and passes
   as well. *)

VerificationTest[StringQ[AlgebraicKernelReport[]["Kernel"]] && AlgebraicKernelReport[]["Operations"]["AlgebraicDecompose"],
  True, TestID -> "smoke: kernel report"];

VerificationTest[AlgebraicDecompose[(x^2 + Sqrt[2] x)^3 + x^2 + Sqrt[2] x, x], {x + x^3, Sqrt[2] x + x^2},
  TestID -> "smoke: functional decomposition with an algebraic coefficient"];
VerificationTest[AlgebraicDecompose[(x^2 + Sqrt[2] x)^3 + x^2 + Sqrt[2] x], {x + x^3, Sqrt[2] x + x^2},
  TestID -> "smoke: inferred variable"];
VerificationTest[MatchQ[AlgebraicDecompose[x^4 + Pi x, x], _Failure], True,
  TestID -> "smoke: a transcendental coefficient is refused"];
VerificationTest[AlgebraicDecompositions[x^12, x, "MaxDecompositions" -> 2]["Limit"], 2,
  TestID -> "smoke: enumeration cap"];

VerificationTest[RootDecompositionLowerBound[Sqrt[2] + Sqrt[3]], 2, TestID -> "smoke: lower bound"];
VerificationTest[RootSumDecomposition[Sqrt[2] + Sqrt[3]]["MaximumDegree"], 2,
  TestID -> "smoke: sum decomposition through the Galois engine"];

VerificationTest[RootToRadicals[Root[#^4 - 10 #^2 + 1 &, 4]], Sqrt[5 + 2 Sqrt[6]],
  TestID -> "smoke: structural radicals"];
VerificationTest[RootSolvableQ[Root[#^5 - # - 1 &, 1]], False, TestID -> "smoke: a non-solvable quintic"];

VerificationTest[DenestRadicals[Sqrt[5 + 2 Sqrt[6]]], Sqrt[2] + Sqrt[3], TestID -> "smoke: denesting"];
VerificationTest[DenestRadicals[(239 + 169 Sqrt[2])^(1/7)], 1 + Sqrt[2], TestID -> "smoke: odd-index denesting"];
VerificationTest[EqualityStatus[Sqrt[2] + Sqrt[3], Sqrt[5 + 2 Sqrt[6]]], "Equal", TestID -> "smoke: exact equality"];
VerificationTest[RadicalDepth[Sqrt[1 + Sqrt[2]]], 2, TestID -> "smoke: radical grammar"];
