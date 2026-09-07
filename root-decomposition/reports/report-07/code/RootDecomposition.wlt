(* Native Wolfram Language tests, supplied but NOT executed in this environment.
   TestReport["/path/to/code/RootDecomposition.wlt"] *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];

VerificationTest[AlgebraicDegree[3/7], 1, TestID -> "rational-degree"]
VerificationTest[AlgebraicDegree[Sqrt[2]], 2, TestID -> "quadratic-degree"]
VerificationTest[FailureQ[AlgebraicDegree[1.5]], True, TestID -> "reject-machine-real"]
VerificationTest[PrimeDegreeBound[Root[-2 + #^9 &, 1]], 3,
  TestID -> "prime-degree-bound"]
VerificationTest[Sort[PolynomialRoots[2 x - 1, x]], {1/2},
  TestID -> "nonmonic-polynomial"]
VerificationTest[FailureQ[PolynomialRoots[0,x]], True,
  TestID -> "zero-polynomial-is-not-a-root-list"]
VerificationTest[FailureQ[RootDictionary[3,1,"MaxPolynomials"->1]], True,
  TestID -> "tagged-exit-from-nested-loops"]

VerificationTest[
  SumPolynomial[x^3+x+1,x^3-x+1,x,z],
  z^9+6 z^6+3 z^5-15 z^3+24 z^2-4 z+8,
  TestID -> "sum-resultant"]
VerificationTest[
  ProductPolynomial[x^3+x+1,x^3-x+1,x,z],
  z^9+2 z^7-3 z^6+z^5-z^4+3 z^3-z-1,
  TestID -> "product-resultant"]

VerificationTest[
  Module[{a=Root[-1-#+3 #^3-#^4+#^5-3 #^6+2 #^7+#^9&,1],r},
    r=PairFromPolynomial[a,x^3+x+1,x,"Product",3];
    Lookup[r,{"MaximumDegree","GlobalOptimal"}]],
  {3,True}, TestID -> "recover-product-pair"]
VerificationTest[
  Module[{a=Root[8-4 #+24 #^2-15 #^3+3 #^5+6 #^6+#^9&,1],r},
    r=SearchRootDecomposition[a,"Sum",3,1,2];
    Lookup[r,{"MaximumDegree","GlobalOptimal"}]],
  {3,True}, TestID -> "discover-sum-with-height-one-search"]
VerificationTest[
  Module[{r=CompleteSumDecomposition[Sqrt[2]+Sqrt[3]]},
    Lookup[r,{"MaximumDegree","GlobalOptimal"}]],
  {2,True}, TestID -> "complete-sum-biquadratic"]
VerificationTest[
  Module[{r=CompleteTwoFactorDecomposition[Sqrt[2]+Sqrt[3]]},
    Lookup[r,{"MaximumDegree","OptimalAmongTwoFactors"}]],
  {2,True}, TestID -> "complete-two-factor-biquadratic"]
VerificationTest[
  Lookup[CheckDecomposition[(1+Sqrt[2]) (1+Sqrt[3]) (1+Sqrt[5]),
    {1+Sqrt[2],1+Sqrt[3],1+Sqrt[5]},"Product"],
    {"MaximumDegree","GlobalOptimal"}],
  {2,True}, TestID -> "three-factor-global-certificate"]

(* Expensive tests are separately available in ExtendedTests.wlt. *)
