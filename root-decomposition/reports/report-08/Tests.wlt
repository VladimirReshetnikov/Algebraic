(* Run with TestReport["Tests.wlt"] from Mathematica. These are regression
   specifications, not a claim that a Wolfram kernel ran in the authoring session. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
Clear[x, z, u, v];
f = x^3 + x + 1; g = x^3 - x + 1;
pTimes = x^9 + 2 x^7 - 3 x^6 + x^5 - x^4 + 3 x^3 - x - 1;
pSum = x^9 + 6 x^6 + 3 x^5 - 15 x^3 + 24 x^2 - 4 x + 8;
a = Root[1 + # + #^3 &, 1]; b = Root[1 - # + #^3 &, 1];
rTimes = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
rSum = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];

VerificationTest[AlgebraicDegree[7/11], 1, TestID -> "rational-degree"]
VerificationTest[AlgebraicDegree /@ {rTimes, rSum}, {9, 9}, TestID -> "target-degrees"]
VerificationTest[DegreeLowerBound /@ {rTimes, rSum}, {3, 3}, TestID -> "global-lower-bounds"]
VerificationTest[RootReduce[rTimes - a b], 0, TestID -> "product-exact"]
VerificationTest[RootReduce[rSum - a - b], 0, TestID -> "sum-exact"]
VerificationTest[And @@ (IrreduciblePolynomialQ /@ {pTimes, pSum}), True, TestID -> "irreducible-nonics"]
VerificationTest[ComposedPolynomial[f, g, x, z, "Product"], pTimes /. x -> z, TestID -> "product-resultant"]
VerificationTest[ComposedPolynomial[f, g, x, z, "Sum"], pSum /. x -> z, TestID -> "sum-resultant"]
VerificationTest[RootPairFromPolynomials[rTimes, {f, g}, x, "Product"]["GloballyOptimal"], True, TestID -> "product-optimal"]
VerificationTest[RootPairFromPolynomials[rSum, {f, g}, x, "Sum"]["GloballyOptimal"], True, TestID -> "sum-optimal"]
VerificationTest[BoundedPairDecompose[rTimes, "Product", 3, 1]["MaximumDegree"], 3, TestID -> "automatic-product-search"]
VerificationTest[BoundedPairDecompose[rSum, "Sum", 3, 1]["MaximumDegree"], 3, TestID -> "automatic-sum-search"]
VerificationTest[BoundedPairDecompose[rSum, "Sum", 2, 1]["AppliesToAnyNumberOfComponents"], True, TestID -> "quadratics-impossible"]
VerificationTest[ComposedPolynomial[x^2 - 2, x^2 - 2, x, z, "Product"], (z^2 - 4)^2 // Expand, TestID -> "repeated-resultant-factors"]
VerificationTest[Expand[ComposedPolynomial[2 x^2 - 1, 3 x^2 - 1, x, z, "Product"] - (z^2 - 1/6)^2], 0, TestID -> "nonmonic-input"]
VerificationTest[ComposedPolynomial[x, x^2 - 2, x, z, "Product"], z^2, TestID -> "zero-factor"]
VerificationTest[MatchQ[AlgebraicDegree[0.25], _Failure], True, TestID -> "inexact-input-rejected"]
VerificationTest[MatchQ[RootPairFromPolynomials[rSum, {x^3 + Sqrt[2], g}, x, "Sum"], _Failure], True, TestID -> "nonrational-coefficients-rejected"]
VerificationTest[SumOverSubfields[Sqrt[2] + Sqrt[3], Sqrt[2] + Sqrt[3], {Sqrt[2], Sqrt[3]}]["MaximumDegree"], 2, TestID -> "supplied-subfields"]
VerificationTest[MissingQ[SumOverSubfields[Sqrt[2] + Sqrt[3], Sqrt[2] + Sqrt[3], {Sqrt[2]}]], True, TestID -> "restricted-span-not-global"]
VerificationTest[GlobalSumDecompose[Sqrt[2] + Sqrt[3]]["ProvenMinimum"], 2, TestID -> "global-biquadratic-sum"]
VerificationTest[GlobalSumDecompose[Sqrt[2 + Sqrt[2]]]["ProvenMinimum"], 4, TestID -> "global-cyclic-quartic"]
VerificationTest[GlobalSumDecompose[Sqrt[2] + Sqrt[3], "MaxFieldDegree" -> 2][[1]], "FieldDegreeLimit", TestID -> "resource-limit-is-not-impossibility"]

VerificationTest[MatchQ[ComposedPolynomial[x^2 - 1.2, x^2 - 2, x, z, "Sum"], _Failure], True, TestID -> "inexact-polynomial-rejected"]
VerificationTest[MatchQ[SumOverSubfields[Sqrt[2], Sqrt[2], {Sqrt[3]}], _Failure], True, TestID -> "nested-subfield-failure-propagates"]
VerificationTest[GlobalSumDecompose[Sqrt[2] + Sqrt[3], "MaxSubgroups" -> 1][[1]], "SubgroupLimit", TestID -> "nested-subgroup-limit-propagates"]
VerificationTest[BoundedDecompose[Sqrt[2], "Sum", 1, 1, 3]["AppliesToAnyNumberOfComponents"], True, TestID -> "multicomponent-degree-obstruction"]
