(* Wolfram Language tests. Run:
   TestReport["tests.wlt"]
   They have NOT been executed in a Wolfram kernel in this environment. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
Clear[x, a, b, productTarget, sumTarget, pM, pA];
a = Root[1 + # + #^3 &, 1]; b = Root[1 - # + #^3 &, 1];
pM = x^9 + 2 x^7 - 3 x^6 + x^5 - x^4 + 3 x^3 - x - 1;
pA = x^9 + 6 x^6 + 3 x^5 - 15 x^3 + 24 x^2 - 4 x + 8;
productTarget = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
sumTarget = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];

VerificationTest[RootDegree[productTarget], 9, TestID -> "product-degree"]
VerificationTest[RootDegree[sumTarget], 9, TestID -> "sum-degree"]
VerificationTest[RootReduce[productTarget - a b], 0, TestID -> "product-branch"]
VerificationTest[RootReduce[sumTarget - a - b], 0, TestID -> "sum-branch"]
VerificationTest[ProductComposedPolynomial[x^3+x+1, x^3-x+1, x], pM,
 TestID -> "product-resultant"]
VerificationTest[SumComposedPolynomial[x^3+x+1, x^3-x+1, x], pA,
 TestID -> "sum-resultant"]
VerificationTest[VerifyRootDecomposition[productTarget, {a,b}, Times]["GloballyOptimalByPrimeBound"],
 True, TestID -> "global-product-optimality"]
VerificationTest[VerifyRootDecomposition[sumTarget, {a,b}, Plus]["GloballyOptimalByPrimeBound"],
 True, TestID -> "global-sum-optimality"]
VerificationTest[RootPairFromPolynomial[productTarget, x^3+x+1, x, Times, 3]["LargestDegree"],
 3, TestID -> "recover-product"]
VerificationTest[RootPairFromPolynomial[sumTarget, x^3+x+1, x, Plus, 3]["LargestDegree"],
 3, TestID -> "recover-sum"]
VerificationTest[FindRootPair[productTarget, Times, 3, 1, "TimeLimit" -> 300]["Verified"],
 True, TestID -> "bounded-product-search"]
VerificationTest[FindRootPair[sumTarget, Plus, 3, 1, "TimeLimit" -> 300]["Verified"],
 True, TestID -> "bounded-sum-search"]
VerificationTest[FailureQ[RootDegree[0.1]], True, TestID -> "reject-inexact"]
VerificationTest[RootDegree[3/7], 1, TestID -> "rational"]
VerificationTest[RootDegree[0], 1, TestID -> "zero"]
VerificationTest[VerifyRootDecomposition[sumTarget, {a,b}, Times]["Verified"],
 False, TestID -> "reject-wrong-operation"]
VerificationTest[SumComposedPolynomial[2 x-1, 3 x-1, x], x-5/6,
 TestID -> "nonmonic-sum"]
VerificationTest[ProductComposedPolynomial[2 x-1, 3 x-1, x], x-1/6,
 TestID -> "nonmonic-product"]
VerificationTest[ProductComposedPolynomial[x, x^2-2, x], x^2,
 TestID -> "zero-root-homogenization"]
VerificationTest[DictionaryRootDecomposition[Sqrt[2]+Sqrt[3], {Sqrt[2]}, Plus, 2, 2]["Verified"],
 True, TestID -> "single-atom-dictionary"]
VerificationTest[DictionaryRootDecomposition[
 RootReduce[Sqrt[2]+Sqrt[3]+Sqrt[5]], {Sqrt[2],Sqrt[3],Sqrt[5]}, Plus, 2, 3]["LargestDegree"],
 2, TestID -> "three-summands"]

(* Small complete normal-field tests. *)
model4 = BuildNormalFieldModel[Sqrt[2]+Sqrt[3], "TimeLimit" -> 300];
VerificationTest[model4["Dimension"], 4, TestID -> "normal-field-dimension"]
VerificationTest[Sort[#["Degree"]& /@ model4["Subfields"]], {1,2,2,2,4},
 TestID -> "complete-biquadratic-lattice"]
VerificationTest[CompleteSumDecomposition[Sqrt[2]+Sqrt[3], model4]["MinimumLargestDegree"],
 2, TestID -> "complete-additive-minimum"]
VerificationTest[CompleteProductPairDecomposition[Sqrt[2]+Sqrt[3], model4]["MinimumLargestDegreeForTwoFactors"],
 2, TestID -> "complete-binary-product-minimum"]

(* Slower negative/control example: no degree <= 3 decomposition. *)
model8 = BuildNormalFieldModel[2^(1/4), "TimeLimit" -> 300];
VerificationTest[CompleteSumDecomposition[2^(1/4), model8]["MinimumLargestDegree"],
 4, TestID -> "quartic-radical-additive-obstruction"]
VerificationTest[CompleteProductPairDecomposition[2^(1/4), model8]["MinimumLargestDegreeForTwoFactors"],
 4, TestID -> "quartic-radical-binary-product-obstruction"]
