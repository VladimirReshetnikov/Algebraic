(* Native Wolfram Language regression tests. Not executed during preparation. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
Clear[x, u, v, w, z];
a = Root[1 + # + #^3 &, 1];
b = Root[1 - # + #^3 &, 1];
p = x^3+x+1; q = x^3-x+1;
pm = x^9+2 x^7-3 x^6+x^5-x^4+3 x^3-x-1;
ps = x^9+6 x^6+3 x^5-15 x^3+24 x^2-4 x+8;
m = RootReduce[a b]; s = RootReduce[a+b];

VerificationTest[AlgebraicDegree[a], 3, TestID -> "cubic-degree"]
VerificationTest[{AlgebraicDegree[m], AlgebraicDegree[s]}, {9,9}, TestID -> "input-degrees"]
VerificationTest[DegreeLowerBound[m], 3, TestID -> "prime-lower-bound"]
VerificationTest[ComposedRootPolynomial[p,q,x,"Product"], pm, TestID -> "product-resultant"]
VerificationTest[ComposedRootPolynomial[p,q,x,"Sum"], ps, TestID -> "sum-resultant"]
VerificationTest[Expand[ComposedRootPolynomial[x^2-2,x^2-3,x,"Product"]-(x^2-6)^2], 0,
  TestID -> "product-collision"]
VerificationTest[Expand[ComposedRootPolynomial[x^2-2,x^2-8,x,"Sum"]-(x^2-18)(x^2-2)], 0,
  TestID -> "shared-field-sum"]
VerificationTest[Expand[ComposedRootPolynomial[x^3-2,x^3+2,x,"Sum"]-x^3(x^6+108)], 0,
  TestID -> "degree-not-divisor-of-product"]
VerificationTest[SelectRootPair[m,p,q,x,"Product"]["MaximumDegree"], 3, TestID -> "product-select"]
VerificationTest[SelectRootPair[s,p,q,x,"Sum"]["Status"], "GloballyOptimal", TestID -> "sum-optimality"]
VerificationTest[FailureQ[SelectRootPair[m,x^2-2,x^2-3,x,"Product"]], True,
  TestID -> "reject-no-pair"]
VerificationTest[FailureQ[VerifyRootDecomposition[m,{a,b},"Sum"]], True,
  TestID -> "reject-wrong-operation"]
VerificationTest[FailureQ[AlgebraicDegree[1.25]], True, TestID -> "reject-machine-real"]
VerificationTest[FailureQ[PolynomialRootList[x^2-Sqrt[2],x]], True,
  TestID -> "reject-algebraic-coefficients"]
VerificationTest[MinimumSumDecomposition[a]["Status"], "GloballyOptimal",
  TestID -> "prime-degree-shortcut"]
VerificationTest[MinimumSumDecomposition[3/7]["MaximumDegree"], 1,
  TestID -> "rational-shortcut"]
VerificationTest[FailureQ[MinimumSumDecomposition[s,"MaxConjugates"->4]], True,
  TestID -> "explicit-resource-guard"]
VerificationTest[VerifyRootDecomposition[0,{0,0},"Sum"]["Degrees"], {1},
  TestID -> "remove-zero-summands"]
VerificationTest[VerifyRootDecomposition[1,{1,1},"Product"]["Degrees"], {1},
  TestID -> "remove-unit-factors"]
VerificationTest[SplitOverFields[(1+Sqrt[2])(2+Sqrt[3]),Sqrt[2],Sqrt[3],"Product"]["Verified"], True,
  TestID -> "fixed-field-product-positive"]
VerificationTest[FailureQ[SplitOverFields[1+Sqrt[2]+Sqrt[3],Sqrt[2],Sqrt[3],"Product"]], True,
  TestID -> "fixed-field-product-negative"]
VerificationTest[SplitOverFields[1+Sqrt[2]+Sqrt[3],Sqrt[2],Sqrt[3],"Sum"]["Verified"], True,
  TestID -> "fixed-field-sum-positive"]
VerificationTest[FailureQ[SplitOverFields[(1+Sqrt[2])(2+Sqrt[3]),Sqrt[2],Sqrt[3],"Sum"]], True,
  TestID -> "fixed-field-sum-negative"]
VerificationTest[Length[SolveRootTemplate[s,x^3+u x+v,x^3+w x+z,{u,v,w,z},x,"Sum"]["Candidates"]]>0,
  True, TestID -> "sum-template-discovers-cubics"]
VerificationTest[Length[SolveRootTemplate[m,x^3+u x+v,x^3+w x+1,{u,v,w},x,"Product"]["Candidates"]]>0,
  True, TestID -> "product-template-discovers-cubics"]
VerificationTest[SearchProductResidual[m,3,{p,q},x,2]["MaximumDegree"], 3,
  TestID -> "residual-product-search"]
VerificationTest[SearchRootCatalog[m,{p,q},x,"Product"]["Status"], "GloballyOptimal",
  TestID -> "finite-catalog-search"]

VerificationTest[Length[PolynomialRootList[(x^2-2)^2,x]], 2,
  TestID -> "square-free-root-enumeration"]
